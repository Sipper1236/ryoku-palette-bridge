#!/usr/bin/env bash
set -euo pipefail

config_root="${VESKTOP_CONFIG_ROOT:-$HOME/.config/vesktop}"
template="${MATUGEN_VESKTOP_TEMPLATE:-$HOME/.config/matugen/templates/vesktop-colors.css}"
settings="$config_root/settings/settings.json"
base="$config_root/themes/midnight-ryoku.theme.css"
quick_css="$config_root/settings/quickCss.css"

if rg -q '^@import .*midnight' "$template"; then
  printf 'FAIL: Matugen rewrites the Midnight import on every palette change\n' >&2
  exit 1
fi

test -f "$base"
rg -q '^@import .*midnight' "$base"
rg -q 'midnight-ryoku.theme.css' "$settings"
rg -q -- '--accent-2:' "$quick_css"
printf 'PASS: stable Midnight base and isolated QuickCSS palette\n'
