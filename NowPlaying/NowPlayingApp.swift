import SwiftUI

@main
struct NowPlayingApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine = PlayerEngine()
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            NowPlayingScreen()
                .environmentObject(engine)
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
                .onAppear {
                    engine.configure(server: appModel.server)
                    appModel.engine = engine
                    appModel.restoreIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        engine.flushPersist()
                        appModel.persistServer()
                    }
                }
        }
    }
}