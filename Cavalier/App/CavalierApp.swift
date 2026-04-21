import SwiftUI

@main
struct CavalierApp: App {
    @State private var config = Configuration.shared
    @State private var engine = VisualizerEngine.shared

    var body: some Scene {
        WindowGroup("Cavalier") {
            ContentView()
                .environment(config)
                .environment(engine)
                .frame(minWidth: 320, minHeight: 200)
                .background(WindowAccessor())
                .onAppear { engine.start() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            PreferencesView()
                .environment(config)
                .frame(minWidth: 480, minHeight: 400)
        }
    }
}
