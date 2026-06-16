# NovaNetchX VPN Installer
### by [ShanuFX](https://github.com/ShanudhaTirosh) · [Netch Solutions](https://netchsolutions.com)

> One-command VPN server stack: VLESS-REALITY · VLESS-TLS-Vision · WebSocket · XHTTP · Trojan-gRPC — all multiplexed behind port **443** with Nginx SNI routing, Let's Encrypt SSL, and a camouflage site.

---

## What Gets Installed

| Component | Role |
|-----------|------|
| **3x-UI Panel** (MHSanaei) | Web panel to manage inbounds and clients |
| **Nginx** | SNI-based port-443 router + reverse proxy |
| **Certbot** | Automatic Let's Encrypt TLS certificates |
| **sub2sing-box** | Subscription format converter (sing-box / Clash) |
| **Camouflage site** | Random decoy HTML site at the server root |
| **Web sub page** | Branded subscription page for end-users |
| **BBR + sysctl tuning** | TCP optimisation for maximum throughput |

### Inbounds Created Automatically

| Protocol | Transport | Ext. Port | Notes |
|----------|-----------|-----------|-------|
| VLESS | TCP + **REALITY** | 443 | Anti-fingerprint; hardest to block |
| VLESS | TCP + **TLS Vision** | 443 | `xtls-rprx-vision`, SNI camouflage (`aka.ms`) |
| VLESS | **WebSocket** | 443 | CDN / Cloudflare-friendly |
| VLESS | **XHTTP** (gRPC) | 443 | Via Nginx gRPC pass over Unix socket |
| **Trojan** | **gRPC** | 443 | Alternative protocol |

---

## Quick Install

```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/ShanudhaTirosh/netch-vpn/main/install.sh) -install y
```

**With domains pre-set (no prompts):**
```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/ShanudhaTirosh/netch-vpn/main/install.sh) -install y -subdomain vpn.yourdomain.com -reality_domain r.yourdomain.com
```

**Uninstall:**
```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/ShanudhaTirosh/netch-vpn/main/install.sh) -uninstall y
```

---

## All Arguments

| Argument | Value | What it does |
|----------|-------|-------------|
| `-install` | `y` | Installs Nginx, Certbot, all packages |
| `-subdomain` | `vpn.yourdomain.com` | Sets main panel domain |
| `-reality_domain` | `r.yourdomain.com` | Sets REALITY inbound domain |
| `-uninstall` | `y` | Removes everything cleanly |
| `-websub` | `0` or `1` | `0` = modern sub page, `1` = classic |
| `-clash` | `0`–`3` | Which Clash YAML template to use |

---

## Full Setup Guide

### Prerequisites
- Clean **Ubuntu 20.04 / 22.04** VPS
- Two domain/subdomain **A records** pointing to the server IP
  - `vpn.yourdomain.com` → server IP (panel + subscriptions)
  - `r.yourdomain.com`   → server IP (REALITY inbound)
- Ports **80** and **443** open

### 1 — Clone & Configure

```bash
git clone https://github.com/ShanudhaTirosh/netch-vpn.git
cd netch-vpn
nano install.sh   # fill in PANEL_DOMAIN and REALITY_DOMAIN at the top
```

Or set domains via arguments:

```bash
bash install.sh -subdomain vpn.yourdomain.com -reality_domain r.yourdomain.com -install y
```

### 2 — Run Installer

```bash
chmod +x install.sh
sudo bash install.sh -install y
```

> First-time installs must pass `-install y` to install Nginx, Certbot, and all dependencies.

### 3 — Re-run / Reconfigure (existing server)

```bash
sudo bash install.sh -subdomain vpn.yourdomain.com -reality_domain r.yourdomain.com
```

---

## Configuration Reference

All user-facing settings are at the **top of `install.sh`**:

```bash
PANEL_DOMAIN=""      # e.g. vpn.netchsolutions.com
REALITY_DOMAIN=""    # e.g. r.netchsolutions.com
VLESS_TLS_SNI="aka.ms"   # SNI used by the TLS-Vision inbound
```

Fixed panel settings (change before running if needed):

| Setting | Default |
|---------|---------|
| Panel Port | `9999` |
| Panel Path | `NovaNetchX` |
| Username | `Shanu` |
| Password | `admin` |

> **Change the password immediately after first login.**

---

## Asset URLs

The installer fetches these assets from this repo at runtime. If you fork,
update the `GITHUB_REPO` / `GITHUB_RAW` variables in `install.sh`:

```
assets/
├── randomfakehtml.sh         ← camouflage site installer
├── sub-page.html             ← modern subscription page
├── sub-page-classic.html     ← classic subscription page
└── clash/
    ├── clash.yaml
    ├── clash_skrepysh.yaml
    ├── clash_fullproxy_without_ru.yaml
    └── clash_refilter_ech.yaml
```

---

## Backup & Restore

```bash
sudo bash backup.sh
```

Interactive menu — backs up Nginx config, 3x-UI database, `config.json`,
and web files individually or all at once. Restore from any saved snapshot.

---

## Uninstall

```bash
sudo bash install.sh -uninstall y
```

Removes 3x-UI, Nginx, Certbot, and all generated configs.

---

## Client SNI Reference

| Inbound | Set `sni=` to |
|---------|--------------|
| REALITY | `r.yourdomain.com` (your reality domain) |
| TLS-Vision | `aka.ms` (or whatever `VLESS_TLS_SNI` is set to) |
| WebSocket / XHTTP | `vpn.yourdomain.com` (your panel domain) |

> For TLS-Vision: the server certificate is issued for your panel domain, not
> `aka.ms`. Configure your client with `allowInsecure=true` **or** add the
> server's certificate fingerprint. REALITY has no this limitation.

---

## Credits

| Project | Author | License |
|---------|--------|---------|
| [3x-ui](https://github.com/MHSanaei/3x-ui) | MHSanaei | GPL-3.0 |
| [x-ui-pro](https://github.com/GFW4Fun/x-ui-pro) | GFW4Fun | — |
| [x-ui-pro](https://github.com/legiz-ru/x-ui-pro) | legiz-ru | — |
| [sub2sing-box](https://github.com/legiz-ru/sub2sing-box) | legiz-ru | — |
| [randomfakehtml](https://github.com/GFW4Fun/randomfakehtml) | GFW4Fun | — |

---

<p align="center">
  Built with ♥ by <strong>ShanuFX</strong> · <strong>Netch Solutions</strong>
</p>
