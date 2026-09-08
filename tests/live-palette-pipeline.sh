#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
section() {
  awk -v wanted="[$1]" '
    $0 == wanted { active=1; next }
    /^\[/ && active { exit }
    active { print }
  ' "$2"
}

palette="${RYOKU_PALETTE:-$HOME/.cache/ryoku/colors.json}"
apps="${MATUGEN_APPS:-$HOME/.config/matugen/apps.toml}"
quick_css="${VESKTOP_QUICK_CSS:-$HOME/.config/vesktop/settings/quickCss.css}"
zen_root="${ZEN_CONFIG_ROOT:-$HOME/.config/zen}"
primary=$(jq -er '.primary' "$palette")

[[ $(jq -r '.followWallpaper' "$HOME/.config/ryoku/theme.json") == true ]] ||
  fail 'Ryoku theme is not following the wallpaper'
[[ $(curl -fsS http://127.0.0.1:47616/healthz) == ok ]] ||
  fail 'palette bridge health endpoint is unavailable'
[[ $(curl -fsS http://127.0.0.1:47616/v1/palette | jq -er '.primary') == "$primary" ]] ||
  fail 'palette bridge is not publishing the active palette'

vesktop_section=$(section templates.vesktop "$apps")
rg -Fq 'input_path = "~/.config/matugen/templates/vesktop-colors.css"' <<<"$vesktop_section" &&
  rg -Fq 'output_path = "~/.config/vesktop/settings/quickCss.css"' <<<"$vesktop_section" ||
  fail 'Vesktop Matugen registration is missing or writes to the themes directory'
vesktop_primary=$(sed -n 's/.*--accent-2:[[:space:]]*\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$quick_css" | head -n1)
[[ ${vesktop_primary,,} == ${primary,,} ]] ||
  fail "Vesktop accent is stale ($vesktop_primary, expected $primary)"

active_profile=$(find "$zen_root" -mindepth 2 -maxdepth 2 -name .parentlock -printf '%h\n' -quit)
[[ -n $active_profile ]] || fail 'could not identify the running Zen profile'
generated="$active_profile/chrome/ryoku-colors.css"
rg -Fq "$primary" "$generated" || fail "Zen startup palette is stale (expected $primary)"
zen_section=$(section templates.zen "$apps")
generated_tilde="~${generated#"$HOME"}"
rg -Fq "output_path = \"$generated_tilde\"" <<<"$zen_section" ||
  fail 'Zen Matugen registration does not target the running profile'
jq -e '.addons[] | select(.id == "ryoku-zen-palette@local" and .active == true and .appDisabled == false)' \
  "$active_profile/extensions.json" >/dev/null || fail 'signed Zen palette extension is inactive'
ss -Htnp | rg -q '127\.0\.0\.1:47616.*zen-bin|zen-bin.*127\.0\.0\.1:47616' ||
  fail 'Zen is not connected to the live palette stream'

rg -q '(^|\|)ryoku-wallpaper-colors\.js($|\|)' "$HOME/.config/spicetify/config-xpui.ini" ||
  fail 'Spotify palette extension is not enabled in Spicetify'
test -s "$HOME/.config/spicetify/Extensions/ryoku-wallpaper-colors.js" ||
  fail 'Spotify palette extension file is missing'
if [[ -f /opt/spotify/Apps/xpui/index.html ]]; then
  rg -q 'ryoku-wallpaper-colors\.js' /opt/spotify/Apps/xpui/index.html ||
    fail 'installed Spotify XPUI is not patched with the palette extension'
elif [[ -f /opt/spotify/Apps/xpui.spa ]]; then
  unzip -p /opt/spotify/Apps/xpui.spa xpui/index.html 2>/dev/null |
    rg -q 'ryoku-wallpaper-colors\.js' || fail 'installed Spotify XPUI is not patched with the palette extension'
fi
if pgrep -x spotify >/dev/null; then
  ss -Htnp | rg -q '127\.0\.0\.1:47616.*spotify|spotify.*127\.0\.0\.1:47616' ||
    fail 'running Spotify is not connected to the live palette stream'
fi

printf 'PASS: wallpaper palette %s reaches Spotify, Zen, and Vesktop integrations\n' "$primary"
