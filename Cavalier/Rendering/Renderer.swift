import AppKit
import CoreGraphics

/// Stateless-ish renderer: given a CGContext, a sample (bar values), a size, and a config,
/// draws the background, foreground (active drawing mode), and handles mirroring.
final class Renderer {
    func draw(in ctx: CGContext, sample: [Float], size: CGSize, config: Configuration) {
        let profile = config.currentProfile
        let width = size.width
        let height = size.height

        // Background
        if let bg = profile.bgColors.first, let color = NSColor(argbHex: bg) {
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Foreground setup
        let fgColor = NSColor(argbHex: profile.fgColors.first ?? "#ff3584e4") ?? NSColor.systemBlue
        if config.filling {
            ctx.setFillColor(fgColor.cgColor)
        } else {
            ctx.setStrokeColor(fgColor.cgColor)
            ctx.setLineWidth(CGFloat(config.linesThickness))
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
        }

        let margin = CGFloat(config.areaMargin)
        let innerW = max(1, width - margin * 2)
        let innerH = max(1, height - margin * 2)

        let mirrorMode = config.mirror
        switch mirrorMode {
        case .off:
            let originX = margin + (width - innerW) * CGFloat(config.areaOffsetX)
            let originY = margin + (height - innerH) * CGFloat(config.areaOffsetY)
            drawMode(ctx: ctx, sample: sample, direction: config.direction,
                     x: originX, y: originY, width: innerW, height: innerH, config: config)
        case .full:
            let halfW = mirrorHalfWidth(innerW, direction: config.direction)
            let halfH = mirrorHalfHeight(innerH, direction: config.direction)
            drawMode(ctx: ctx, sample: sample, direction: config.direction,
                     x: margin, y: margin, width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: config.reverseMirror ? sample.reversed() : sample,
                     direction: mirroredDirection(config.direction),
                     x: margin + mirrorOffsetX(innerW, direction: config.direction),
                     y: margin + mirrorOffsetY(innerH, direction: config.direction),
                     width: halfW, height: halfH, config: config)
        case .splitChannels:
            let mid = sample.count / 2
            let firstHalf = Array(sample.prefix(mid))
            let secondHalfRaw = Array(sample.suffix(from: mid))
            let secondHalf = config.reverseMirror ? secondHalfRaw : secondHalfRaw.reversed()
            let halfW = mirrorHalfWidth(innerW, direction: config.direction)
            let halfH = mirrorHalfHeight(innerH, direction: config.direction)
            drawMode(ctx: ctx, sample: firstHalf, direction: config.direction,
                     x: margin, y: margin, width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: secondHalf, direction: mirroredDirection(config.direction),
                     x: margin + mirrorOffsetX(innerW, direction: config.direction),
                     y: margin + mirrorOffsetY(innerH, direction: config.direction),
                     width: halfW, height: halfH, config: config)
        }
    }

    private func drawMode(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                          x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, config: Configuration) {
        switch config.mode {
        case .waveBox:
            WaveBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height, config: config)
        case .barsBox:
            BarsBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height, config: config)
        default:
            // Not yet implemented — fall back to BarsBox.
            BarsBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height, config: config)
        }
    }

    private func mirroredDirection(_ d: DrawingDirection) -> DrawingDirection {
        switch d {
        case .topBottom: return .bottomTop
        case .bottomTop: return .topBottom
        case .leftRight: return .rightLeft
        case .rightLeft: return .leftRight
        }
    }

    private func mirrorHalfWidth(_ w: CGFloat, direction: DrawingDirection) -> CGFloat {
        direction.isVertical ? w : w / 2
    }

    private func mirrorHalfHeight(_ h: CGFloat, direction: DrawingDirection) -> CGFloat {
        direction.isVertical ? h / 2 : h
    }

    private func mirrorOffsetX(_ w: CGFloat, direction: DrawingDirection) -> CGFloat {
        direction.isVertical ? 0 : w / 2
    }

    private func mirrorOffsetY(_ h: CGFloat, direction: DrawingDirection) -> CGFloat {
        direction.isVertical ? h / 2 : 0
    }
}
