import Foundation

public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate(currentVersion: String)
    case updateAvailable(latest: AppcastItem, currentVersion: String)
}

public enum UpdateError: LocalizedError, Equatable, Sendable {
    case invalidFeedURL
    case unsignedUpdateItem(version: String)
    case unsupportedSystemVersion(required: String, current: String)
    case parseError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "Invalid update feed URL."
        case .unsignedUpdateItem(let version):
            return "Security violation: Update item \(version) lacks a valid Ed25519 signature."
        case let .unsupportedSystemVersion(required, current):
            return "Update requires macOS \(required), but host is running macOS \(current)."
        case .parseError(let msg):
            return "Failed to parse appcast: \(msg)"
        case .networkError(let msg):
            return "Network check failed: \(msg)"
        }
    }
}

public protocol UpdateCheckerProvider: Sendable {
    func checkForUpdates(
        channel: UpdateChannel,
        currentVersion: String
    ) async throws -> UpdateCheckResult
}

public final class MockUpdateCheckerProvider: UpdateCheckerProvider, @unchecked Sendable {
    private let lock = NSLock()
    public var shouldThrowError: UpdateError?
    public var cannedResult: UpdateCheckResult?
    public var checkCount: Int = 0
    public var lastCheckedChannel: UpdateChannel?

    public init(cannedResult: UpdateCheckResult? = nil) {
        self.cannedResult = cannedResult
    }

    public func checkForUpdates(
        channel: UpdateChannel,
        currentVersion: String
    ) async throws -> UpdateCheckResult {
        try lock.withLock {
            checkCount += 1
            lastCheckedChannel = channel

            if let error = shouldThrowError {
                throw error
            }

            if let canned = cannedResult {
                return canned
            }

            return .upToDate(currentVersion: currentVersion)
        }
    }
}

public final class AppcastParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let xmlData: Data
    private var items: [AppcastItem] = []

    // State while parsing
    private var currentElement = ""
    private var currentTitle = ""
    private var currentVersion = ""
    private var currentBuild = ""
    private var currentReleaseNotes: URL?
    private var currentDownloadURL: URL?
    private var currentEdSignature = ""
    private var currentMinSystemVersion = "14.0"
    private var currentFileSize: Int64?
    private var isInsideItem = false

    public init(xmlData: Data) {
        self.xmlData = xmlData
    }

    public func parse() throws -> [AppcastItem] {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        if !parser.parse() {
            let errorMsg = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw UpdateError.parseError(errorMsg)
        }
        return items
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentVersion = ""
            currentBuild = ""
            currentReleaseNotes = nil
            currentDownloadURL = nil
            currentEdSignature = ""
            currentMinSystemVersion = "14.0"
            currentFileSize = nil
        } else if isInsideItem && elementName == "enclosure" {
            if let urlStr = attributeDict["url"], let url = URL(string: urlStr) {
                currentDownloadURL = url
            }
            if let sig = attributeDict["sparkle:edSignature"] ?? attributeDict["edSignature"] {
                currentEdSignature = sig
            }
            if let ver = attributeDict["sparkle:shortVersionString"] ?? attributeDict["shortVersionString"] {
                currentVersion = ver
            }
            if let build = attributeDict["sparkle:version"] ?? attributeDict["version"] {
                currentBuild = build
            }
            if let lengthStr = attributeDict["length"], let len = Int64(lengthStr) {
                currentFileSize = len
            }
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "sparkle:minimumSystemVersion", "minimumSystemVersion":
            currentMinSystemVersion = trimmed
        case "sparkle:releaseNotesLink", "releaseNotesLink":
            if let url = URL(string: trimmed) {
                currentReleaseNotes = url
            }
        default:
            break
        }
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            isInsideItem = false
            if let dlURL = currentDownloadURL, !currentVersion.isEmpty {
                let item = AppcastItem(
                    title: currentTitle.isEmpty ? "Maczy \(currentVersion)" : currentTitle,
                    version: currentVersion,
                    buildNumber: currentBuild.isEmpty ? "1" : currentBuild,
                    releaseNotesURL: currentReleaseNotes,
                    downloadURL: dlURL,
                    ed25519Signature: currentEdSignature,
                    minimumSystemVersion: currentMinSystemVersion,
                    publicationDate: Date(),
                    fileSize: currentFileSize
                )
                items.append(item)
            }
        }
    }
}
