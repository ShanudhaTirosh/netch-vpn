# Panel theme overlay (glassmorphism + Netch brand)

This folder holds the **only** 3x-ui frontend files Netch modifies, mirroring
their upstream paths under `frontend/src/`. It is an *overlay*, not a fork — we
don't vendor the GPL-licensed 3x-ui source here.

```
panel-theme/frontend/src/
  hooks/useTheme.tsx       # adds teal colorPrimary (#289DB7) to ConfigProvider (light/dark/ultra)
  styles/page-shell.css    # dark/ultra --bg-page -> brand navy gradient; translucent --bg-card
  styles/page-cards.css    # glass: backdrop-filter blur/saturate + teal border on .ant-card
```

Brand tokens: `--netch-bg-base #03061D`, `--netch-bg-base-alt #02051D`,
`--netch-accent #289DB7`, `--netch-slate #2B2D38`.

## Why this is a build-from-source step

`install.sh` installs 3x-ui from **official prebuilt releases**, whose bundled
frontend obviously doesn't contain these edits. To run the themed panel you must
build a 3x-ui from source with this overlay applied, then serve that build.

## Apply + build

```bash
# 1. Clone 3x-ui at the version you intend to run (>= v2.3.5, matching install.sh).
git clone https://github.com/MHSanaei/3x-ui
cd 3x-ui && git checkout <tag>     # pin a release tag

# 2. Apply the Netch overlay.
bash /path/to/netch-vpn/panel-theme/apply.sh "$PWD"

# 3. Build the frontend.
cd frontend && npm ci && npm run build && cd ..

# 4. Build the Go binary (bundles the freshly built web assets).
go build -o x-ui

# 5. Deploy: replace the official /usr/local/x-ui/x-ui binary with this one
#    (stop x-ui, swap, start x-ui), keeping /etc/x-ui/x-ui.db untouched.
```

> Each file is backed up as `*.netch-bak` before being overwritten, so
> `apply.sh` is reversible.

## Keeping it upstream-safe

These are surgical, additive edits (a token block + CSS variables + an appended
glass block). If a future 3x-ui release relayouts these files, `apply.sh` warns
on any missing target and skips it rather than corrupting the tree — re-port the
small diffs by hand and update the overlay.
