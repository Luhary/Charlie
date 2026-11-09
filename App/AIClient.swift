import Foundation

struct ChatMessage {
    let role: String      // "user" | "assistant"
    let content: String
}

enum AIError: LocalizedError {
    case noKey
    case server(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noKey: return "Нет API-ключа. Открой настройки (⚙️) и вставь ключ."
        case .server(let m): return m
        case .badResponse: return "Пустой ответ от модели. Попробуй ещё раз или выбери другую модель в ⚙️."
        }
    }
}

/// Единственное место, куда приложение что-то отправляет по сети — выбранная тобой нейронка.
final class AIClient {
    static let shared = AIClient()

    struct Config {
        let provider: AIProvider
        let key: String
        let model: String
        let baseURL: String
    }

    // MARK: настройки

    static func keyName(_ p: AIProvider) -> String { "apiKey.\(p.rawValue)" }

    /// Ключ провайдера. Для старых установок (до появления разных провайдеров) ключ лежал под именем «apiKey».
    static func storedKey(for p: AIProvider) -> String? {
        if let k = Keychain.get(keyName(p)), !k.isEmpty { return k }
        if p == .openai || p == .anthropic, let legacy = Keychain.get("apiKey"), !legacy.isEmpty { return legacy }
        return nil
    }

    static func storedModel(for p: AIProvider) -> String? {
        let d = UserDefaults.standard
        if let m = d.string(forKey: Prefs.modelKey(p)), !m.isEmpty { return m }
        if p == .openai || p == .anthropic, let legacy = d.string(forKey: Prefs.model), !legacy.isEmpty { return legacy }
        return nil
    }

    static func currentProvider() -> AIProvider {
        AIProvider(rawValue: UserDefaults.standard.string(forKey: Prefs.provider) ?? "") ?? .openai
    }

    private func config() throws -> Config {
        let p = Self.currentProvider()
        guard let key = Self.storedKey(for: p) else { throw AIError.noKey }
        var base = p.defaultBaseURL
        if p == .openai, let custom = UserDefaults.standard.string(forKey: Prefs.baseURL), !custom.isEmpty { base = custom }
        return Config(provider: p, key: key, model: Self.storedModel(for: p) ?? p.defaultModel, baseURL: base)
    }

    // MARK: запросы

    func ask(_ text: String, history: [ChatMessage]) async throws -> String {
        let c = try config()
        let custom = UserDefaults.standard.string(forKey: Prefs.persona) ?? ""
        let system = custom.isEmpty ? Prefs.defaultPersona : custom
        var messages = Array(history.suffix(10))
        messages.append(ChatMessage(role: "user", content: text))
        return try await complete(c, system: system, messages: messages)
    }

    /// Разовый запрос со своей системной инструкцией, без характера и истории (например, разбор даты из фразы).
    func oneShot(system: String, user: String) async throws -> String {
        try await complete(try config(), system: system, messages: [ChatMessage(role: "user", content: user)])
    }

    private func complete(_ c: Config, system: String, messages: [ChatMessage]) async throws -> String {
        if c.provider == .anthropic {
            return try await anthropic(c, system: system, messages: messages)
        }
        return try await openAIStyle(c, system: system, messages: messages)
    }

    // MARK: Anthropic

    private func anthropic(_ c: Config, system: String, messages: [ChatMessage]) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(c.key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": c.model,
            "max_tokens": 400,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(req)
        if let dict = json as? [String: Any],
           let content = dict["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw AIError.badResponse
    }

    // MARK: OpenAI-совместимый формат (OpenAI, Gemini, OpenRouter, DeepSeek …)

    private func openAIStyle(_ c: Config, system: String, messages: [ChatMessage]) async throws -> String {
        var base = c.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else { throw AIError.badResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(c.key)", forHTTPHeaderField: "authorization")
        if c.provider == .openrouter { req.setValue("Charlie", forHTTPHeaderField: "X-Title") }

        // Модели Gemma не принимают системную роль — тогда вклеиваем инструкцию в первое сообщение.
        var msgs: [[String: String]] = []
        if c.model.lowercased().contains("gemma") {
            var items = messages.map { ["role": $0.role, "content": $0.content] }
            if !items.isEmpty { items[0]["content"] = system + "\n\n" + (items[0]["content"] ?? "") }
            msgs = items
        } else {
            msgs = [["role": "system", "content": system]]
            msgs += messages.map { ["role": $0.role, "content": $0.content] }
        }

        var body: [String: Any] = ["model": c.model, "messages": msgs]
        // Лимит длины ставим только там, где он точно понимается. У Gemini и бесплатных моделей «рассуждения»
        // тоже считаются токенами, и жёсткий лимит даёт пустой ответ.
        switch c.provider {
        case .openai:
            let isOpenAI = (url.host ?? "").contains("openai.com")
            body[isOpenAI ? "max_completion_tokens" : "max_tokens"] = 600
        default:
            break
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(req)
        if let dict = json as? [String: Any],
           let choices = dict["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any] {
            if let text = message["content"] as? String {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
            if let parts = message["content"] as? [[String: Any]] {
                let t = parts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }
        throw AIError.badResponse
    }

    // MARK: список моделей (для выбора в настройках)

    func listModels(provider p: AIProvider, key: String, baseURL: String) async throws -> [String] {
        var base = baseURL.isEmpty ? p.defaultBaseURL : baseURL
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/models") else { throw AIError.badResponse }

        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        switch p {
        case .anthropic:
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        default:
            if !key.isEmpty { req.setValue("Bearer \(key)", forHTTPHeaderField: "authorization") }
        }

        let json = try await send(req)
        guard let dict = json as? [String: Any], let data = dict["data"] as? [[String: Any]] else { throw AIError.badResponse }

        var ids: [String] = []
        for item in data {
            guard var id = item["id"] as? String else { continue }
            switch p {
            case .openrouter:
                // только бесплатные: цена за токен равна нулю
                let pricing = item["pricing"] as? [String: Any]
                let free = id.hasSuffix(":free") || ((pricing?["prompt"] as? String) == "0" && (pricing?["completion"] as? String) == "0")
                guard free else { continue }
            case .gemini:
                if id.hasPrefix("models/") { id = String(id.dropFirst(7)) }
                let l = id.lowercased()
                guard l.contains("gemini") || l.contains("gemma") else { continue }
                let skip = ["embedding", "imagen", "veo", "tts", "image", "live", "audio", "robotics", "computer-use"]
                if skip.contains(where: { l.contains($0) }) { continue }
            default:
                break
            }
            ids.append(id)
        }
        return Array(Set(ids)).sorted()
    }

    // MARK: общее

    private func send(_ req: URLRequest) async throws -> Any {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let obj = try? JSONSerialization.jsonObject(with: data)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIError.server(Self.explain(status: http.statusCode, body: data, obj: obj))
        }
        return obj ?? [String: Any]()
    }

    /// Понятное сообщение вместо сырой ошибки сервера.
    private static func explain(status: Int, body: Data, obj: Any?) -> String {
        var dict = obj as? [String: Any]
        if dict == nil, let arr = obj as? [[String: Any]] { dict = arr.first }   // Gemini иногда заворачивает ошибку в массив
        var message = ""
        if let err = dict?["error"] as? [String: Any] { message = (err["message"] as? String) ?? "" }
        else if let err = dict?["error"] as? String { message = err }
        if message.isEmpty { message = String((String(data: body, encoding: .utf8) ?? "").prefix(200)) }

        if message.lowercased().contains("location is not supported") {
            return "Gemini недоступен из твоего региона. Нужен VPN или другой провайдер (например, OpenRouter)."
        }
        switch status {
        case 401, 403: return "Ключ не подходит или нет доступа (\(status)). Проверь ключ в ⚙️."
        case 402: return "На счёте провайдера не хватает средств (402)."
        case 404: return "Модель не найдена. Выбери другую: ⚙️ → «Выбрать из списка»."
        case 429: return "Лимит запросов исчерпан (429). Подожди минуту: на бесплатных тарифах бывает и дневной лимит. Можно выбрать другую модель."
        default: return "Ошибка сервера \(status)" + (message.isEmpty ? "" : ": \(message)")
        }
    }
}
