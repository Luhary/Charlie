import Foundation

/// Откуда брать нейронку. У каждого провайдера свой ключ, модель и адрес.
enum AIProvider: String, CaseIterable, Identifiable {
    case openrouter, gemini, openai, anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openrouter: return "OpenRouter (есть бесплатные модели)"
        case .gemini: return "Google Gemini (есть бесплатный тариф)"
        case .openai: return "OpenAI-совместимый (свой адрес)"
        case .anthropic: return "Anthropic"
        }
    }

    var defaultModel: String {
        switch self {
        case .openrouter: return "meta-llama/llama-3.3-70b-instruct:free"
        case .gemini: return "gemini-2.5-flash-lite"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-5-5"
        }
    }

    /// Адрес для OpenAI-совместимого формата (у Anthropic свой формат).
    var defaultBaseURL: String {
        switch self {
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        }
    }

    var help: String {
        switch self {
        case .openrouter:
            return "Ключ: openrouter.ai/keys (карта не нужна). Бесплатные модели оканчиваются на :free. Лимит: 20 запросов в минуту и 50 в день (1000 в день, если когда-то пополнить счёт на $10). Часть бесплатных провайдеров может использовать твои запросы для обучения."
        case .gemini:
            return "Ключ: aistudio.google.com → Get API key (карта не нужна). Бесплатный тариф с лимитами. Google AI Studio и Gemini API недоступны в России без VPN. На бесплатном тарифе Google может использовать запросы для улучшения своих продуктов."
        case .openai:
            return "Любой сервис с OpenAI-совместимым API: укажи его адрес, модель и ключ."
        case .anthropic:
            return "Ключ: console.anthropic.com."
        }
    }
}
