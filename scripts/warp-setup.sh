#!/bin/bash
# shellcheck disable=SC2034,SC2086
##########################################################################
#  NovaNetchX — Cloudflare WARP Setup Helper
#  Developer  : ShanuFX  (github.com/ShanudhaTirosh)
#  Repository : github.com/ShanudhaTirosh/netch-vpn
#  ----------
#  Installs Cloudflare WARP on the VPS and configures it as a SOCKS5 proxy
#  on 127.0.0.1:40000.  Then writes an Xray outbound config snippet that
#  routes traffic through WARP — useful for bypassing destination-side
#  blocks (e.g. streaming services that block VPS IPs) while still serving
#  your VPN clients through your own server.
#
#  USAGE
#  -----
#  bash warp-setup.sh              # install + configure
#  bash warp-setup.sh --remove     # uninstall WARP and remove outbound
#
#  AFTER RUNNING
#  -------------
#  1. In the 3x-ui panel → Xray Settings → paste the outbound snippet
#     from /root/warp-outbound.json (or import via the JSON editor).
#  2. In Routing → add rules that send desired traffic to the "warp" tag.
#     Example: route geoip:us / geoip:uk through warp so streaming
#     services see a Cloudflare IP instead of your VPS IP.
##########################################################################
set -o pipefail

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

msg_ok()  { echo -e "\e[1;42m $1 \e[0m"; }
msg_err() { echo -e "\e[1;41m $1 \e[0m"; }
msg_inf() { echo -e "\e[1;35m$1\e[0m"; }

WARP_SOCKS_PORT=40000
OUTBOUND_FILE="/root/warp-outbound.json"

############################### REMOVE ##########################################
if [[ "${1}" == "--remove" ]]; then
    msg_inf "  Removing Cloudflare WARP..."
    warp-cli disconnect 2>/dev/null || true
    warp-cli registration delete 2>/dev/null || true
    apt-get remove -y cloudflare-warp 2>/dev/null || true
    rm -f "$OUTBOUND_FILE"
    rm -f /etc/apt/sources.list.d/cloudflare-warp.list
    rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    msg_ok "WARP removed. Remember to also remove the warp outbound from Xray settings."
    exit 0
fi

############################### INSTALL #########################################
msg_inf "  Installing Cloudflare WARP..."

# Add Cloudflare apt repo (official — https://pkg.cloudflareclient.com)
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
    | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] \
https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/cloudflare-warp.list > /dev/null

apt-get update -qq
apt-get install -y cloudflare-warp
msg_ok "cloudflare-warp installed"

############################### CONFIGURE #######################################
msg_inf "  Registering WARP (no account required)..."

# Fresh registration — delete any stale one first
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new
msg_ok "WARP registered"

# Set proxy mode: WARP exposes a local SOCKS5 proxy instead of a full tunnel.
# This is what we point Xray's outbound at.  Full-tunnel mode would route ALL
# server traffic through WARP which breaks SSH and panel access.
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port "${WARP_SOCKS_PORT}"
msg_ok "WARP set to proxy mode on port ${WARP_SOCKS_PORT}"

# Connect
warp-cli --accept-tos connect
sleep 2

# Verify
if warp-cli status 2>/dev/null | grep -q "Connected"; then
    msg_ok "WARP connected"
else
    msg_err "WARP did not connect — check: warp-cli status"
    exit 1
fi

############################### PERSIST ON REBOOT ################################
# WARP doesn't ship a systemd unit on server installs — add a cron @reboot entry
(crontab -l 2>/dev/null | grep -v "warp-cli connect"; \
 echo "@reboot sleep 10 && warp-cli connect > /dev/null 2>&1") | crontab -
msg_ok "WARP auto-connect on reboot configured"

############################### XRAY OUTBOUND SNIPPET ###########################
# Write a ready-to-paste Xray outbound config.
# Import this in 3x-ui → Xray Settings → Outbounds (JSON tab).
# Then create a routing rule: traffic tag "warp" goes through this outbound.
cat > "$OUTBOUND_FILE" << 'XRAY_OUT'
{
  "tag": "warp",
  "protocol": "socks",
  "settings": {
    "servers": [
      {
        "address": "127.0.0.1",
        "port": 40000
      }
    ]
  },
  "streamSettings": {
    "network": "tcp"
  },
  "mux": {
    "enabled": false
  }
}
XRAY_OUT
chmod 600 "$OUTBOUND_FILE"

############################### ROUTING EXAMPLES ################################
cat > /root/warp-routing-examples.txt << 'REXAMPLES'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  NovaNetchX — WARP Routing Examples
  Add these in 3x-ui → Xray Settings → Routing (JSON)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE 1 — Route US/UK geo-IPs through WARP
(so streaming services see a Cloudflare edge IP, not your VPS)

{
  "type": "field",
  "outboundTag": "warp",
  "ip": ["geoip:us", "geoip:gb"]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE 2 — Route specific domains through WARP

{
  "type": "field",
  "outboundTag": "warp",
  "domain": [
    "netflix.com",
    "nflxso.net",
    "spotify.com"
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXAMPLE 3 — Route all traffic through WARP except the panel
(use with care — slow for non-streaming use cases)

{
  "type": "field",
  "outboundTag": "direct",
  "domain": ["your-panel-domain.com"]
},
{
  "type": "field",
  "outboundTag": "warp",
  "network": "tcp,udp"
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REXAMPLES

############################### SUMMARY #########################################
echo
msg_ok " Cloudflare WARP setup complete!"
echo
echo "  SOCKS5 proxy : 127.0.0.1:${WARP_SOCKS_PORT}"
echo "  Status       : $(warp-cli status 2>/dev/null | head -1)"
echo
msg_inf "  Next steps:"
echo "  1. Open 3x-ui panel → Xray Settings → Outbounds"
echo "  2. Add outbound from: cat ${OUTBOUND_FILE}"
echo "  3. Add routing rules from: cat /root/warp-routing-examples.txt"
echo "  4. Click Save + Restart Xray"
echo
msg_inf "  Verify WARP IP:"
echo "  curl --socks5 127.0.0.1:${WARP_SOCKS_PORT} https://cloudflare.com/cdn-cgi/trace | grep ip"
echo
