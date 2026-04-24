import { readFileSync, watch } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const CONFIG_PATH = join(homedir(), "Library/Application Support/Cavalier/config.json");

type RGB = { r: number; g: number; b: number };

// Default when config can't be read — matches Cavalier's "Classic" preset (#ff3584e4).
const DEFAULT_GRADIENT: RGB[] = [{ r: 0x35, g: 0x84, b: 0xe4 }];

function parseArgb(hex: string): RGB | null {
  let s = hex.startsWith("#") ? hex.slice(1) : hex;
  // "aarrggbb" (8 hex chars) — Cavalier's format.
  if (s.length !== 8) return null;
  const v = parseInt(s, 16);
  if (!Number.isFinite(v)) return null;
  return { r: (v >> 16) & 0xff, g: (v >> 8) & 0xff, b: v & 0xff };
}

function loadFromDisk(): RGB[] {
  try {
    const raw = readFileSync(CONFIG_PATH, "utf8");
    const cfg = JSON.parse(raw);
    const profiles: unknown[] = Array.isArray(cfg.colorProfiles) ? cfg.colorProfiles : [];
    const active = typeof cfg.activeProfile === "number" ? cfg.activeProfile : 0;
    const profile = profiles[active] as { fgColors?: unknown } | undefined;
    const fg = Array.isArray(profile?.fgColors) ? (profile!.fgColors as string[]) : [];
    const parsed = fg.map(parseArgb).filter((c): c is RGB => c !== null);
    return parsed.length > 0 ? parsed : DEFAULT_GRADIENT;
  } catch {
    return DEFAULT_GRADIENT;
  }
}

/// Holds the current gradient and reloads it when Cavalier rewrites its config file.
export class CavalierColors {
  private stops: RGB[] = DEFAULT_GRADIENT;

  constructor() {
    this.reload();
    try {
      // fs.watch fires on any change event (write, rename on atomic-save, etc).
      // Debounced by reading the file synchronously on each event.
      let reloadTimer: NodeJS.Timeout | null = null;
      watch(CONFIG_PATH, () => {
        if (reloadTimer) clearTimeout(reloadTimer);
        reloadTimer = setTimeout(() => this.reload(), 100);
      });
    } catch {
      // Config not yet written — bridge still works with defaults. Cavalier creates the file on launch.
    }
  }

  private reload() {
    const before = JSON.stringify(this.stops);
    this.stops = loadFromDisk();
    const after = JSON.stringify(this.stops);
    if (before !== after) {
      const hex = this.stops.map((c) => `#${((c.r << 16) | (c.g << 8) | c.b).toString(16).padStart(6, "0")}`).join(" ");
      console.log(`color gradient loaded: ${hex}`);
    }
  }

  /// Sample the gradient at t ∈ [0, 1]. Returns sRGB. Linear interpolation in RGB space,
  /// matching CGGradient's sRGB path used by Cavalier's renderer.
  sample(t: number): RGB {
    const stops = this.stops;
    if (stops.length === 1) return stops[0];
    const scaled = Math.max(0, Math.min(1, t)) * (stops.length - 1);
    const lo = Math.floor(scaled);
    const hi = Math.min(stops.length - 1, lo + 1);
    const frac = scaled - lo;
    const a = stops[lo], b = stops[hi];
    return {
      r: Math.round(a.r * (1 - frac) + b.r * frac),
      g: Math.round(a.g * (1 - frac) + b.g * frac),
      b: Math.round(a.b * (1 - frac) + b.b * frac),
    };
  }
}

export function rgbToHsv(rgb: RGB): { h: number; s: number; v: number } {
  const r = rgb.r / 255, g = rgb.g / 255, b = rgb.b / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    else if (max === g) h = ((b - r) / d + 2) / 6;
    else h = ((r - g) / d + 4) / 6;
  }
  const s = max === 0 ? 0 : d / max;
  return { h: Math.round(h * 255), s: Math.round(s * 255), v: Math.round(max * 255) };
}
