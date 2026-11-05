import SwiftUI

@main
struct CompanionApp: App {
    @StateObject private var store = CompanionStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { store.handle(url: $0) }
                .task { Notifier.requestPermission() }
        }
    }
}
