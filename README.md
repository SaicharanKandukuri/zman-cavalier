# Cavalier for macOS (zman edition)

<p align="center">
  <img src="docs/banner.png" alt="Cavalier visualizer in Synthwave preset" width="640" />
</p>

A native macOS music visualizer. Independent Swift rewrite of [Nickvision Cavalier](https://github.com/NickvisionApps/Cavalier) — no CAVA, no BlackHole, no Homebrew dependencies. Uses Core Audio's process tap API to capture system audio directly.

Bundle ID: `com.zman.cavalier`.

## Credits

- Original Cavalier (GTK / .NET): © 2023 Fyodor Sobolev and the Nickvision contributors, MIT licensed. See `LICENSE.upstream`.
- macOS rewrite (this repository): separate codebase in Swift/SwiftUI, written from scratch against the original's public algorithms and UX. Not affiliated with Nickvision.

## Requirements

- macOS 14.4 or newer (Core Audio process tap requires 14.2+; some entitlement behavior stabilized in 14.4)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build & run

```bash
xcodegen generate
open Cavalier.xcodeproj
# or headless:
xcodebuild -project Cavalier.xcodeproj -scheme Cavalier -configuration Debug build
```

The `.xcodeproj` is regenerated from `project.yml` and is git-ignored — only commit `project.yml` and the Swift sources.

## Architecture

- `Audio/SystemAudioTap.swift` — Core Audio process tap + aggregate device; captures stereo Float32 @ 48 kHz.
- `Audio/AudioProcessor.swift` — Hann window → vDSP FFT → log-spaced bin grouping → autosens/sensitivity → temporal smoothing (noise reduction) → Monstercat spread.
- `Audio/VisualizerEngine.swift` — framerate-paced pull from the ring buffer; publishes `latestBars` via `@Observable`.
- `Rendering/` — pure `CGContext` drawing, one file per mode.
- `Views/VisualizerView.swift` — `NSView` driven by `CVDisplayLink` for vsync-locked redraws.

Config is persisted to `~/Library/Application Support/Cavalier/config.json`.

## License

MIT. See `LICENSE`.
