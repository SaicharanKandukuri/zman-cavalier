import AppKit
import SwiftUI

/// Hidden NSViewRepresentable that exposes the hosting NSWindow so we can set
/// properties SwiftUI doesn't surface directly (level, titlebar, traffic lights).
struct WindowAccessor: NSViewRepresentable {
    let alwaysOnTop: Bool
    let borderless: Bool
    let showControls: Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { apply(to: v.window) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.title = "Cavalier"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black

        // Borderless: remove title bar entirely. Keep resizable so users can size it.
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if borderless {
            mask = [.borderless, .resizable]
        }
        if window.styleMask != mask {
            window.styleMask = mask
        }

        // Traffic lights
        let hidden = !showControls
        window.standardWindowButton(.closeButton)?.isHidden = hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = hidden
        window.standardWindowButton(.zoomButton)?.isHidden = hidden

        // Floating + follow-across-Spaces for always-on-top.
        window.level = alwaysOnTop ? .floating : .normal
        if alwaysOnTop {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.fullScreenPrimary]
        }
    }
}
