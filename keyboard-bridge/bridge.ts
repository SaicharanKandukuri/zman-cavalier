import HID from "node-hid";
import dgram from "node:dgram";
import { LED_X, LED_COUNT, X_MAX } from "./v6-layout.ts";
import { CavalierColors, rgbToHsv } from "./cavalier-colors.ts";

// Keychron V6 (all variants use VID 0x3434). Raw HID interface is always usagePage 0xFF60 / usage 0x61.
const VID = 0x3434;
const PRODUCT_PREFIX = "Keychron V6";
const USAGE_PAGE = 0xff60;
const USAGE = 0x61;
const UDP_PORT = 7777;

// VIA custom-value protocol (channel 3 = RGB matrix, value 2 = effect mode).
const ID_CUSTOM_SET_VALUE = 0x07;
const ID_CUSTOM_GET_VALUE = 0x08;
const CHANNEL_RGB_MATRIX = 3;
const VAL_BRIGHTNESS = 1;
const VAL_EFFECT = 2;
const VAL_COLOR = 4;

// Keychron vendor command 0xA8 — subcommands documented in
// keyboards/keychron/common/rgb/keychron_rgb.c (enum near line 45).
const KC_RGB_CMD = 0xa8;
const KC_RGB_PROTOCOL_VER = 0x01;
const KC_PER_KEY_RGB_SET_TYPE = 0x08;
const KC_PER_KEY_RGB_SET_COLOR = 0x0a;
const PER_KEY_TYPE_SOLID = 0x00;

// Keychron's Per-Key-RGB custom effect renders from `per_key_led[]` but overrides V
// with the global rgb_matrix_config.hsv.v. So we carry amplitude in S, not V.
const LEDS_PER_PACKET = 9; // max per PER_KEY_RGB_SET_COLOR packet (firmware caps at 9)
const FRAME_MS = 40; // ~25 fps of full-keyboard updates (~12 packets per frame → 300 pps)

// Known-good PER_KEY_RGB effect index for stock Keychron V6 ANSI-encoder firmware
// (confirmed by --probe). If your firmware build differs, pass --effect <n> or --discover.
const DEFAULT_PER_KEY_EFFECT = 23;

function listDevices() {
  for (const d of HID.devices()) console.log(JSON.stringify(d));
}

function findDevice() {
  return HID.devices().find(
    (d) =>
      d.vendorId === VID &&
      (d.product ?? "").startsWith(PRODUCT_PREFIX) &&
      d.usagePage === USAGE_PAGE &&
      d.usage === USAGE,
  );
}

function openDevice(): HID.HID {
  const dev = findDevice();
  if (!dev?.path) {
    throw new Error(
      `No Keychron V6 Raw HID interface found (VID=0x3434, usagePage=0xFF60, usage=0x61). Run --list to inspect.`,
    );
  }
  console.log(`opened ${dev.product} @ ${dev.path} (pid=0x${dev.productId!.toString(16)})`);
  return new HID.HID(dev.path);
}

function send(hid: HID.HID, cmd: number[]) {
  const buf = new Array(33).fill(0); // report ID (0x00) + 32-byte report
  for (let i = 0; i < cmd.length && i < 32; i++) buf[i + 1] = cmd[i];
  hid.write(buf);
}

// Drop any queued reports (Keychron's state_notify sends spontaneous KC_GET_DEFAULT_LAYER
// packets; those corrupt our read-after-write probes).
function drain(hid: HID.HID) {
  for (let i = 0; i < 16; i++) {
    const r = hid.readTimeout(5);
    if (r.length === 0) return;
  }
}

// Send a VIA get_value request and keep reading until we see the echo for the right
// command_id/channel/value_id. Discards any unrelated reports (state-notify, etc).
function readValue(hid: HID.HID, channel: number, value: number, verbose = false): number[] {
  drain(hid);
  send(hid, [ID_CUSTOM_GET_VALUE, channel, value]);
  for (let attempt = 0; attempt < 8; attempt++) {
    const reply = hid.readTimeout(250);
    if (reply.length === 0) continue;
    if (verbose) console.log(`  rx ${reply.slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join(" ")}`);
    if (reply[0] === ID_CUSTOM_GET_VALUE && reply[1] === channel && reply[2] === value) {
      return reply.slice(3);
    }
    // Unexpected packet (layer change notify etc) — keep reading.
  }
  return [];
}

function setEffect(hid: HID.HID, mode: number) {
  send(hid, [ID_CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VAL_EFFECT, mode]);
}

function setBrightness(hid: HID.HID, v: number) {
  send(hid, [ID_CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VAL_BRIGHTNESS, v]);
}

// Clamp mode=255 → clamped to EFFECT_MAX-1 in firmware, then read back to discover max.
// In Keychron's rgb_matrix_kb.inc the two custom effects are registered in order
// PER_KEY_RGB (first) then MIXED_RGB (second, last). So PER_KEY_RGB index = max - 2.
function discoverPerKeyMode(hid: HID.HID, verbose = false): { original: number; perKey: number } {
  const origRaw = readValue(hid, CHANNEL_RGB_MATRIX, VAL_EFFECT, verbose);
  const orig = origRaw[0] ?? 1;
  if (verbose) console.log(`discover: orig effect = ${orig}`);

  setEffect(hid, 255);
  // Short wait so the firmware's state settles before we re-probe.
  const end = Date.now() + 50;
  while (Date.now() < end) {}

  const lastRaw = readValue(hid, CHANNEL_RGB_MATRIX, VAL_EFFECT, verbose);
  const last = lastRaw[0] ?? 0;
  if (verbose) console.log(`discover: clamp read back = ${last} (expected EFFECT_MAX-1 = MIXED_RGB)`);

  if (last < 2) {
    throw new Error(
      `mode discovery failed — firmware returned ${last} after setting mode=255. ` +
        `Run with --verbose to see raw packets, or pin the effect with --effect <n>.`,
    );
  }
  return { original: orig, perKey: last - 1 };
}

// -----------------------------------------------------------------------------
// Modes
// -----------------------------------------------------------------------------

// Walk the last few effect indices, flooding red per-key on each. User watches
// which index makes the keyboard turn solid red — that's PER_KEY_RGB. Print each
// index so user can pass it back via --effect <n>.
function probe(hid: HID.HID) {
  const lastRaw = (() => {
    setEffect(hid, 255);
    const end = Date.now() + 50; while (Date.now() < end) {}
    return readValue(hid, CHANNEL_RGB_MATRIX, VAL_EFFECT)[0] ?? 0;
  })();
  if (lastRaw < 2) {
    console.error(`probe failed: could not read back effect after clamp (got ${lastRaw}).`);
    hid.close();
    process.exit(1);
  }
  console.log(`EFFECT_MAX-1 = ${lastRaw}. Trying candidates ${lastRaw}..${lastRaw - 5}:`);
  console.log(`for each effect, every key floods red for 3s. when the whole keyboard turns solid red, note the effect number and re-run with  --effect <n>.\n`);

  // Force per_key_rgb_type to SOLID so if we land on PER_KEY_RGB it uses the color buffer.
  send(hid, [KC_RGB_CMD, KC_PER_KEY_RGB_SET_TYPE, PER_KEY_TYPE_SOLID]);
  setBrightness(hid, 220);

  let idx = lastRaw;
  const next = () => {
    if (idx < lastRaw - 5) {
      console.log("probe done. ctrl-c to exit.");
      return;
    }
    console.log(`>>> effect ${idx}`);
    setEffect(hid, idx);
    // paint every key red via per-key buffer
    for (let start = 0; start < LED_COUNT; start += LEDS_PER_PACKET) {
      const count = Math.min(LEDS_PER_PACKET, LED_COUNT - start);
      const payload: number[] = [KC_RGB_CMD, KC_PER_KEY_RGB_SET_COLOR, start, count];
      for (let k = 0; k < count; k++) payload.push(0, 255, 255);
      send(hid, payload);
    }
    idx -= 1;
    setTimeout(next, 3000);
  };
  next();
}

function demo(hid: HID.HID) {
  console.log("demo: cycling hue for 10 seconds, ctrl-c to exit");
  setEffect(hid, 1); // SOLID
  setBrightness(hid, 200);
  const start = Date.now();
  const iv = setInterval(() => {
    const t = (Date.now() - start) / 1000;
    if (t > 10) {
      clearInterval(iv);
      hid.close();
      process.exit(0);
    }
    const hue = Math.floor((t * 40) % 256);
    send(hid, [ID_CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VAL_COLOR, hue, 255]);
  }, 40);
}

// Pulse mode (stage 1): single color, bass → brightness, treble → hue.
function pulseMode(hid: HID.HID, sock: dgram.Socket) {
  setEffect(hid, 1); // SOLID
  let lastSent = 0;
  let smoothedHue = 0;
  let smoothedVal = 0;

  sock.on("message", (msg) => {
    const now = Date.now();
    if (now - lastSent < 33) return;
    lastSent = now;
    if (msg.byteLength < 4 || msg.byteLength % 4 !== 0) return;
    const bars = new Float32Array(msg.buffer, msg.byteOffset, msg.byteLength / 4);
    const n = bars.length;
    if (n === 0) return;
    const third = Math.max(1, Math.floor(n / 3));
    let bass = 0, treb = 0, total = 0;
    for (let i = 0; i < third; i++) bass += bars[i];
    for (let i = n - third; i < n; i++) treb += bars[i];
    for (let i = 0; i < n; i++) total += bars[i];
    bass /= third; treb /= third; total /= n;
    const energy = Math.min(1, total * 2.5);
    const hueRaw = treb / Math.max(0.001, bass + treb);
    const hue = Math.min(255, Math.max(0, Math.floor(hueRaw * 200)));
    const val = Math.max(8, Math.min(255, Math.floor(energy * 255)));
    smoothedHue = smoothedHue * 0.6 + hue * 0.4;
    smoothedVal = smoothedVal * 0.4 + val * 0.6;
    send(hid, [ID_CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VAL_COLOR, Math.round(smoothedHue), 255]);
    setBrightness(hid, Math.round(smoothedVal));
  });
}

// Wave mode (stage 2): per-key hue/saturation driven by spectrum.
function waveMode(
  hid: HID.HID,
  sock: dgram.Socket,
  opts: { effectOverride?: number; discover: boolean; verbose: boolean },
) {
  // Switch to Keychron's PER_KEY_RGB custom effect, solid type (renders from per_key_led[]).
  let perKey: number;
  let original = 1;
  if (opts.discover) {
    const probe = discoverPerKeyMode(hid, opts.verbose);
    original = probe.original;
    perKey = probe.perKey;
    console.log(`discovered: per_key mode = ${perKey}, restoring to ${original} on exit`);
  } else {
    perKey = opts.effectOverride ?? DEFAULT_PER_KEY_EFFECT;
    const orig = readValue(hid, CHANNEL_RGB_MATRIX, VAL_EFFECT, opts.verbose);
    original = orig[0] ?? 1;
    const src = opts.effectOverride !== undefined ? "--effect" : "default";
    console.log(`using effect ${perKey} (${src}). restoring to ${original} on exit.`);
  }
  setEffect(hid, perKey);
  send(hid, [KC_RGB_CMD, KC_PER_KEY_RGB_SET_TYPE, PER_KEY_TYPE_SOLID]);

  // Verify we actually landed on the intended mode.
  drain(hid);
  const confirm = readValue(hid, CHANNEL_RGB_MATRIX, VAL_EFFECT, opts.verbose);
  const actual = confirm[0] ?? 0;
  if (actual !== perKey) {
    console.warn(`warning: set effect=${perKey} but readback shows ${actual}. keyboard may not be in per-key mode.`);
  } else if (opts.verbose) {
    console.log(`confirmed effect = ${actual}`);
  }

  // Visible sanity check: flood every key red for ~1.5s. If the keyboard stays red,
  // the per-key channel is wired up. If the previous pattern (raindrops, WASD-highlight,
  // etc.) keeps playing, we're on the wrong effect — run --probe to find the right one.
  console.log("sanity: painting all keys red for 1.5s...");
  setBrightness(hid, 200);
  for (let start = 0; start < LED_COUNT; start += LEDS_PER_PACKET) {
    const count = Math.min(LEDS_PER_PACKET, LED_COUNT - start);
    const payload: number[] = [KC_RGB_CMD, KC_PER_KEY_RGB_SET_COLOR, start, count];
    for (let k = 0; k < count; k++) payload.push(0, 255, 255); // h=0 (red), s=255, v=255
    send(hid, payload);
  }
  const waitEnd = Date.now() + 1500;
  while (Date.now() < waitEnd) {}

  const colors = new CavalierColors();

  // Latest spectrum. Updated from UDP, read by the render loop.
  let latestBars: Float32Array = new Float32Array(0);
  sock.on("message", (msg) => {
    if (msg.byteLength < 4 || msg.byteLength % 4 !== 0) return;
    latestBars = new Float32Array(msg.buffer, msg.byteOffset, msg.byteLength / 4);
  });

  // Sample the spectrum at a normalized x position in [0, 1]. Linear between bars.
  function sampleBar(bars: Float32Array, xNorm: number): number {
    if (bars.length === 0) return 0;
    const f = xNorm * (bars.length - 1);
    const lo = Math.floor(f);
    const hi = Math.min(bars.length - 1, lo + 1);
    const frac = f - lo;
    return bars[lo] * (1 - frac) + bars[hi] * frac;
  }

  // Per-LED HSV state (previous frame) for temporal smoothing.
  const prevH = new Uint8Array(LED_COUNT);
  const prevS = new Uint8Array(LED_COUNT);

  const render = () => {
    const bars = latestBars;

    // Global energy → master brightness (clamped floor so it never goes fully dark).
    let energy = 0;
    for (let i = 0; i < bars.length; i++) energy += bars[i];
    energy = bars.length ? energy / bars.length : 0;
    const brightness = Math.max(40, Math.min(255, Math.floor(energy * 380 + 40)));
    setBrightness(hid, brightness);

    // Compute each LED's target H/S, then blend with previous for smoothness.
    // Hue is sampled from Cavalier's active fgColors gradient at the key's x position —
    // same source of truth as the UI, so preset switches auto-propagate to the keyboard.
    const targetH = new Uint8Array(LED_COUNT);
    const targetS = new Uint8Array(LED_COUNT);
    for (let i = 0; i < LED_COUNT; i++) {
      const xNorm = LED_X[i] / X_MAX;
      const amp = Math.min(1, sampleBar(bars, xNorm) * 1.4);
      const rgb = colors.sample(xNorm);
      const hsv = rgbToHsv(rgb);
      targetH[i] = hsv.h;
      // Scale the gradient's inherent saturation by amplitude so quiet keys wash toward
      // white while loud keys hit the gradient's full vibrance.
      targetS[i] = Math.min(255, Math.round(hsv.s * amp));
    }
    // EMA smoothing.
    for (let i = 0; i < LED_COUNT; i++) {
      prevH[i] = Math.round(prevH[i] * 0.5 + targetH[i] * 0.5);
      prevS[i] = Math.round(prevS[i] * 0.3 + targetS[i] * 0.7);
    }

    // Stream in chunks of 9 LEDs. Firmware enforces count ≤ 9.
    for (let start = 0; start < LED_COUNT; start += LEDS_PER_PACKET) {
      const count = Math.min(LEDS_PER_PACKET, LED_COUNT - start);
      const payload: number[] = [KC_RGB_CMD, KC_PER_KEY_RGB_SET_COLOR, start, count];
      for (let k = 0; k < count; k++) {
        payload.push(prevH[start + k], prevS[start + k], 255);
      }
      send(hid, payload);
    }
  };

  const iv = setInterval(render, FRAME_MS);

  const cleanup = () => {
    clearInterval(iv);
    setEffect(hid, original);
  };
  process.on("SIGINT", () => {
    console.log("\nrestoring original effect");
    cleanup();
    sock.close();
    hid.close();
    process.exit(0);
  });
}

// -----------------------------------------------------------------------------
// Entry
// -----------------------------------------------------------------------------

function main() {
  const argv = process.argv.slice(2);
  if (argv.includes("--list")) return listDevices();

  const hid = openDevice();
  if (argv.includes("--demo")) return demo(hid);
  if (argv.includes("--probe")) return probe(hid);

  const modeIdx = argv.indexOf("--mode");
  const mode = modeIdx >= 0 ? argv[modeIdx + 1] : "wave";
  const effectIdx = argv.indexOf("--effect");
  const effectOverride = effectIdx >= 0 ? parseInt(argv[effectIdx + 1]!, 10) : undefined;
  const discover = argv.includes("--discover");
  const verbose = argv.includes("--verbose");

  const sock = dgram.createSocket("udp4");
  sock.bind(UDP_PORT, "127.0.0.1", () => {
    console.log(`listening udp://127.0.0.1:${UDP_PORT} in ${mode} mode`);
  });

  if (mode === "pulse") pulseMode(hid, sock);
  else if (mode === "wave") waveMode(hid, sock, { effectOverride, discover, verbose });
  else {
    console.error(`unknown mode: ${mode} (expected pulse|wave)`);
    process.exit(1);
  }

  // Safety shutdown for modes that don't register their own SIGINT handler.
  process.on("SIGTERM", () => {
    sock.close();
    hid.close();
    process.exit(0);
  });
}

main();
