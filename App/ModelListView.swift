import SwiftUI

/// Список моделей, которые провайдер отдаёт прямо сейчас (у бесплатных моделей названия часто меняются).
struct ModelListView: View {
    let provider: AIProvider
    let apiKey: String
    let baseURL: String
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var models: [String] = []
    @State private var loading = true
    @State private var error: String?
    @State private var query = ""

    private var filtered: [String] {
        query.isEmpty ? models : models.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if loading { ProgressView() }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            ForEach(filtered, id: \.self) { id in
                Button {
                    selection = id
                    dismiss()
                } label: {
                    HStack {
                        Text(id).foregroundStyle(.primary)
                        Spacer()
                        if id == selection { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle(provider == .openrouter ? "Бесплатные модели" : "Модели")
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            models = try await AIClient.shared.listModels(provider: provider, key: apiKey, baseURL: baseURL)
            if models.isEmpty { error = "Провайдер не вернул моделей." }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
