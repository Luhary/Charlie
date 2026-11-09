import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Prefs.provider) private var providerRaw = "openai"
    @AppStorage(Prefs.baseURL) private var baseURL = ""
    @AppStorage(Prefs.persona) private var persona = ""
    @AppStorage(Prefs.speak) private var speak = true
    @AppStorage(Prefs.maps) private var maps = "yandex"
    @AppStorage(Prefs.lockShortcut) private var lockShortcut = ""

    @State private var model = ""
    @State private var apiKey = ""

    private var provider: AIProvider { AIProvider(rawValue: providerRaw) ?? .openai }

    var body: some View {
        NavigationStack {
            Form {
                Section("Нейронка") {
                    Picker("Провайдер", selection: $providerRaw) {
                        ForEach(AIProvider.allCases) { p in
                            Text(p.title).tag(p.rawValue)
                        }
                    }
                    if provider == .openai {
                        TextField(provider.defaultBaseURL, text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    SecureField("API-ключ", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(provider.defaultModel, text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    NavigationLink("Выбрать из списка") {
                        ModelListView(provider: provider, apiKey: apiKey, baseURL: provider == .openai ? baseURL : "", selection: $model)
                    }
                    Text(provider.help)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                Section("Блокировка экрана") {
                    TextField(Prefs.defaultLockShortcut, text: $lockShortcut)
                        .autocorrectionDisabled()
                    Text("Название команды из приложения «Команды», которая ждёт N секунд и блокирует экран. Как её создать, написано в README.")
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
                    Text("Ключи лежат только в Keychain этого телефона. Наружу уходят лишь твои запросы — в выбранную нейронку. Фразы про календарь и будильники тоже разбирает она.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear { load(provider) }
            .onChange(of: providerRaw) { old, new in
                // ключ и модель у каждого провайдера свои
                if let oldProvider = AIProvider(rawValue: old) { save(oldProvider) }
                if let newProvider = AIProvider(rawValue: new) { load(newProvider) }
            }
            .onDisappear { save(provider) }   // сохраняется и при закрытии свайпом вниз
        }
    }

    private func load(_ p: AIProvider) {
        apiKey = AIClient.storedKey(for: p) ?? ""
        model = AIClient.storedModel(for: p) ?? ""
    }

    private func save(_ p: AIProvider) {
        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: AIClient.keyName(p))
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Prefs.modelKey(p))
    }
}
