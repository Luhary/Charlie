import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

enum AlarmRequest {
    case alarm(date: Date, label: String)
    case timer(seconds: TimeInterval, label: String)
}

enum AlarmError: LocalizedError {
    case denied
    var errorDescription: String? {
        "Нет доступа к будильникам. Разреши: Настройки → Чарли."
    }
}

enum AlarmIntent {
    private struct Extracted: Decodable {
        let kind: String
        let time: String?
        let seconds: Double?
        let label: String?
    }

    static func looksLikeAlarm(_ raw: String) -> Bool {
        raw.lowercased().range(of: "будильник|разбуди|таймер", options: .regularExpression) != nil
    }

    /// Просит нейронку превратить фразу в будильник или таймер. nil — это не про будильник.
    static func extract(_ text: String) async throws -> AlarmRequest? {
        let nowFormatter = DateFormatter()
        nowFormatter.locale = Locale(identifier: "ru_RU")
        nowFormatter.dateFormat = "EEEE, yyyy-MM-dd HH:mm"

        let system = """
        Ты разбираешь русскую просьбу про будильник или таймер. Сейчас: \(nowFormatter.string(from: Date())), часовой пояс \(TimeZone.current.identifier).
        Верни ТОЛЬКО JSON без пояснений и без markdown:
        {"kind": "alarm", "time": "YYYY-MM-DDTHH:mm", "seconds": 0, "label": ""}
        kind = "alarm": time это ближайший будущий момент («в 7 утра» = ближайшие 07:00, «в 7 вечера» = 19:00, «в половине седьмого» = 06:30, «через 20 минут» = сейчас плюс 20 минут). kind = "timer": seconds это длительность в секундах («полчаса» = 1800), time пустая строка. label это короткая подпись или пустая строка. Если это не про будильник или таймер, верни {"kind": "none"}.
        """

        let raw = try await AIClient.shared.oneShot(system: system, user: text)
        guard let a = raw.firstIndex(of: "{"), let b = raw.lastIndex(of: "}"), a < b,
              let data = String(raw[a...b]).data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Extracted.self, from: data) else { return nil }

        let label = (parsed.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch parsed.kind {
        case "alarm":
            guard let t = parsed.time, let date = parseDate(t), date > Date() else { return nil }
            return .alarm(date: date, label: label.isEmpty ? "Будильник" : label)
        case "timer":
            guard let s = parsed.seconds, s >= 1 else { return nil }
            return .timer(seconds: s, label: label.isEmpty ? "Таймер" : label)
        default:
            return nil
        }
    }

    static func describe(date: Date, label: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM yyyy, HH:mm"
        return "\(label)\n\(f.string(from: date))"
    }

    static func humanDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s) сек" }
        if s < 3600 { return "\(s / 60) мин" + (s % 60 == 0 ? "" : " \(s % 60) сек") }
        let h = s / 3600, m = (s % 3600) / 60
        return "\(h) ч" + (m == 0 ? "" : " \(m) мин")
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

/// Будильники и таймеры. На iOS 26+ это настоящие системные будильники (AlarmKit): звонят даже в беззвучном
/// режиме и под фокусом. Если AlarmKit недоступен, ставится обычное уведомление со звуком.
enum AlarmService {
    static func setAlarm(at date: Date, label: String) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try await viaAlarmKit(date: date, duration: nil, label: label)
            return
        }
        #endif
        Notifier.notify(title: "⏰ \(label)", body: "Будильник", after: max(1, date.timeIntervalSinceNow))
    }

    static func startTimer(seconds: TimeInterval, label: String) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try await viaAlarmKit(date: nil, duration: seconds, label: label)
            return
        }
        #endif
        Notifier.notify(title: "⏰ \(label)", body: "Время вышло", after: max(1, seconds))
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func viaAlarmKit(date: Date?, duration: TimeInterval?, label: String) async throws {
        let manager = AlarmManager.shared
        let state = try await manager.requestAuthorization()
        guard state == .authorized else { throw AlarmError.denied }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: label),
            stopButton: AlarmButton(text: "Стоп", textColor: .white, systemImageName: "stop.fill")
        )
        let attributes = AlarmAttributes<CharlieAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .red
        )

        if let date {
            _ = try await manager.schedule(id: UUID(), configuration: .alarm(schedule: .fixed(date), attributes: attributes))
        } else {
            _ = try await manager.schedule(id: UUID(), configuration: .timer(duration: duration ?? 60, attributes: attributes))
        }
    }
    #endif
}
