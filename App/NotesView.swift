import SwiftUI

struct NotesView: View {
    @ObservedObject private var store = NoteStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.notes.isEmpty {
                    Text("Пока пусто.\nСкажи: «Чарли, запиши заметку: купить хлеб».")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(store.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text)
                                Text(note.date, format: .dateTime.day().month().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contextMenu {
                                // отсюда можно отправить в Заметки Apple, Telegram и т. д.
                                ShareLink(item: note.text)
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Заметки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
