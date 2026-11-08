import SwiftUI
import WidgetKit

@main
struct CompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompanionWidget()
        CompanionLiveActivity()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            CharlieAlarmLiveActivity()
        }
        #endif
    }
}
