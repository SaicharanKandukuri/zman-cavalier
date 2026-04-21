import AppKit
import CoreGraphics

/// Renderer draws background, optional background image, foreground bars, and optional
/// foreground image clipped to the bar shape.
final class Renderer {
    private let bgImageCache = ImageCache()
    private let fgImageCache = ImageCache()

    func draw(in ctx: CGContext, sample: [Float], size: CGSize, config: Configuration) {
        let profile = config.currentProfile
        let width = size.width
        let height = size.height

        // ----- Background fill -----
        let bgColors = FillBrush.parse(profile.bgColors, fallback: .black)
        let bgBrush = makeBackgroundBrush(colors: bgColors, width: width, height: height, config: config)
        let bgPath = CGMutablePath()
        bgPath.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.addPath(bgPath)
        bgBrush.apply(ctx: ctx, filling: true)

        // ----- Background image (on top of bg fill) -----
        if let bgImage = bgImageCache.image(for: config.bgImagePath) {
            drawImage(ctx: ctx, image: bgImage,
                      boundsSize: size, scale: config.bgImageScale, alpha: config.bgImageAlpha)
        }

        // ----- Foreground -----
        let fgColors = FillBrush.parse(profile.fgColors, fallback: .systemBlue)
        let fgFallback = fgColors.first ?? .systemBlue
        if !config.filling {
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
        }

        // Only collect path when a foreground image is configured.
        let fgImage = fgImageCache.image(for: config.fgImagePath)
        let capture: CGMutablePath? = fgImage != nil ? CGMutablePath() : nil

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
                     rotation: rotation, config: config, brush: brush,
                     fallback: fgFallback, capture: capture)

        case .full:
            let halfW = mirrorHalfWidth(innerW, direction: config.direction)
            let halfH = mirrorHalfHeight(innerH, direction: config.direction)
            let brush1 = makeForegroundBrush(colors: fgColors, x: margin, y: margin,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: sample, direction: config.direction,
                     x: margin, y: margin, width: halfW, height: halfH,
                     rotation: rotation, config: config, brush: brush1,
                     fallback: fgFallback, capture: capture)
            let x2 = margin + mirrorOffsetX(innerW, direction: config.direction)
            let y2 = margin + mirrorOffsetY(innerH, direction: config.direction)
            let brush2 = makeForegroundBrush(colors: fgColors.reversed(), x: x2, y: y2,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx,
                     sample: config.reverseMirror ? sample.reversed() : sample,
                     direction: mirroredDirection(config.direction),
                     x: x2, y: y2, width: halfW, height: halfH,
                     rotation: -rotation, config: config, brush: brush2,
                     fallback: fgFallback, capture: capture)

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
                     rotation: rotation, config: config, brush: brush1,
                     fallback: fgFallback, capture: capture)
            let x2 = margin + mirrorOffsetX(innerW, direction: config.direction)
            let y2 = margin + mirrorOffsetY(innerH, direction: config.direction)
            let brush2 = makeForegroundBrush(colors: fgColors.reversed(), x: x2, y: y2,
                                             width: halfW, height: halfH, config: config)
            drawMode(ctx: ctx, sample: secondHalf, direction: mirroredDirection(config.direction),
                     x: x2, y: y2, width: halfW, height: halfH,
                     rotation: -rotation, config: config, brush: brush2,
                     fallback: fgFallback, capture: capture)
        }

        // ----- Foreground image, clipped to the accumulated bar shape -----
        if let fgImage = fgImage, let capture = capture, !capture.isEmpty {
            ctx.saveGState()
            ctx.addPath(capture)
            ctx.clip()
            drawImage(ctx: ctx, image: fgImage,
                      boundsSize: size, scale: config.fgImageScale, alpha: config.fgImageAlpha)
            ctx.restoreGState()
        }
    }

    private func drawImage(ctx: CGContext, image: CGImage, boundsSize: CGSize,
                           scale: Float, alpha: Float) {
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)
        guard imgW > 0 && imgH > 0 else { return }
        // Aspect-fill: fit image so the shorter side covers the view, then apply scale.
        let cover = max(boundsSize.width / imgW, boundsSize.height / imgH)
        let s = cover * CGFloat(max(0.01, scale))
        let drawW = imgW * s
        let drawH = imgH * s
        let rect = CGRect(
            x: (boundsSize.width - drawW) / 2,
            y: (boundsSize.height - drawH) / 2,
            width: drawW, height: drawH)
        ctx.saveGState()
        ctx.setAlpha(CGFloat(max(0, min(1, alpha))))
        // The renderer's NSView uses isFlipped=true; CGImage draws bottom-up by default.
        // Flip vertically around the target rect so the image appears right-side-up.
        ctx.translateBy(x: 0, y: rect.maxY + rect.minY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private func makeBackgroundBrush(colors: [NSColor], width: CGFloat, height: CGFloat,
                                     config: Configuration) -> FillBrush {
        guard colors.count > 1 else { return .solid(colors.first ?? .black) }
        return linearGradientAlongDirection(colors: colors, x: 0, y: 0, width: width, height: height,
                                            direction: config.direction)
    }

    private func makeForegroundBrush(colors: [NSColor], x: CGFloat, y: CGFloat,
                                     width: CGFloat, height: CGFloat,
                                     config: Configuration) -> FillBrush {
        guard colors.count > 1 else { return .solid(colors.first ?? .systemBlue) }

        if config.mode == .waveCircle {
            let full = min(width, height) / 2
            let inner = full * CGFloat(config.innerRadius)
            return .radialGradient(colors: colors,
                                   center: CGPoint(x: width / 2, y: height / 2),
                                   startRadius: inner, endRadius: full)
        }
        if config.mode.rawValue > DrawingMode.waveCircle.rawValue {
            let full = min(width, height) / 2
            let inner = full * CGFloat(config.innerRadius)
            return .linearGradient(colors: colors,
                                   start: CGPoint(x: 0, y: inner),
                                   end: CGPoint(x: 0, y: full))
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
                          brush: FillBrush, fallback: NSColor, capture: CGMutablePath?) {
        switch config.mode {
        case .waveBox:
            WaveBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height,
                         rotation: rotation, config: config, brush: brush, capture: capture)
        case .levelsBox:
            LevelsBox.draw(ctx: ctx, sample: sample, direction: direction,
                           x: x, y: y, width: width, height: height,
                           rotation: rotation, config: config, brush: brush, capture: capture)
        case .particlesBox:
            ParticlesBox.draw(ctx: ctx, sample: sample, direction: direction,
                              x: x, y: y, width: width, height: height,
                              rotation: rotation, config: config, brush: brush, capture: capture)
        case .barsBox:
            BarsBox.draw(ctx: ctx, sample: sample, direction: direction,
                         x: x, y: y, width: width, height: height,
                         rotation: rotation, config: config, brush: brush, capture: capture)
        case .spineBox:
            SpineBox.draw(ctx: ctx, sample: sample, direction: direction,
                          x: x, y: y, width: width, height: height,
                          rotation: rotation, config: config, fallback: fallback)
        case .splitterBox:
            SplitterBox.draw(ctx: ctx, sample: sample, direction: direction,
                             x: x, y: y, width: width, height: height,
                             rotation: rotation, config: config, brush: brush, capture: capture)
        case .waveCircle:
            WaveCircle.draw(ctx: ctx, sample: sample, direction: direction,
                            x: x, y: y, width: width, height: height,
                            rotation: rotation, config: config, brush: brush, capture: capture)
        case .levelsCircle:
            LevelsCircle.draw(ctx: ctx, sample: sample, direction: direction,
                              x: x, y: y, width: width, height: height,
                              rotation: rotation, config: config, brush: brush, capture: capture)
        case .particlesCircle:
            ParticlesCircle.draw(ctx: ctx, sample: sample, direction: direction,
                                 x: x, y: y, width: width, height: height,
                                 rotation: rotation, config: config, brush: brush, capture: capture)
        case .barsCircle:
            BarsCircle.draw(ctx: ctx, sample: sample, direction: direction,
                            x: x, y: y, width: width, height: height,
                            rotation: rotation, config: config, brush: brush, capture: capture)
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
