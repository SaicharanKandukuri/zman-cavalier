import CoreGraphics
import Foundation

/// Circular closed cubic-bezier curve; filling clips to the curve and fills an inner ring.
enum WaveCircle {
    static func draw(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                     x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                     rotation: CGFloat, config: Configuration) {
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

        if config.filling {
            ctx.addPath(path)
            ctx.clip()
            // Draw a stroked ring that fills the area between innerRadius and fullRadius.
            let ringWidth = fullRadius - innerRadius
            ctx.setLineWidth(ringWidth)
            let ringPath = CGMutablePath()
            ringPath.addArc(center: CGPoint(x: width / 2, y: height / 2),
                            radius: innerRadius + ringWidth / 2,
                            startAngle: 0, endAngle: twoPi,
                            clockwise: false)
            ctx.addPath(ringPath)
            ctx.strokePath()
        } else {
            ctx.setLineWidth(CGFloat(config.linesThickness))
            ctx.addPath(path)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
