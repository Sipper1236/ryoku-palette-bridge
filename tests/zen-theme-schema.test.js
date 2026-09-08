"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { paletteToTheme } = require("../zen-extension/palette.js");

const omni = process.env.ZEN_OMNI_JA || "/opt/zen-browser-bin/omni.ja";
if (!require("node:fs").existsSync(omni)) {
  if (process.env.ZEN_OMNI_JA) {
    assert.fail(`ZEN_OMNI_JA does not exist: ${omni}`);
  }
  console.log("SKIP: installed Zen theme schema is unavailable on this host");
  process.exit(0);
}
const extracted = spawnSync("unzip", [
  "-p", omni, "chrome/toolkit/content/extensions/schemas/theme.json"
], { encoding: "utf8" });
assert.ok(extracted.stdout, "could not extract Zen's bundled theme schema");
const schema = JSON.parse(extracted.stdout);
const manifest = schema.find(entry => entry.namespace === "manifest");
const themeType = manifest.types.find(type => type.id === "ThemeType");
const allowed = new Set(Object.keys(themeType.properties.colors.properties));
const sample = {
  primary: "#112233", onSurface: "#eeeeee", surface: "#010203",
  surfaceContainer: "#111213", surfaceContainerHigh: "#212223",
  outlineVariant: "#313233", primaryContainer: "#414243",
  onPrimaryContainer: "#f1f2f3", tertiary: "#515253"
};
const emitted = Object.keys(paletteToTheme(sample).colors);
const unsupported = emitted.filter(key => !allowed.has(key));

assert.deepEqual(unsupported, [], `unsupported Zen theme color keys: ${unsupported.join(", ")}`);
console.log("PASS: Zen mapper only emits colors supported by the installed theme API");
