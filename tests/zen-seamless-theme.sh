#!/usr/bin/env bash
set -euo pipefail

zen_root="${ZEN_CONFIG_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/zen}"
if [[ -n "${ZEN_PROFILE_ROOT:-}" ]]; then
  profile_root="$ZEN_PROFILE_ROOT"
else
  profile_path=$(find "$zen_root" -mindepth 2 -maxdepth 2 -name .parentlock -printf '%h\n' -quit)
  profile_path=${profile_path#"$zen_root/"}
  [[ -n "$profile_path" ]] || {
    printf 'FAIL: could not identify the running Zen profile\n' >&2
    exit 1
  }
  profile_root="$zen_root/$profile_path"
fi
template="${MATUGEN_ZEN_TEMPLATE:-${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/zen.css}"
generated="$profile_root/chrome/ryoku-colors.css"

node "$(dirname "$0")/zen-palette.test.js"
jq -e '.addons[] | select(.id == "ryoku-zen-palette@local" and .active == true and .appDisabled == false)' \
  "$profile_root/extensions.json" >/dev/null || {
  printf 'FAIL: signed Ryoku Zen extension is not active\n' >&2
  exit 1
}
for stylesheet in "$template" "$generated"; do
  rg -q -- '--zen-primary-color: var\(--toolbar-field-border-color-focus,' "$stylesheet" || {
    printf 'FAIL: %s does not consume live theme variables\n' "$stylesheet" >&2
    exit 1
  }
  if rg -q -- '--lwt-[^:]+: #[0-9a-fA-F]{6}|tab-background \{[^}]*#[0-9a-fA-F]{6}' "$stylesheet"; then
    printf 'FAIL: %s overrides live tab/theme colors\n' "$stylesheet" >&2
    exit 1
  fi
done
printf 'PASS: signed extension and live Zen tab variable layer are active\n'
