import AppKit
import CoreGraphics

/// A fill style (solid color, linear gradient, or radial gradient) plus an apply() method
/// that draws it to a CGContext's current path (clipping when a gradient is requested).
enum FillBrush {
    case solid(NSColor)
    case linearGradient(colors: [NSColor], start: CGPoint, end: CGPoint)
    case radialGradient(colors: [NSColor], center: CGPoint, startRadius: CGFloat, endRadius: CGFloat)

    /// Apply this brush to the CGContext's current path (which must already be added).
    /// `filling=true` fills the path; `filling=false` strokes it (solid colors only —
    /// gradient strokes fall back to the first color).
    func apply(ctx: CGContext, filling: Bool, thickness: CGFloat = 0) {
        switch self {
        case .solid(let color):
            if filling {
                ctx.setFillColor(color.cgColor)
                ctx.fillPath()
            } else {
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(thickness)
                ctx.strokePath()
            }

        case .linearGradient(let colors, let start, let end):
            if filling {
                drawGradient(ctx: ctx) { gradient in
                    ctx.drawLinearGradient(gradient, start: start, end: end,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
            } else {
                ctx.setStrokeColor((colors.first ?? .systemBlue).cgColor)
                ctx.setLineWidth(thickness)
                ctx.strokePath()
            }

        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            if filling {
                drawGradient(ctx: ctx) { gradient in
                    ctx.drawRadialGradient(gradient,
                                           startCenter: center, startRadius: startRadius,
                                           endCenter: center, endRadius: endRadius,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
            } else {
                ctx.setStrokeColor((colors.first ?? .systemBlue).cgColor)
                ctx.setLineWidth(thickness)
                ctx.strokePath()
            }
        }
    }

    private func drawGradient(ctx: CGContext, body: (CGGradient) -> Void) {
        let colorArray: [NSColor]
        switch self {
        case .linearGradient(let cs, _, _): colorArray = cs
        case .radialGradient(let cs, _, _, _): colorArray = cs
        default: return
        }
        let cgColors = colorArray.map { $0.cgColor } as CFArray
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: space, colors: cgColors, locations: nil)
        else { return }
        ctx.saveGState()
        ctx.clip()  // consume current path as clip
        body(gradient)
        ctx.restoreGState()
    }

    static func parse(_ hex: [String], fallback: NSColor) -> [NSColor] {
        let parsed = hex.compactMap { NSColor(argbHex: $0) }
        return parsed.isEmpty ? [fallback] : parsed
    }
}
