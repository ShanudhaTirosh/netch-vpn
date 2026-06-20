<div align="center">

<img src="https://raw.githubusercontent.com/ShanudhaTirosh/BRAND_LOGOS/main/SHANUTECHX.png" alt="Netch VPN / NovaNetchX" width="180">

# Netch VPN / NovaNetchX

**Self-hosted VPN/proxy automation on top of upstream [3x-ui](https://github.com/MHSanaei/3x-ui).**

[![CI](https://github.com/ShanudhaTirosh/netch-vpn/actions/workflows/ci.yml/badge.svg)](https://github.com/ShanudhaTirosh/netch-vpn/actions/workflows/ci.yml)
[![Release](https://github.com/ShanudhaTirosh/netch-vpn/actions/workflows/release.yml/badge.svg)](https://github.com/ShanudhaTirosh/netch-vpn/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-289DB7.svg)](LICENSE)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04-2B2D38)

</div>

One script provisions a hardened, single-VPS stack: Nginx SNI stream router on
`:443`, five pre-seeded Xray inbounds, Let's Encrypt certs, BBR/sysctl tuning, a
`sub2sing-box` converter, a generic camouflage decoy site, and a glassmorphism
subscription page rendered by 3x-ui's native template engine.

> **Maintained-upstream, not a fork.** The panel itself is installed from
> official 3x-ui releases at install time. This repo is the installer,
> branding, sub-template and automation layer — so you keep getting upstream
> updates.

---

## Quick start

On a clean **Ubuntu 20.04 / 22.04** VPS with two A records pointing at it
(one for the panel, one for REALITY):

```bash
# Edit PANEL_DOMAIN / REALITY_DOMAIN near the top of install.sh first, or pass them as flags.
bash <(curl -fsSL https://raw.githubusercontent.com/ShanudhaTirosh/netch-vpn/main/install.sh) \
  -install y -subdomain vpn.example.com -reality_domain r.example.com
```

Flags:

| Flag | Meaning |
|---|---|
| `-install y` | Install packages + panel |
| `-subdomain` | Panel/sub/WS/XHTTP domain |
| `-reality_domain` | REALITY inbound domain |
| `-auto_domain y` | Derive both domains from a wildcard DNS service (edit the provider in-script) |
| `-clash 0..3` | Clash profile (see `assets/clash/`) |
| `-websub 0\|1` | Static sub page variant (`assets/sub-page*.html`) |
| `-uninstall y` | Remove everything |

At the end the script prints the **randomized** panel URL, username and
password **once** — save them.

---

## Architecture

```
                         Nginx :443 (stream, ssl_preread, PROXY-protocol out)
                                     │  SNI routing (no TLS termination here)
        ┌────────────────────────────┼─────────────────────────────┐
   SNI=reality_domain        SNI=aka.ms (VLESS-TLS)           SNI=panel_domain
        ▼                            ▼                              ▼
  Xray :8443 REALITY        Xray :vless_tls_port           Nginx :7443 (TLS term,
  target 127.0.0.1:9443                                     real_ip from PROXY proto)
                                                             ├─ /<panel>/  → x-ui :9999
                                                             ├─ /<sub>/    → x-ui sub
                                                             ├─ /<web>/    → /var/www/subpage
                                                             ├─ /<xhttp>   → unix socket (gRPC)
                                                             └─ /:port/:path → WS + Trojan-gRPC
   Decoy site (assets/randomfakehtml.sh) at /var/www/html for unmatched/direct-IP hits.
```

### Inbounds (all multiplexed onto 443)

| Protocol | Transport | Camouflage | Real-client-IP |
|---|---|---|---|
| VLESS | REALITY | own target cert | PROXY protocol (`acceptProxyProtocol`) |
| VLESS | TCP+TLS Vision | SNI `aka.ms` | PROXY protocol |
| VLESS | WebSocket | panel domain (CDN-friendly) | `trustedXForwardedFor: X-Forwarded-For` |
| VLESS | XHTTP (gRPC/unix socket) | panel domain | `trustedXForwardedFor: X-Forwarded-For` |
| Trojan | gRPC | panel domain | n/a on grpc_pass hop (see note below) |

All five share `tcpFastOpen` / `tcpcongestion=bbr` / `tcpMptcp` sockopt tuning.
See [`docs/real-client-ip`](https://github.com/MHSanaei/3x-ui/blob/main/docs/real-client-ip.md)
for the IP-attribution mechanism.

> **Trojan-gRPC note:** gRPC can't read `X-Forwarded-For` and Nginx `grpc_pass`
> can't emit PROXY protocol, so accurate per-client IP isn't recoverable on that
> hop. The inbound still works; only its online-IP/IP-limit view is blind.

---

## Repository layout

```
install.sh                         # the installer (v1.2.0)
backup.sh                          # snapshot / restore
SECURITY.md                        # security policy / reporting
CONTRIBUTING.md                    # contribution + local-lint guide
.github/workflows/ci.yml           # shellcheck + HTML validate + yamllint
.github/workflows/release.yml      # auto GitHub Release on tag push
.github/workflows/scan.yml         # gitleaks secret scan
assets/
  favicon.svg / favicon.ico        # real NovaNetchX brand mark (navy/teal)
  brand/SHANUTECHX.png / .jpg       # full brand logo (ShanuTechX)
  randomfakehtml.sh                # generic camouflage decoy generator
  sub-page.html                    # static sub landing (glass)   -> -websub 0
  sub-page-classic.html            # static sub landing (classic) -> -websub 1
  clash/
    clash.yaml                     # -clash 0 (default)
    clash_skrepysh.yaml            # -clash 1
    clash_fullproxy_without_ru.yaml# -clash 2
    clash_refilter_ech.yaml        # -clash 3
scripts/
  warp.md                          # Cloudflare WARP setup (selective routing)
  netch-warp-setup.sh              # best-effort WARP registration helper
sub_templates/
  netch-glass/index.html           # native Go html/template sub page (subThemeDir)
```

---

## Branding

| Token | Value |
|---|---|
| `--netch-bg-base` | `#03061D` |
| `--netch-bg-base-alt` | `#02051D` |
| `--netch-accent` | `#289DB7` |
| `--netch-slate` | `#2B2D38` |

The panel theme (teal `colorPrimary` + glassmorphism cards) is applied in the
3x-ui frontend via `ConfigProvider` tokens and `page-shell.css` /
`page-cards.css`. The sub page and favicon use the same tokens for a single
visual identity.

---

## Cloudflare WARP

WARP is an **opt-in, selective** egress (geosite-based, default traffic stays
direct). See [`scripts/warp.md`](scripts/warp.md) for the one-click panel steps,
the exact outbound/routing JSON, and the `netch-warp-setup.sh` helper.

---

## Security notes

- Panel credentials are randomized per install and shown once.
- The decoy site is intentionally **generic** — it never impersonates a real
  brand.
- `trustedXForwardedFor` / `acceptProxyProtocol` are server-side only and never
  reach clients.
- Consider an Nginx `limit_req` on the panel login path and enabling Fail2ban.

---

## Verifying an install

```bash
nginx -t                                   # syntax is ok / successful
nginx -T | grep real_ip_header             # proxy_protocol
# Per-inbound TLS reachability on 443 with the right SNI:
openssl s_client -connect <reality_domain>:443 -servername <reality_domain> </dev/null
openssl s_client -connect <panel_domain>:443   -servername aka.ms           </dev/null
openssl s_client -connect <panel_domain>:443   -servername <panel_domain>   </dev/null
```

Then log into the panel, open the glass sub page at
`https://<panel_domain>/<sub_path>/<subId>`, and confirm a WS client's online IP
shows the real client address.

---

## Continuous integration

Every push / PR runs `.github/workflows/ci.yml`:

- **ShellCheck** on all `*.sh` — full report is informational; the build only
  fails on genuine `error`-severity findings (not style warnings).
- **HTML validate** — `assets/*.html` are checked strictly; the Go-template
  `sub_templates/**/*.html` is checked leniently (template `{{ }}`/`${ }`
  tokens are ignored since a static checker can't render them).
- **YAML lint** — Clash profiles under `assets/clash/` (relaxed `.yamllint`:
  flow mappings and long provider URLs are allowed).

## Credits

- [3x-ui](https://github.com/MHSanaei/3x-ui) — the panel (GPL-3.0; installed
  from official releases at runtime, not redistributed here).
- [x-ui-pro](https://github.com/GFW4Fun/x-ui-pro) — installer lineage / decoy
  concept.
- [sub2sing-box](https://github.com/legiz-ru/sub2sing-box) — subscription
  conversion.

See [LICENSE](LICENSE) for this repo's own scripts.
