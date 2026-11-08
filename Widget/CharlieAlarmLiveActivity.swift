import SwiftUI
import WidgetKit
#if canImport(AlarmKit)
import AlarmKit

/// Как будильник и таймер Чарли выглядят на экране блокировки и в Dynamic Island.
@available(iOS 26.0, *)
struct CharlieAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CharlieAlarmMetadata>.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "alarm.fill")
                Text(context.attributes.presentation.alert.title)
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }
}
#endif
