# Changelog

All notable changes to **NovaNetchX VPN Installer** are documented here.

---

## [1.3.0] — 2026-07

### Fixed (Phase 1 — bugs)
- **Startup wipe gate**: the 6 `rm -rf` + `systemctl stop` commands ran at bash
  parse-time on every execution; moved into `fresh_install_cleanup()` called
  only from `install_panel()`.
- **x25519 public key grep**: `grep "^Password"` never matched xray's output
  (`Private key:` / `Public key:`), silently seeding all REALITY inbounds with
  a blank `publicKey`. Fixed to `grep "^Public key:"`.
- **Settings INSERT duplicates**: plain `INSERT INTO "settings"` without a prior
  `DELETE` stacked rows on every re-run; 3x-ui could read a stale value. Added
  `DELETE FROM "settings"; DELETE FROM "inbounds" WHERE user_id='1';` at the
  top of the sqlite3 heredoc.
- **sysctl idempotency**: all BBR / buffer settings used `tee -a /etc/sysctl.conf`
  (append-mode), duplicating every line on re-run. Rewritten to write to a
  dedicated `/etc/sysctl.d/99-netch.conf` drop-in (overwrite-on-run).
- **Unused `ws_path`**: dead variable after WS path was changed to `/${domain}`.
  Removed.
- **Unused `trojan_pass`**: generated but never referenced in any INSERT. Removed.
- **`PORT` global leak**: `make_port()` assigned `PORT` without `local`, clobbering
  any outer `$PORT`. Fixed with `local PORT`.
- **`local` outside function (SC2168)**: health-check block used `local _hc_ok`,
  `local _cert_out`, `local _expiry` at top-level scope. Removed `local`.

### Security (Phase 2)
- **Panel rate-limit**: `limit_req_zone` in `conf.d/netch-security.conf`;
  `limit_req zone=panel_login burst=10 nodelay` on both panel location blocks
  (5 req/min per IP, HTTP 429 on overflow).
- **Cloudflare IP allowlist**: `-ONLY_CF_IP_ALLOW y` fetches Cloudflare CIDRs
  at install time and injects `allow <cidr>; … deny all;` into the WS
  `location = /${domain}` block, so direct (non-CDN) connections are rejected.
- **fail2ban**: installed, `/etc/fail2ban/filter.d/x-ui.conf` watches x-ui log
  for login failures (JSON + text format); jail bans after 5 failures for 1 h.
- **Random bootstrap credentials**: `config_after_install()` no longer uses
  hardcoded `netchadmin`/`Netch@Setup1`; generates a 10/20-char random pair
  that is overwritten within seconds by `UPDATE_XUIDB`.

### Reliability (Phase 3)
- **Certbot post-hook**: renewal cron now runs `nginx -s reload && x-ui restart`
  (previously only `nginx -s reload`; x-ui holds the cert path and needs a reload).
- **`/etc/nginx/snippets/` mkdir**: added `mkdir -p /etc/nginx/snippets` before
  writing `includes.conf`; the directory may not exist on a fresh nginx install.
- **sub2sing-box auto-version**: replaced hardcoded `v0.0.9` with a GitHub API
  fetch; falls back to `v0.0.9` if unreachable.
- **DB backup**: `UPDATE_XUIDB()` now copies `x-ui.db` to
  `/root/x-ui-backup-<timestamp>.db` before the DELETE wipe.
- **Post-install health check**: verifies nginx config, port 443, WS port, x-ui
  service, fail2ban, and TLS cert validity after every successful install.

### Added (Phase 4)
- **`-update_config y`**: re-seeds DB + reloads nginx without reinstalling 3x-ui.
  Use when changing domains, ports, sub paths, or Telegram settings on a live server.
- **`-tgbot TOKEN -tgchat ID`**: auto-configures `tgBotToken`, `tgBotChatId`,
  `tgBotEnable=true` in the 3x-ui DB at install time.
- **`-dry_run y`**: wraps destructive operations in `drun()`; prints what would
  run without executing. Safe to use on a live server.
- **Client reference file**: `/root/nova-client.txt` (chmod 600) written after
  every successful install with all inbound connection parameters pre-filled.
- **Log rotation**: `/etc/logrotate.d/x-ui` — daily, 7-day retain, compressed,
  restarts x-ui in `postrotate`.
- **IPv6 UFW**: `IPV6=yes` enforced in `/etc/default/ufw` before any `ufw allow`
  so rules cover `[::]:443` as well as `0.0.0.0:443`.
- **gzip**: `conf.d/netch-perf.conf` — compresses subscription/JSON responses
  (60–80% reduction on sub refreshes).
- **SSL session cache**: `ssl_session_cache shared:SSL:10m; ssl_session_tickets off`
  — returning clients skip the full TLS handshake (~40,000 sessions / 10 MB).
- **OCSP stapling**: `ssl_stapling on; ssl_stapling_verify on` — eliminates the
  CA round-trip on first connection.

### Changed (Phase 5 — code structure)
- `set -o pipefail` added after shebang — pipeline failures surface immediately.
- `arch()` result cached in `readonly ARCH=$(arch)`; was spawning 6 subshells.
- `check_free()` renamed `port_in_use()` — semantics now match the call site
  (`if ! port_in_use "$PORT"` → "if port is NOT in use → use it").
- `warp-setup.sh` moved to `scripts/warp-setup.sh`; supersedes the older
  `scripts/netch-warp-setup.sh` (cloudflare-warp apt approach, full
  proxy-mode setup, routing examples written to `/root/warp-routing-examples.txt`).

### Added — modular `lib/` split (Fix 25)
All functions extracted from the monolith and available as sourced modules:

| File | Provides |
|---|---|
| `lib/utils.sh` | `msg_*`, `drun`, `gen_random_string`, `get_port`, `port_in_use`, `make_port` |
| `lib/ssl.sh` | `resolve_to_ip`, `issue_certs` |
| `lib/deps.sh` | `install_deps`, `tune_kernel`, `setup_fail2ban`, `install_sub2singbox`, `setup_firewall`, `setup_logrotate`, `setup_crons` |
| `lib/panel.sh` | `arch`, `ARCH` cache, `fresh_install_cleanup`, `config_after_install`, `install_panel` |
| `lib/nginx.sh` | `SETUP_NGINX` (all heredocs, CF allowlist builder, symlinks) |
| `lib/xray.sh` | `CHECK_DB_SCHEMA`, `UPDATE_XUIDB` (all 5 inbound INSERTs + settings seed) |

See `ARCHITECTURE.md` for the extraction order and how to migrate to the slim
orchestrator.

---

## [1.2.4] — 2026-06

### Changed
- The panel **theme + SX-UI rebrand** are now also injected on the
  **REALITY-domain vhost (:9443)** panel path, not just the main panel domain.
  That vhost previously served the stock UI and proxied the panel over `http`
  (the panel serves `https`); it now uses `https` + the same `sub_filter`
  injection, so the panel looks identical regardless of which domain it's
  opened from.

---

## [1.2.3] — 2026-06

### Added
- Every panel surface now matches the glass theme: **inputs, selects,
  dropdowns, date pickers, default buttons, checkboxes, modals, drawers and
  tables** are recoloured to navy by overriding AntD v6's surface/fill/border
  CSS variables (dark mode only). Fixes the near-black form fields and popups
  (Edit Client, Add Node, Outbounds, Outbound Subscriptions, WARP, Nord, etc.).

### Changed
- Footer GitHub/version link repointed to the Netch repo.

### Removed
- The donation/sponsor **heart icon** in the panel header (hidden via the
  injected rebrand script + CSS).

---

## [1.2.2] — 2026-06

### Added
- **Runtime rebrand** `3X-UI → SX-UI` across the panel (sidebar, titles, login)
  via an injected script (`assets/netch-brand.js`) — text nodes only, link
  hrefs left intact, re-applied after React re-renders. The footer GitHub/version
  link is repointed from `MHSanaei/3x-ui` to the Netch repo.

### Fixed
- **Panel UI theme now actually applies** on the stock prebuilt 3x-ui binary.
  Previously only the favicon/inbounds changed because the installer uses the
  official release (stock React bundle) — the glass/teal theme lived only in the
  `panel-theme/` source overlay. Now a brand stylesheet (`assets/netch-theme.css`)
  is injected into the SPA via the same Nginx `sub_filter` as the favicon:
  navy glassmorphism surfaces + teal AntD primary (AntD v6 CSS variables), no
  source rebuild required. `panel-theme/` remains for compiled-in builds.
- Themed the parts that still looked stock — **sidebar, menu, header, inputs**
  and the **login screen** — and removed a redundant `sub_filter_types` line
  that produced a harmless `duplicate MIME type` nginx warning.

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
