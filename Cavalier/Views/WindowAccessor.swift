import AppKit
import SwiftUI

/// Hidden NSViewRepresentable that exposes the hosting NSWindow so we can set
/// properties SwiftUI doesn't surface directly (level, titlebar appearance, etc.).
struct WindowAccessor: NSViewRepresentable {
    let alwaysOnTop: Bool

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
        window.titlebarAppearsTransparent = true
        window.title = "Cavalier"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.level = alwaysOnTop ? .floating : .normal
        // Floating windows should follow the user to every Space — matches Spotify mini.
        if alwaysOnTop {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.fullScreenPrimary]
        }
    }
}
