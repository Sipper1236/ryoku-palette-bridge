"use strict";

const assert = require("node:assert/strict");
const { paletteToTheme } = require("../zen-extension/palette.js");
const palette = {
  primary: "#112233", onSurface: "#eeeeee", surface: "#010203",
  surfaceContainer: "#111213", surfaceContainerHigh: "#212223",
  outlineVariant: "#313233", primaryContainer: "#414243",
  onPrimaryContainer: "#f1f2f3"
};
const colors = paletteToTheme(palette).colors;
assert.equal(colors.frame, palette.surface);
assert.equal(colors.toolbar_field_focus_border, palette.primary);
assert.equal(colors.toolbar_field_highlight, palette.primaryContainer);
assert.equal(colors.sidebar_highlight_text, palette.onPrimaryContainer);
console.log("PASS: Zen palette maps onto live Gecko theme colors");
