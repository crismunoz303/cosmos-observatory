import SwiftUI

// Native iOS entry point for the Supernova Watch observatory.
@main
struct SupernovaWatchApp: App {
    @StateObject private var store = ObservatoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
