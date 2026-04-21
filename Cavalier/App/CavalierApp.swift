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
                .background(WindowAccessor(alwaysOnTop: config.alwaysOnTop))
                .onAppear { engine.start() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .windowArrangement) {
                Divider()
                Toggle("Always on Top", isOn: Binding(
                    get: { config.alwaysOnTop },
                    set: { newValue in
                        config.alwaysOnTop = newValue
                        config.save()
                    }
                ))
                .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }

        Settings {
            PreferencesView()
                .environment(config)
                .frame(minWidth: 480, minHeight: 400)
        }
    }
}
