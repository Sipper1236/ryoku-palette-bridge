# Ryoku Palette Bridge

> One wallpaper palette. Three apps. No disruptive reloads.

Ryoku Palette Bridge keeps **Zen Browser**, **Spotify**, and **Discord through
Vesktop** in step with Ryoku's wallpaper colours. Change the wallpaper and the
apps you already have open repaint themselves—your browser stays open, Discord
doesn't flash back to its stock theme, and Spotify keeps playing.

This is one small bridge for all three integrations, rather than a collection
of unrelated scripts.

```text
 Wallpaper
    │
    ▼
 Ryoku + Matugen ──► ~/.cache/ryoku/colors.json
                           │
                           ▼
                ryoku-palette-bridge
                  inotify + local SSE
                    │       │       │
                    ▼       ▼       ▼
                   Zen   Spotify  Vesktop
```

## What makes it feel seamless

Wallpaper theming is often implemented by rewriting a theme file and forcing
the whole application to reload. That works, but it also interrupts whatever
you were doing. This project treats a new palette as a live event instead.

| App | How it updates | What you avoid |
| --- | --- | --- |
| **Zen Browser** | Firefox's native theme API updates the browser chrome; Matugen CSS provides a startup fallback | Restarting Zen for every wallpaper |
| **Spotify + Spicetify** | An extension updates classic Spicetify variables and modern Encore tokens in place | Renderer reloads and interrupted playback |
| **Vesktop / Discord** | Matugen changes QuickCSS variables while the Midnight base theme stays loaded | The flash of unthemed Discord between updates |

Underneath, a dependency-free Go daemon watches Ryoku's palette with Linux
inotify, validates every colour, and publishes changes over a loopback-only
Server-Sent Events stream. Nothing is sent off the machine.

## Quick start

You need Linux, Go 1.24 or newer, systemd user services, and Ryoku generating a
palette at `~/.cache/ryoku/colors.json`.

```bash
git clone https://github.com/Sipper1236/ryoku-palette-bridge.git
cd ryoku-palette-bridge

./install.sh
./install-integrations.sh --all
```

Prefer to enable only the apps you use? Install them individually:

```bash
./install-integrations.sh --spotify
./install-integrations.sh --vesktop
./install-integrations.sh --zen
```

Make sure Ryoku is following the wallpaper, then check that the bridge is
healthy:

```bash
ryoku-shell theme Wallpaper
curl --fail http://127.0.0.1:47616/healthz
```

The core installer builds a stripped binary in `~/.local/bin`, installs and
starts `ryoku-palette-bridge.service`, and safely disables the older
`ryoku-spicetify-palette.service` when it is present. The old unit file is left
in place.

## The three integrations

### Spotify

The Spotify integration requires [Spicetify](https://spicetify.app/). It
installs `spicetify/ryoku-wallpaper-colors.js`, adds it without removing your
existing extensions, and runs `spicetify apply` once during setup.

After that initial setup, palette changes arrive through SSE and repaint the
open client directly. The extension covers both the familiar `--spice-*`
variables and Spotify's newer Encore semantic tokens, so it works with themes
such as Comfy as well as modern Spotify surfaces.

### Vesktop / Discord

The Discord integration requires Vesktop with Vencord and `jq`. It installs a
stable Midnight loader from `vesktop/`, enables QuickCSS, and registers
`templates/vesktop-colors.css` in Ryoku's durable Matugen overlay.

The small architectural detail is what makes this integration pleasant:
Matugen writes only the live palette variables in `settings/quickCss.css`. It
does not rewrite the loaded theme file, so Vesktop does not briefly fall back
to Discord's stock appearance when the wallpaper changes.

Midnight and the referenced Font Awesome icon are third-party works; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

### Zen Browser

The Zen integration finds the running profile first and otherwise falls back
to the default profile in `profiles.ini`. You can set `ZEN_PROFILE_ROOT` when
you want to choose one explicitly. The installer then:

- registers `templates/zen.css` in Ryoku's durable Matugen overlay;
- imports the generated stylesheet from `userChrome.css`; and
- enables legacy user stylesheets in `user.js`.

Live updates come from the lightweight extension in `zen-extension/`, which
subscribes to the local event stream and calls Firefox's native
`browser.theme.update()` API. The Matugen stylesheet remains useful as the
cold-start fallback before the extension connects.

Zen requires extensions to be signed. Run the included wizard to validate the
extension, submit a private unlisted build to Mozilla, and install the signed
artifact:

```bash
./setup-zen-signing.sh
```

Mozilla credentials, upload metadata, and signed XPI files are ignored by Git.
Zen needs one restart after the initial profile setup, but not for later
wallpaper changes.

For manual setups, `templates/matugen-apps.example.toml` contains the portable
Zen and Vesktop Matugen entries without embedding a personal Zen profile or
unrelated Ryoku settings.

## Local API

The daemon listens on `127.0.0.1:47616` by default.

| Endpoint | Purpose |
| --- | --- |
| `GET /v1/events` | Stream validated palette changes over SSE |
| `GET /v1/palette` | Return the current palette |
| `GET /colors.json` | Compatibility endpoint for the original Spotify integration |
| `GET /healthz` | Report service health |

## Tests

Run the portable checks used by CI:

```bash
go test -race ./...
go vet ./...
node tests/zen-palette.test.js
node tests/spicetify-palette.test.js
node tests/zen-theme-schema.test.js
./tests/install-integrations.test.sh
npx --yes web-ext@latest lint --source-dir zen-extension
```

The Zen schema test checks the installed `omni.ja` when Zen is available and
otherwise skips on a generic CI host. Set `ZEN_OMNI_JA` to require a particular
archive.

On a configured Ryoku desktop, the live checks cover each integration and the
complete wallpaper-to-app path:

```bash
./tests/vesktop-seamless-theme.sh
./tests/zen-seamless-theme.sh
./tests/zen-live-palette.sh
./tests/live-palette-pipeline.sh
```

## Security and privacy

- The daemon binds only to loopback.
- Every palette value must be a valid six-digit hexadecimal colour.
- The Zen extension asks only for theme access and access to the local bridge.
- The extension declares no data collection.
- Credentials, signed extensions, generated palettes, and machine-specific app
  state stay out of the repository.

## License

Ryoku Palette Bridge is available under the [MIT License](LICENSE). Third-party
theme attribution is collected in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
