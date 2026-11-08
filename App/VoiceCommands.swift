import Foundation

// MARK: - Заметки

enum NoteCommand {
    private static let pattern = "^(?:чарли[,\\s]+)?(?:пожалуйста[,\\s]+)?(?:(?:запиши|создай|сделай|добавь|оставь|сохрани)\\s+(?:мне\\s+)?(?:новую\\s+)?(?:заметку|заметка)|(?:запиши|добавь|занеси|сохрани)\\s+в\\s+заметки|заметка)\\s*[:,\\-—]?\\s*(.*)$"

    /// nil — это не заметка. Пустая строка — заметка без текста (Чарли спросит, что записать).
    static func parse(_ raw: String) -> String? {
        let t = raw.normalizedPhrase
        guard let m = t.rxMatch(pattern), m.count > 1 else { return nil }
        return m[1].trimmingCharacters(in: .whitespacesAndNewlines).firstUppercased
    }
}

// MARK: - Звонок

enum CallTarget {
    case number(String)
    case name(String)
}

enum CallCommand {
    private static let pattern = "^(?:чарли[,\\s]+)?(?:пожалуйста[,\\s]+)?(?:позвони|набери|звони|вызови|дозвонись\\s+до)(?:\\s+мне)?\\s+(?:на\\s+номер\\s+|по\\s+номеру\\s+)?(.+)$"

    static func parse(_ raw: String) -> CallTarget? {
        let t = raw.normalizedPhrase
        guard let m = t.rxMatch(pattern), m.count > 1 else { return nil }
        var rest = m[1].trimmingCharacters(in: .whitespacesAndNewlines)
        // «позвони Ивану пожалуйста»
        if let p = rest.rxMatch("^(.*?)[,\\s]+пожалуйста$"), p.count > 1 { rest = p[1] }
        guard !rest.isEmpty else { return nil }

        let digits = rest.filter { "+0123456789".contains($0) }
        if digits.filter(\.isNumber).count >= 6 { return .number(digits) }
        return .name(rest)
    }
}

// MARK: - Блокировка экрана

enum LockCommand {
    private static let lockPattern = "(?:заблокир|блокир|залоч)\\p{L}*\\s+(?:мне\\s+)?(?:экран|телефон|айфон)|(?:выключи|погаси)\\s+экран"
    private static let delayPattern = "через\\s+(?:(\\d+|[а-я]+)\\s+)?(секунд\\p{L}*|минут\\p{L}*|час\\p{L}*)"

    private static let words: [String: Int] = [
        "один": 1, "одну": 1, "одна": 1, "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5,
        "шесть": 6, "семь": 7, "восемь": 8, "девять": 9, "десять": 10, "пятнадцать": 15,
        "двадцать": 20, "тридцать": 30, "сорок": 40, "пятьдесят": 50
    ]

    /// nil — это не про блокировку. Иначе — через сколько секунд блокировать (0 = сразу).
    static func parse(_ raw: String) -> Int? {
        let t = raw.normalizedPhrase
        guard t.rxMatch(lockPattern) != nil else { return nil }
        if t.rxMatch("через\\s+полчаса") != nil { return 1800 }
        guard let m = t.rxMatch(delayPattern), m.count > 2 else { return 0 }

        let count: Int
        if m[1].isEmpty { count = 1 }
        else if let n = Int(m[1]) { count = n }
        else if let n = words[m[1].lowercased()] { count = n }
        else { count = 1 }

        let unit = m[2].lowercased()
        if unit.hasPrefix("сек") { return count }
        if unit.hasPrefix("мин") { return count * 60 }
        return count * 3600
    }

    static func humanDelay(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) сек" }
        if seconds < 3600 { return "\(seconds / 60) мин" }
        return "\(seconds / 3600) ч"
    }
}
