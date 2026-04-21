import CoreGraphics
import Foundation

/// One particle per sample, distance from inner circle scaled by sample.
enum ParticlesCircle {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, brush: FillBrush) {
        guard !sample.isEmpty else { return }
        let fullRadius = min(width, height) / 2
        let innerRadius = fullRadius * CGFloat(config.innerRadius)
        let n = sample.count
        let barWidth = 2 * CGFloat.pi * innerRadius / CGFloat(n)
        let itemsOffset = CGFloat(config.itemsOffset)
        let thickness = CGFloat(config.linesThickness)
        let strokeInset = config.filling ? CGFloat(0) : thickness / 2
        let segH = (fullRadius - innerRadius) / 10
        let cx = x + width / 2
        let cy = y + height / 2

        for i in 0..<n {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: 2 * .pi * (CGFloat(i) + 0.5) / CGFloat(n) + rotation)
            let rect = CGRect(
                x: -barWidth * (1 - itemsOffset * 2) / 2 + strokeInset,
                y: innerRadius + segH * 9 * CGFloat(sample[i]) + segH * itemsOffset + strokeInset,
                width: barWidth * (1 - itemsOffset * 2) - strokeInset * 2,
                height: segH * (1 - itemsOffset * 2) - strokeInset * 2)
            let rx = (barWidth * (1 - itemsOffset) - strokeInset * 2) * CGFloat(config.itemsRoundness)
            let ry = (segH * (1 - itemsOffset) - strokeInset * 2) * CGFloat(config.itemsRoundness)
            let path = CGMutablePath()
            if rect.width > 0 && rect.height > 0 {
                if rx > 0 && ry > 0 {
                    path.addRoundedRect(in: rect, cornerWidth: rx, cornerHeight: ry)
                } else {
                    path.addRect(rect)
                }
                ctx.addPath(path)
                brush.apply(ctx: ctx, filling: config.filling, thickness: thickness)
            }
            ctx.restoreGState()
        }
    }
}
