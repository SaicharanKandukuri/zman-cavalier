import AppKit
import CoreGraphics

/// Row (or column) of centered squares whose size scales with each sample value.
enum SpineBox {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, fallback: NSColor) {
        guard !sample.isEmpty else { return }
        let n = sample.count
        let step = (direction.isVertical ? width : height) / CGFloat(n)
        let itemsOffset = CGFloat(config.itemsOffset)
        let thickness = CGFloat(config.linesThickness)
        let strokeInset = config.filling ? CGFloat(0) : thickness
        let itemSize = step * (1 - itemsOffset * 2) - strokeInset

        for i in 0..<n {
            let v = CGFloat(sample[i])
            if v == 0 { continue }
            let size = itemSize * v
            let rect: CGRect
            switch direction {
            case .topBottom, .bottomTop:
                let cx = x + step * CGFloat(i) + step / 2
                let cy = y + height / 2
                rect = CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
            case .leftRight, .rightLeft:
                let cx = x + width / 2
                let cy = y + step * CGFloat(i) + step / 2
                rect = CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
            }
            let color = SpinePaint.color(for: sample[i], fgColors: config.currentProfile.fgColors, fallback: fallback)
            if config.filling {
                ctx.setFillColor(color.cgColor)
            } else {
                ctx.setStrokeColor(color.cgColor)
            }
            let radius = size / 2 * CGFloat(config.itemsRoundness)
            let path = CGMutablePath()
            if radius > 0 {
                path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
            } else {
                path.addRect(rect)
            }
            ctx.addPath(path)
            if config.filling { ctx.fillPath() } else { ctx.strokePath() }
        }
    }
}
