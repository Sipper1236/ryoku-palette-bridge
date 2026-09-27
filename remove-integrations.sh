#!/usr/bin/env bash
set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/palette-bridge"
ownership_file="$state_root/owned-files.tsv"
overlay_apps="$config_root/ryoku/user_edits/matugen/apps.toml"
want=

usage() { printf 'Usage: %s --spotify | --vesktop | --zen\n' "${0##*/}"; }

case "${1:-}" in
  --spotify) want=spotify ;;
  --vesktop) want=vesktop ;;
  --zen) want=zen ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

remove_owned_file() {
  local path="$1"
  [[ -f "$path" ]] && rm -f -- "$path"
}

remove_matugen_section() {
  local section="$1" temporary
  [[ -f "$overlay_apps" ]] || return 0
  temporary=$(mktemp)
  awk -v target="[$section]" '
    $0 == target { skip=1; next }
    /^\[/ && skip { skip=0 }
    !skip { print }
  ' "$overlay_apps" > "$temporary"
  install -m 0644 "$temporary" "$overlay_apps"
  rm -f "$temporary"
}

remove_vesktop_enabled_signal() {
  local css="$config_root/vesktop/settings/quickCss.css" temporary
  [[ -f "$css" ]] || return 0
  temporary=$(mktemp)
  awk '
    $0 == "/* ryoku-palette-bridge:vesktop-enabled-begin */" && !inside { inside=1; next }
    inside {
      if ($0 == "/* ryoku-palette-bridge:vesktop-enabled-end */") inside=0
      next
    }
    { print }
    END { if (inside) exit 1 }
  ' "$css" > "$temporary" || { rm -f "$temporary"; return 1; }
  cat "$temporary" > "$css"
  rm -f "$temporary"
}

remove_vesktop_palette() {
  local css="$config_root/vesktop/settings/quickCss.css" temporary legacy_digest
  [[ -f "$css" ]] || return 0
  temporary=$(mktemp)
  # Only a complete, explicitly owned block may be removed. Preserve incomplete
  # markers verbatim so malformed or user-authored CSS cannot disappear.
  awk '
    $0 == "/* ryoku-palette-bridge:begin */" && !inside { inside=1; buffer=$0 ORS; next }
    inside {
      buffer=buffer $0 ORS
      if ($0 == "/* ryoku-palette-bridge:end */") { inside=0; buffer="" }
      next
    }
    { print }
    END { if (inside) printf "%s", buffer }
  ' "$css" > "$temporary"
  # Before ownership markers, Matugen wrote this exact leading template. Match
  # its entire shape (including static values), allowing only rendered hex colors
  # to vary. A changed/unknown block is left alone; never delete arbitrary :root.
  legacy_digest=$(sed -n '1,/^}$/p' "$temporary" |
    sed -E 's/#[[:xdigit:]]{6}/#000000/g' | sha256sum)
  if [[ "${legacy_digest%% *}" == 77dc96171961a855d7a08ac36ab306a061155f724f747d5fed76f0b9c35056a2 ]]; then
    sed '1,/^}$/d' "$temporary" > "$temporary.legacy"
    mv "$temporary.legacy" "$temporary"
  fi
  cat "$temporary" > "$css"
  rm -f "$temporary"
}

case "$want" in
  spotify)
    if command -v spicetify >/dev/null; then
      spicetify config extensions ryoku-wallpaper-colors.js- || true
      spicetify apply || true
    fi
    ;;
  vesktop)
    remove_matugen_section templates.vesktop
    remove_vesktop_enabled_signal
    remove_vesktop_palette
    settings="$config_root/vesktop/settings/settings.json"
    if [[ -f "$settings" ]] && command -v jq >/dev/null; then
      temporary=$(mktemp)
      jq '.enabledThemes = ((.enabledThemes // []) | map(select(. != "midnight-ryoku.theme.css")))' "$settings" > "$temporary"
      install -m 0644 "$temporary" "$settings"
      rm -f "$temporary"
    fi
    ;;
  zen)
    remove_matugen_section templates.zen
    ;;
esac

if [[ -f "$ownership_file" ]]; then
  while IFS=$'\t' read -r integration path; do
    [[ "$integration" == "$want" ]] || continue
    case "$want:$path" in
      spotify:"$config_root"/spicetify/Extensions/ryoku-wallpaper-colors.js|\
      vesktop:"$config_root"/ryoku/user_edits/matugen/templates/vesktop-colors.css|\
      vesktop:"$config_root"/vesktop/themes/midnight-ryoku.theme.css|\
      zen:"$config_root"/ryoku/user_edits/matugen/templates/zen.css)
        remove_owned_file "$path"
        ;;
      zen:*/chrome/userChrome.css)
        temporary=$(mktemp)
        grep -Fvx '@import "ryoku-colors.css";' "$path" > "$temporary" || true
        install -m 0644 "$temporary" "$path"
        rm -f "$temporary"
        ;;
      zen:*/user.js)
        temporary=$(mktemp)
        grep -vE 'user_pref\("(toolkit\.legacyUserProfileCustomizations\.stylesheets", true|zen\.theme\.disable-lightweight", false)\);' "$path" > "$temporary" || true
        install -m 0644 "$temporary" "$path"
        rm -f "$temporary"
        ;;
    esac
  done < "$ownership_file"
  temporary=$(mktemp)
  awk -F '\t' -v app="$want" '$1 != app' "$ownership_file" > "$temporary"
  install -m 0600 "$temporary" "$ownership_file"
  rm -f "$temporary"
fi

if [[ "$want" == vesktop || "$want" == zen ]]; then
  command -v ryoku >/dev/null && ryoku materialize
  command -v ryogami >/dev/null && ryogami wallpaper repaint
fi
printf 'Removed the %s integration files owned by Ryoku Palette Bridge.\n' "$want"
