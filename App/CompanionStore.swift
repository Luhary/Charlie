import Foundation
import SwiftUI

@MainActor
final class CompanionStore: ObservableObject {
    static let shared = CompanionStore()

    enum PendingAction { case listen, type }

    @Published var mood: CompanionMood = .idle
    @Published var lastAnswer = "Привет. Я Чарли. Тапни по мне и скажи что-нибудь…"
    @Published var liveTranscript = ""
    @Published var input = ""
    @Published var pendingAction: PendingAction?

    private let listener = SpeechListener()
    private let location = LocationOnce()
    private let speaker = Speaker()
    private var history: [ChatMessage] = []

    private init() {
        UserDefaults.standard.register(defaults: [Prefs.speak: true])

        listener.onTranscript = { [weak self] text in
            self?.liveTranscript = text
        }
        listener.onFinished = { [weak self] text in
            self?.handleVoice(text)
        }
        speaker.onFinish = { [weak self] in
            self?.react(.smirk, "Чарли здесь 🖤")
        }
    }

    // MARK: действия

    func handle(url: URL) {
        switch url.host {
        case "listen": pendingAction = .listen
        case "type": pendingAction = .type
        default: break
        }
    }

    func startListening() {
        speaker.stop()
        Task {
            // маленькая пауза, чтобы приложение успело стать активным (например, после Action Button)
            try? await Task.sleep(nanoseconds: 300_000_000)
            liveTranscript = ""
            setMood(.listening, "Слушаю…")
            if let error = await listener.start() {
                lastAnswer = error
                setMood(.idle, "Чарли здесь 🖤")
            }
        }
    }

    func ask(_ text: String) {
        // «как добраться до …», «где ближайший …» — это не к нейронке, а сразу в карты
        if let command = MapCommand.parse(text) {
            openMaps(command)
            return
        }
        setMood(.thinking, "Думаю…")
        Task {
            do {
                let answer = try await AIClient.shared.ask(text, history: history)
                history.append(ChatMessage(role: "user", content: text))
                history.append(ChatMessage(role: "assistant", content: answer))
                lastAnswer = answer
                if UserDefaults.standard.bool(forKey: Prefs.speak) {
                    setMood(.speaking, answer)
                    speaker.speak(answer)
                } else {
                    setMood(.idle, answer)
                }
            } catch {
                lastAnswer = error.localizedDescription
                react(.surprised, "Что-то пошло не так", seconds: 3)
            }
        }
    }

    private func handleVoice(_ text: String) {
        liveTranscript = ""
        if text.isEmpty {
            setMood(.idle, "Чарли здесь 🖤")
        } else {
            ask(text)
        }
    }

    func setMood(_ newMood: CompanionMood, _ message: String) {
        mood = newMood
        Task { await LiveActivityManager.shared.update(mood: newMood, message: message) }
    }

    private func openMaps(_ command: MapCommand) {
        lastAnswer = command.confirmation
        setMood(.thinking, command.confirmation)
        Task {
            let provider = UserDefaults.standard.string(forKey: Prefs.maps) ?? "yandex"
            let url = await MapsRouter.url(for: command, provider: provider, location: location)
            UIApplication.shared.open(url) { [weak self] ok in
                Task { @MainActor in
                    if ok {
                        self?.react(.smirk, "Открыла карты")
                    } else {
                        self?.lastAnswer = "Не получилось открыть карты."
                        self?.react(.surprised, "Карты не открылись", seconds: 3)
                    }
                }
            }
        }
    }

    /// Короткая реакция (ухмылка, удивление) и возврат в покой.
    func react(_ reaction: CompanionMood, _ message: String, seconds: Double = 2.5) {
        setMood(reaction, message)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if mood == reaction { setMood(.idle, "Чарли здесь 🖤") }
        }
    }
}
