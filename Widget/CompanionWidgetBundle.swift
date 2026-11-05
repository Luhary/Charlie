import SwiftUI
import WidgetKit

@main
struct CompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompanionWidget()
        CompanionLiveActivity()
    }
}
