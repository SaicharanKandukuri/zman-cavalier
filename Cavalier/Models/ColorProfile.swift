import AppKit
import Foundation

struct ColorProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var fgColors: [String]
    var bgColors: [String]
    var theme: Theme

    init(name: String = "Default",
         fgColors: [String] = ["#ff3584e4"],
         bgColors: [String] = ["#ff242424"],
         theme: Theme = .dark) {
        self.name = name
        self.fgColors = fgColors
        self.bgColors = bgColors
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey {
        case name, fgColors, bgColors, theme
    }
}

extension NSColor {
    convenience init?(argbHex: String) {
        var s = argbHex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 8, let value = UInt32(s, radix: 16) else { return nil }
        let a = CGFloat((value >> 24) & 0xff) / 255
        let r = CGFloat((value >> 16) & 0xff) / 255
        let g = CGFloat((value >> 8) & 0xff) / 255
        let b = CGFloat(value & 0xff) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
