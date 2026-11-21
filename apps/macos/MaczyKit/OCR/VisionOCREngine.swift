import Foundation
import CoreGraphics
import AppKit
import Vision

/// Recognition accuracy level for Vision OCR processing.
public enum OCRRecognitionLevel: String, Sendable, CaseIterable {
    case accurate
    case fast

    public var vnLevel: VNRequestTextRecognitionLevel {
        switch self {
        case .accurate: return .accurate
        case .fast: return .fast
        }
    }
}

/// Represents a recognized text line with confidence and spatial bounding box.
public struct OCRLineResult: Sendable, Equatable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Consolidated output of an OCR extraction operation.
public struct OCRResult: Sendable {
    public let fullText: String
    public let lines: [OCRLineResult]
    public let candidateCount: Int
    public let durationMs: Double

    public init(fullText: String, lines: [OCRLineResult], candidateCount: Int, durationMs: Double) {
        self.fullText = fullText
        self.lines = lines
        self.candidateCount = candidateCount
        self.durationMs = durationMs
    }

    public var isEmpty: Bool {
        fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Errors occurring during on-device Vision OCR recognition.
public enum OCRError: Error, LocalizedError, Equatable {
    case invalidImage
    case recognitionFailed(String)
    case noTextFound

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the image for OCR recognition."
        case .recognitionFailed(let reason):
            return "Vision OCR failed: \(reason)"
        case .noTextFound:
            return "No readable text detected in the provided image."
        }
    }
}

/// Hardware-accelerated, 100% on-device text recognition engine using Apple Vision Framework.
public final class VisionOCREngine: @unchecked Sendable {
    public static let shared = VisionOCREngine()

    public init() {}

    /// Supported recognition languages on Apple Silicon macOS.
    public static var supportedLanguages: [String] {
        (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? ["en-US"]
    }

    /// Performs offline text extraction from a CGImage using the Apple Neural Engine.
    public func recognizeText(
        in cgImage: CGImage,
        level: OCRRecognitionLevel = .accurate,
        languages: [String] = ["en-US", "id-ID"],
        minimumConfidence: Float = 0.2
    ) async throws -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(fullText: "", lines: [], candidateCount: 0, durationMs: elapsedMs))
                    return
                }

                var extractedLines: [OCRLineResult] = []
                var rawLineStrings: [String] = []

                // Sort observations top-to-bottom (Vision coordinate origin is bottom-left, so higher Y is higher on page)
                let sortedObservations = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

                for obs in sortedObservations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    guard topCandidate.confidence >= minimumConfidence else { continue }

                    let lineText = topCandidate.string.trimmingCharacters(in: .whitespaces)
                    guard !lineText.isEmpty else { continue }

                    let lineResult = OCRLineResult(
                        text: lineText,
                        confidence: topCandidate.confidence,
                        boundingBox: obs.boundingBox
                    )
                    extractedLines.append(lineResult)
                    rawLineStrings.append(lineText)
                }

                let fullText = rawLineStrings.joined(separator: "\n")
                let result = OCRResult(
                    fullText: fullText,
                    lines: extractedLines,
                    candidateCount: extractedLines.count,
                    durationMs: elapsedMs
                )
                continuation.resume(returning: result)
            }

            request.recognitionLevel = level.vnLevel
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// Copies extracted text to the macOS system pasteboard.
    @discardableResult
    public func copyToPasteboard(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
