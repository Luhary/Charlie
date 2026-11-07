import Foundation
import EventKit

/// Событие, которое Чарли поняла из фразы и ещё не записала.
struct PendingEvent: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool

    /// Человеческая сводка для подтверждения: название, день (с годом) и время.
    var summary: String {
        let ru = Locale(identifier: "ru_RU")
        let day = DateFormatter()
        day.locale = ru
        day.dateFormat = "d MMMM yyyy"
        if allDay { return "\(title)\n\(day.string(from: start)), весь день" }
        let time = DateFormatter()
        time.locale = ru
        time.dateFormat = "HH:mm"
        return "\(title)\n\(day.string(from: start)), \(time.string(from: start))–\(time.string(from: end))"
    }
}

enum CalendarError: LocalizedError {
    case denied
    case noCalendar

    var errorDescription: String? {
        switch self {
        case .denied: return "Нет доступа к календарю. Разреши: Настройки → Чарли → Календари."
        case .noCalendar: return "Не нашла календарь, куда записать."
        }
    }
}

enum CalendarIntent {
    private struct Extracted: Decodable {
        let is_event: Bool
        let title: String?
        let start: String?
        let end: String?
        let all_day: Bool?
    }

    /// Дешёвая локальная проверка: есть и «календарное» слово, и дата/время.
    /// Если да, фразу разбирает нейронка; если она скажет «это не событие», фраза уйдёт в обычный чат.
    static func looksLikeEvent(_ raw: String) -> Bool {
        let t = raw.lowercased().replacingOccurrences(of: "ё", with: "е")
        let words = "календар|задач|событи|встреч|запланир|созвон|запиши|занеси|хочу|надо|нужно|планирую"
        let dates = "января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря|сегодня|завтра|послезавтра|понедельник|вторник|сред[уы]|четверг|пятниц[уы]|суббот[уы]|воскресенье|\\b(?:в|с|до|на|к)\\s+\\d{1,2}(?::\\d{2})?\\b|\\bчас(?:у|а|ов)?\\b|утра|вечера|дня"
        return t.range(of: words, options: .regularExpression) != nil
            && t.range(of: dates, options: .regularExpression) != nil
    }

    /// Просит нейронку превратить фразу в дату, время и название. Возвращает nil, если это не просьба записать событие.
    static func extract(_ text: String) async throws -> PendingEvent? {
        let nowFormatter = DateFormatter()
        nowFormatter.locale = Locale(identifier: "ru_RU")
        nowFormatter.dateFormat = "EEEE, yyyy-MM-dd HH:mm"

        let system = """
        Ты извлекаешь событие календаря из русской фразы. Сейчас: \(nowFormatter.string(from: Date())), часовой пояс \(TimeZone.current.identifier).
        Верни ТОЛЬКО JSON без пояснений и без markdown:
        {"is_event": true, "title": "...", "start": "YYYY-MM-DDTHH:mm", "end": "YYYY-MM-DDTHH:mm", "all_day": false}
        Правила: время локальное, без часового пояса. «с часу до трёх дня» = 13:00–15:00. Если конец не назван, длительность 1 час. Если время не названо, all_day=true, а start и end = дата с T00:00. Если год не назван, бери ближайшую будущую дату. title: короткая суть без слов «хочу», «задача», «событие» (например «Лабораторная Атнабаева»). Если это не просьба записать событие, верни {"is_event": false}.
        """

        let raw = try await AIClient.shared.oneShot(system: system, user: text)
        guard let jsonText = jsonObject(in: raw), let data = jsonText.data(using: .utf8) else { return nil }
        guard let parsed = try? JSONDecoder().decode(Extracted.self, from: data), parsed.is_event,
              let startText = parsed.start, let start = parseDate(startText) else { return nil }

        let allDay = parsed.all_day ?? false
        var end = parsed.end.flatMap(parseDate) ?? start.addingTimeInterval(3600)
        if end <= start { end = start.addingTimeInterval(3600) }

        let title = (parsed.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return PendingEvent(title: title.isEmpty ? "Событие" : title, start: start, end: end, allDay: allDay)
    }

    private static func jsonObject(in text: String) -> String? {
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"), a < b else { return nil }
        return String(text[a...b])
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

/// Запись в календарь. Доступ «только запись»: Чарли не видит твои события, только добавляет новые.
enum CalendarService {
    private static let store = EKEventStore()

    static func save(_ event: PendingEvent) async throws {
        let granted = try await store.requestWriteOnlyAccessToEvents()
        guard granted else { throw CalendarError.denied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }

        let ev = EKEvent(eventStore: store)
        ev.title = event.title
        ev.startDate = event.start
        ev.endDate = event.end
        ev.isAllDay = event.allDay
        ev.calendar = calendar
        try store.save(ev, span: .thisEvent)
    }
}
