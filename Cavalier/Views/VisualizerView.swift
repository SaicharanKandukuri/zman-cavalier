import AppKit
import SwiftUI

struct VisualizerView: NSViewRepresentable {
    @Environment(Configuration.self) private var config
    @Environment(VisualizerEngine.self) private var engine

    func makeNSView(context: Context) -> VisualizerNSView {
        let view = VisualizerNSView()
        view.engine = engine
        view.config = config
        view.startDisplayLink()
        return view
    }

    func updateNSView(_ nsView: VisualizerNSView, context: Context) {
        nsView.config = config
        nsView.engine = engine
        nsView.needsDisplay = true
    }

    static func dismantleNSView(_ nsView: VisualizerNSView, coordinator: ()) {
        nsView.stopDisplayLink()
    }
}

final class VisualizerNSView: NSView {
    weak var engine: VisualizerEngine?
    weak var config: Configuration?
    private let renderer = Renderer()
    private var displayLink: CVDisplayLink?

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let config = config ?? Configuration.shared
        let bars = engine?.latestBars ?? []
        renderer.draw(in: ctx, sample: bars.isEmpty ? [Float](repeating: 0, count: Int(config.barPairs) * 2) : bars,
                      size: bounds.size, config: config)
    }

    func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let view = Unmanaged<VisualizerNSView>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { view.needsDisplay = true }
            return kCVReturnSuccess
        }, userInfo)
        CVDisplayLinkStart(link)
        self.displayLink = link
    }

    func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }
}
