"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const calls = [];
const releases = [];
const context = vm.createContext({
  EventSource: class {}, console, setTimeout, clearTimeout,
  browser: { theme: { update(theme) {
    calls.push(theme);
    return new Promise(resolve => releases.push(resolve));
  } } }
});
vm.runInContext(fs.readFileSync(require.resolve("../zen-extension/background.js"), "utf8"), context);
(async () => {
  const first = vm.runInContext('applyLatest({colors: {frame: "#111111"}})', context);
  vm.runInContext('applyLatest({colors: {frame: "#222222"}})', context);
  vm.runInContext('applyLatest({colors: {frame: "#333333"}})', context);
  assert.equal(calls.length, 1, "theme updates must not overlap");
  releases.shift()();
  await new Promise(setImmediate);
  assert.equal(calls.length, 2);
  assert.equal(calls[1].colors.frame, "#333333", "apply newest pending palette");
  releases.shift()();
  await first;
  await vm.runInContext('applyLatest({colors: {frame: "#333333"}})', context);
  assert.equal(calls.length, 2, "reconnect must not repaint identical colours");
  console.log("PASS: Zen serializes updates, skips intermediate palettes and deduplicates reconnects");
})().catch(error => { console.error(error); process.exitCode = 1; });
