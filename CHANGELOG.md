# Changelog

All notable changes to **NovaNetchX VPN Installer** are documented here.

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
