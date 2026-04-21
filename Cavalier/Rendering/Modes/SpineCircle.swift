import AppKit
import CoreGraphics
import Foundation

/// Centered squares at each angle, scaled by sample value. Uses spine color interpolation.
enum SpineCircle {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, fallback: NSColor) {
        guard !sample.isEmpty else { return }
        let fullRadius = min(width, height) / 2
        let innerRadius = fullRadius * CGFloat(config.innerRadius)
        let n = sample.count
        let barWidth = 2 * CGFloat.pi * innerRadius / CGFloat(n)
        let itemsOffset = CGFloat(config.itemsOffset)
        let thickness = CGFloat(config.linesThickness)
        let strokeInset = config.filling ? CGFloat(0) : thickness
        let itemSize = barWidth * (1 - itemsOffset * 2) - strokeInset
        let cx = x + width / 2
        let cy = y + height / 2

        for i in 0..<n {
            let v = CGFloat(sample[i])
            if v == 0 { continue }
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: 2 * .pi * (CGFloat(i) + 0.5) / CGFloat(n) + rotation)
            let size = itemSize * v
            let rect = CGRect(
                x: -size / 2 + (config.filling ? 0 : thickness / 2),
                y: innerRadius - size / 2,
                width: size, height: size)
            let radius = size / 2 * CGFloat(config.itemsRoundness)
            let color = SpinePaint.color(for: sample[i], fgColors: config.currentProfile.fgColors, fallback: fallback)
            if config.filling {
                ctx.setFillColor(color.cgColor)
            } else {
                ctx.setStrokeColor(color.cgColor)
            }
            let path = CGMutablePath()
            if rect.width > 0 && rect.height > 0 {
                if radius > 0 {
                    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
                } else {
                    path.addRect(rect)
                }
                ctx.addPath(path)
                if config.filling { ctx.fillPath() } else { ctx.strokePath() }
            }
            ctx.restoreGState()
        }
    }
}
