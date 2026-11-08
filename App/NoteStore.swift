import Foundation
import SwiftUI

struct Note: Codable, Identifiable {
    var id = UUID()
    var text: String
    var date: Date
}

/// Заметки Чарли. Лежат только на телефоне (файл в документах приложения), никуда не отправляются.
@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published private(set) var notes: [Note] = []
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("notes.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = saved
        }
    }

    func add(_ text: String) {
        notes.insert(Note(text: text, date: Date()), at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
