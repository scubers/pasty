import AppKit
import Foundation
import PastyCore
import Vision
import Combine

final class OCRService {
    static let shared = OCRService()

    private struct TaskPayload: Decodable {
        let id: String
        let imagePath: String
    }

    private let queue = DispatchQueue(label: "OCRService", qos: .background)
    private var isProcessing = false
    private var started = false
    private var imageCaptureObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        SettingsManager.shared.$settings
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
            if !SettingsManager.shared.settings.ocr.enabled {
                return
            }
            self.started = true
            self.observeImageCapturedNotification()
            self.scheduleNextCheck(after: 5)
        }
    }

    deinit {
        if let imageCaptureObserver {
            NotificationCenter.default.removeObserver(imageCaptureObserver)
        }
    }

    private func observeImageCapturedNotification() {
        imageCaptureObserver = NotificationCenter.default.addObserver(
            forName: .clipboardImageCaptured,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                self?.processNext(force: true)
            }
        }
    }

    private func processNext(force: Bool = false) {
        if !SettingsManager.shared.settings.ocr.enabled {
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
                    LoggerService.info("OCRService: Task \(task.id) completed")
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
        let absolutePath = SettingsManager.shared.clipboardData.appendingPathComponent(imagePath).path
        guard let image = NSImage(contentsOfFile: absolutePath) else {
            completion(.failure(NSError(domain: "OCRService", code: -10)))
            return
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "OCRService", code: -11)))
            return
        }

        let timeout = DispatchWorkItem {
            completion(.failure(NSError(domain: "OCRService", code: -12)))
        }

        queue.asyncAfter(deadline: .now() + 30, execute: timeout)

        let request = VNRecognizeTextRequest { request, error in
            if timeout.isCancelled {
                return
            }
            timeout.cancel()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            LoggerService.debug("OCRService: OCR processing finished in \(String(format: "%.3f", duration))s")

            if let error {
                completion(.failure(error))
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            var confidenceSum: Float = 0
            var confidenceCount: Float = 0
            var lines: [String] = []

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else {
                    continue
                }
                confidenceSum += candidate.confidence
                confidenceCount += 1
                lines.append(candidate.string)
            }

            let averageConfidence = confidenceCount == 0 ? 0 : confidenceSum / confidenceCount
            let threshold = SettingsManager.shared.settings.ocr.confidenceThreshold
            if averageConfidence < threshold {
                completion(.success(""))
                return
            }

            let text = lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            completion(.success(text))
        }
        
        let settings = SettingsManager.shared.settings.ocr
        request.recognitionLevel = settings.recognitionLevel == "fast" ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = settings.languages

        if #available(macOS 13.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            timeout.cancel()
            completion(.failure(error))
        }
    }
}
