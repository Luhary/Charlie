import SwiftUI
import WidgetKit
import ActivityKit

struct CompanionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompanionAttributes.self) { context in
            // Экран блокировки
            HStack(spacing: 12) {
                CharlieAvatar(mood: context.state.mood, size: 48, bust: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.name).font(.headline)
                    Text(context.state.message).font(.subheadline).lineLimit(2)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CharlieAvatar(mood: context.state.mood, size: 56, bust: true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.message)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Link(destination: URL(string: "companion://listen")!) {
                            Label("Сказать", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        Link(destination: URL(string: "companion://type")!) {
                            Label("Написать", systemImage: "keyboard")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                    }
                }
            } compactLeading: {
                CharlieAvatar(mood: context.state.mood, size: 26, bust: true)
            } compactTrailing: {
                Text(context.state.mood.emoji)
            } minimal: {
                CharlieAvatar(mood: context.state.mood, size: 24, bust: true)
            }
            .keylineTint(context.state.mood.color)
        }
    }
}
