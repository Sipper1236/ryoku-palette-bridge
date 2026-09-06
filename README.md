# Ryoku Palette Bridge

A small, event-driven bridge that publishes Ryoku's active wallpaper palette
to local applications without polling.

## Endpoints

- `GET /v1/palette` returns the current palette.
- `GET /v1/events` streams palette changes with Server-Sent Events.
- `GET /colors.json` preserves compatibility with the original Spotify hook.
- `GET /healthz` reports service health.

The server listens on `127.0.0.1:47616` by default and watches
`~/.cache/ryoku/colors.json` with inotify.

## Install the bridge

Requirements: Linux, Go 1.24 or newer, and a Ryoku palette at
`~/.cache/ryoku/colors.json`.

```bash
./install.sh
curl --fail http://127.0.0.1:47616/healthz
```

The installer builds a stripped binary in `~/.local/bin` and enables a user
systemd service. No root access is required.

## Zen Browser

`zen-extension/` contains the signed-extension source used to apply palette
updates through Firefox's native theme API. The extension connects only to the
local SSE endpoint, collects no data, and requires the `theme` permission.

Mozilla credentials and signed XPI artifacts are intentionally excluded from
Git. Run `./setup-zen-signing.sh` to validate and submit a private, unlisted
build for Mozilla signing.

The matching Matugen stylesheet should consume Gecko's live `--lwt-*`
variables instead of redefining them with static `!important` colors. The local
template is provided at `templates/zen.css`. Add it to Matugen and import its
generated output from the active Zen profile's `chrome/userChrome.css`.

The local integration check is:

```bash
./tests/zen-seamless-theme.sh
```

## Tests

```bash
go test ./...
node tests/zen-palette.test.js
npx --yes web-ext@latest lint --source-dir zen-extension
```

`tests/vesktop-seamless-theme.sh` and `tests/zen-seamless-theme.sh` validate
the live desktop integrations on a configured Ryoku machine.

## Security

The HTTP server binds only to loopback and accepts palette values only after
validating the required color roles. The extension requests only Firefox's
theme permission and access to the loopback palette endpoint. It declares no
data collection. Mozilla API credentials, signed XPIs, and upload metadata are
excluded by `.gitignore`.
