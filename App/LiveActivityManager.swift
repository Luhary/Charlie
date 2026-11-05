import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var isActive = false
    private var activity: Activity<CompanionAttributes>?

    private init() {
        activity = Activity<CompanionAttributes>.activities.first
        isActive = activity != nil
    }

    func start(mood: CompanionMood = .idle, message: String = "Чарли здесь 🖤") {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = CompanionAttributes.ContentState(mood: mood, message: message)
        do {
            activity = try Activity.request(
                attributes: CompanionAttributes(name: "Чарли"),
                content: ActivityContent(state: state, staleDate: nil)
            )
            isActive = true
        } catch {
            print("Live Activity error: \(error)")
        }
    }

    func update(mood: CompanionMood, message: String) async {
        guard let activity else { return }
        let state = CompanionAttributes.ContentState(mood: mood, message: String(message.prefix(90)))
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func stop() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        isActive = false
    }
}
