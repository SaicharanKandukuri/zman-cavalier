import AppKit

/// Spine/particle-per-sample color: when the active profile has a gradient
/// foreground color list, pick and lerp a color based on the sample intensity.
enum SpinePaint {
    static func color(for sample: Float, fgColors: [String], fallback: NSColor) -> NSColor {
        guard fgColors.count > 1 else { return fallback }
        let pos = Float(fgColors.count - 1) * (1 - sample)
        let lo = max(0, min(fgColors.count - 1, Int(floor(pos))))
        let hi = max(0, min(fgColors.count - 1, Int(ceil(pos))))
        let weight = sample < 1 ? CGFloat(pos.truncatingRemainder(dividingBy: 1)) : 1
        guard let c1 = NSColor(argbHex: fgColors[lo]), let c2 = NSColor(argbHex: fgColors[hi]) else {
            return fallback
        }
        let r = c1.redComponent * (1 - weight) + c2.redComponent * weight
        let g = c1.greenComponent * (1 - weight) + c2.greenComponent * weight
        let b = c1.blueComponent * (1 - weight) + c2.blueComponent * weight
        let a = c1.alphaComponent * (1 - weight) + c2.alphaComponent * weight
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
