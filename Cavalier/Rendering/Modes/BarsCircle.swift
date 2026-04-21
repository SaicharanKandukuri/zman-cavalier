import CoreGraphics
import Foundation

/// Radial bars: length = sample * (outerRadius - innerRadius).
enum BarsCircle {
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
        let cx = x + width / 2
        let cy = y + height / 2

        for i in 0..<n {
            let v = CGFloat(sample[i])
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: 2 * .pi * (CGFloat(i) + 0.5) / CGFloat(n) + rotation)
            let rect = CGRect(
                x: -barWidth * (1 - itemsOffset * 2) / 2 + strokeInset,
                y: innerRadius + strokeInset,
                width: barWidth * (1 - itemsOffset * 2) - strokeInset * 2,
                height: (fullRadius - innerRadius) * v - strokeInset * 2 + 1)
            if rect.width > 0 && rect.height > 0 {
                let path = CGMutablePath()
                path.addRect(rect)
                ctx.addPath(path)
                brush.apply(ctx: ctx, filling: config.filling, thickness: thickness)
            }
            ctx.restoreGState()
        }
    }
}
