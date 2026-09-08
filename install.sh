#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

install -d "$bin_dir" "$unit_dir"
go build -trimpath -ldflags='-s -w' -o "$bin_dir/ryoku-palette-bridge" "$project_root"
install -m 0644 "$project_root/packaging/systemd/ryoku-palette-bridge.service" \
  "$unit_dir/ryoku-palette-bridge.service"
systemctl --user daemon-reload
if systemctl --user list-unit-files ryoku-spicetify-palette.service --no-legend 2>/dev/null | grep -q '^ryoku-spicetify-palette.service'; then
  systemctl --user disable --now ryoku-spicetify-palette.service
  printf 'Disabled legacy ryoku-spicetify-palette.service (its unit file was preserved)\n'
fi
systemctl --user enable --now ryoku-palette-bridge.service
printf 'Installed and started ryoku-palette-bridge.service\n'
