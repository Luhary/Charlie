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
        case .badResponse: return "Не смог разобрать ответ нейронки."
        }
    }
}

/// Единственное место, куда приложение что-то отправляет по сети — выбранная тобой нейронка.
final class AIClient {
    static let shared = AIClient()

    func ask(_ text: String, history: [ChatMessage]) async throws -> String {
        guard let key = Keychain.get("apiKey"), !key.isEmpty else { throw AIError.noKey }

        let d = UserDefaults.standard
        let provider = d.string(forKey: Prefs.provider) ?? "openai"
        let customModel = d.string(forKey: Prefs.model) ?? ""
        let model = customModel.isEmpty ? (provider == "anthropic" ? "claude-sonnet-5-5" : "gpt-4o-mini") : customModel
        let customPersona = d.string(forKey: Prefs.persona) ?? ""
        let system = customPersona.isEmpty ? Prefs.defaultPersona : customPersona

        var messages = Array(history.suffix(10))
        messages.append(ChatMessage(role: "user", content: text))

        if provider == "anthropic" {
            return try await askAnthropic(key: key, model: model, system: system, messages: messages)
        } else {
            let customURL = d.string(forKey: Prefs.baseURL) ?? ""
            let base = customURL.isEmpty ? Prefs.defaultBaseURL : customURL
            return try await askOpenAI(base: base, key: key, model: model, system: system, messages: messages)
        }
    }

    /// Разовый запрос со своей системной инструкцией, без характера и истории (например, разбор даты из фразы).
    func oneShot(system: String, user: String) async throws -> String {
        guard let key = Keychain.get("apiKey"), !key.isEmpty else { throw AIError.noKey }
        let d = UserDefaults.standard
        let provider = d.string(forKey: Prefs.provider) ?? "openai"
        let customModel = d.string(forKey: Prefs.model) ?? ""
        let model = customModel.isEmpty ? (provider == "anthropic" ? "claude-sonnet-5-5" : "gpt-4o-mini") : customModel
        let messages = [ChatMessage(role: "user", content: user)]
        if provider == "anthropic" {
            return try await askAnthropic(key: key, model: model, system: system, messages: messages)
        }
        let customURL = d.string(forKey: Prefs.baseURL) ?? ""
        let base = customURL.isEmpty ? Prefs.defaultBaseURL : customURL
        return try await askOpenAI(base: base, key: key, model: model, system: system, messages: messages)
    }

    // MARK: Anthropic

    private func askAnthropic(key: String, model: String, system: String, messages: [ChatMessage]) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 400,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(req)
        if let content = json["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw AIError.badResponse
    }

    // MARK: OpenAI-совместимый (OpenAI, OpenRouter, DeepSeek и т.д.)

    private func askOpenAI(base: String, key: String, model: String, system: String, messages: [ChatMessage]) async throws -> String {
        var b = base
        while b.hasSuffix("/") { b.removeLast() }
        guard let url = URL(string: b + "/chat/completions") else { throw AIError.badResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        var msgs: [[String: String]] = [["role": "system", "content": system]]
        msgs += messages.map { ["role": $0.role, "content": $0.content] }
        // у самой OpenAI новые модели принимают только max_completion_tokens
        let tokenKey = (url.host ?? "").contains("openai.com") ? "max_completion_tokens" : "max_tokens"
        let body: [String: Any] = ["model": model, "messages": msgs, tokenKey: 600]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(req)
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let text = message["content"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw AIError.badResponse
    }

    // MARK: общее

    private func send(_ req: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var msg = "Ошибка сервера \(http.statusCode)"
            if let err = json["error"] as? [String: Any], let m = err["message"] as? String {
                msg += ": \(m)"
            }
            throw AIError.server(msg)
        }
        return json
    }
}
