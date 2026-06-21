# Changelog

All notable changes to **NovaNetchX VPN Installer** are documented here.

---

## [1.2.1] — 2026-06

### Fixed
- **`certbot: command not found`** on a plain run: core dependencies
  (`certbot`, `nginx-full`, `python3-certbot-nginx`, `sqlite3`, `jq`, `psmisc`
  for `fuser`, `netcat-openbsd`, `openssl`) are now installed **unconditionally**
  (idempotent) instead of only under `-install y`, with a hard preflight that
  aborts with a clear message if any required tool is still missing.
- Start banner version string corrected (was still `v1.0.0`).

---

## [1.2.0] — 2026-06

### Security
- **Randomized panel credentials** per install (was hard-coded `Shanu`/`admin`);
  printed once in the final summary. No credentials are committed anywhere.
- Added gitleaks secret-scanning CI; `.gitignore` blocks certs/keys/`.env`.

### Added
- Native **glassmorphism subscription page** rendered by 3x-ui's Go
  `html/template` engine (`subThemeDir` → `sub_templates/netch-glass/`).
- Real **NovaNetchX brand** (navy `#03061D`/`#02051D`, teal `#289DB7`) across
  favicon, sub page, and a `panel-theme/` overlay for the 3x-ui frontend
  (`useTheme.tsx` + `page-shell.css` + `page-cards.css`) with `apply.sh`.
- Brand logo assets (`assets/brand/SHANUTECHX.png` / `.jpg`).
- Cloudflare **WARP** selective-routing docs + `scripts/netch-warp-setup.sh`.
- `CHECK_DB_SCHEMA()` preflight: aborts loudly on inbounds/settings schema drift.
- CI (`shellcheck` + HTML validate + `yamllint`), release automation, secret scan.
- `SECURITY.md`, `CONTRIBUTING.md`, `.gitattributes` (LF enforcement).

### Changed
- Consistent real-client-IP + sockopt across all 5 inbounds (per
  `docs/real-client-ip.md`): WS/XHTTP gain `trustedXForwardedFor`, the 7443
  vhost recovers the client IP from PROXY protocol (`real_ip_header`), and
  `tcpFastOpen`/`bbr`/`tcpMptcp` is applied to every TCP inbound.
- Performance: Nginx keepalive tuning, `somaxconn`/`tcp_max_syn_backlog` sysctl.
- Favicon now ships the real brand asset (repo-first; brand-accurate fallback)
  instead of the purple `#7c3aed` placeholder.
- `check_free` no longer depends on `nc` (uses `ss` with `nc` fallback).

### Fixed
- Sub template JS: removed `{{ .x | js }}` (which produced **unquoted** JS and
  broke the page); rely on html/template contextual autoescaping. Verified with
  Go 1.26 `html/template`.
- Clash profiles: dropped the bogus `?clash=meta` query param (3x-ui serves
  Clash on a separate path, not via a format query).

---

## [1.0.0] — 2025-06

### Added
- Initial release by ShanuFX / Netch Solutions
- Full rebranding from x-ui-pro → NovaNetchX / ShanuFX stack
- **5 auto-configured inbounds** on port 443 via Nginx SNI routing:
  - VLESS + TCP + REALITY
  - VLESS + TCP + TLS-Vision (`xtls-rprx-vision`, SNI camouflage)
  - VLESS + WebSocket (CDN-friendly)
  - VLESS + XHTTP over Unix socket (gRPC-style)
  - Trojan + gRPC
- Fixed panel settings: port `9999`, path `NovaNetchX`, user `Shanu`
- `PANEL_DOMAIN` / `REALITY_DOMAIN` placeholders at top of installer
- `VLESS_TLS_SNI` configurable camouflage SNI (default: `aka.ms`)
- Purple (#7c3aed) + Cyan (#06b6d4) ShanuFX brand colours throughout
- **NovaNetchX favicon** (SVG + ICO) injected into panel via Nginx `sub_filter`
- Favicon served at `/favicon.ico` and `/favicon.svg` on the main domain
- Subscription web page and Clash YAML templates moved to `assets/` in this repo
- Backup/restore utility (`backup.sh`) fully rebranded
- `Asia/Colombo` set as default timezone in 3x-UI
- BBR TCP congestion control + sysctl tuning
- Sub2sing-box converter on port 8080 with `@reboot` cron
- Monthly Certbot renewal cron
- UFW firewall: allow 22/80/443 only
- Credits preserved for all upstream open-source projects

### Changed
- Panel port: random → fixed `9999`
- Panel path: random → fixed `NovaNetchX`
- Panel username: random → `Shanu`
- Panel password: random → `admin` *(change after first login)*
- `msg_inf` colour: blue → purple (brand alignment)
- New `msg_cyan()` helper added
- Asset URLs centralised as `GITHUB_REPO` / `GITHUB_RAW` variables

### Credits
- Based on [x-ui-pro](https://github.com/GFW4Fun/x-ui-pro) by GFW4Fun
- Extended with assets from [x-ui-pro](https://github.com/legiz-ru/x-ui-pro) by legiz-ru
- Panel: [3x-ui](https://github.com/MHSanaei/3x-ui) by MHSanaei
