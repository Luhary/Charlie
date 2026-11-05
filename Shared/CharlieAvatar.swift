import SwiftUI
import UIKit

/// Чарли на готовых картинках. Недостающие картинки заменяются на idle,
/// поэтому новые настроения подключаются простым добавлением файла в CharlieAssets.xcassets.
///
/// phase — время для анимации (0 = статичный кадр, как в виджете и острове).
/// blink — глаза закрыты. bust — крупный план лица в круге (для Dynamic Island).
struct CharlieAvatar: View {
    var mood: CompanionMood
    var size: CGFloat
    var phase: Double = 0
    var blink: Bool = false
    var bust: Bool = false

    private static func exists(_ name: String) -> Bool { UIImage(named: name) != nil }
    private static func pick(_ name: String) -> String { exists(name) ? name : "charlie_idle" }

    private var imageName: String {
        switch mood {
        case .idle:
            return blink ? Self.pick("charlie_blink") : "charlie_idle"
        case .listening:
            return Self.pick("charlie_listening")
        case .thinking:
            return Self.pick("charlie_thinking")
        case .surprised:
            return Self.pick("charlie_surprised")
        case .smirk:
            return Self.pick("charlie_smirk")
        case .speaking:
            let a = "charlie_speaking_a"
            let b = "charlie_speaking_b"
            guard Self.exists(a), Self.exists(b) else { return "charlie_idle" }
            return Int(phase * 6) % 2 == 0 ? a : b   // «открыла-закрыла рот»
        }
    }

    private var sway: Double {
        switch mood {
        case .idle, .surprised, .smirk: return 0
        case .listening: return 0.8 * sin(phase * 2)
        case .thinking: return 1.2 * sin(phase * 1.5)
        case .speaking: return 0.8 * sin(phase * 5)
        }
    }

    private var bob: CGFloat {
        mood == .speaking ? CGFloat(-0.006 * abs(sin(phase * 6))) : 0
    }

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .id(imageName)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.15), value: imageName)
        .frame(width: size, height: size)
        .rotationEffect(.degrees(sway), anchor: UnitPoint(x: 0.5, y: 0.95))
        .offset(y: bob * size)
        .scaleEffect(bust ? 1.7 : 1.0, anchor: UnitPoint(x: 0.56, y: 0.42))
        .frame(width: size, height: size)
        .mask {
            if bust {
                Circle()
            } else {
                Rectangle().inset(by: -size * 0.1)
            }
        }
    }
}
