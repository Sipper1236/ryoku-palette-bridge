# Palette update performance

Audit: 2026-09-13.

The bridge uses inotify and SSE, with no palette polling. A queue regression
test reproduced a stale-update bug: a full client queue retained the old
palette and discarded the newest. Publishing now replaces the queued value.
File notifications from a single read are coalesced, and newly created files
are read after close rather than while the writer is still filling them.

On this machine (Intel i5-8350U), `go test -run '^$' -bench
BenchmarkPalettePublish -benchmem` measured about 10 microseconds per publish
with three client queues, 441 bytes and 6 allocations per operation. This is
an in-process measurement, not wallpaper-to-screen latency.

Spotify previously rewrote all 55 mapped properties on any palette change.
The single-secondary-role regression test now requires only two writes.
There are no DOM scans or forced layout reads in the update callback.

Zen now serializes theme updates, replaces pending intermediate palettes and
skips identical themes after reconnecting. Reconnection waits one second,
down from three. Version 1.0.3 needs signing and installation before these
extension changes take effect. The installer also enables lightweight themes;
Zen otherwise discards the extension's theme colours. The stylesheet uses
the installed browser's theme variable names and avoids assigning them.

Vesktop keeps Midnight loaded and updates a separate QuickCSS palette. That
path still depends on Matugen generation and Vesktop's file watcher, rather
than the bridge's SSE queue. No measured evidence yet attributes its stutter
to a particular callback, so its theme and animation settings were retained.

The tests establish queue correctness and reduced update work. They do not
measure frame times in the user's three open apps. Visual latency and stutter
still need checking after the updated clients are loaded.
