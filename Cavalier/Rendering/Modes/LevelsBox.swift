import CoreGraphics

/// 10-segment level meter per bar. Number of lit segments = floor(sample * 10).
enum LevelsBox {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, brush: FillBrush,
                     capture: CGMutablePath? = nil) {
        guard !sample.isEmpty else { return }
        let n = sample.count
        let step = (direction.isVertical ? width : height) / CGFloat(n)
        let itemsOffset = CGFloat(config.itemsOffset)
        let thickness = CGFloat(config.linesThickness)
        let strokeInset = config.filling ? CGFloat(0) : thickness / 2
        let itemW = (direction.isVertical ? step : width / 10) * (1 - itemsOffset * 2) - strokeInset
        let itemH = (direction.isVertical ? height / 10 : step) * (1 - itemsOffset * 2) - strokeInset
        let path = CGMutablePath()

        for i in 0..<n {
            let segments = Int(floor(CGFloat(sample[i]) * 10))
            for j in 0..<segments {
                let rect: CGRect
                switch direction {
                case .topBottom:
                    let x0 = x + step * (CGFloat(i) + itemsOffset) + strokeInset
                    let y0 = y + height / 10 * CGFloat(j) + height / 10 * itemsOffset + strokeInset
                    rect = CGRect(x: x0, y: y0, width: itemW - strokeInset, height: itemH - strokeInset)
                case .bottomTop:
                    let x0 = x + step * (CGFloat(i) + itemsOffset) + strokeInset
                    let y0 = y + height / 10 * CGFloat(9 - j) + height / 10 * itemsOffset + strokeInset
                    rect = CGRect(x: x0, y: y0, width: itemW - strokeInset, height: itemH - strokeInset)
                case .leftRight:
                    let x0 = x + width / 10 * CGFloat(j) + width / 10 * itemsOffset + strokeInset
                    let y0 = y + step * (CGFloat(i) + itemsOffset) + strokeInset
                    rect = CGRect(x: x0, y: y0, width: itemW - strokeInset, height: itemH - strokeInset)
                case .rightLeft:
                    let x0 = x + width / 10 * CGFloat(9 - j) + width / 10 * itemsOffset + strokeInset
                    let y0 = y + step * (CGFloat(i) + itemsOffset) + strokeInset
                    rect = CGRect(x: x0, y: y0, width: itemW - strokeInset, height: itemH - strokeInset)
                }
                if rect.width > 0 && rect.height > 0 {
                    let rx = min(rect.width, rect.height) / 2 * CGFloat(config.itemsRoundness)
                    if rx > 0 {
                        path.addRoundedRect(in: rect, cornerWidth: rx, cornerHeight: rx)
                    } else {
                        path.addRect(rect)
                    }
                }
            }
        }
        ctx.addPath(path)
        brush.apply(ctx: ctx, filling: config.filling, thickness: thickness, capture: capture)
    }
}
