# cavalier keyboard bridge

Drives a Keychron V6's RGB LEDs in sync with Cavalier's audio spectrum.
No firmware flashing — rides on the stock Keychron vendor HID protocol
(`0xA8 / PER_KEY_RGB_SET_COLOR`) that Keychron Launcher itself uses for
per-key RGB.

Colour is sampled from the **active `fgColors` gradient in your Cavalier
config**. Switch presets in the app and the keyboard follows — Classic
gives you one solid blue pulsing with amplitude; Synthwave paints
pink → purple → violet across the keys; etc.

## Requirements

- macOS (tested on 14.4+)
- [Bun](https://bun.sh) (`brew install oven-sh/bun/bun`)
- Cavalier built from this repo (the UDP sink lives in
  `Cavalier/Audio/UDPBarSink.swift`)
- A Keychron V6 with stock Keychron firmware (VID `0x3434`)

## Install

```sh
cd keyboard-bridge
bun install
```

## Run

```sh
bun run bridge.ts                  # wave mode — colour from Cavalier's active preset
bun run bridge.ts --mode pulse     # single-colour pulse (bass → bright, treble → hue)
bun run bridge.ts --demo           # 10-sec colour cycle, no audio needed
bun run bridge.ts --probe          # cycle last 6 RGB modes flooding red (see below)
bun run bridge.ts --effect 52      # pin a specific effect index
bun run bridge.ts --discover       # auto-probe instead of the baked default
bun run bridge.ts --verbose        # log raw HID traffic
bun run bridge.ts --list           # dump every HID device node-hid sees
```

Typical use: start Cavalier, then `bun run bridge.ts`. Play something
with dynamics (a track with a drop works well). Ctrl-C restores your
previous RGB effect.

## How it works

1. **Cavalier** publishes its per-frame bar array on
   `udp://127.0.0.1:7777` via the `UDPBarSink` in `VisualizerEngine.tick`.
2. **Bridge** reads bars, samples Cavalier's active colour gradient at
   each LED's x-position, scales saturation by the spectrum amplitude at
   that position, and tracks overall energy as global brightness.
3. Sends the result to the keyboard as HSV packets of 9 LEDs via
   `0xA8 / 0x0A` (`PER_KEY_RGB_SET_COLOR`), ~25 fps. The keyboard's
   `PER_KEY_RGB` custom effect is already set up to render from
   `per_key_led[]`, so no firmware work is needed — just switch to that
   mode and stream.

**No EEPROM writes.** All RGB mutations are `_noeeprom`; the bridge
never sends `RGB_SAVE` or VIA `id_custom_save`. Safe to run for hours.

## Colour sync (Cavalier → keyboard)

The bridge reads `~/Library/Application Support/Cavalier/config.json`
on startup and uses `fs.watch` to reload when Cavalier rewrites it. The
gradient is sampled in sRGB (linear interpolation between colour stops)
then converted to HSV — matches how Cavalier's own `CGGradient`
renderer looks. Single-stop gradients give a mono-hue keyboard that
pulses with volume; multi-stop gradients spread spatially across the
keys.

## If the lights go weird (raindrops pattern, only WASD reacting, etc.)

That means the bridge is writing colours but the keyboard is on an RGB
mode that ignores `per_key_led[]` (probably Keychron's `MIXED_RGB`). The
default effect index (`23`) is correct for stock Keychron V6 ANSI-encoder
firmware as of writing; if your firmware was updated or differs, probe:

```sh
bun run bridge.ts --probe
```

The bridge cycles the last few RGB matrix modes, flooding every key red
at each one. When the whole keyboard turns solid red, note the printed
index and re-run:

```sh
bun run bridge.ts --effect <that-number>
```

…or edit `DEFAULT_PER_KEY_EFFECT` in `bridge.ts` to bake it in.

## Tuning

All knobs live at the top of `bridge.ts` or inside `waveMode`:

- `FRAME_MS` — render cadence (40 ms = 25 fps). 20 ms is the practical
  floor; below that the HID endpoint backs up.
- `* 1.4` in `sampleBar(bars, xNorm) * 1.4` — amplitude-to-saturation
  gain. Raise if quiet music looks too washed.
- `energy * 380 + 40` — brightness formula. The `+ 40` is the floor so
  the keyboard never goes fully dark; raise it if you want more ambient
  glow during silence.
- EMA weights on `prevH`, `prevS` — response vs. stability. More weight
  on `prev*` = smoother but slower.

## Other V6 variants

`v6-layout.ts` holds the LED x-positions for **v6 ANSI encoder** (PID
`0x0361`). Other v6 variants (ISO, base-ANSI without encoder, v6 Max
with different PIDs) use different LED counts/positions — copy the
`g_led_config` block from `keyboards/keychron/v6/<variant>/<variant>.c`
in the QMK tree and replace `LED_X` in `v6-layout.ts`. Also adjust
`PRODUCT_PREFIX` if your keyboard reports a different name
(`"Keychron V6"`, `"Keychron V6 Max"`, etc.).

## Troubleshooting

- **"No Keychron V6 Raw HID interface found"** — matcher is strict
  (VID `0x3434`, `usagePage` `0xFF60`, `usage` `0x61`, product string
  starting with `"Keychron V6"`). Run `--list` and confirm.
- **Bridge opens device but nothing happens** — audio not playing, or
  Cavalier isn't running. Try `--demo` first to isolate the HID path;
  if that works, the UDP feed is the problem.
- **Colours look washed out** — lift `* 1.4` amplitude gain or raise
  the brightness floor.
- **Rapid flicker / dropouts** — bump `FRAME_MS` to 60 (~16 fps) and/or
  increase EMA weight on `prevS`.
- **The UI shows one colour but the keyboard stays grey** — gradient
  failed to load. Check that `~/Library/Application Support/Cavalier/config.json`
  exists; launch Cavalier at least once to create it. Restart the bridge
  after first launch.
