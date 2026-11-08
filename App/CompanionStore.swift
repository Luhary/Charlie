import Foundation
import SwiftUI
import UIKit

/// То, что Чарли поняла, но ждёт твоего подтверждения (ошибка в распознавании дороже лишней кнопки).
enum PendingCommand {
    case event(PendingEvent)
    case alarm(date: Date, label: String)
    case chooseContact([ContactMatch])
}

@MainActor
final class CompanionStore: ObservableObject {
    static let shared = CompanionStore()

    enum PendingAction { case listen, type }

    @Published var mood: CompanionMood = .idle
    @Published var lastAnswer = "Привет. Я Чарли. Тапни по мне и скажи что-нибудь…"
    @Published var liveTranscript = ""
    @Published var input = ""
    @Published var pendingAction: PendingAction?
    @Published var pending: PendingCommand?

    private let listener = SpeechListener()
    private let speaker = Speaker()
    private let location = LocationOnce()
    private var history: [ChatMessage] = []
    private var askTask: Task<Void, Never>?
    private var expectNote = false
    private let home = "Чарли здесь 🖤"

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

    // MARK: вход

    func handle(url: URL) {
        switch url.host {
        case "listen": pendingAction = .listen
        case "type": pendingAction = .type
        default: break
        }
    }

    func startListening() {
        askTask?.cancel()   // начала говорить снова — старый ответ уже не нужен
        speaker.stop()
        Task {
            // маленькая пауза, чтобы приложение успело стать активным (например, после Action Button)
            try? await Task.sleep(nanoseconds: 300_000_000)
            liveTranscript = ""
            setMood(.listening, "Слушаю…")
            if let error = await listener.start() {
                lastAnswer = error
                setMood(.idle, home)
            }
        }
    }

    private func handleVoice(_ text: String) {
        liveTranscript = ""
        if text.isEmpty {
            setMood(.idle, home)
        } else {
            ask(text)
        }
    }

    /// Единая точка входа для голоса и текста: сначала команды, потом обычный чат.
    func ask(_ text: String) {
        pending = nil

        if expectNote {                                   // «запиши заметку» → «что записать?» → текст
            expectNote = false
            saveNote(text)
            return
        }
        if let body = NoteCommand.parse(text) { handleNote(body); return }
        if let target = CallCommand.parse(text) { handleCall(target); return }
        if let seconds = LockCommand.parse(text) { handleLock(seconds); return }
        if AlarmIntent.looksLikeAlarm(text) { handleAlarm(text); return }
        if let command = MapCommand.parse(text) { openMaps(command); return }
        if CalendarIntent.looksLikeEvent(text) { handleCalendar(text); return }
        chat(text)
    }

    // MARK: обычный чат

    private func chat(_ text: String) {
        setMood(.thinking, "Думаю…")
        askTask?.cancel()
        askTask = Task {
            do {
                let answer = try await AIClient.shared.ask(text, history: history)
                guard !Task.isCancelled else { return }
                history.append(ChatMessage(role: "user", content: text))
                history.append(ChatMessage(role: "assistant", content: answer))
                lastAnswer = answer
                if UserDefaults.standard.bool(forKey: Prefs.speak) {
                    setMood(.speaking, answer)
                    speaker.speak(answer)
                    watchSpeech()
                } else {
                    setMood(.idle, answer)
                }
            } catch {
                guard !Task.isCancelled else { return }
                lastAnswer = error.localizedDescription
                react(.surprised, "Что-то пошло не так", seconds: 3)
            }
        }
    }

    /// Страховка: если озвучка не запустилась, Чарли не должна «говорить» вечно.
    private func watchSpeech() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if mood == .speaking && !speaker.isSpeaking {
                react(.smirk, home)
            }
        }
    }

    // MARK: заметки

    private func handleNote(_ body: String) {
        if body.isEmpty {
            expectNote = true
            lastAnswer = "Что записать?"
            startListening()
        } else {
            saveNote(body)
        }
    }

    private func saveNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).firstUppercased
        guard !t.isEmpty else { return }
        NoteStore.shared.add(t)
        lastAnswer = "Записала заметку:\n\(t)"
        react(.smirk, "Заметка записана")
    }

    // MARK: звонок

    private func handleCall(_ target: CallTarget) {
        switch target {
        case .number(let number):
            dial(number, name: number)
        case .name(let query):
            setMood(.thinking, "Ищу контакт…")
            askTask?.cancel()
            askTask = Task {
                do {
                    let matches = try await ContactsService.find(query)
                    guard !Task.isCancelled else { return }
                    if matches.isEmpty {
                        lastAnswer = "Не нашла в контактах: \(query)"
                        react(.surprised, "Контакт не найден", seconds: 3)
                    } else if matches.count == 1 {
                        dial(matches[0].number, name: matches[0].name)
                    } else {
                        pending = .chooseContact(Array(matches.prefix(4)))
                        lastAnswer = "Кому именно позвонить?"
                        setMood(.idle, "Кому позвонить?")
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    lastAnswer = error.localizedDescription
                    react(.surprised, "Нет доступа к контактам", seconds: 3)
                }
            }
        }
    }

    private func dial(_ number: String, name: String) {
        guard let url = URL(string: "tel://\(number)") else { return }
        lastAnswer = "Звоню: \(name)"
        react(.smirk, "Звоню: \(name)")
        UIApplication.shared.open(url)   // iOS сам спросит «Позвонить?»
    }

    func choose(_ match: ContactMatch) {
        pending = nil
        dial(match.number, name: match.name)
    }

    // MARK: блокировка экрана (через «Команду» Shortcuts: у приложений нет права блокировать экран)

    private func handleLock(_ seconds: Int) {
        let saved = UserDefaults.standard.string(forKey: Prefs.lockShortcut) ?? ""
        let name = saved.isEmpty ? Prefs.defaultLockShortcut : saved
        var comps = URLComponents(string: "shortcuts://run-shortcut")!
        comps.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: String(seconds))
        ]
        guard let url = comps.url else { return }
        lastAnswer = seconds == 0 ? "Блокирую экран." : "Заблокирую экран через \(LockCommand.humanDelay(seconds))."
        react(.smirk, "Блокирую экран")
        UIApplication.shared.open(url)
    }

    // MARK: будильник и таймер

    private func handleAlarm(_ text: String) {
        setMood(.thinking, "Ставлю…")
        askTask?.cancel()
        askTask = Task {
            do {
                let request = try await AlarmIntent.extract(text)
                guard !Task.isCancelled else { return }
                guard let request else { chat(text); return }   // оказалось, это не про будильник
                switch request {
                case .alarm(let date, let label):
                    pending = .alarm(date: date, label: label)
                    lastAnswer = "Поставить будильник?\n" + AlarmIntent.describe(date: date, label: label)
                    setMood(.idle, "Поставить будильник?")
                case .timer(let seconds, let label):
                    try await AlarmService.startTimer(seconds: seconds, label: label)
                    lastAnswer = "Таймер на \(AlarmIntent.humanDuration(seconds)) запущен."
                    react(.smirk, "Таймер запущен")
                }
            } catch {
                guard !Task.isCancelled else { return }
                lastAnswer = error.localizedDescription
                react(.surprised, "Не получилось", seconds: 3)
            }
        }
    }

    // MARK: карты

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

    // MARK: календарь

    private func handleCalendar(_ text: String) {
        setMood(.thinking, "Смотрю даты…")
        askTask?.cancel()
        askTask = Task {
            do {
                if let event = try await CalendarIntent.extract(text) {
                    guard !Task.isCancelled else { return }
                    pending = .event(event)
                    lastAnswer = "Записать в календарь?\n" + event.summary
                    setMood(.idle, "Записать в календарь?")
                } else {
                    guard !Task.isCancelled else { return }
                    chat(text)   // оказалось, это не про календарь — отвечаем как обычно
                }
            } catch {
                guard !Task.isCancelled else { return }
                lastAnswer = error.localizedDescription
                react(.surprised, "Что-то пошло не так", seconds: 3)
            }
        }
    }

    // MARK: подтверждение

    func confirmPending() {
        guard let command = pending else { return }
        pending = nil
        Task {
            do {
                switch command {
                case .event(let event):
                    try await CalendarService.save(event)
                    lastAnswer = "Записала:\n" + event.summary
                    react(.smirk, "Записала в календарь")
                case .alarm(let date, let label):
                    try await AlarmService.setAlarm(at: date, label: label)
                    lastAnswer = "Будильник поставлен:\n" + AlarmIntent.describe(date: date, label: label)
                    react(.smirk, "Будильник поставлен")
                case .chooseContact:
                    break
                }
            } catch {
                lastAnswer = error.localizedDescription
                react(.surprised, "Не получилось", seconds: 3)
            }
        }
    }

    func cancelPending() {
        pending = nil
        lastAnswer = "Хорошо, отменяю."
        setMood(.idle, home)
    }

    // MARK: настроение

    func setMood(_ newMood: CompanionMood, _ message: String) {
        mood = newMood
        Task { await LiveActivityManager.shared.update(mood: newMood, message: message) }
    }

    /// Короткая реакция (ухмылка, удивление) и возврат в покой.
    func react(_ reaction: CompanionMood, _ message: String, seconds: Double = 2.5) {
        setMood(reaction, message)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if mood == reaction { setMood(.idle, home) }
        }
    }
}
