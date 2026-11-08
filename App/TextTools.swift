import Foundation

extension String {
    /// Первое совпадение регулярного выражения (без учёта регистра): [вся строка, группа 1, группа 2, …].
    func rxMatch(_ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = self as NSString
        guard let m = re.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    /// Фраза в удобном для разбора виде: без «ё», без знаков по краям.
    var normalizedPhrase: String {
        replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "Ё", with: "Е")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// Первая буква заглавная.
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
}
