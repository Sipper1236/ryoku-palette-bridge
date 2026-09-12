"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const properties = new Map();
const elements = new Map();
const streams = [];
const events = [];
const timers = [];
class EventSource {
  constructor(url) {
    this.url = url;
    this.closed = false;
    streams.push(this);
  }
  close() {
    this.closed = true;
  }
}
class CustomEvent {
  constructor(type, options) {
    this.type = type;
    this.detail = options.detail;
  }
}
const document = {
  documentElement: { style: { setProperty: (name, value) => properties.set(name, value) } },
  getElementById: id => elements.get(id) || null,
  createElement: () => ({}),
  head: { appendChild: element => elements.set(element.id, element) },
};
const window = { dispatchEvent: event => events.push(event) };
const setTimeout = (callback, delay) => {
  timers.push({ callback, delay });
  return timers.length;
};
const source = fs.readFileSync(
  path.join(__dirname, "..", "spicetify", "ryoku-wallpaper-colors.js"),
  "utf8",
);
vm.runInNewContext(source, {
  window, document, EventSource, CustomEvent, JSON, Object, setTimeout,
});

assert.equal(streams.length, 1);
assert.equal(streams[0].url, "http://127.0.0.1:47616/v1/events");
assert.ok(elements.get("ryoku-wallpaper-token-bridge").textContent.includes("--encore-focus-outline-color"));

const palette = {
  primary: "#112233", onSurface: "#eeeeee", onSurfaceVariant: "#cccccc",
  background: "#010203", surface: "#111213", surfaceContainer: "#212223",
  surfaceContainerHigh: "#313233", surfaceContainerHighest: "#414243",
  surfaceContainerLow: "#090a0b", shadow: "#000000", primaryContainer: "#445566",
  outlineVariant: "#777777", tertiary: "#abcdef", error: "#ff0000",
  surfaceVariant: "#515253", secondary: "#778899",
};
streams[0].onmessage({ data: JSON.stringify(palette) });

assert.equal(properties.get("--spice-button"), palette.primary);
assert.equal(properties.get("--spice-rgb-button"), "17,34,51");
assert.equal(properties.get("--spice-main"), palette.background);
assert.equal(properties.get("--spice-primary"), palette.primary);
assert.equal(events.at(-1).type, "ryoku-palette-changed");

streams[0].onerror();
assert.equal(streams[0].closed, true);
assert.equal(timers.length, 1);
assert.equal(timers[0].delay, 1000);
timers[0].callback();
assert.equal(streams.length, 2);
assert.equal(streams[1].url, "http://127.0.0.1:47616/v1/events");
console.log("PASS: Spotify extension maps Ryoku roles and reconnects its local SSE stream");
