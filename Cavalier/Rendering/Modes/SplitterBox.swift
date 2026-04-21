import CoreGraphics

/// Zigzag polyline through center that alternates above/below with each sample.
enum SplitterBox {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, brush: FillBrush,
                     capture: CGMutablePath? = nil) {
        guard !sample.isEmpty else { return }
        let n = sample.count
        let step = (direction.isVertical ? width : height) / CGFloat(n)
        let path = CGMutablePath()
        var orient: CGFloat = 1

        switch direction {
        case .topBottom:
            path.move(to: CGPoint(x: x, y: y + height / 2 * (1 + CGFloat(sample[0]))))
        case .bottomTop:
            orient = -1
            path.move(to: CGPoint(x: x, y: y + height / 2 * (1 + CGFloat(sample[0]) * orient)))
        case .leftRight:
            path.move(to: CGPoint(x: x + width / 2 * (1 + CGFloat(sample[0])), y: y))
        case .rightLeft:
            orient = -1
            path.move(to: CGPoint(x: x + width / 2 * (1 + CGFloat(sample[0]) * orient), y: y))
        }

        for i in 0..<n {
            let v = CGFloat(sample[i])
            let sign: CGFloat = (i % 2 == 0) ? orient : -orient
            switch direction {
            case .topBottom, .bottomTop:
                if i > 0 {
                    path.addLine(to: CGPoint(x: x + step * CGFloat(i), y: y + height / 2))
                }
                path.addLine(to: CGPoint(x: x + step * CGFloat(i), y: y + height / 2 * (1 + v * sign)))
                path.addLine(to: CGPoint(x: x + step * CGFloat(i + 1), y: y + height / 2 * (1 + v * sign)))
                if i < n - 1 {
                    path.addLine(to: CGPoint(x: x + step * CGFloat(i + 1), y: y + height / 2))
                }
            case .leftRight, .rightLeft:
                if i > 0 {
                    path.addLine(to: CGPoint(x: x + width / 2, y: y + step * CGFloat(i)))
                }
                path.addLine(to: CGPoint(x: x + width / 2 * (1 + v * sign), y: y + step * CGFloat(i)))
                path.addLine(to: CGPoint(x: x + width / 2 * (1 + v * sign), y: y + step * CGFloat(i + 1)))
                if i < n - 1 {
                    path.addLine(to: CGPoint(x: x + width / 2, y: y + step * CGFloat(i + 1)))
                }
            }
        }

        let thickness = CGFloat(config.linesThickness)
        if !config.filling {
            ctx.addPath(path)
            brush.apply(ctx: ctx, filling: false, thickness: thickness, capture: capture)
        }
        switch direction {
        case .topBottom:
            path.addLine(to: CGPoint(x: x + width, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
        case .bottomTop:
            path.addLine(to: CGPoint(x: x + width, y: y + height))
            path.addLine(to: CGPoint(x: x, y: y + height))
        case .leftRight:
            path.addLine(to: CGPoint(x: x, y: y + height))
            path.addLine(to: CGPoint(x: x, y: y))
        case .rightLeft:
            path.addLine(to: CGPoint(x: x + width, y: y + height))
            path.addLine(to: CGPoint(x: x + width, y: y))
        }
        path.closeSubpath()
        if config.filling {
            ctx.addPath(path)
            brush.apply(ctx: ctx, filling: true, thickness: thickness, capture: capture)
        }
    }
}
