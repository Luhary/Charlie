import SwiftUI
import WidgetKit

struct CompanionEntry: TimelineEntry {
    let date: Date
}

struct CompanionProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompanionEntry { CompanionEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (CompanionEntry) -> Void) {
        completion(CompanionEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompanionEntry>) -> Void) {
        // Статичный виджет: никаких обновлений в фоне — батарею не тратит.
        completion(Timeline(entries: [CompanionEntry(date: Date())], policy: .never))
    }
}

struct CompanionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private let bone = Color(red: 0.91, green: 0.85, blue: 0.80)
    private let bg = Color(red: 0.11, green: 0.095, blue: 0.105)

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    Image("charlie_full")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 135)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Чарли")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(bone)
                        Text("Нажми, чтобы заговорить")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 8) {
                    CharlieAvatar(mood: .idle, size: 120)
                    Text("Чарли")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(bone)
                }
            }
        }
        .widgetURL(URL(string: "companion://listen"))
        .containerBackground(for: .widget) { bg }
    }
}

struct CompanionWidget: Widget {
    let kind = "CompanionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompanionProvider()) { _ in
            CompanionWidgetView()
        }
        .configurationDisplayName("Чарли")
        .description("Нажми, чтобы заговорить с Чарли.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
