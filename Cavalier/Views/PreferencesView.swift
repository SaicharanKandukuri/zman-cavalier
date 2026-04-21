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
            ImagesTab(config: config)
                .tabItem { Label("Images", systemImage: "photo") }
        }
    }
}

private struct ImagesTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            Section("Background image") {
                ImageRow(
                    path: config.bgImagePath,
                    onPick: { newPath in config.bgImagePath = newPath; config.save() })
                LabeledSlider(title: "Scale", value: $config.bgImageScale, range: 0.1...1.0, format: "%.2f")
                LabeledSlider(title: "Alpha", value: $config.bgImageAlpha, range: 0...1, format: "%.2f")
            }
            Section("Foreground image (clipped to bars)") {
                ImageRow(
                    path: config.fgImagePath,
                    onPick: { newPath in config.fgImagePath = newPath; config.save() })
                LabeledSlider(title: "Scale", value: $config.fgImageScale, range: 0.1...1.0, format: "%.2f")
                LabeledSlider(title: "Alpha", value: $config.fgImageAlpha, range: 0...1, format: "%.2f")
            }
        }
        .padding()
        .onChange(of: config.bgImageScale) { _, _ in config.save() }
        .onChange(of: config.bgImageAlpha) { _, _ in config.save() }
        .onChange(of: config.fgImageScale) { _, _ in config.save() }
        .onChange(of: config.fgImageAlpha) { _, _ in config.save() }
    }
}

private struct ImageRow: View {
    let path: String
    let onPick: (String) -> Void

    var body: some View {
        HStack {
            Text(displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
            Spacer()
            Button("Choose…") { choose() }
            if !path.isEmpty {
                Button("Clear") { onPick("") }
            }
        }
    }

    private var displayName: String {
        path.isEmpty ? "No image" : (path as NSString).lastPathComponent
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.jpeg, .png, .webP, .heic, .image]
        if panel.runModal() == .OK, let url = panel.url {
            onPick(url.path)
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
            LabeledSlider(title: "Gravity (fall speed)",
                          value: $config.gravity, range: 0...5, format: "%.2f")
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
        .onChange(of: config.gravity) { _, _ in config.save() }
    }
}

private struct LayoutTab: View {
    @Bindable var config: Configuration

    var body: some View {
        Form {
            Toggle("Always on top", isOn: $config.alwaysOnTop)
            Toggle("Borderless (no title bar)", isOn: $config.borderless)
            Toggle("Show window controls", isOn: $config.showControls)
            Toggle("Show FPS overlay", isOn: $config.showFPS)
            Divider()
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
        .onChange(of: config.alwaysOnTop) { _, _ in config.save() }
        .onChange(of: config.borderless) { _, _ in config.save() }
        .onChange(of: config.showControls) { _, _ in config.save() }
        .onChange(of: config.showFPS) { _, _ in config.save() }
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
            Section("Presets") {
                PresetGrid { preset in applyPreset(preset) }
            }
            Section {
                ColorListEditor(
                    title: "Foreground",
                    hexes: config.currentProfile.fgColors,
                    default: "#ff3584e4",
                    onChange: { list in updateActive { $0.fgColors = list } })
            }
            Section {
                ColorListEditor(
                    title: "Background",
                    hexes: config.currentProfile.bgColors,
                    default: "#ff242424",
                    onChange: { list in updateActive { $0.bgColors = list } })
            }
            Text("Pick a preset or add a second color (+) to make a gradient. Config: \(Configuration.configURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func applyPreset(_ preset: ColorPreset) {
        updateActive { p in
            p.fgColors = preset.fgColors
            p.bgColors = preset.bgColors
            p.theme = preset.theme
            p.name = preset.name
        }
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

private struct PresetGrid: View {
    let onPick: (ColorPreset) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ColorPresets.all) { preset in
                PresetSwatch(preset: preset) { onPick(preset) }
            }
        }
    }
}

private struct PresetSwatch: View {
    let preset: ColorPreset
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                swatchBody
                    .frame(height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(preset.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var swatchBody: some View {
        ZStack {
            bgGradient
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fgGradient)
                        .frame(width: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 6)
        }
    }

    private var fgGradient: LinearGradient {
        let colors = preset.fgColors.compactMap { NSColor(argbHex: $0).map(Color.init) }
        return LinearGradient(colors: colors.isEmpty ? [.blue] : colors,
                              startPoint: .bottom, endPoint: .top)
    }

    private var bgGradient: LinearGradient {
        let colors = preset.bgColors.compactMap { NSColor(argbHex: $0).map(Color.init) }
        return LinearGradient(colors: colors.isEmpty ? [.black] : colors,
                              startPoint: .top, endPoint: .bottom)
    }
}

private struct ColorListEditor: View {
    let title: String
    let hexes: [String]
    let `default`: String
    let onChange: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button {
                    var next = hexes
                    next.append(`default`)
                    onChange(next)
                } label: { Image(systemName: "plus.circle") }
                .help("Add another color (creates a gradient)")
            }
            ForEach(hexes.indices, id: \.self) { i in
                HStack {
                    ColorRow(title: "", hex: hexes[i]) { newHex in
                        var next = hexes
                        if next.indices.contains(i) { next[i] = newHex }
                        onChange(next)
                    }
                    if hexes.count > 1 {
                        Button {
                            var next = hexes
                            if next.indices.contains(i) { next.remove(at: i) }
                            onChange(next)
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
