#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
zen_root="${ZEN_CONFIG_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/zen}"
palette="${RYOKU_PALETTE:-$HOME/.cache/ryoku/colors.json}"
profile_root="${ZEN_PROFILE_ROOT:-}"

if [[ -z "$profile_root" ]]; then
  profile_root=$(find "$zen_root" -mindepth 2 -maxdepth 2 -name .parentlock -printf '%h\n' -quit)
fi
[[ -n "$profile_root" ]] || fail 'Zen is not running; launch it before this live check'

generated="$profile_root/chrome/ryoku-colors.css"
current=$(jq -er .primary "$palette")
published=$(curl -fsS http://127.0.0.1:47616/v1/palette | jq -er .primary) ||
  fail 'palette bridge is unavailable'
fallback=$(sed -n 's/.*--zen-primary-color: var([^,]*, \(#[0-9a-fA-F]\{6\}\)).*/\1/p' \
  "$generated" | head -n1)

[[ "${published,,}" == "${current,,}" ]] ||
  fail "bridge palette is stale ($published, expected $current)"
[[ "${fallback,,}" == "${current,,}" ]] ||
  fail "Zen startup palette is stale ($fallback, expected $current)"
ss -Htnp | grep -Eq '127\.0\.0\.1:47616.*zen-bin|zen-bin.*127\.0\.0\.1:47616' ||
  fail 'Zen is not connected to the live palette stream'

printf 'PASS: Zen, the bridge, and Ryoku agree on %s with a live SSE connection\n' "$current"
