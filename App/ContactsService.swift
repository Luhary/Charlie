import Foundation
import Contacts

struct ContactMatch: Identifiable {
    let id = UUID()
    let name: String
    let number: String
}

enum ContactsError: LocalizedError {
    case denied
    var errorDescription: String? {
        "Нет доступа к контактам. Разреши: Настройки → Чарли → Контакты."
    }
}

/// Поиск контакта по имени, как его произносят: «позвони маме», «позвони Ивану Петрову».
/// Контакты читаются только на телефоне и никуда не отправляются.
enum ContactsService {
    @MainActor
    static func find(_ query: String) async throws -> [ContactMatch] {
        let store = CNContactStore()
        guard try await store.requestAccess(for: .contacts) else { throw ContactsError.denied }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        let wanted = tokens(query)
        guard !wanted.isEmpty else { return [] }

        var found: [(match: ContactMatch, extraWords: Int)] = []
        try store.enumerateContacts(with: request) { contact, _ in
            guard let number = bestNumber(contact) else { return }
            let nameTokens = tokens([contact.givenName, contact.middleName, contact.familyName, contact.nickname].joined(separator: " "))
            guard !nameTokens.isEmpty else { return }
            let matched = wanted.filter { w in nameTokens.contains { tokenMatches(w, $0) } }.count
            if matched == wanted.count {
                found.append((ContactMatch(name: displayName(contact), number: number), nameTokens.count))
            }
        }
        // «Иван» точнее подходит контакту «Иван», чем «Иван Петров»
        guard let best = found.map({ $0.extraWords }).min() else { return [] }
        return found.filter { $0.extraWords == best }.map { $0.match }
    }

    private static func tokens(_ s: String) -> [String] {
        s.lowercased().replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Совпадение начала слова с запасом на падежи: «маме» ~ «мама», «Ивану» ~ «Иван».
    private static func tokenMatches(_ query: String, _ name: String) -> Bool {
        let a = Array(query), b = Array(name)
        var i = 0
        while i < min(a.count, b.count) && a[i] == b[i] { i += 1 }
        return i >= max(3, min(a.count, b.count) - 2)
    }

    private static func bestNumber(_ c: CNContact) -> String? {
        let numbers = c.phoneNumbers
        let preferred = numbers.first { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone } ?? numbers.first
        guard let raw = preferred?.value.stringValue else { return nil }
        let digits = raw.filter { "+0123456789".contains($0) }
        return digits.isEmpty ? nil : digits
    }

    private static func displayName(_ c: CNContact) -> String {
        let full = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !full.isEmpty { return full }
        return c.nickname.isEmpty ? "Без имени" : c.nickname
    }
}
