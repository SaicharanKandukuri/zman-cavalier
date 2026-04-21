import CoreGraphics

/// Simple rectangular bars. Ported from DrawBarsBox in the Skia renderer.
enum BarsBox {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration) {
        guard !sample.isEmpty else { return }
        let n = sample.count
        let step = (direction.isVertical ? width : height) / CGFloat(n)
        let itemsOffset = CGFloat(config.itemsOffset)
        let thickness = CGFloat(config.linesThickness)
        let strokeInset = config.filling ? CGFloat(0) : thickness / 2
        let path = CGMutablePath()

        for i in 0..<n {
            let v = CGFloat(sample[i])
            if v == 0 { continue }
            let rect: CGRect
            switch direction {
            case .topBottom:
                let x0 = x + step * (CGFloat(i) + itemsOffset) + strokeInset
                let x1 = x0 + step * (1 - itemsOffset * 2) - strokeInset * 2
                let y0 = y + (config.filling ? 0 : thickness / 2)
                let y1 = y + height * v - (config.filling ? 0 : thickness)
                rect = CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
            case .bottomTop:
                let x0 = x + step * (CGFloat(i) + itemsOffset) + strokeInset
                let x1 = x0 + step * (1 - itemsOffset * 2) - strokeInset * 2
                let y0 = y + height * (1 - v) + strokeInset
                let y1 = y + height - (config.filling ? 0 : thickness)
                rect = CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
            case .leftRight:
                let x0 = config.filling ? x : x + thickness / 2
                let x1 = x + width * v - (config.filling ? 0 : thickness)
                let y0 = y + step * (CGFloat(i) + itemsOffset) + strokeInset
                let y1 = y0 + step * (1 - itemsOffset * 2) - strokeInset * 2
                rect = CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
            case .rightLeft:
                let x0 = x + width * (1 - v) + strokeInset
                let x1 = x + width - (config.filling ? 0 : thickness / 2)
                let y0 = y + step * (CGFloat(i) + itemsOffset) + strokeInset
                let y1 = y0 + step * (1 - itemsOffset * 2) - strokeInset * 2
                rect = CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
            }
            if rect.width > 0 && rect.height > 0 {
                let radius = min(rect.width, rect.height) / 2 * CGFloat(config.itemsRoundness)
                if radius > 0 {
                    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
                } else {
                    path.addRect(rect)
                }
            }
        }
        ctx.addPath(path)
        if config.filling {
            ctx.fillPath()
        } else {
            ctx.strokePath()
        }
    }
}
