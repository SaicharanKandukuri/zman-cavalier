// Physical LED x-positions for Keychron V6 ANSI encoder, indexed by LED number.
// Source: keyboards/keychron/v6/ansi_encoder/ansi_encoder.c:157 (g_led_config).
// x range is 0..224; y range is 0..64. Index order matches per_key_led[] in firmware,
// so bridge can write HSV at index i and expect it to light the physical key at LED_X[i].
export const LED_X: readonly number[] = [
  // row 0, y=0  (function row + right cluster)
  0, 13, 24, 34, 45, 57, 68, 78, 89, 102, 112, 123, 133, 159, 169, 180, 193, 203, 214, 224,
  // row 1, y=15  (numbers row + numpad top)
  0, 10, 21, 31, 42, 52, 63, 73, 83, 94, 104, 115, 125, 141, 159, 169, 180, 193, 203, 214, 224,
  // row 2, y=27  (qwerty row)
  3, 16, 26, 36, 47, 57, 68, 78, 89, 99, 109, 120, 130, 143, 159, 169, 180, 193, 203, 214,
  // row 3, y=40  (asdf row)
  4, 18, 29, 39, 50, 60, 70, 81, 91, 102, 112, 123, 139, 193, 203, 214, 224,
  // row 4, y=52  (zxcv row + arrow)
  7, 23, 34, 44, 55, 65, 76, 86, 96, 107, 117, 137, 169, 193, 203, 214,
  // row 5, y=64  (bottom row)
  1, 14, 27, 66, 105, 118, 131, 145, 159, 169, 180, 198, 214, 224,
];

export const LED_COUNT = LED_X.length; // 108
export const X_MAX = 224;
