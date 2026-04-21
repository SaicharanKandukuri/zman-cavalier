import SwiftUI

struct PreferencesView: View {
    @Environment(Configuration.self) private var config

    var body: some View {
        @Bindable var config = config

        TabView {
            Form {
                Picker("Mode", selection: $config.mode) {
                    ForEach(DrawingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("Filling", isOn: $config.filling)
                HStack {
                    Text("Line thickness")
                    Slider(value: $config.linesThickness, in: 1...20)
                    Text("\(Int(config.linesThickness))px").monospacedDigit()
                }
            }
            .padding()
            .tabItem { Label("Appearance", systemImage: "paintpalette") }

            Form {
                Stepper(value: $config.barPairs, in: 2...64) {
                    Text("Bar pairs: \(config.barPairs)")
                }
                Stepper(value: $config.framerate, in: 15...120) {
                    Text("Framerate: \(config.framerate) fps")
                }
                Toggle("Autosens", isOn: $config.autosens)
                if !config.autosens {
                    Stepper(value: $config.sensitivity, in: 1...100) {
                        Text("Sensitivity: \(config.sensitivity)")
                    }
                }
                Toggle("Stereo", isOn: $config.stereo)
                Toggle("Monstercat smoothing", isOn: $config.monstercat)
                HStack {
                    Text("Noise reduction")
                    Slider(value: $config.noiseReduction, in: 0.15...0.95)
                    Text(String(format: "%.2f", config.noiseReduction)).monospacedDigit()
                }
            }
            .padding()
            .tabItem { Label("Audio", systemImage: "waveform") }
        }
        .onChange(of: config.mode) { _, _ in config.save() }
        .onChange(of: config.filling) { _, _ in config.save() }
        .onChange(of: config.linesThickness) { _, _ in config.save() }
        .onChange(of: config.barPairs) { _, _ in config.save() }
        .onChange(of: config.framerate) { _, _ in config.save() }
        .onChange(of: config.autosens) { _, _ in config.save() }
        .onChange(of: config.sensitivity) { _, _ in config.save() }
        .onChange(of: config.stereo) { _, _ in config.save() }
        .onChange(of: config.monstercat) { _, _ in config.save() }
        .onChange(of: config.noiseReduction) { _, _ in config.save() }
    }
}
