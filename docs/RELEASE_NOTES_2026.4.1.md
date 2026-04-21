# Cavalier 2026.4.1 — Release Notes

A native-stack rewrite of [Nickvision Cavalier](https://github.com/NickvisionApps/Cavalier) targeting macOS 14.4+. Zero third-party dependencies in the shipped binary — everything uses first-party Apple frameworks.

![banner](banner.png)

---

## Install

**Requires macOS 14.4+ (Apple Silicon).**

1. Download `Cavalier-2026.4.1.dmg` from the assets below.
2. Open the DMG and drag **Cavalier** into **Applications**.
3. **Before launching, strip the quarantine attribute.** The build is ad-hoc signed, not notarized with an Apple Developer ID, so Gatekeeper will refuse to open it with a hard *"Cavalier can't be opened"* error (no "Open Anyway" button):

   ```sh
   xattr -dr com.apple.quarantine /Applications/Cavalier.app
   ```

4. Launch from Applications or Launchpad.

If you get *"'Cavalier' is damaged and can't be opened"* instead, that's the same issue — the xattr command above fixes both. You only need to run it once per install.

### Why?

Apple's Gatekeeper treats downloads (anything with the `com.apple.quarantine` extended attribute set by Safari / AirDrop / Messages / curl) more strictly when the app isn't signed with a paid `$99/yr` Apple Developer ID certificate. The command above removes that attribute — it doesn't disable any other security check, and once the app is trusted on first launch you never need it again.

---

## What's new since 2026.4.0

- 15 color presets in the Colors tab (Classic, Sunset, Ocean, Synthwave, Forest, Fire, Nord, Dracula, Mono, Matrix, Rainbow, Pastel, Amber, Solarized, Ice).
- Scrollable Colors tab — preset grid + per-color editors in one pane.
- Foreground + background images with clip-to-bars masking (via CGPath capture + `CGContext.clip`).
- Multi-color gradient support (linear along direction for box modes, radial from inner→outer for WaveCircle, linear local-space for other circle modes).
- Borderless / show-controls window chrome toggles.
- Always-on-top now defaults to `true` and is toggleable via ⌥⌘T.
- Gravity slider: CAVA-style instant-rise, gravity-limited fall. No more strobing on rock.
- Per-channel FFT + shared autosens/Monstercat, so the L/R seam at the center of the visualizer is gone.
- Temporal interpolation in the render loop: samples publish at ~60 Hz, the `CVDisplayLink` draws at 100/120 Hz, and the renderer lerps between consecutive frames so motion is smooth at the display's refresh rate.
- FPS overlay (bottom-left pill) showing draw Hz and sample Hz.

---

## Swift / macOS tech decisions

### No .NET, no CAVA, no BlackHole

The upstream project spawns a `cava` subprocess via `System.Diagnostics.Process` and reads 16-bit little-endian samples over its stdout. That works on Linux because PulseAudio exposes a global output monitor. On macOS, `cava` with `method=coreaudio` captures *input* devices only — it would never see Spotify playing without a loopback driver like BlackHole.

Rather than ship the CAVA binary and a 2-minute BlackHole setup as a user tax, the rewrite uses **Core Audio's process tap API** (`CATapDescription`, `AudioHardwareCreateProcessTap`, `AudioHardwareCreateAggregateDevice`) introduced in macOS 14.2. With `isExclusive = true` and an empty `processes` list, the tap captures everything, gets wrapped into an aggregate device, and delivers Float32 stereo @ 48 kHz via a plain `AudioDeviceIOProcID` callback. No extensions, no permission dialog, no extra install steps.

### Accelerate/vDSP for FFT

CAVA does its own FFT with FFTW internally. In Swift we get `vDSP.FFT` (Swift overlay on `vDSP_fft_zrip`) for free — hardware-accelerated via AMX on Apple Silicon, ~20 lines to set up, ~0.5 ms per 4096-sample stereo frame. Dropping FFTW removes a C dependency.

### Pipeline split: per-channel `spectrum()` + shared `BarFinalizer`

An early bug: the visualizer had a visible seam at the center because left and right channels were running autosens independently. The fix was to split the processor:

- `AudioProcessor.spectrum(frame:)` — per channel. Hann window → vDSP FFT → log-spaced log-bin grouping → per-channel temporal EMA (noise reduction). Returns un-normalized magnitudes.
- `BarFinalizer.finalize(bars:config:)` — shared across channels. Slow-attack autosens, Monstercat neighbor spread, CAVA-style gravity (instant rise, fall-rate-limited drop).

Running autosens and Monstercat on the concatenated stereo array is what makes the L/R halves line up cleanly.

### Rendering: `CGContext` in `NSView.draw(_:)`, not Metal

All 11 drawing modes are 2D path construction — no per-pixel shaders, no textures beyond optional images. `CGMutablePath.addCurve`/`addRoundedRect`/`addArc` maps 1-to-1 from the upstream `SKPath` code. Metal was evaluated and rejected: it would add hundreds of lines of pipeline/shader plumbing for zero visual benefit at the resolutions the app runs at.

Instead: an `NSView` subclass with `isFlipped = true` (matches Skia's top-down y-axis so the upstream math ports verbatim) overrides `draw(_:)` and pulls the current `CGContext` from `NSGraphicsContext.current`.

### `CVDisplayLink` + temporal interpolation

The audio engine publishes new bar frames at `config.framerate` (default 60 Hz) via a `DispatchSourceTimer`. The view redraws whenever `CVDisplayLink` fires — 60 Hz on a standard display, 100/120 Hz on ProMotion. Without interpolation, the difference manifests as visible stutter: on a 120 Hz display, half the draws show duplicate sample data.

Solution: the engine stores a `BarFrame` struct with `(previous, current, publishTime, interval)`. In `NSView.draw(_:)` the renderer computes `alpha = (now - publishTime) / interval` and lerps element-wise between `previous` and `current`. The display link now produces visually distinct frames at its native rate regardless of sample rate.

### `FillBrush` abstraction for gradients

Upstream uses SkiaSharp's `SKShader` which handles gradient fills and strokes transparently. Core Graphics splits the job:

- Solid fills: `setFillColor` + `fillPath`.
- Gradient fills: `clip()` to the current path, then `drawLinearGradient` or `drawRadialGradient` over the clipped region.
- Stroking with a gradient: requires `replacePathWithStrokedPath()` (converts a stroke into a fillable annular shape) + the gradient fill dance, or falls back to the first color for solid strokes.

The `FillBrush` enum hides all three cases behind one `apply(ctx:filling:thickness:capture:)` method so the 9 non-spine modes don't care which variant is active. Circle modes pass the brush into their per-bar rotated context so linear gradients align with each radial bar direction rather than rotating with every bar.

### Path capture for foreground image masking

The upstream foreground-image feature clips an image to the bar silhouette. To support this across world-space box modes and locally-rotated circle modes uniformly, `FillBrush.apply` takes an optional `capture: CGMutablePath?`. Before consuming the context's current path, it grabs the path, applies `ctx.ctm` via `CGPath.copy(using: &matrix)` to bring it into world coordinates, and appends to the capture. The renderer builds up the aggregate foreground silhouette across all drawMode calls (including both halves of mirror mode), then clips to it and paints the image in one pass.

### `@Observable` over `@StateObject` / Combine

`@Observable` (Swift Macro, available from macOS 14) gives us `willSet` / `didSet` granularity without boilerplate `@Published` and without the retain cycles that `ObservableObject` closures inside `.sink` love to create. The `Configuration` and `VisualizerEngine` classes are both `@Observable`; SwiftUI views reach them via `@Environment(Configuration.self)` and NSView subclasses read properties directly (no observation registered — the `CVDisplayLink` drives redraws).

### `NSViewRepresentable` bridges

Two places SwiftUI can't do what AppKit can:

- `WindowAccessor` — a zero-size `NSView` whose sole purpose is to grab `view.window` on first layout so we can set `NSWindow.level = .floating` (always-on-top), toggle `styleMask` between `[.titled, .closable, .miniaturizable, .resizable]` and `[.borderless, .resizable]` (borderless mode), and hide individual traffic-light buttons. SwiftUI's window APIs don't expose any of these.
- `VisualizerView` — wraps `VisualizerNSView` so the visualizer can own its own `CVDisplayLink` and draw via `CGContext` while everything else stays in SwiftUI.

### Swift Codable, not `PropertyListEncoder`

`Configuration` is a `@Observable final class` conforming to `Codable` with explicit `init(from:)` and `encode(to:)`. Every field has a sensible default so adding a new preference (e.g. `alwaysOnTop`, `gravity`, `bgImagePath`) is a one-line change that's forward- and backward-compatible with old JSON files on disk. No model migrations needed.

### Project layout: XcodeGen, not checked-in `.xcodeproj`

The `.xcodeproj` is regenerated from `project.yml`. Adding a new source file is a single `xcodegen generate` away, no pbxproj merge conflicts, no mystery UUID churn. Only `project.yml`, the Swift sources, `Info.plist` and `.entitlements` are under version control.

### What was deliberately left out

- **Metal** — overkill for 2D paths at UI resolutions.
- **AVAudioEngine** — wasn't suited to capture system output (taps the engine's own mix, not the system mixdown).
- **ScreenCaptureKit audio** — works 13+, but shows a persistent "Cavalier is recording your screen" chip in the menu bar. Process tap is cleaner.
- **Avalonia / MAUI / any .NET** — user preference plus: running the .NET runtime for a 500-line visualizer that could be ~1 MB of native Swift is the wrong trade-off.

---

## Known limitations

- Ad-hoc signed; Gatekeeper will block on first launch unless you right-click → Open, or run `xattr -dr com.apple.quarantine /Applications/Cavalier.app`.
- No Universal build yet — arm64 only. Intel Mac support would require adding `ARCHS = arm64 x86_64` and a rebuild.
- No Developer ID notarization; the app isn't eligible for standalone distribution outside GitHub releases.
- No multiple-profile UI yet; there's one color profile slot and presets overwrite it.
- Autohide-header and Sharp-corners toggles from the upstream config are still unwired on the macOS side.
