import AppKit
import QuartzCore
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

    // FPS measurement
    private var drawCount: Int = 0
    private var lastFpsStamp: CFTimeInterval = 0
    private var displayFps: Int = 0

    // Cached overlay rendering assets — monospacedSystemFont + NSAttributedString.size()
    // has a known Core Text crash path on macOS 26; use a named font + NSString.draw.
    private let overlayFont: NSFont = NSFont(name: "Menlo", size: 11)
        ?? NSFont.systemFont(ofSize: 11)
    private lazy var overlayAttrs: [NSAttributedString.Key: Any] = [
        .font: overlayFont,
        .foregroundColor: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9)
    ]

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let config = config ?? Configuration.shared
        let now = CACurrentMediaTime()
        let bars = engine?.interpolatedBars(now: now) ?? []
        renderer.draw(
            in: ctx,
            sample: bars.isEmpty ? [Float](repeating: 0, count: Int(config.barPairs) * 2) : bars,
            size: bounds.size,
            config: config)

        tickFps()
        if config.showFPS {
            drawOverlay(ctx: ctx)
        }
    }

    private func tickFps() {
        let now = CACurrentMediaTime()
        if lastFpsStamp == 0 { lastFpsStamp = now }
        drawCount += 1
        let elapsed = now - lastFpsStamp
        if elapsed >= 1.0 {
            displayFps = Int((Double(drawCount) / elapsed).rounded())
            drawCount = 0
            lastFpsStamp = now
        }
    }

    private func drawOverlay(ctx: CGContext) {
        let sampleHz = engine?.sampleHz ?? 0
        let text = String(format: "draw: %d Hz   samples: %.0f Hz", displayFps, sampleHz) as NSString
        let textSize = text.size(withAttributes: overlayAttrs)
        let padding: CGFloat = 6
        let bgHeight = textSize.height + padding
        let bgWidth = textSize.width + padding * 2
        let bgRect = CGRect(
            x: 8,
            y: bounds.height - bgHeight - 8,
            width: bgWidth,
            height: bgHeight)

        ctx.saveGState()
        ctx.setFillColor(NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55).cgColor)
        let pill = CGMutablePath()
        pill.addRoundedRect(in: bgRect, cornerWidth: 4, cornerHeight: 4)
        ctx.addPath(pill)
        ctx.fillPath()
        ctx.restoreGState()

        text.draw(at: CGPoint(x: bgRect.minX + padding, y: bgRect.minY + padding / 2),
                  withAttributes: overlayAttrs)
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
