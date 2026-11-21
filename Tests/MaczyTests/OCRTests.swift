import XCTest
import CoreGraphics
import AppKit
@testable import MaczyKit

@MainActor
final class OCRTests: XCTestCase {

    private func createTextImage(text: String, width: Int = 400, height: Int = 120) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        // Solid white background
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Push graphics context to draw text via NSAttributedString
        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext

        let font = NSFont.systemFont(ofSize: 32, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let nsString = NSString(string: text)
        nsString.draw(at: NSPoint(x: 20, y: 35), withAttributes: attrs)

        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    private func createBlankImage(width: Int = 100, height: Int = 100) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        context.setFillColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testRecognizeTextFromRenderedImage() async throws {
        let expectedText = "Maczy Apple Silicon"
        let testImage = createTextImage(text: expectedText)

        let engine = VisionOCREngine.shared
        let result = try await engine.recognizeText(in: testImage, level: .accurate)

        XCTAssertFalse(result.isEmpty, "OCR result should not be empty")
        XCTAssertGreaterThan(result.lines.count, 0, "Should have detected at least one line")

        let recognizedNormalized = result.fullText.lowercased()
        XCTAssertTrue(
            recognizedNormalized.contains("maczy") || recognizedNormalized.contains("apple") || recognizedNormalized.contains("silicon"),
            "OCR result '\(result.fullText)' should contain expected words"
        )
        XCTAssertGreaterThan(result.durationMs, 0.0)
    }

    func testRecognizeTextBlankImageReturnsEmpty() async throws {
        let blankImage = createBlankImage()
        let engine = VisionOCREngine.shared

        let result = try await engine.recognizeText(in: blankImage, level: .fast)
        XCTAssertTrue(result.isEmpty, "Blank image OCR should be empty")
        XCTAssertEqual(result.lines.count, 0)
    }

    func testSupportedLanguagesAreAvailable() {
        let languages = VisionOCREngine.supportedLanguages
        XCTAssertFalse(languages.isEmpty, "Vision supported languages must not be empty")
        XCTAssertTrue(languages.contains { $0.hasPrefix("en") }, "English must be supported")
    }

    func testOCRRecognitionLevels() {
        XCTAssertEqual(OCRRecognitionLevel.accurate.vnLevel, .accurate)
        XCTAssertEqual(OCRRecognitionLevel.fast.vnLevel, .fast)
    }

    func testCopyOCRTextToPasteboard() {
        let engine = VisionOCREngine.shared
        let sample = "Maczy Vision OCR Output Test"

        let copied = engine.copyToPasteboard(sample)
        XCTAssertTrue(copied)

        let pasteboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardString, sample)

        // Empty copy should return false
        XCTAssertFalse(engine.copyToPasteboard(""))
    }
}
