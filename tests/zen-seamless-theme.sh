#!/usr/bin/env bash
set -euo pipefail

zen_root="${ZEN_CONFIG_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/zen}"
if [[ -n "${ZEN_PROFILE_ROOT:-}" ]]; then
  profile_root="$ZEN_PROFILE_ROOT"
else
  profile_path=$(awk -F= '
    /^\[Profile/ { in_profile=1; path=""; is_default=0; next }
    /^\[/ { if (in_profile && is_default && path != "") { print path; exit }; in_profile=0 }
    in_profile && $1 == "Path" { path=$2 }
    in_profile && $1 == "Default" && $2 == "1" { is_default=1 }
    END { if (in_profile && is_default && path != "") print path }
  ' "$zen_root/profiles.ini" | head -n1)
  [[ -n "$profile_path" ]] || {
    printf 'FAIL: could not identify Zen default profile\n' >&2
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
  rg -q -- '--zen-primary-color: var\(--lwt-' "$stylesheet" || {
    printf 'FAIL: %s does not consume live theme variables\n' "$stylesheet" >&2
    exit 1
  }
  if rg -q -- '--lwt-[^:]+: #[0-9a-fA-F]{6}|tab-background \{[^}]*#[0-9a-fA-F]{6}' "$stylesheet"; then
    printf 'FAIL: %s overrides live tab/theme colors\n' "$stylesheet" >&2
    exit 1
  fi
done
printf 'PASS: signed extension and live Zen tab variable layer are active\n'
