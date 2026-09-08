#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root=$(mktemp -d /tmp/ryoku-palette-install.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
config_root="$test_root/config"
fake_bin="$test_root/bin"
profile_root="$config_root/zen/test.default"
state_file="$test_root/spicetify-extensions"
mkdir -p "$fake_bin" "$config_root/matugen" "$config_root/vesktop/settings" "$profile_root/chrome"

printf '[config]\n\n[templates.existing]\ninput_path = "keep"\noutput_path = "keep"\n' \
  > "$config_root/matugen/apps.toml"
printf '{}\n' > "$config_root/vesktop/settings/settings.json"
printf '@import "existing.css";\n' > "$profile_root/chrome/userChrome.css"
printf 'user_pref("existing", true);\n' > "$profile_root/user.js"

printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fake_bin/ryoku"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fake_bin/ryogami"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ $1 == config && $2 == extensions && $# == 2 ]]; then' \
  '  test -f "$FAKE_SPICETIFY_STATE" && cat "$FAKE_SPICETIFY_STATE"' \
  'elif [[ $1 == config && $2 == extensions ]]; then' \
  '  printf "%s\\n" "$3" >> "$FAKE_SPICETIFY_STATE"' \
  'elif [[ $1 != apply ]]; then' \
  '  exit 2' \
  'fi' > "$fake_bin/spicetify"
chmod +x "$fake_bin/ryoku" "$fake_bin/ryogami" "$fake_bin/spicetify"

for _ in 1 2; do
  XDG_CONFIG_HOME="$config_root" \
  ZEN_PROFILE_ROOT="$profile_root" \
  FAKE_SPICETIFY_STATE="$state_file" \
  PATH="$fake_bin:$PATH" \
    "$project_root/install-integrations.sh" --all
done

overlay="$config_root/ryoku/user_edits/matugen"
cmp "$project_root/spicetify/ryoku-wallpaper-colors.js" \
  "$config_root/spicetify/Extensions/ryoku-wallpaper-colors.js"
cmp "$project_root/templates/vesktop-colors.css" "$overlay/templates/vesktop-colors.css"
cmp "$project_root/templates/zen.css" "$overlay/templates/zen.css"
cmp "$project_root/vesktop/midnight-ryoku.theme.css" \
  "$config_root/vesktop/themes/midnight-ryoku.theme.css"
[[ $(grep -c '^\[templates\.vesktop\]$' "$overlay/apps.toml") == 1 ]]
[[ $(grep -c '^\[templates\.zen\]$' "$overlay/apps.toml") == 1 ]]
[[ $(grep -c '^\[templates\.existing\]$' "$overlay/apps.toml") == 1 ]]
[[ $(grep -Fc '@import "ryoku-colors.css";' "$profile_root/chrome/userChrome.css") == 1 ]]
[[ $(grep -Fc 'toolkit.legacyUserProfileCustomizations.stylesheets' "$profile_root/user.js") == 1 ]]
[[ $(grep -Fc 'ryoku-wallpaper-colors.js' "$state_file") == 1 ]]
jq -e '.useQuickCss == true and (.enabledThemes | map(select(. == "midnight-ryoku.theme.css")) | length == 1)' \
  "$config_root/vesktop/settings/settings.json" >/dev/null

printf 'PASS: integration installer is idempotent and preserves existing configuration\n'
