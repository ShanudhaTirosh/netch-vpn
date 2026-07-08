# NovaNetchX — Installer Architecture (v1.3.0 → modular)

The current `install.sh` is a **1706-line monolith**.  This document maps every
section to its target module in the `lib/` directory so you can split it
incrementally — one file at a time — without breaking a working install.

---

## Target directory layout

```
netch-vpn/
├── install.sh              ← slim orchestrator (~120 lines after full split)
├── warp-setup.sh           ← standalone WARP installer (already split ✓)
├── lib/
│   ├── utils.sh            ← colour output, drun, port helpers  (DONE ✓)
│   ├── deps.sh             ← apt preflight, bbr/sysctl tuning, fail2ban
│   ├── ssl.sh              ← certbot issuance + renewal cron
│   ├── nginx.sh            ← all nginx config heredocs (SETUP_NGINX)
│   ├── xray.sh             ← CHECK_DB_SCHEMA + UPDATE_XUIDB sqlite seeding
│   └── panel.sh            ← install_panel + config_after_install + arch()
└── assets/
    ├── favicon.svg
    ├── netch-theme.css
    └── sub-page.html
```

---

## Section → module mapping

| install.sh section | Lines (approx) | Target file | Status |
|---|---|---|---|
| Brand output helpers (msg_ok etc.) | 78–82 | `lib/utils.sh` | ✅ Done |
| drun() | 83–93 | `lib/utils.sh` | ✅ Done |
| get_port / gen_random_string | 182–190 | `lib/utils.sh` | ✅ Done |
| port_in_use / make_port | 197–219 | `lib/utils.sh` | ✅ Done |
| apt preflight (certbot, nginx, sqlite3…) | 270–310 | `lib/deps.sh` | ✅ Done |
| BBR / sysctl tuning (99-netch.conf) | 1195–1215 | `lib/deps.sh` | ✅ Done |
| fail2ban install + filter + jail | 1252–1285 | `lib/deps.sh` | ✅ Done |
| UFW rules | 1450–1462 | `lib/deps.sh` | ✅ Done |
| logrotate config | 1426–1445 | `lib/deps.sh` | ✅ Done |
| cron jobs | 1446–1452 | `lib/deps.sh` | ✅ Done |
| sub2sing-box install | 1360–1400 | `lib/deps.sh` | ✅ Done |
| certbot issue + renewal cron | 1310–1360 | `lib/ssl.sh` | ✅ Done |
| nginx.conf patching (stream, gzip…) | 395–415 | `lib/nginx.sh` | ✅ Done |
| 80.conf + 443.conf + includes.conf | 415–710 | `lib/nginx.sh` | ✅ Done |
| CF_ALLOW_BLOCK builder | 525–548 | `lib/nginx.sh` | ✅ Done |
| CHECK_DB_SCHEMA | 730–785 | `lib/xray.sh` | ✅ Done |
| UPDATE_XUIDB (sqlite3 seed) | 820–1020 | `lib/xray.sh` | ✅ Done |
| arch() | 1140–1150 | `lib/panel.sh` | ✅ Done |
| install_panel | 1155–1220 | `lib/panel.sh` | ✅ Done |
| config_after_install | 1135–1150 | `lib/panel.sh` | ✅ Done |
| sub2sing-box install | 1360–1400 | `lib/panel.sh` | ✅ Done |
| fresh_install_cleanup | 170–179 | `lib/panel.sh` | ✅ Done |

---

## What the slim orchestrator looks like

After a full split, `install.sh` becomes ~120 lines that only orchestrate:

```bash
#!/bin/bash
set -o pipefail
[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/deps.sh"
source "${SCRIPT_DIR}/lib/ssl.sh"
source "${SCRIPT_DIR}/lib/nginx.sh"
source "${SCRIPT_DIR}/lib/xray.sh"
source "${SCRIPT_DIR}/lib/panel.sh"

# ── Config ────────────────────────────────────────────────────────────────
PANEL_DOMAIN=""
REALITY_DOMAIN=""
VLESS_TLS_SNI="aka.ms"
WS_CDN_HOST="support.zoom.us"
WS_CDN_PORT=8080
# … rest of config vars …

# ── Argument parsing ──────────────────────────────────────────────────────
while [ "$#" -gt 0 ]; do
    case "$1" in
        -subdomain)     PANEL_DOMAIN="$2";     shift 2;;
        -tgbot)         TG_BOT_TOKEN="$2";     shift 2;;
        -tgchat)        TG_CHAT_ID="$2";       shift 2;;
        -update_config) UPDATE_CONFIG="$2";    shift 2;;
        -dry_run)       DRY_RUN="$2";          shift 2;;
        # …
        *) shift 1;;
    esac
done

# ── Validation ────────────────────────────────────────────────────────────
[[ -z "$PANEL_DOMAIN" ]] && { msg_err "Set PANEL_DOMAIN or pass -subdomain"; exit 1; }

# ── Orchestrate ───────────────────────────────────────────────────────────
if [[ "${UPDATE_CONFIG}" == "y" ]]; then
    SETUP_NGINX && UPDATE_XUIDB && nginx -s reload && x-ui restart
elif systemctl is-active --quiet x-ui; then
    x-ui restart
else
    install_deps
    issue_cert
    SETUP_NGINX
    install_panel
    UPDATE_XUIDB
    systemctl daemon-reload && systemctl enable x-ui && x-ui restart
fi

print_summary
health_check
write_client_reference
```

---

## How to split safely — one module at a time

1. **Start with `lib/utils.sh`** (already done). It has zero dependencies —
   anything can source it first without side effects.

2. **`lib/deps.sh` next** — apt installs, sysctl, fail2ban, UFW, logrotate, crons.
   These are all independent install steps that don't touch nginx or xray state.

3. **`lib/ssl.sh`** — certbot is called once during install and once in cron.
   Extract `issue_cert()` wrapping the existing certbot commands.

4. **`lib/nginx.sh`** — the biggest heredoc block. Extract `SETUP_NGINX()`.
   Test by calling it standalone after a manual wipe of `/etc/nginx/sites-*`.

5. **`lib/xray.sh`** — extract `CHECK_DB_SCHEMA()` and `UPDATE_XUIDB()`.
   These only touch `/etc/x-ui/x-ui.db` so they're safe to test in isolation.

6. **`lib/panel.sh`** last — `install_panel()` is the most stateful function
   (downloads, extracts, starts services). Extract it last once everything else
   is proven stable.

---

## Testing each split

After extracting each module, run:
```bash
bash -n install.sh          # syntax check — no execution
bash -n lib/utils.sh
bash install.sh -dry_run y -subdomain test.example.com
```

`-dry_run y` exercises the full argument parse and print path without
touching the server, making it safe to run on a live install to verify
the new sourced-module path works end-to-end.
