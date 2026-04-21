import AppKit
import CoreGraphics

/// Stateless-ish renderer: given a CGContext, a sample (bar values), a size, and a config,
/// draws the background, foreground (active drawing mode), and handles mirroring.
final class Renderer {
    func draw(in ctx: CGContext, sample: [Float], size: CGSize, config: Configuration) {
        let profile = config.currentProfile
        let width = size.width
        let height = size.height

        // ----- Background -----
        let bgColors = FillBrush.parse(profile.bgColors, fallback: .black)
        let bgBrush = makeBackgroundBrush(colors: bgColors, width: width, height: height, config: config)
        let bgPath = CGMutablePath()
        bgPath.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.addPath(bgPath)
        bgBrush.apply(ctx: ctx, filling: true)

        // ----- Foreground setup -----
        let fgColors = FillBrush.parse(profile.fgColors, fallback: .systemBlue)
        let fgFallback = fgColors.first ?? .systemBlue
        if !config.filling {
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
        }

        let margin = CGFloat(config.areaMargin)
        let innerW = max(1, width - margin * 2)
        let innerH = max(1, height - margin * 2)
        let rotation = CGFloat(config.rotation)

        switch config.mirror {
        case .off:
            let originX = margin + (width - innerW) * CGFloat(config.areaOffsetX)
            let originY = margin + (height - innerH) * CGFloat(config.areaOffsetY)
            let brush = makeForegroundBrush(colors: fgColors, x: originX, y: originY,
                                            width: innerW, height: innerH, config: config)
            drawMode(ctx: ctx, sample: sample, direction: config.direction,
                     x: originX, y: originY, width: innerW, height: innerH,
                     rotation: rotation, config: config, brush: brush, fallback: fgFallback)

        case .full:
            let halfW = mirrorHalfWidth(innerW, direction: config.direction)
            let halfH = mirrorHalfHeight(innerH, direction: config.direction)
            let brush1 = makeForegroundBrush(colors: fgColors, x: margin, y: margin,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: sample, direction: config.direction,
                     x: margin, y: margin, width: halfW, height: halfH,
                     rotation: rotation, config: config, brush: brush1, fallback: fgFallback)
            let x2 = margin + mirrorOffsetX(innerW, direction: config.direction)
            let y2 = margin + mirrorOffsetY(innerH, direction: config.direction)
            let brush2 = makeForegroundBrush(colors: fgColors.reversed(), x: x2, y: y2,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx,
                     sample: config.reverseMirror ? sample.reversed() : sample,
                     direction: mirroredDirection(config.direction),
                     x: x2, y: y2, width: halfW, height: halfH,
                     rotation: -rotation, config: config, brush: brush2, fallback: fgFallback)

        case .splitChannels:
            let mid = sample.count / 2
            let firstHalf = Array(sample.prefix(mid))
            let secondHalfRaw = Array(sample.suffix(from: mid))
            let secondHalf = config.reverseMirror ? secondHalfRaw : secondHalfRaw.reversed()
            let halfW = mirrorHalfWidth(innerW, direction: config.direction)
            let halfH = mirrorHalfHeight(innerH, direction: config.direction)
            let brush1 = makeForegroundBrush(colors: fgColors, x: margin, y: margin,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: firstHalf, direction: config.direction,
                     x: margin, y: margin, width: halfW, height: halfH,
                     rotation: rotation, config: config, brush: brush1, fallback: fgFallback)
            let x2 = margin + mirrorOffsetX(innerW, direction: config.direction)
            let y2 = margin + mirrorOffsetY(innerH, direction: config.direction)
            let brush2 = makeForegroundBrush(colors: fgColors.reversed(), x: x2, y: y2,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: secondHalf, direction: mirroredDirection(config.direction),
                     x: x2, y: y2, width: halfW, height: halfH,
                     rotation: -rotation, config: config, brush: brush2, fallback: fgFallback)
        }
    }

    /// Linear gradient along the drawing direction, or solid if just one color.
    private func makeBackgroundBrush(colors: [NSColor], width: CGFloat, height: CGFloat,
                                     config: Configuration) -> FillBrush {
        guard colors.count > 1 else { return .solid(colors.first ?? .black) }
        return linearGradientAlongDirection(colors: colors, x: 0, y: 0, width: width, height: height,
                                            direction: config.direction)
    }

    /// Compute the gradient for the foreground, accounting for mode (WaveCircle = radial,
    /// other Circle modes = vertical) and direction (Box modes = along direction).
    private func makeForegroundBrush(colors: [NSColor], x: CGFloat, y: CGFloat,
                                     width: CGFloat, height: CGFloat,
                                     config: Configuration) -> FillBrush {
        guard colors.count > 1 else { return .solid(colors.first ?? .systemBlue) }

        if config.mode == .waveCircle {
            let full = min(width, height) / 2
            let inner = full * CGFloat(config.innerRadius)
            return .radialGradient(colors: colors,
                                   center: CGPoint(x: x + width / 2, y: y + height / 2),
                                   startRadius: inner, endRadius: full)
        }
        if config.mode.rawValue > DrawingMode.waveCircle.rawValue {
            // Other circle modes — linear vertical from inner ring outward.
            let short = min(width, height)
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: x, y: y + short * CGFloat(config.innerRadius) / 2),
                                   end: CGPoint(x: x, y: y + short / 2))
        }
        return linearGradientAlongDirection(colors: colors, x: x, y: y, width: width, height: height,
                                            direction: config.direction)
    }

    private func linearGradientAlongDirection(colors: [NSColor], x: CGFloat, y: CGFloat,
                                              width: CGFloat, height: CGFloat,
                                              direction: DrawingDirection) -> FillBrush {
        switch direction {
        case .topBottom:
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: x, y: y),
                                   end: CGPoint(x: x, y: y + height))
        case .bottomTop:
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: x, y: y + height),
                                   end: CGPoint(x: x, y: y))
        case .leftRight:
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: x, y: y),
                                   end: CGPoint(x: x + width, y: y))
        case .rightLeft:
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: x + width, y: y),
                                   end: CGPoint(x: x, y: y))
        }
    }

    private func drawMode(ctx: CGContext, sample: [Float], direction: DrawingDirection,
                          x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                          rotation: CGFloat, config: Configuration,
                          brush: FillBrush, fallback: NSColor) {
        switch config.mode {
        case .waveBox:
            WaveBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height,
                         rotation: rotation, config: config, brush: brush)
        case .levelsBox:
            LevelsBox.draw(ctx: ctx, sample: sample, direction: direction,
                           x: x, y: y, width: width, height: height,
                           rotation: rotation, config: config, brush: brush)
        case .particlesBox:
            ParticlesBox.draw(ctx: ctx, sample: sample, direction: direction,
                              x: x, y: y, width: width, height: height,
                              rotation: rotation, config: config, brush: brush)
        case .barsBox:
            BarsBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height,
                         rotation: rotation, config: config, brush: brush)
        case .spineBox:
            SpineBox.draw(ctx: ctx, sample: sample, direction: direction,
                          x: x, y: y, width: width, height: height,
                          rotation: rotation, config: config, fallback: fallback)
        case .splitterBox:
            SplitterBox.draw(ctx: ctx, sample: sample, direction: direction,
                             x: x, y: y, width: width, height: height,
                             rotation: rotation, config: config, brush: brush)
        case .waveCircle:
            WaveCircle.draw(ctx: ctx, sample: sample, direction: direction,
                            x: x, y: y, width: width, height: height,
                            rotation: rotation, config: config, brush: brush)
        case .levelsCircle:
            LevelsCircle.draw(ctx: ctx, sample: sample, direction: direction,
                              x: x, y: y, width: width, height: height,
                              rotation: rotation, config: config, brush: brush)
        case .particlesCircle:
            ParticlesCircle.draw(ctx: ctx, sample: sample, direction: direction,
                                 x: x, y: y, width: width, height: height,
                                 rotation: rotation, config: config, brush: brush)
        case .barsCircle:
            BarsCircle.draw(ctx: ctx, sample: sample, direction: direction,
                            x: x, y: y, width: width, height: height,
                            rotation: rotation, config: config, brush: brush)
        case .spineCircle:
            SpineCircle.draw(ctx: ctx, sample: sample, direction: direction,
                             x: x, y: y, width: width, height: height,
                             rotation: rotation, config: config, fallback: fallback)
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
