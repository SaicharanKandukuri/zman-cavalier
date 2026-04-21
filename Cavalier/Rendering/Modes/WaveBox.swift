import CoreGraphics

/// Smooth cubic-bezier wave across the drawing area. Ported from the Skia SKPath CubicTo version.
enum WaveBox {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, brush: FillBrush) {
        guard sample.count >= 2 else { return }
        let n = sample.count
        let axisLength = direction.isVertical ? width : height
        let step = axisLength / CGFloat(n - 1)
        let thickness = CGFloat(config.linesThickness)
        let path = CGMutablePath()

        var pts = [CGPoint](repeating: .zero, count: n)
        var grads = [CGFloat](repeating: 0, count: n)

        let flipped: Bool
        switch direction {
        case .topBottom, .bottomTop:
            flipped = direction == .topBottom
            for i in 0..<n {
                pts[i] = CGPoint(x: step * CGFloat(i), y: height * CGFloat(1 - sample[i]))
            }
            for i in 0..<n {
                let prev = pts[max(i - 1, 0)]
                let next = pts[min(i + 1, n - 1)]
                let g = next.y - prev.y
                grads[i] = (i == 0 || i == n - 1) ? g : g / 2
            }
            let yOffset = y + (config.filling ? 0 : thickness / 2)
            path.move(to: CGPoint(x: x + pts[0].x, y: yOffset + flipCoord(flipped, height, pts[0].y)))
            for i in 0..<(n - 1) {
                let c1 = CGPoint(
                    x: x + pts[i].x + step * 0.5,
                    y: yOffset + flipCoord(flipped, height, pts[i].y + grads[i] * 0.5))
                let c2 = CGPoint(
                    x: x + pts[i + 1].x - step * 0.5,
                    y: yOffset + flipCoord(flipped, height, pts[i + 1].y - grads[i + 1] * 0.5))
                let end = CGPoint(
                    x: x + pts[i + 1].x,
                    y: yOffset + flipCoord(flipped, height, pts[i + 1].y))
                path.addCurve(to: end, control1: c1, control2: c2)
            }
            if config.filling {
                path.addLine(to: CGPoint(x: x + width, y: y + flipCoord(flipped, height, height)))
                path.addLine(to: CGPoint(x: x, y: y + flipCoord(flipped, height, height)))
                path.closeSubpath()
            }

        case .leftRight, .rightLeft:
            flipped = direction == .rightLeft
            for i in 0..<n {
                pts[i] = CGPoint(x: width * CGFloat(sample[i]), y: step * CGFloat(i))
            }
            for i in 0..<n {
                let prev = pts[max(i - 1, 0)]
                let next = pts[min(i + 1, n - 1)]
                let g = next.x - prev.x
                grads[i] = (i == 0 || i == n - 1) ? g : g / 2
            }
            let xOffset = x - (config.filling ? 0 : thickness / 2)
            path.move(to: CGPoint(x: xOffset + flipCoord(flipped, width, pts[0].x), y: y + pts[0].y))
            for i in 0..<(n - 1) {
                let c1 = CGPoint(
                    x: xOffset + flipCoord(flipped, width, pts[i].x + grads[i] * 0.5),
                    y: y + pts[i].y + step * 0.5)
                let c2 = CGPoint(
                    x: xOffset + flipCoord(flipped, width, pts[i + 1].x - grads[i + 1] * 0.5),
                    y: y + pts[i + 1].y - step * 0.5)
                let end = CGPoint(
                    x: xOffset + flipCoord(flipped, width, pts[i + 1].x),
                    y: y + pts[i + 1].y)
                path.addCurve(to: end, control1: c1, control2: c2)
            }
            if config.filling {
                path.addLine(to: CGPoint(x: x + flipCoord(flipped, width, 0), y: y + height))
                path.addLine(to: CGPoint(x: x + flipCoord(flipped, width, 0), y: y))
                path.closeSubpath()
            }
        }

        ctx.addPath(path)
        brush.apply(ctx: ctx, filling: config.filling, thickness: thickness)
    }

    private static func flipCoord(_ enabled: Bool, _ screenDim: CGFloat, _ v: CGFloat) -> CGFloat {
        let clamped = max(0, min(v, screenDim))
        return enabled ? screenDim - clamped : clamped
    }
}
