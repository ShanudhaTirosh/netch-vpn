# Cloudflare WARP — selective egress for Netch VPN

This is the **Step 4** deliverable: how WARP is wired into the stack, exactly what
traffic does and does not go through it, and how to enable it.

## Decision (Step 0.2): selective routing, not always-on relay

WARP is added as a **named `wireguard` outbound (`tag: warp`)** plus a **routing
rule** that sends only a couple of geosite categories through it. Everything else
keeps exiting directly from the VPS IP via `freedom`. Rationale:

- Preserves REALITY's core value — most traffic still looks like ordinary direct
  traffic from your server, which is the whole point of the camouflage.
- Avoids making every connection depend on Cloudflare WARP's availability and its
  free-tier throttling / rate limits.
- WARP is used where it actually helps (e.g. services that treat Cloudflare IP
  space more favourably, or to add a hop for specific destinations).

## Why this is a one-click manual step, not fully auto-scripted

The panel already ships a complete WARP client (`internal/web/service/integration/warp.go`):
`RegWarp()` registers a free identity against Cloudflare's public API and stores the
WireGuard keys; `ChangeWarpIP()` rotates it. The **registration** call is reliable to
script. The fragile part is the second half: after `/warp/reg`, the `wireguard`
outbound still has to be merged into the live Xray template JSON and saved
(`WarpModal` does this in-browser via `onAddOutbound` → template save). Scripting a
JSON merge into an actively-evolving config schema from bash is exactly the kind of
brittle step we avoided for inbound seeding. So:

- **Primary path:** one-click in the panel (below). Robust, uses the maintained UI.
- **Helper:** `netch-warp-setup.sh` automates login + registration and then prints
  the exact outbound + routing JSON to paste once. It does **not** blindly rewrite
  your Xray config.

## One-click path (recommended)

1. Panel → **Xray Configuration** → **Outbounds** tab → **Warp** button.
2. Click **Create Account** (this calls `RegWarp`), then **Add Outbound**.
   This creates the `wireguard` outbound with `tag: warp`.
3. Go to the **Routing** tab and add a rule:
   - **Outbound tag:** `warp`
   - **Domain:** `geosite:openai`, `geosite:netflix`
   (edit this list to taste — see "Editing the domain list" below).
4. Save the Xray config. Done.

## The outbound this produces (for reference)

```json
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "mtu": 1420,
    "secretKey": "<your private key>",
    "address": ["172.16.0.2/32", "2606:4700:110:8.../128"],
    "reserved": [.., .., ..],
    "domainStrategy": "ForceIPv4v6",
    "peers": [{
      "publicKey": "<cloudflare public key>",
      "endpoint": "engage.cloudflareclient.com:2408"
    }],
    "noKernelTun": true
  }
}
```

(`reserved`, `address`, and the peer public key come back from registration —
`WarpModal` derives them; that's why letting the panel build it is easiest.)

## The routing rule (selective)

Add this to `routing.rules` (the panel's Routing tab is the same array):

```json
{
  "type": "field",
  "domain": ["geosite:openai", "geosite:netflix"],
  "outboundTag": "warp"
}
```

## What goes through WARP after this — plainly

- **Through WARP:** only DNS/connections whose destination matches the geosites in
  the rule (with the defaults above: OpenAI/ChatGPT and Netflix domains). For those,
  the exit IP your clients present to the destination is Cloudflare WARP's, not your
  VPS's.
- **NOT through WARP (stays direct from the VPS):** everything else — all other
  browsing, the bulk of traffic, and crucially all of your **inbound** REALITY /
  TLS-Vision / WS / XHTTP / Trojan camouflage, which is an ingress concern and is
  completely unaffected by an egress routing rule.

## Editing the domain list

The single place to change is the `domain` array of the `warp` routing rule (panel
Routing tab, or the `routing.rules` array in the Xray config JSON). Add geosites
(`geosite:google`, `geosite:spotify`, ...) or explicit domains (`domain:example.com`).
No reinstall needed — save and Xray reloads.

## No collision with inbound camouflage (Step 4c — verified)

WARP is purely an **outbound/egress** concern. The REALITY `dest`/`target`
(`127.0.0.1:9443`) and the TLS-Vision SNI (`aka.ms`) are **inbound/ingress**
camouflage settings. They live in different parts of the config (`inbounds[].streamSettings`
vs `outbounds[]` + `routing.rules`) and never share a port or tag, so adding the
`warp` outbound + rule cannot collide with them. The only shared name to avoid is the
outbound `tag` — keep it `warp` and don't reuse it elsewhere.

## Rotating the WARP IP

Panel → Warp modal → **Change IP** (calls `ChangeWarpIP`, which re-registers and
rewrites the saved outbound), or set the auto-update interval (days) in the same
modal.
