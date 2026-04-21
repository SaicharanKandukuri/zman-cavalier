import SwiftUI

struct ContentView: View {
    @Environment(Configuration.self) private var config
    @Environment(VisualizerEngine.self) private var engine

    var body: some View {
        VisualizerView()
            .ignoresSafeArea()
    }
}
