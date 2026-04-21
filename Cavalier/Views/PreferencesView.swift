import SwiftUI

struct PreferencesView: View {
    @Environment(Configuration.self) private var config

    var body: some View {
        @Bindable var config = config
        return TabView {
            AppearanceTab(config: config)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            AudioTab(config: config)
                .tabItem { Label("Audio", systemImage: "waveform") }
            LayoutTab(config: config)
                .tabItem { Label("Layout", systemImage: "square.grid.2x2") }
            ColorsTab(config: config)
                .tabItem { Label("Colors", systemImage: "eyedropper") }
        }
    }
}

private struct AppearanceTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            Picker("Mode", selection: $config.mode) {
                ForEach(DrawingMode.allCases) { m in Text(m.displayName).tag(m) }
            }
            Picker("Direction", selection: $config.direction) {
                Text("Top → Bottom").tag(DrawingDirection.topBottom)
                Text("Bottom → Top").tag(DrawingDirection.bottomTop)
                Text("Left → Right").tag(DrawingDirection.leftRight)
                Text("Right → Left").tag(DrawingDirection.rightLeft)
            }
            Toggle("Filled", isOn: $config.filling)
            if !config.filling {
                LabeledSlider(title: "Line thickness",
                              value: $config.linesThickness, range: 1...20, format: "%.0f px")
            }
            LabeledSlider(title: "Item spacing",
                          value: $config.itemsOffset, range: 0...0.4, format: "%.2f")
            LabeledSlider(title: "Roundness",
                          value: $config.itemsRoundness, range: 0...1, format: "%.2f")
        }
        .padding()
        .onChange(of: config.mode) { _, _ in config.save() }
        .onChange(of: config.direction) { _, _ in config.save() }
        .onChange(of: config.filling) { _, _ in config.save() }
        .onChange(of: config.linesThickness) { _, _ in config.save() }
        .onChange(of: config.itemsOffset) { _, _ in config.save() }
        .onChange(of: config.itemsRoundness) { _, _ in config.save() }
    }
}

private struct AudioTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            Stepper(value: $config.barPairs, in: 2...64) {
                Text("Bar pairs: \(config.barPairs)")
            }
            Stepper(value: $config.framerate, in: 15...120) {
                Text("Framerate: \(config.framerate) fps")
            }
            Toggle("Stereo", isOn: $config.stereo)
            Toggle("Reverse order", isOn: $config.reverseOrder)
            Divider()
            Toggle("Autosens", isOn: $config.autosens)
            if !config.autosens {
                Stepper(value: $config.sensitivity, in: 1...100) {
                    Text("Sensitivity: \(config.sensitivity)")
                }
            }
            Toggle("Monstercat smoothing", isOn: $config.monstercat)
            LabeledSlider(title: "Noise reduction",
                          value: $config.noiseReduction, range: 0.15...0.95, format: "%.2f")
        }
        .padding()
        .onChange(of: config.barPairs) { _, _ in config.save() }
        .onChange(of: config.framerate) { _, _ in config.save() }
        .onChange(of: config.stereo) { _, _ in config.save() }
        .onChange(of: config.reverseOrder) { _, _ in config.save() }
        .onChange(of: config.autosens) { _, _ in config.save() }
        .onChange(of: config.sensitivity) { _, _ in config.save() }
        .onChange(of: config.monstercat) { _, _ in config.save() }
        .onChange(of: config.noiseReduction) { _, _ in config.save() }
    }
}

private struct LayoutTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            Picker("Mirror", selection: $config.mirror) {
                Text("Off").tag(Mirror.off)
                Text("Full").tag(Mirror.full)
                Text("Split channels").tag(Mirror.splitChannels)
            }
            if config.mirror != .off {
                Toggle("Reverse mirror", isOn: $config.reverseMirror)
            }
            Stepper(value: $config.areaMargin, in: 0...100) {
                Text("Area margin: \(config.areaMargin) px")
            }
            Divider()
            Text("Circle modes").font(.headline)
            LabeledSlider(title: "Inner radius",
                          value: $config.innerRadius, range: 0.2...0.8, format: "%.2f")
            LabeledSlider(title: "Rotation",
                          value: $config.rotation, range: 0...(Float.pi * 2), format: "%.2f rad")
        }
        .padding()
        .onChange(of: config.mirror) { _, _ in config.save() }
        .onChange(of: config.reverseMirror) { _, _ in config.save() }
        .onChange(of: config.areaMargin) { _, _ in config.save() }
        .onChange(of: config.innerRadius) { _, _ in config.save() }
        .onChange(of: config.rotation) { _, _ in config.save() }
    }
}

private struct ColorsTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            let fg = config.currentProfile.fgColors.first ?? "#ff3584e4"
            let bg = config.currentProfile.bgColors.first ?? "#ff242424"
            ColorRow(title: "Foreground", hex: fg) { newHex in
                updateActive { p in
                    if p.fgColors.isEmpty { p.fgColors = [newHex] } else { p.fgColors[0] = newHex }
                }
            }
            ColorRow(title: "Background", hex: bg) { newHex in
                updateActive { p in
                    if p.bgColors.isEmpty { p.bgColors = [newHex] } else { p.bgColors[0] = newHex }
                }
            }
            Text("Config: \(Configuration.configURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func updateActive(_ mutate: (inout ColorProfile) -> Void) {
        let idx = max(0, min(config.activeProfile, config.colorProfiles.count - 1))
        guard config.colorProfiles.indices.contains(idx) else { return }
        var p = config.colorProfiles[idx]
        mutate(&p)
        config.colorProfiles[idx] = p
        config.save()
    }
}

private struct ColorRow: View {
    let title: String
    let hex: String
    let onChange: (String) -> Void

    var body: some View {
        let nsColor = NSColor(argbHex: hex) ?? .systemBlue
        let binding = Binding<Color>(
            get: { Color(nsColor: nsColor) },
            set: { newColor in
                let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? .systemBlue
                onChange(formatHex(ns))
            }
        )
        HStack {
            ColorPicker(title, selection: binding, supportsOpacity: true)
            Text(hex).font(.system(.caption, design: .monospaced))
        }
    }

    private func formatHex(_ c: NSColor) -> String {
        let a = Int(round(c.alphaComponent * 255))
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02x%02x%02x%02x", a, r, g, b)
    }
}

private struct LabeledSlider: View {
    let title: String
    let value: Binding<Float>
    let range: ClosedRange<Float>
    let format: String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)
        }
    }
}
