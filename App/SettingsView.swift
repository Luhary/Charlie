import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Prefs.provider) private var provider = "openai"
    @AppStorage(Prefs.baseURL) private var baseURL = ""
    @AppStorage(Prefs.model) private var model = ""
    @AppStorage(Prefs.persona) private var persona = ""
    @AppStorage(Prefs.speak) private var speak = true
    @AppStorage(Prefs.maps) private var maps = "yandex"
    @State private var apiKey = Keychain.get("apiKey") ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Нейронка") {
                    Picker("Провайдер", selection: $provider) {
                        Text("OpenAI-совместимый").tag("openai")
                        Text("Anthropic").tag("anthropic")
                    }
                    if provider == "openai" {
                        TextField(Prefs.defaultBaseURL, text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    TextField(provider == "anthropic" ? "claude-sonnet-5-5" : "gpt-4o-mini", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API-ключ", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Toggle("Озвучивать ответы", isOn: $speak)
                }
                Section("Карты") {
                    Picker("Открывать в", selection: $maps) {
                        Text("Яндекс Карты").tag("yandex")
                        Text("Apple Карты").tag("apple")
                        Text("Google Карты").tag("google")
                    }
                    Text("Скажи: «как добраться до улицы Ленина» или «где ближайший строительный».")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Характер") {
                    TextEditor(text: $persona)
                        .frame(minHeight: 100)
                    Text("Пусто = характер Чарли по умолчанию: загадочная, спокойная, коротко.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text("Ключ лежит только в Keychain этого телефона. Наружу уходят лишь твои запросы — в выбранную нейронку.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: "apiKey")
                        dismiss()
                    }
                }
            }
        }
    }
}
