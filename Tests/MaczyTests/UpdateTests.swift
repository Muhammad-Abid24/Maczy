import XCTest
@testable import MaczyKit

@MainActor
final class UpdateTests: XCTestCase {

    func testSemanticVersionParsingAndComparison() {
        let v1 = SemanticVersion("0.1.0")
        let v2 = SemanticVersion("0.2.0")
        let v3 = SemanticVersion("1.0.0")
        let v3Beta = SemanticVersion("1.0.0-beta.1")
        let vPrefixed = SemanticVersion("v1.2.3")

        XCTAssertNotNil(v1)
        XCTAssertNotNil(v2)
        XCTAssertNotNil(v3)
        XCTAssertNotNil(v3Beta)
        XCTAssertNotNil(vPrefixed)

        XCTAssertTrue(v1! < v2!)
        XCTAssertTrue(v2! < v3!)
        XCTAssertTrue(v3Beta! < v3!)
        XCTAssertEqual(vPrefixed!.major, 1)
        XCTAssertEqual(vPrefixed!.minor, 2)
        XCTAssertEqual(vPrefixed!.patch, 3)

        XCTAssertNil(SemanticVersion(""))
        XCTAssertNil(SemanticVersion("invalid"))
    }

    func testUpdateChannelURLs() {
        XCTAssertTrue(UpdateChannel.stable.appcastURL.absoluteString.hasSuffix("appcast-stable.xml"))
        XCTAssertTrue(UpdateChannel.beta.appcastURL.absoluteString.hasSuffix("appcast-beta.xml"))
        XCTAssertTrue(UpdateChannel.nightly.appcastURL.absoluteString.hasSuffix("appcast-nightly.xml"))
    }

    func testAppcastItemSignatureValidation() {
        let validItem = AppcastItem(
            title: "Maczy 0.2.0",
            version: "0.2.0",
            buildNumber: "15",
            downloadURL: URL(string: "https://example.com/maczy.dmg")!,
            ed25519Signature: "ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890"
        )
        XCTAssertTrue(validItem.hasValidSignatureMetadata)

        let unsignedItem = AppcastItem(
            title: "Maczy 0.2.0",
            version: "0.2.0",
            buildNumber: "15",
            downloadURL: URL(string: "https://example.com/maczy.dmg")!,
            ed25519Signature: ""
        )
        XCTAssertFalse(unsignedItem.hasValidSignatureMetadata)

        let shortSignatureItem = AppcastItem(
            title: "Maczy 0.2.0",
            version: "0.2.0",
            buildNumber: "15",
            downloadURL: URL(string: "https://example.com/maczy.dmg")!,
            ed25519Signature: "short"
        )
        XCTAssertFalse(shortSignatureItem.hasValidSignatureMetadata)
    }

    func testAppcastXMLParsing() throws {
        let xmlString = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
                <title>Maczy Changelog</title>
                <item>
                    <title>Maczy 0.2.0</title>
                    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
                    <sparkle:releaseNotesLink>https://example.com/release-notes.html</sparkle:releaseNotesLink>
                    <enclosure
                        url="https://example.com/Maczy-0.2.0.dmg"
                        sparkle:version="25"
                        sparkle:shortVersionString="0.2.0"
                        sparkle:edSignature="G1K2L3M4N5O6P7Q8R9S0T1U2V3W4X5Y6Z7A8B9C0D1E2F3"
                        length="15728640"
                        type="application/octet-stream" />
                </item>
            </channel>
        </rss>
        """

        let parser = AppcastParser(xmlData: xmlString.data(using: .utf8)!)
        let items = try parser.parse()

        XCTAssertEqual(items.count, 1)
        let first = items[0]
        XCTAssertEqual(first.version, "0.2.0")
        XCTAssertEqual(first.buildNumber, "25")
        XCTAssertEqual(first.downloadURL.absoluteString, "https://example.com/Maczy-0.2.0.dmg")
        XCTAssertEqual(first.minimumSystemVersion, "14.0")
        XCTAssertTrue(first.hasValidSignatureMetadata)
        XCTAssertEqual(first.fileSize, 15728640)
    }

    func testUpdateManagerWithUpToDateResult() async {
        let mock = MockUpdateCheckerProvider(cannedResult: .upToDate(currentVersion: "0.1.0"))
        let manager = UpdateManager(checkerProvider: mock, currentVersion: "0.1.0", currentBuild: "1")

        XCTAssertEqual(manager.status, .idle)
        let status = await manager.checkForUpdates()

        XCTAssertEqual(status, .upToDate(version: "0.1.0"))
        XCTAssertEqual(mock.checkCount, 1)
        XCTAssertNotNil(manager.lastCheckedDate)
    }

    func testUpdateManagerWithAvailableUpdate() async {
        let item = AppcastItem(
            title: "Maczy 0.3.0",
            version: "0.3.0",
            buildNumber: "30",
            downloadURL: URL(string: "https://example.com/maczy.dmg")!,
            ed25519Signature: "ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890"
        )
        let mock = MockUpdateCheckerProvider(cannedResult: .updateAvailable(latest: item, currentVersion: "0.1.0"))
        let manager = UpdateManager(checkerProvider: mock, currentVersion: "0.1.0", currentBuild: "1")

        let status = await manager.checkForUpdates()
        XCTAssertEqual(status, .updateAvailable(item: item))
    }

    func testUpdateManagerFailsClosedOnUnsignedUpdate() async {
        // Security invariant: If an appcast contains an update missing an Ed25519 signature,
        // UpdateManager MUST reject it and report an error rather than offering the download.
        let unsignedItem = AppcastItem(
            title: "Maczy 0.3.0 Rogue",
            version: "0.3.0",
            buildNumber: "30",
            downloadURL: URL(string: "https://example.com/maczy.dmg")!,
            ed25519Signature: "" // unsigned!
        )
        let mock = MockUpdateCheckerProvider(cannedResult: .updateAvailable(latest: unsignedItem, currentVersion: "0.1.0"))
        let manager = UpdateManager(checkerProvider: mock, currentVersion: "0.1.0", currentBuild: "1")

        let status = await manager.checkForUpdates()
        switch status {
        case .error(let msg):
            XCTAssertTrue(msg.contains("Ed25519") || msg.contains("Security violation"))
        default:
            XCTFail("Expected error due to missing Ed25519 signature, got \(status)")
        }
    }

    func testChannelSwitchingAndAutoCheckToggle() {
        let mock = MockUpdateCheckerProvider()
        let manager = UpdateManager(checkerProvider: mock)

        XCTAssertEqual(manager.selectedChannel, .stable)
        manager.setChannel(.beta)
        XCTAssertEqual(manager.selectedChannel, .beta)

        manager.setChannel(.nightly)
        XCTAssertEqual(manager.selectedChannel, .nightly)

        XCTAssertTrue(manager.automaticallyChecksForUpdates)
        manager.setAutomaticallyChecksForUpdates(false)
        XCTAssertFalse(manager.automaticallyChecksForUpdates)
    }

    func testAppStateDispatchCheckForUpdates() {
        let mock = MockUpdateCheckerProvider(cannedResult: .upToDate(currentVersion: "0.1.0"))
        let updateManager = UpdateManager(checkerProvider: mock)
        let appState = AppState(updateManager: updateManager)

        let result = appState.dispatch(.checkForUpdates)
        XCTAssertTrue(result.ok)
        XCTAssertEqual(appState.status(for: .updates)?.runtimeState, .running)
    }
}
