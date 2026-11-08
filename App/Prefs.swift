import Foundation

enum Prefs {
    static let provider = "provider"   // "openai" (OpenAI-совместимый) или "anthropic"
    static let baseURL = "baseURL"
    static let model = "model"
    static let persona = "persona"
    static let speak = "speak"
    static let lockShortcut = "lockShortcut"
    static let maps = "maps"           // "yandex" | "apple" | "google"

    static let defaultPersona = "Тебя зовут Чарли. Ты — таинственная, спокойная и слегка ироничная помощница на iPhone: говоришь негромко, загадочно, с лёгкой театральностью, но всегда по делу. Отвечай коротко (1–3 предложения), по-русски, неформально, без лишних оговорок. Не ломай образ, но полезность важнее."
    static let defaultLockShortcut = "Заблокировать Чарли"
    static let defaultBaseURL = "https://api.openai.com/v1"
}
