import SwiftUI

@main struct StockTrackerApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .onChange(of: scenePhase) { _, phase in
                    container.coordinator.sceneDidChange(isActive: phase == .active)
                }
        }
    }
}
