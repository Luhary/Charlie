import SwiftUI
import ActivityKit

enum CompanionMood: String, Codable, Hashable {
    case idle, listening, thinking, speaking, surprised, smirk

    /// Нужна ли постоянная анимация (качание, рот). В остальных состояниях картинка статична — батарея не тратится.
    var animates: Bool {
        switch self {
        case .listening, .thinking, .speaking: return true
        case .idle, .surprised, .smirk: return false
        }
    }

    var emoji: String {
        switch self {
        case .idle: return "🖤"
        case .listening: return "👂"
        case .thinking: return "💭"
        case .speaking: return "💬"
        case .surprised: return "❗️"
        case .smirk: return "😏"
        }
    }

    var color: Color {
        switch self {
        case .idle: return Color(red: 0.91, green: 0.16, blue: 0.29)
        case .listening: return Color(red: 1.00, green: 0.36, blue: 0.48)
        case .thinking: return Color(red: 0.64, green: 0.48, blue: 1.00)
        case .speaking: return Color(red: 1.00, green: 0.48, blue: 0.24)
        case .surprised: return Color(red: 0.92, green: 0.85, blue: 0.78)
        case .smirk: return Color(red: 0.70, green: 0.07, blue: 0.18)
        }
    }
}

struct CompanionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mood: CompanionMood
        var message: String
    }
    var name: String
}
