import SwiftUI

@main
struct PulseApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .task { await model.load() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.refreshIfStale() }
                    }
                }
        }
    }
}
