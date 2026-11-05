import Foundation
import Speech
import AVFoundation

/// Распознавание речи ТОЛЬКО на устройстве. Слушает, пока ты говоришь, и сам останавливается после паузы.
final class SpeechListener {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private(set) var isListening = false
    private var transcript = ""

    var onTranscript: ((String) -> Void)?
    var onFinished: ((String) -> Void)?   // вызывается всегда при остановке (текст может быть пустым)

    /// Возвращает текст ошибки или nil, если всё запустилось.
    func start() async -> String? {
        guard !isListening else { return nil }

        let speechOK = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else { return "Нет доступа к микрофону или распознаванию речи (Настройки → Чарли)." }

        guard let recognizer, recognizer.isAvailable else { return "Распознавание речи сейчас недоступно." }
        guard recognizer.supportsOnDeviceRecognition else {
            return "Нет русской диктовки на устройстве. Включи: Настройки → Основные → Клавиатура → Диктовка (и скачай русский)."
        }

        transcript = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return "Не удалось включить микрофон."
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true   // аудио никуда не уходит
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return "Не удалось запустить запись."
        }

        isListening = true
        restartTimer(seconds: 8)   // если вообще ничего не сказал

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.onTranscript?(self.transcript)
                    self.restartTimer(seconds: 1.8)   // пауза после речи = конец фразы
                    if result.isFinal { self.finish() }
                }
                if error != nil { self.finish() }
            }
        }
        return nil
    }

    func finish() {
        guard isListening else { return }
        isListening = false
        timer?.invalidate()
        timer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinished?(transcript.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func restartTimer(seconds: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }
}
