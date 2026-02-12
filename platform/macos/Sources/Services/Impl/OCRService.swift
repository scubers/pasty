import AppKit
import Foundation
import PastyCore
import Vision
import Combine

final class OCRService {
    private struct TaskPayload: Decodable {
        let id: String
        let imagePath: String
    }

    private struct OCRPassResult {
        let text: String
        let averageConfidence: Float
        let quality: Float

        var score: Float {
            // Balance engine confidence and content readability to avoid mojibake-like garbage.
            (averageConfidence * 0.65) + (quality * 0.35)
        }
    }

    private let queue = DispatchQueue(label: "OCRService", qos: .background)
    private var isProcessing = false
    private var started = false
    private var cancellables = Set<AnyCancellable>()
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        coordinator.$settings
            .map(\.ocr.enabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled {
                    self?.start()
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        queue.async {
            guard !self.started else {
                return
            }
            // Check if enabled
            if !self.coordinator.settings.ocr.enabled {
                return
            }
            self.started = true
            self.observeImageCapturedNotification()
            self.scheduleNextCheck(after: 5)
        }
    }

    private func observeImageCapturedNotification() {
        coordinator.events
            .sink { [weak self] event in
                guard case .clipboardImageCaptured = event else {
                    return
                }
                self?.queue.async {
                    self?.processNext(force: true)
                }
            }
            .store(in: &cancellables)
    }

    private func processNext(force: Bool = false) {
        if !coordinator.settings.ocr.enabled {
            scheduleNextCheck(after: 10)
            return
        }

        if isProcessing {
            if force {
                scheduleNextCheck(after: 0.6)
            }
            return
        }

        guard let task = getNextTask() else {
            scheduleNextCheck(after: 10)
            return
        }
        
        LoggerService.info("OCRService: Starting task \(task.id)")

        isProcessing = true
        guard markProcessing(id: task.id) else {
            LoggerService.error("OCRService: Failed to mark processing for task \(task.id)")
            isProcessing = false
            scheduleNextCheck(after: 2)
            return
        }

        performOCR(imagePath: task.imagePath) { [weak self] result in
            guard let self else {
                return
            }
            self.queue.async {
                switch result {
                case let .success(text):
                    LoggerService.info("OCRService: Task \(task.id) completed: \(text)")
                    _ = self.reportSuccess(id: task.id, text: text)
                case let .failure(error):
                    LoggerService.error("OCRService: Task \(task.id) failed: \(error.localizedDescription)")
                    _ = self.reportFailure(id: task.id)
                }

                self.isProcessing = false
                self.processNext()
            }
        }
    }

    private func scheduleNextCheck(after seconds: TimeInterval) {
        queue.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.processNext()
        }
    }

    private func getNextTask() -> TaskPayload? {
        var outJson: UnsafeMutablePointer<CChar>?
        guard pasty_history_get_next_ocr_task(&outJson) else {
            return nil
        }
        guard let outJson else {
            return nil
        }

        defer {
            pasty_free_string(outJson)
        }

        let jsonString = String(cString: outJson)
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(TaskPayload.self, from: data)
    }

    private func markProcessing(id: String) -> Bool {
        id.withCString { pasty_history_ocr_mark_processing($0) }
    }

    private func reportSuccess(id: String, text: String) -> Bool {
        id.withCString { idPtr in
            text.withCString { textPtr in
                pasty_history_ocr_success(idPtr, textPtr)
            }
        }
    }

    private func reportFailure(id: String) -> Bool {
        id.withCString { pasty_history_ocr_failed($0) }
    }

    private func performOCR(imagePath: String, completion: @escaping (Result<String, Error>) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let absolutePath = coordinator.clipboardData.appendingPathComponent(imagePath).path
        guard let image = NSImage(contentsOfFile: absolutePath) else {
            completion(.failure(NSError(domain: "OCRService", code: -10)))
            return
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "OCRService", code: -11)))
            return
        }
        
        let settings = coordinator.settings.ocr
        let normalizedLanguages = normalizedRecognitionLanguages(from: settings.languages)

        do {
            let primary = try recognizeText(
                in: cgImage,
                recognitionLevel: settings.recognitionLevel == "fast" ? .fast : .accurate,
                languages: normalizedLanguages,
                usesLanguageCorrection: true,
                autoDetectLanguage: true
            )

            // Fallback pass for mixed-script short headlines where first pass can output garbage.
            let fallback = try recognizeText(
                in: cgImage,
                recognitionLevel: .accurate,
                languages: normalizedLanguages,
                usesLanguageCorrection: true,
                autoDetectLanguage: true
            )

            let best = primary.score >= fallback.score ? primary : fallback
            let threshold = settings.confidenceThreshold
            if best.averageConfidence < threshold && best.quality < 0.55 {
                completion(.success(""))
                return
            }

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            LoggerService.debug(
                "OCRService: OCR finished in \(String(format: "%.3f", duration))s " +
                "score=\(String(format: "%.3f", best.score)) conf=\(String(format: "%.3f", best.averageConfidence)) quality=\(String(format: "%.3f", best.quality))"
            )
            completion(.success(best.text))
        } catch {
            completion(.failure(error))
        }
    }

    private func normalizedRecognitionLanguages(from raw: [String]) -> [String] {
        let normalized = raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { code -> String in
                switch code.lowercased() {
                case "zh-ch", "zh_cn", "zh-cn", "zh":
                    return "zh-Hans"
                case "zh-tw", "zh_hk", "zh-hk":
                    return "zh-Hant"
                case "en":
                    return "en-US"
                default:
                    return code
                }
            }

        let deduplicated = Array(NSOrderedSet(array: normalized)) as? [String] ?? normalized
        return deduplicated.isEmpty ? ["en", "zh-Hans"] : deduplicated
    }

    private func recognizeText(
        in cgImage: CGImage,
        recognitionLevel: VNRequestTextRecognitionLevel,
        languages: [String],
        usesLanguageCorrection: Bool,
        autoDetectLanguage: Bool
    ) throws -> OCRPassResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection
        request.recognitionLanguages = languages
        request.minimumTextHeight = 0.01

        if #available(macOS 13.0, *) {
            request.revision = VNRecognizeTextRequest.currentRevision
            request.automaticallyDetectsLanguage = autoDetectLanguage
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        var confidenceSum: Float = 0
        var confidenceCount: Float = 0
        var lines: [String] = []

        for observation in observations {
            let candidates = observation.topCandidates(3)
            guard let bestCandidate = candidates.max(by: { lhs, rhs in
                candidateScore(lhs) < candidateScore(rhs)
            }) else {
                continue
            }

            confidenceSum += bestCandidate.confidence
            confidenceCount += 1
            lines.append(bestCandidate.string)
        }

        let text = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let averageConfidence = confidenceCount == 0 ? 0 : confidenceSum / confidenceCount
        let quality = textQuality(text)
        return OCRPassResult(text: text, averageConfidence: averageConfidence, quality: quality)
    }

    private func candidateScore(_ candidate: VNRecognizedText) -> Float {
        let quality = textQuality(candidate.string)
        return (candidate.confidence * 0.7) + (quality * 0.3)
    }

    private func textQuality(_ text: String) -> Float {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }

        let acceptable = CharacterSet.alphanumerics
            .union(.whitespacesAndNewlines)
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "，。！？；：、（）《》“”‘’【】·—…「」『』"))
            .union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
            .union(CharacterSet(charactersIn: "\u{3400}"..."\u{4DBF}"))

        let stronglySuspicious = CharacterSet(charactersIn: "†‡÷§ß¤¦¶")
        var acceptableCount = 0
        var suspiciousCount = 0
        var totalCount = 0

        for scalar in trimmed.unicodeScalars {
            totalCount += 1
            if stronglySuspicious.contains(scalar) {
                suspiciousCount += 1
            }
            if acceptable.contains(scalar) {
                acceptableCount += 1
            }
        }

        guard totalCount > 0 else {
            return 0
        }

        let acceptableRatio = Float(acceptableCount) / Float(totalCount)
        let suspiciousRatio = Float(suspiciousCount) / Float(totalCount)
        return max(0, min(1, acceptableRatio - suspiciousRatio * 0.7))
    }
}
