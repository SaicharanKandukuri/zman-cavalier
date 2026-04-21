import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let win = v.window else { return }
            win.titlebarAppearsTransparent = true
            win.title = "Cavalier"
            win.isMovableByWindowBackground = true
            win.backgroundColor = .black
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
