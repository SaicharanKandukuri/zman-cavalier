import CoreGraphics
import Foundation

/// 10-segment radial level meters around the inner circle.
enum LevelsCircle {
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
            let segments = Int(floor(CGFloat(sample[i]) * 10))
            guard segments > 0 else { continue }
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: 2 * .pi * (CGFloat(i) + 0.5) / CGFloat(n) + rotation)
            for j in 0..<segments {
                let rect = CGRect(
                    x: -barWidth * (1 - itemsOffset * 2) / 2 + strokeInset,
                    y: innerRadius + segH * CGFloat(j) + segH * itemsOffset + strokeInset,
                    width: barWidth * (1 - itemsOffset * 2) - strokeInset * 2,
                    height: segH * (1 - itemsOffset * 2) - strokeInset * 2)
                let rx = (barWidth * (1 - itemsOffset) - strokeInset * 2) * CGFloat(config.itemsRoundness)
                let ry = (segH * (1 - itemsOffset) - strokeInset * 2) * CGFloat(config.itemsRoundness)
                let path = CGMutablePath()
                if rx > 0 && ry > 0 && rect.width > 0 && rect.height > 0 {
                    path.addRoundedRect(in: rect, cornerWidth: rx, cornerHeight: ry)
                } else if rect.width > 0 && rect.height > 0 {
                    path.addRect(rect)
                }
                ctx.addPath(path)
                brush.apply(ctx: ctx, filling: config.filling, thickness: thickness)
            }
            ctx.restoreGState()
        }
    }
}
