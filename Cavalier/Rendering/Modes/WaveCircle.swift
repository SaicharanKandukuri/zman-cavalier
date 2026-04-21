import CoreGraphics
import Foundation

/// Circular closed cubic-bezier curve. Filled variant fills an annular ring clipped to the wave.
enum WaveCircle {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration, brush: FillBrush,
                     capture: CGMutablePath? = nil) {
        guard !sample.isEmpty else { return }
        let fullRadius = min(width, height) / 2
        let innerRadius = fullRadius * CGFloat(config.innerRadius)
        let radius = fullRadius - innerRadius
        let n = sample.count
        let twoPi = 2 * CGFloat.pi
        let halfPi = CGFloat.pi / 2
        let path = CGMutablePath()

        func pt(_ angle: CGFloat, _ s: Float) -> CGPoint {
            let r = innerRadius + radius * CGFloat(s)
            return CGPoint(x: width / 2 + r * cos(halfPi + angle),
                           y: height / 2 + r * sin(halfPi + angle))
        }

        ctx.saveGState()
        ctx.translateBy(x: x, y: y)

        let startAngle: CGFloat = rotation
        path.move(to: pt(startAngle, sample[0]))
        for i in 0..<(n - 1) {
            let a1 = twoPi * (CGFloat(i) + 0.5) / CGFloat(n) + rotation
            let a2 = twoPi * CGFloat(i + 1) / CGFloat(n) + rotation
            let c1 = pt(a1, sample[i])
            let c2 = pt(a1, sample[i + 1])
            let end = pt(a2, sample[i + 1])
            path.addCurve(to: end, control1: c1, control2: c2)
        }
        let last = n - 1
        let aMid = twoPi * (CGFloat(last) + 0.5) / CGFloat(n) + rotation
        let c1 = pt(aMid, sample[last])
        let c2 = pt(aMid, sample[0])
        let end = pt(startAngle, sample[0])
        path.addCurve(to: end, control1: c1, control2: c2)
        path.closeSubpath()

        if let capture = capture {
            var m = ctx.ctm
            let worldPath = path.copy(using: &m) ?? path
            capture.addPath(worldPath)
        }

        if config.filling {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()

            let ringWidth = fullRadius - innerRadius
            let ringPath = CGMutablePath()
            ringPath.addArc(center: CGPoint(x: width / 2, y: height / 2),
                            radius: innerRadius + ringWidth / 2,
                            startAngle: 0, endAngle: twoPi,
                            clockwise: false)
            ctx.addPath(ringPath)
            ctx.setLineWidth(ringWidth)
            ctx.replacePathWithStrokedPath()
            brush.apply(ctx: ctx, filling: true)

            ctx.restoreGState()
        } else {
            ctx.addPath(path)
            brush.apply(ctx: ctx, filling: false, thickness: CGFloat(config.linesThickness))
        }
        ctx.restoreGState()
    }
}
