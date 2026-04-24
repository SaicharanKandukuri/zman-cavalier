# Cavalier 2026.4.2 — Release Notes

A native-stack macOS visualizer built on Core Audio + Core Graphics + SwiftUI. This release introduces an optional bridge for driving a Keychron V6's RGB LEDs in sync with the visualizer.

---

## Install

**Requires macOS 14.4+ (Apple Silicon).**

1. Download `Cavalier-2026.4.2.dmg` from the assets below.
2. Open the DMG and drag **Cavalier** into **Applications**.
3. Strip the quarantine attribute (the build is ad-hoc signed, not notarized):

   ```sh
   xattr -dr com.apple.quarantine /Applications/Cavalier.app
   ```

4. Launch from Applications or Launchpad.

Without the `xattr` step Gatekeeper will refuse to open with *"Cavalier can't be opened"* or *"Cavalier is damaged"*. The command removes only the quarantine flag; no other security check is disabled.

---

## What's new since 2026.4.1

### Keyboard RGB bridge (opt-in)

`keyboard-bridge/` is a small Bun tool (in the source tree, not bundled in the DMG) that drives a Keychron V6's per-key RGB in sync with Cavalier's spectrum. Colour is sampled from the active `fgColors` gradient in your color profile, so switching presets in the app immediately repaints the keyboard — Classic gives you a single blue pulsing with volume; Synthwave spreads pink → purple → violet across the keys; etc.

No firmware flashing required. The bridge rides Keychron's stock vendor HID protocol (`0xA8 / PER_KEY_RGB_SET_COLOR`) and Keychron's built-in `PER_KEY_RGB` custom RGB matrix mode. No EEPROM writes — all mutations are `_noeeprom`, the bridge never sends `RGB_SAVE`. On Ctrl-C it restores your previous RGB effect.

See [`keyboard-bridge/README.md`](../keyboard-bridge/README.md) for setup. Requires `bun` on macOS.

### UDP broadcast toggle — **off by default**

To feed the bridge, Cavalier needs to emit bar frames to `udp://127.0.0.1:7777`. That's an explicit opt-in:

**Preferences → Audio → External integrations → "Broadcast spectrum to localhost (UDP 7777)"**

While enabled, any local process can read audio-derived spectrum data on that port. First launch (and upgrades from 2026.4.1) default to off.

### Under the hood

- `Audio/UDPBarSink.swift` — loopback UDP client bound lazily; gated on the preference, zero `sendto()` calls when off.
- `Configuration.udpBridgeEnabled: Bool = false` with full `Codable` upgrade path (existing `config.json` files without the key decode to `false`).
- Preferences UI: new "External integrations" section in the Audio tab with a caption explaining the exposure.

---

## Keyboard bridge — quick start

```sh
# in the source tree
cd keyboard-bridge
bun install
bun run bridge.ts
```

Then in Cavalier: **Preferences → Audio → enable the UDP toggle**. Play music. Switch color presets while it runs — the keyboard follows.

If the wave looks off (raindrops pattern, only WASD reacting), your firmware's `PER_KEY_RGB` effect index differs from the bundled default (23 for stock v6 ANSI-encoder). Run `bun run bridge.ts --probe` to find it, then pin it with `--effect <n>`.

Tested against Keychron V6 ANSI-encoder (PID `0x0361`) on stock firmware. Other v6 variants (ISO, base-ANSI, v6 Max) need a layout data swap — see the bridge README.

---

## Known limitations

- Ad-hoc signed; Gatekeeper blocks until `xattr` runs.
- arm64 only; no Universal build.
- Bridge supports v6 ANSI-encoder out of the box; other v6 variants need a one-file LED-position swap.
- Bridge's default `PER_KEY_RGB` effect index (23) is firmware-build-specific — if Keychron reshuffles it in a future firmware, use `--probe` and pass `--effect <n>`.
