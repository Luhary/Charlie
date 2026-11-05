import AppIntents
import Foundation

/// Для Action Button: открывает приложение и сразу начинает слушать.
struct ListenIntent: AppIntent {
    static let title: LocalizedStringResource = "Слушать Чарли"
    static let description = IntentDescription("Открывает Чарли и начинает слушать голос.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CompanionStore.shared.pendingAction = .listen
        return .result()
    }
}

/// Для Команд: «Спросить компаньона» с текстом (например, из диктовки). Работает без открытия приложения.
struct AskTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Спросить Чарли"
    static let description = IntentDescription("Отправляет вопрос в нейронку и возвращает ответ.")

    @Parameter(title: "Вопрос")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Спросить Чарли \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = try await AIClient.shared.ask(question, history: [])
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// Для автоматизации «Когда открыто приложение»: реагирует и ставит таймер.
struct AppOpenedIntent: AppIntent {
    static let title: LocalizedStringResource = "Реакция на открытое приложение"
    static let description = IntentDescription("Пишет уведомление и ставит таймер на выход из приложения.")

    @Parameter(title: "Приложение")
    var appName: String

    @Parameter(title: "Минут", default: 5)
    var minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Я открыл \(\.$appName) на \(\.$minutes) мин")
    }

    func perform() async throws -> some IntentResult {
        let m = max(1, minutes)
        Notifier.notify(title: "Опа, ты в \(appName) 👀",
                        body: "Чарли всё видит. Давай ненадолго — таймер на \(m) мин.",
                        after: 1)
        Notifier.notify(title: "⏰ \(m) мин прошло",
                        body: "Пора выходить из \(appName).",
                        after: Double(m) * 60)
        return .result()
    }
}

struct CompanionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListenIntent(),
            phrases: ["Listen with \(.applicationName)"],
            shortTitle: "Слушать Чарли",
            systemImageName: "mic.fill"
        )
    }
}
