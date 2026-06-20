#!/bin/bash
##########################################################################
#  Netch VPN — WARP setup helper  (Step 4)
#  Registers a free Cloudflare WARP identity via the panel's own API and
#  prints the exact `wireguard` outbound + selective routing rule to add.
#
#  This intentionally does the RELIABLE half (login + registration) and, by
#  default, only PRINTS the JSON to paste in the panel — it does not blindly
#  rewrite your live Xray config. Pass --apply to attempt an automatic merge
#  via jq (best effort; review the result in the panel afterwards).
#
#  Usage:
#    bash netch-warp-setup.sh                 # interactive, print-only
#    bash netch-warp-setup.sh --apply         # also try to merge into Xray cfg
#  Env overrides (skip prompts):
#    PANEL_URL=https://vpn.example.com/NovaNetchX  PANEL_USER=...  PANEL_PASS=...
##########################################################################
set -euo pipefail

APPLY="n"; [[ "${1:-}" == "--apply" ]] && APPLY="y"
GEOSITES_DEFAULT='["geosite:openai","geosite:netflix"]'

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need curl; need jq

# --- Locate an xray binary for keypair generation (curve25519) ---------------
XRAY_BIN=""
for c in /usr/local/x-ui/bin/xray-linux-amd64 /usr/local/x-ui/bin/xray-linux-arm64 \
         /usr/local/x-ui/bin/xray-linux-arm $(command -v xray 2>/dev/null); do
    [[ -x "$c" ]] && XRAY_BIN="$c" && break
done
[[ -z "$XRAY_BIN" ]] && { echo "Could not find an xray binary for key generation."; exit 1; }

# --- Inputs ------------------------------------------------------------------
PANEL_URL="${PANEL_URL:-}"; PANEL_USER="${PANEL_USER:-}"; PANEL_PASS="${PANEL_PASS:-}"
[[ -z "$PANEL_URL"  ]] && read -rp "Panel URL (incl. base path, e.g. https://vpn.example.com/NovaNetchX): " PANEL_URL
[[ -z "$PANEL_USER" ]] && read -rp "Panel username: " PANEL_USER
[[ -z "$PANEL_PASS" ]] && { read -rsp "Panel password: " PANEL_PASS; echo; }
PANEL_URL="${PANEL_URL%/}"

CJ="$(mktemp)"; trap 'rm -f "$CJ"' EXIT

# --- 1) Login (cookie session) ----------------------------------------------
echo "[*] Logging in..."
login_resp="$(curl -fsS -c "$CJ" -k \
    --data-urlencode "username=$PANEL_USER" \
    --data-urlencode "password=$PANEL_PASS" \
    "$PANEL_URL/login" || true)"
if ! echo "$login_resp" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "[!] Login failed. Check URL/base-path and credentials."
    echo "    Response: $login_resp"
    exit 1
fi
echo "[+] Logged in."

# --- 2) Generate keypair + register WARP ------------------------------------
kp="$($XRAY_BIN x25519)"
priv="$(echo "$kp" | awk -F': ' '/PrivateKey/{print $2}' | tr -d '[:space:]')"
pub="$(echo  "$kp" | awk -F': ' '/Password|PublicKey/{print $2}' | tr -d '[:space:]')"
[[ -z "$priv" || -z "$pub" ]] && { echo "[!] Key generation failed."; exit 1; }

echo "[*] Registering WARP identity with Cloudflare (via panel)..."
reg="$(curl -fsS -b "$CJ" -k \
    --data-urlencode "privateKey=$priv" \
    --data-urlencode "publicKey=$pub" \
    "$PANEL_URL/panel/api/xray/warp/reg" || true)"
if ! echo "$reg" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "[!] WARP registration failed. Response: $reg"
    exit 1
fi
echo "[+] WARP registered."

# The .obj is a JSON string containing {data, config}.
obj="$(echo "$reg" | jq -r '.obj')"
data="$(echo "$obj" | jq '.data')"
cfg="$(echo  "$obj" | jq '.config')"

secretKey="$(echo "$data" | jq -r '.private_key')"
clientId="$(echo "$data" | jq -r '.client_id // empty')"
peerPub="$(echo "$cfg" | jq -r '.config.peers[0].public_key')"
endpoint="$(echo "$cfg" | jq -r '.config.peers[0].endpoint.host // "engage.cloudflareclient.com:2408"')"
v4="$(echo "$cfg" | jq -r '.config.interface.addresses.v4 // "172.16.0.2"')"
v6="$(echo "$cfg" | jq -r '.config.interface.addresses.v6 // empty')"

# reserved[] is derived from the base64 client_id (3 bytes).
reserved="[]"
if [[ -n "$clientId" ]]; then
    reserved="$(printf '%s' "$clientId" | base64 -d 2>/dev/null | od -An -tu1 | tr -s ' ' '\n' \
        | grep -E '^[0-9]+$' | head -3 | paste -sd, - | sed 's/^/[/; s/$/]/')"
    [[ -z "$reserved" || "$reserved" == "[]" ]] && reserved="[]"
fi

addr="[\"${v4}/32\"$([[ -n "$v6" ]] && echo ",\"${v6}/128\"")]"

OUTBOUND="$(jq -n \
    --arg sk "$secretKey" --arg pk "$peerPub" --arg ep "$endpoint" \
    --argjson addr "$addr" --argjson res "$reserved" '
{
  tag: "warp",
  protocol: "wireguard",
  settings: {
    mtu: 1420,
    secretKey: $sk,
    address: $addr,
    reserved: $res,
    domainStrategy: "ForceIPv4v6",
    peers: [{ publicKey: $pk, endpoint: $ep }],
    noKernelTun: true
  }
}')"

RULE="$(jq -n --argjson gs "$GEOSITES_DEFAULT" '
{ type: "field", domain: $gs, outboundTag: "warp" }')"

echo
echo "================ WARP outbound (tag: warp) ================"
echo "$OUTBOUND"
echo
echo "================ Selective routing rule ==================="
echo "$RULE"
echo "==========================================================="
echo

if [[ "$APPLY" != "y" ]]; then
    echo "[i] Print-only mode. Paste the outbound into Xray → Outbounds and the rule"
    echo "    into Xray → Routing, then Save. Re-run with --apply to attempt an"
    echo "    automatic merge. (Recommended: paste manually — it's one paste.)"
    exit 0
fi

# --- 3) Optional best-effort auto-merge into the live Xray config ------------
echo "[*] --apply: fetching current Xray config..."
xray_resp="$(curl -fsS -b "$CJ" -k -X POST "$PANEL_URL/panel/api/xray/" || true)"
# getXraySetting returns the config under .obj (string or object depending on
# release). Normalise to a JSON object; bail to manual paste if we can't.
xray_cfg="$(echo "$xray_resp" | jq -c '.obj.xraySetting // .obj // empty' 2>/dev/null || true)"
if [[ -z "$xray_cfg" || "$xray_cfg" == "null" ]]; then
    echo "[!] Could not read current Xray config in a known shape; paste manually."
    exit 1
fi
# If obj.xraySetting was itself a JSON string, decode one more level.
if echo "$xray_cfg" | jq -e 'type == "string"' >/dev/null 2>&1; then
    xray_cfg="$(echo "$xray_cfg" | jq -r '.')"
fi

merged="$(echo "$xray_cfg" | jq \
    --argjson ob "$OUTBOUND" --argjson rule "$RULE" '
    .outbounds = ((.outbounds // []) | map(select(.tag != "warp")) + [$ob])
    | .routing = (.routing // {})
    | .routing.rules = ((.routing.rules // []) | map(select(.outboundTag != "warp")) + [$rule])
')"

echo "[*] Saving merged Xray config..."
save="$(curl -fsS -b "$CJ" -k \
    --data-urlencode "xraySetting=$merged" \
    "$PANEL_URL/panel/api/xray/update" || true)"
if echo "$save" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "[+] WARP outbound + selective rule applied. Verify in the panel and"
    echo "    restart Xray if it didn't auto-reload."
else
    echo "[!] Auto-merge save failed; paste the JSON above manually instead."
    echo "    Response: $save"
    exit 1
fi
