"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const archives = [
  ["/opt/zen-browser-bin/omni.ja", "modules/LightweightThemeConsumer.sys.mjs"],
  ["/opt/zen-browser-bin/browser/omni.ja", "modules/ThemeVariableMap.sys.mjs"]
];
if (archives.some(([path]) => !fs.existsSync(path))) {
  console.log("SKIP: installed Zen theme variable maps are unavailable");
  process.exit(0);
}
const variables = new Set();
for (const [archive, path] of archives) {
  const result = spawnSync("unzip", ["-p", archive, path], { encoding: "utf8" });
  assert.ok(result.stdout.includes("lwtProperty"), `Cannot read ${path}`);
  for (const match of result.stdout.matchAll(/"(--[\w-]+)"\s*,\s*\{\s*lwtProperty:/g)) {
    variables.add(match[1]);
  }
}
const css = fs.readFileSync(new URL("../templates/zen.css", `file://${__filename}`), "utf8");
const referenced = [...css.matchAll(/var\((--[\w-]+)/g)].map(match => match[1]);
assert.deepEqual(referenced.filter(name => !variables.has(name)), [], "CSS must consume variables Zen actually updates");
const assigned = [...css.matchAll(/(--[\w-]+)\s*:/g)].map(match => match[1]);
assert.deepEqual(assigned.filter(name => variables.has(name)), [], "CSS must not override variables owned by Zen's theme API");
console.log("PASS: Zen CSS consumes live theme variables without overriding them");
