import SwiftUI

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
