#!/bin/bash
##########################################################################
#  Netch VPN / NovaNetchX Installer  v1.2.4
#  Developer  : ShanuFX  (github.com/ShanudhaTirosh)
#  Company    : Netch Solutions  (netchsolutions.com)
#  Repository : github.com/ShanudhaTirosh/netch-vpn
#  ----------
#  Credits    : x-ui-pro by GFW4Fun (github.com/GFW4Fun/x-ui-pro)
#               3x-ui Panel by MHSanaei (github.com/MHSanaei/3x-ui)
#               sub2sing-box by legiz-ru (github.com/legiz-ru/sub2sing-box)
##########################################################################
#  CHANGELOG  (v1.1.0 -> v1.2.4)
#  ----------
#  [v1.2.4]    Theme + rebrand now also applied to the REALITY-domain panel
#              vhost (:9443) — it previously served the stock UI and proxied the
#              panel over http (panel is https); now https + sub_filter injection.
#  [v1.2.3]    Theme polish: glass-themed modals/drawers/popups, navy tables,
#              themed select/date dropdowns; footer GitHub/version link repointed
#              to the Netch repo; donation/sponsor heart icon removed.
#  [v1.2.2]    Panel UI theme now applies to the STOCK prebuilt 3x-ui without a
#              source rebuild: a brand glassmorphism stylesheet (netch-theme.css)
#              is injected into the SPA via the same Nginx sub_filter as the
#              favicon (navy glass surfaces + teal AntD primary via CSS vars).
#  [v1.2.1]    Fix: core deps (certbot/nginx/sqlite3/fuser) are now installed
#              UNCONDITIONALLY with a hard preflight, instead of only under
#              "-install y" — fixes "certbot: command not found" on plain runs.
#              Start banner version corrected to match.
#  [SECURITY]  Panel credentials are now randomized per install (was the
#              hard-coded Shanu/admin). They are printed once in the final
#              "Panel Access" summary and never again.
#  [IP-ATTR]   Consistent real-client-IP / sockopt across all 5 inbounds,
#              per docs/real-client-ip.md:
#                - REALITY + VLESS-TLS (behind nginx stream proxy_protocol):
#                  acceptProxyProtocol=true (kept) + BBR sockopt block.
#                - WS + XHTTP (behind nginx HTTP hop): sockopt.
#                  trustedXForwardedFor=["X-Forwarded-For"] to match the
#                  header nginx actually sets (X-Forwarded-For).
#                - Trojan-gRPC: gRPC supports only acceptProxyProtocol for
#                  real-IP, and nginx grpc_pass cannot emit PROXY protocol on
#                  this hop, so accurate per-client IP is NOT recoverable here
#                  (documented limitation). BBR sockopt added for throughput.
#  [SOCKOPT]   tcpFastOpen / tcpcongestion=bbr / tcpMptcp extended from
#              XHTTP-only to every TCP-based inbound.
#  [SEEDING]   Raw sqlite3 seeding retained (works pre-first-boot) but now
#              gated by a PRAGMA table_info preflight that fails loudly if the
#              inbounds/settings schema drifts from what this script expects.
#  [SUBPAGE]   Migrated the subscription page to the native 3x-ui Go
#              html/template engine via the subThemeDir setting
#              (/etc/x-ui/sub_templates/netch-glass). Glassmorphism theme.
#  [BRAND]     Favicon now ships the real NovaNetchX navy/teal brand asset
#              (repo assets/favicon.svg+.ico fetched first; brand-accurate
#              navy/teal inline SVG fallback) instead of the purple placeholder.
#  [PERF]      Nginx keepalive tuning for long-lived proxy connections;
#              sysctl somaxconn / tcp_max_syn_backlog sized for ~hundreds of
#              concurrent clients. HTTP/3 evaluated (see notes, not enabled).
#  [WARP]      Selective Cloudflare WARP routing documented as a one-click
#              post-install step (see warp summary block + scripts/warp.md).
##########################################################################

[[ $EUID -ne 0 ]] && echo "Run as root!" && sudo su -

############################### BRAND OUTPUT ####################################################
msg_ok()   { echo -e "\e[1;42m $1 \e[0m"; }
msg_err()  { echo -e "\e[1;41m $1 \e[0m"; }
msg_inf()  { echo -e "\e[1;35m$1\e[0m"; }    # Purple  — ShanuFX primary
msg_cyan() { echo -e "\e[1;36m$1\e[0m"; }    # Cyan    — Netch accent

clear; echo
msg_inf  '   _____ _                       ___________  __  '
msg_inf  '  / ____| |                     |  ___|  __ \\ \\ \\ '
msg_inf  ' | (___ | |__   __ _ _ __  _   _| |_  | |  \\/ /\\ \\ '
msg_inf  '  \\___ \\|  _ \\ / _` | \`_ \\| | | |  _| |  \\\\ / /\\ \\'
msg_inf  '  ____) | | | | (_| | | | | |_| | |   | |__/ / / /'
msg_inf  ' |_____/|_| |_|\\__,_|_| |_|\\__,_|_|   |_____/_/_/ '
echo
msg_cyan ' ┌──────────────────────────────────────────────────────────┐'
msg_cyan ' │   ShanuFX VPN Installer  v1.2.4                         │'
msg_cyan ' │   Powered by Netch Solutions  ·  netchsolutions.com      │'
msg_cyan ' │   github.com/ShanudhaTirosh/netch-vpn                          │'
msg_cyan ' └──────────────────────────────────────────────────────────┘'
echo

############################### BRANDING ASSET URLS #############################################
# TODO: Fork the assets listed below into your own GitHub repo and update these URLs.
#       Originals are from GFW4Fun/x-ui-pro and legiz-ru/x-ui-pro.
GITHUB_REPO="https://github.com/ShanudhaTirosh/netch-vpn"
GITHUB_RAW="https://raw.githubusercontent.com/ShanudhaTirosh/netch-vpn/main"

# Fake camouflage site generator (fork randomfakehtml.sh into your repo)
FAKE_SITE_SCRIPT="${GITHUB_RAW}/assets/randomfakehtml.sh"

# Subscription web page templates
URL_SUB_PAGE=(
    "${GITHUB_REPO}/raw/main/assets/sub-page.html"
    "${GITHUB_REPO}/raw/main/assets/sub-page-classic.html"
)

# Clash YAML templates
URL_CLASH_SUB=(
    "${GITHUB_REPO}/raw/main/assets/clash/clash.yaml"
    "${GITHUB_REPO}/raw/main/assets/clash/clash_skrepysh.yaml"
    "${GITHUB_REPO}/raw/main/assets/clash/clash_fullproxy_without_ru.yaml"
    "${GITHUB_REPO}/raw/main/assets/clash/clash_refilter_ech.yaml"
)

############################### DOMAIN CONFIGURATION ############################################
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  SET THESE TWO BEFORE RUNNING THE SCRIPT                                ║
# ║  Both domains must have valid A records pointing to this server's IP.   ║
# ╠══════════════════════════════════════════════════════════════════════════╣
PANEL_DOMAIN=""       # e.g.  vpn.yourdomain.com   — panel, subscriptions, WS, XHTTP
REALITY_DOMAIN=""     # e.g.  r.yourdomain.com     — REALITY inbound domain
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║  VLESS+TCP+TLS inbound — DPI camouflage SNI                             ║
# ║  Nginx routes port-443 traffic whose ClientHello matches this SNI       ║
# ║  to the VLESS+TLS inbound. Using a trusted Microsoft domain makes       ║
# ║  the traffic look like a legit HTTPS connection to that service.        ║
# ║  Change to any SNI you prefer (e.g. www.microsoft.com, dl.google.com). ║
VLESS_TLS_SNI="aka.ms"
# ╚══════════════════════════════════════════════════════════════════════════╝

############################### VARIABLES #######################################################
XUIDB="/etc/x-ui/x-ui.db"; domain=""; UNINSTALL="x"; INSTALL="n"; PNLNUM=1
CFALLOW="n"; CLASH=0; CUSTOMWEBSUB=0
Pak=$(type apt &>/dev/null && echo "apt" || echo "yum")
systemctl stop x-ui
rm -rf /etc/systemd/system/x-ui.service
rm -rf /usr/local/x-ui
rm -rf /etc/x-ui
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/*
rm -rf /etc/nginx/stream-enabled/*

############################### PORT / PATH GENERATORS ##########################################
get_port() {
    echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
}

gen_random_string() {
    local length="$1"
    head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
    echo
}

check_free() {
    local port=$1
    # Returns 0 when the port is IN USE, non-zero when free (make_port relies on
    # this inverted sense). Prefer ss (always present via iproute2); fall back to
    # nc; if neither exists, assume free rather than loop forever.
    if command -v ss &>/dev/null; then
        ss -ltnuH 2>/dev/null | awk '{print $5}' | grep -qE "[:.]${port}$" && return 0
        return 1
    elif command -v nc &>/dev/null; then
        nc -z 127.0.0.1 "$port" &>/dev/null
        return $?
    else
        return 1
    fi
}

make_port() {
    while true; do
        PORT=$(get_port)
        if ! check_free $PORT; then
            echo $PORT
            break
        fi
    done
}

sub_port=$(make_port)
panel_port=9999                          # Fixed panel port
vless_tls_port=$(make_port)              # Auto — VLESS+TLS inbound (exposed as 443 via SNI)
ws_port=$(make_port)
trojan_port=$(make_port)
web_path=$(gen_random_string 10)
sub2singbox_path=$(gen_random_string 10)
sub_path=$(gen_random_string 10)
json_path=$(gen_random_string 10)
panel_path="NovaNetchX"                  # Fixed panel base path
ws_path=$(gen_random_string 10)
trojan_path=$(gen_random_string 10)
xhttp_path=$(gen_random_string 10)
# Panel credentials are randomized per install (same pattern as sub_port/web_path).
# They are printed ONCE in the final "Panel Access" summary and never stored elsewhere.
config_username=$(gen_random_string 8)   # Random panel username
config_password=$(gen_random_string 20)  # Random panel password
AUTODOMAIN="n"

############################### ARGUMENT PARSING ################################################
while [ "$#" -gt 0 ]; do
  case "$1" in
    -auto_domain)      AUTODOMAIN="$2";        shift 2;;
    -install)          INSTALL="$2";           shift 2;;
    -panel)            PNLNUM="$2";            shift 2;;
    -subdomain)        domain="$2";            shift 2;;
    -reality_domain)   reality_domain="$2";    shift 2;;
    -ONLY_CF_IP_ALLOW) CFALLOW="$2";           shift 2;;
    -websub)           CUSTOMWEBSUB="$2";      shift 2;;
    -clash)            CLASH="$2";             shift 2;;
    -uninstall)        UNINSTALL="$2";         shift 2;;
    *)                 shift 1;;
  esac
done

############################### UNINSTALL #######################################################
UNINSTALL_XUI(){
    printf 'y\n' | x-ui uninstall
    rm -rf "/etc/x-ui/" "/usr/local/x-ui/" "/usr/bin/x-ui/"
    $Pak -y remove nginx nginx-common nginx-core nginx-full python3-certbot-nginx
    $Pak -y purge nginx nginx-common nginx-core nginx-full python3-certbot-nginx
    $Pak -y autoremove
    $Pak -y autoclean
    rm -rf "/var/www/html/" "/etc/nginx/" "/usr/share/nginx/"
}
if [[ ${UNINSTALL} == *"y"* ]]; then
    UNINSTALL_XUI
    clear && msg_ok "ShanuFX VPN — Completely Uninstalled!" && exit 1
fi

# --- Get public IPv4 early (needed for auto-domain mode)
IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*')
[[ $IP4 =~ $IP4_REGEX ]] || IP4=$(curl -s ipv4.icanhazip.com | tr -d '[:space:]')

if [[ ${AUTODOMAIN} == *"y"* ]]; then
    # -----------------------------------------------------------------------
    # NOTE: Replace cdn-one.org below with your own wildcard DNS service.
    # The wildcard must resolve *.yourdomain.tld → this server's public IP.
    # Example providers: DuckDNS (free), your own NS with a wildcard A record.
    # -----------------------------------------------------------------------
    domain="${IP4}.cdn-one.org"
    reality_domain="${IP4//./-}.cdn-one.org"
fi

############################### DOMAIN VALIDATION ###############################################
# Use the top-of-file placeholders if they were filled in
[[ -n "$PANEL_DOMAIN"   ]] && domain="$PANEL_DOMAIN"
[[ -n "$REALITY_DOMAIN" ]] && reality_domain="$REALITY_DOMAIN"

while true; do
    if [[ -n "$domain" ]]; then break; fi
    echo -en "Enter panel subdomain (sub.domain.tld): " && read domain
done

domain=$(echo "$domain" 2>&1 | tr -d '[:space:]')
SubDomain=$(echo "$domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
MainDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')
if [[ "${SubDomain}.${MainDomain}" != "${domain}" ]]; then
    MainDomain=${domain}
fi

while true; do
    if [[ -n "$reality_domain" ]]; then break; fi
    echo -en "Enter subdomain for REALITY (sub.domain.tld): " && read reality_domain
done

reality_domain=$(echo "$reality_domain" 2>&1 | tr -d '[:space:]')
RealitySubDomain=$(echo "$reality_domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
RealityMainDomain=$(echo "$reality_domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')
if [[ "${RealitySubDomain}.${RealityMainDomain}" != "${reality_domain}" ]]; then
    RealityMainDomain=${reality_domain}
fi

############################### INSTALL PACKAGES ################################################
ufw disable

# Core dependencies are ALWAYS ensured here (idempotent), regardless of the
# -install flag. The rest of the script uses certbot/nginx/sqlite3/fuser
# unconditionally, so gating their install behind "-install y" previously caused
# "certbot: command not found" (and similar) when run without that flag.
version=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release 2>/dev/null)
msg_inf "Detected OS version: ${version:-unknown} — ensuring dependencies..."
export DEBIAN_FRONTEND=noninteractive
$Pak -y update
$Pak -y install curl wget jq bash sudo nginx-full certbot python3-certbot-nginx \
                sqlite3 ufw netcat-openbsd psmisc openssl ca-certificates
systemctl daemon-reload
systemctl enable --now nginx 2>/dev/null || true

# Hard preflight: fail early with a clear message if a required tool is still
# missing (e.g. certbot absent from the distro repos) instead of dying deep in
# SSL issuance.
_missing=""
for _bin in certbot nginx sqlite3 jq curl wget openssl fuser; do
    command -v "$_bin" >/dev/null 2>&1 || _missing="$_missing $_bin"
done
if [[ -n "$_missing" ]]; then
    msg_err "Missing required tool(s):$_missing"
    msg_err "Auto-install failed. Install them manually and re-run, e.g.:"
    msg_err "  apt-get update && apt-get install -y nginx-full certbot python3-certbot-nginx sqlite3 jq curl wget openssl psmisc"
    exit 1
fi

systemctl stop nginx 2>/dev/null
fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null

############################### SERVER IP DETECTION #############################################
IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
IP6_REGEX="([a-f0-9:]+:+)+[a-f0-9]+"
IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*')
IP6=$(ip route get 2620:fe::fe 2>&1 | grep -Po -- 'src \K\S*')
[[ $IP4 =~ $IP4_REGEX ]] || IP4=$(curl -s ipv4.icanhazip.com)
[[ $IP6 =~ $IP6_REGEX ]] || IP6=$(curl -s ipv6.icanhazip.com)

############################### SSL CERTIFICATES ################################################
resolve_to_ip() {
    local host="$1"
    local a
    a=$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}')
    [[ -n "$a" ]] && [[ "$a" == "$IP4" ]]
}

if [[ ${AUTODOMAIN} == *"y"* ]]; then
    if ! resolve_to_ip "$domain"; then
        msg_err "Auto-domain $domain does not resolve to this server ($IP4). Fix DNS and retry."
        exit 1
    fi
    if ! resolve_to_ip "$reality_domain"; then
        msg_err "Auto-domain $reality_domain does not resolve to this server ($IP4). Fix DNS and retry."
        exit 1
    fi
fi

certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$domain"
if [[ ! -d "/etc/letsencrypt/live/${domain}/" ]]; then
    systemctl start nginx >/dev/null 2>&1
    msg_err "SSL for $domain could not be generated! Check domain/IP and retry." && exit 1
fi

certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$reality_domain"
if [[ ! -d "/etc/letsencrypt/live/${reality_domain}/" ]]; then
    systemctl start nginx >/dev/null 2>&1
    msg_err "SSL for $reality_domain could not be generated! Check domain/IP and retry." && exit 1
fi

############################### RESTORE EXISTING XUI PORT/PATH #################################
if [[ -f $XUIDB ]]; then
    XUIPORT=$(sqlite3 -list $XUIDB 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>&1)
    XUIPATH=$(sqlite3 -list $XUIDB 'SELECT "value" FROM settings WHERE "key"="webBasePath" LIMIT 1;' 2>&1)
    if [[ $XUIPORT -gt 0 && $XUIPORT != "54321" && $XUIPORT != "2053" ]] && [[ ${#XUIPORT} -gt 4 ]]; then
        RNDSTR=$(echo "$XUIPATH" 2>&1 | tr -d '/')
        PORT=$XUIPORT
        sqlite3 $XUIDB <<EOF
DELETE FROM "settings" WHERE ( "key"="webCertFile" ) OR ( "key"="webKeyFile" );
INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  "");
INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile", "");
EOF
    fi
fi

############################### NGINX CONFIGURATION #############################################
mkdir -p /root/cert/${domain}
chmod 755 /root/cert/*

ln -s /etc/letsencrypt/live/${domain}/fullchain.pem /root/cert/${domain}/fullchain.pem
ln -s /etc/letsencrypt/live/${domain}/privkey.pem   /root/cert/${domain}/privkey.pem

mkdir -p /etc/nginx/stream-enabled

cat > "/etc/nginx/stream-enabled/stream.conf" << EOF
# SNI routing — port 443 traffic is dispatched based on TLS ClientHello server name.
# No TLS termination here; each upstream handles its own TLS.
map \$ssl_preread_server_name \$sni_name {
    hostnames;
    ${reality_domain}    xray;       # VLESS+REALITY  → Xray port 8443
    ${VLESS_TLS_SNI}     vless_tls;  # VLESS+TLS      → Xray port ${vless_tls_port}
    ${domain}            www;        # Panel + subs   → Nginx port 7443
    default              xray;       # Fallback       → REALITY inbound
}

upstream xray      { server 127.0.0.1:8443; }
upstream www       { server 127.0.0.1:7443; }
upstream vless_tls { server 127.0.0.1:${vless_tls_port}; }

server {
    proxy_protocol on;
    set_real_ip_from unix:;
    listen     443;
    listen     [::]:443;
    proxy_pass \$sni_name;
    ssl_preread on;
}
EOF

grep -xqFR "stream { include /etc/nginx/stream-enabled/*.conf; }" /etc/nginx/* || \
    echo "stream { include /etc/nginx/stream-enabled/*.conf; }" >> /etc/nginx/nginx.conf
grep -xqFR "load_module modules/ngx_stream_module.so;" /etc/nginx/* || \
    sed -i '1s/^/load_module \/usr\/lib\/nginx\/modules\/ngx_stream_module.so; /' /etc/nginx/nginx.conf
grep -xqFR "load_module modules/ngx_stream_geoip2_module.so;" /etc/nginx* || \
    sed -i '2s/^/load_module \/usr\/lib\/nginx\/modules\/ngx_stream_geoip2_module.so; /' /etc/nginx/nginx.conf
grep -xqFR "worker_rlimit_nofile 16384;" /etc/nginx/* || \
    echo "worker_rlimit_nofile 16384;" >> /etc/nginx/nginx.conf
sed -i "/worker_connections/c\worker_connections 4096;" /etc/nginx/nginx.conf

cat > "/etc/nginx/sites-available/80.conf" << EOF
server {
    listen 80;
    server_name ${domain} ${reality_domain};
    return 301 https://\$host\$request_uri;
}
EOF

cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
	server_tokens off;
	server_name ${domain};
	listen 7443 ssl http2 proxy_protocol;
	listen [::]:7443 ssl http2 proxy_protocol;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

	# Real client IP recovery (Step 1b): the :443 stream server sends the
	# original client address in a PROXY-protocol header. Map it onto
	# \$remote_addr so \$proxy_add_x_forwarded_for (and the X-Forwarded-For
	# header passed to the WS/XHTTP Xray inbounds) carries the true visitor IP
	# instead of 127.0.0.1. Pairs with sockopt.trustedXForwardedFor on those
	# inbounds. See docs/real-client-ip.md.
	set_real_ip_from 127.0.0.1;
	set_real_ip_from ::1;
	real_ip_header proxy_protocol;

	# Long-lived proxy connections (Step 5a): VPN/proxy traffic holds sockets
	# open far longer than typical short HTTP requests, so raise keepalive well
	# above nginx's 75s/100-request HTTP defaults to avoid premature teardown.
	keepalive_timeout 300s;
	keepalive_requests 10000;

	if (\$host !~* ^(.+\.)?$domain\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?$domain\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;

	# NovaNetchX — Admin Panel (with favicon injection)
	location /${panel_path}/ {
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Upgrade websocket;
		proxy_set_header Connection Upgrade;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Accept-Encoding "";
		proxy_read_timeout 3600s;
		proxy_send_timeout 3600s;
		proxy_pass https://127.0.0.1:${panel_port};
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="shortcut icon" type="image/x-icon" href="/favicon.ico"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	location /${panel_path} {
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Upgrade websocket;
		proxy_set_header Connection Upgrade;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Accept-Encoding "";
		proxy_read_timeout 3600s;
		proxy_send_timeout 3600s;
		proxy_pass https://127.0.0.1:${panel_port};
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="shortcut icon" type="image/x-icon" href="/favicon.ico"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	# NovaNetchX favicons
	location = /favicon.ico {
		root /var/www/html;
		expires 30d;
		access_log off;
		add_header Cache-Control "public, immutable";
	}
	location = /favicon.svg {
		root /var/www/html;
		expires 30d;
		access_log off;
		add_header Cache-Control "public, immutable";
		add_header Content-Type "image/svg+xml";
	}
	include /etc/nginx/snippets/includes.conf;
}
EOF

cat > "/etc/nginx/snippets/includes.conf" << EOF
	# sub2sing-box proxy
	location /${sub2singbox_path}/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:8080/;
	}

	# Clash YAML / web subscription page
	location ~ ^/${web_path}/clashmeta/(.+)\$ {
		default_type text/plain;
		ssi on;
		ssi_types text/plain;
		set \$subid \$1;
		root /var/www/subpage;
		try_files /clash.yaml =404;
	}
	location ~ ^/${web_path} {
		root /var/www/subpage;
		index index.html;
		try_files \$uri \$uri/ /index.html =404;
	}

	# Subscription path (simple/encoded)
	location /${sub_path} {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}
	location /${sub_path}/ {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}
	location /assets/ {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}
	location /assets {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}

	# Subscription path (JSON/fragment)
	location /${json_path} {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}
	location /${json_path}/ {
		if (\$hack = 1) {return 404;}
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${sub_port};
		break;
	}

	# XHTTP (gRPC over Unix socket)
	location /${xhttp_path} {
		grpc_pass grpc://unix:/dev/shm/uds2023.sock;
		grpc_buffer_size        16k;
		grpc_socket_keepalive   on;
		grpc_read_timeout       1h;
		grpc_send_timeout       1h;
		grpc_set_header Connection         "";
		grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
		grpc_set_header X-Forwarded-Proto  \$scheme;
		grpc_set_header X-Forwarded-Port   \$server_port;
		grpc_set_header Host               \$host;
		grpc_set_header X-Forwarded-Host   \$host;
	}

	# Xray dynamic port routing
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
		if (\$hack = 1) {return 404;}
		client_max_body_size 0;
		client_body_timeout 1d;
		grpc_read_timeout 1d;
		grpc_socket_keepalive on;
		proxy_read_timeout 1d;
		proxy_http_version 1.1;
		proxy_buffering off;
		proxy_request_buffering off;
		proxy_socket_keepalive on;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		if (\$content_type ~* "GRPC") {
			grpc_pass grpc://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
		if (\$http_upgrade ~* "(WEBSOCKET|WS)") {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
		if (\$request_method ~* ^(PUT|POST|GET)\$) {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
	}
	location / { try_files \$uri \$uri/ =404; }
EOF

cat > "/etc/nginx/sites-available/${reality_domain}" << EOF
server {
	server_tokens off;
	server_name ${reality_domain};
	listen 9443 ssl http2;
	listen [::]:9443 ssl http2;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$reality_domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$reality_domain/privkey.pem;
	if (\$host !~* ^(.+\.)?${reality_domain}\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?${reality_domain}\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;

	# SX-UI Admin Panel (Reality domain) — themed + rebranded, same as main vhost
	location /${panel_path}/ {
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Accept-Encoding "";
		proxy_read_timeout 3600s;
		proxy_send_timeout 3600s;
		proxy_pass https://127.0.0.1:${panel_port};
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="shortcut icon" type="image/x-icon" href="/favicon.ico"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	location /$panel_path {
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Accept-Encoding "";
		proxy_read_timeout 3600s;
		proxy_send_timeout 3600s;
		proxy_pass https://127.0.0.1:${panel_port};
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="shortcut icon" type="image/x-icon" href="/favicon.ico"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	include /etc/nginx/snippets/includes.conf;
}
EOF

############################### NGINX SYMLINKS + VERIFY #########################################
if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
    unlink "/etc/nginx/sites-enabled/default" >/dev/null 2>&1
    rm -f  "/etc/nginx/sites-enabled/default" "/etc/nginx/sites-available/default"
    ln -s "/etc/nginx/sites-available/${domain}"         "/etc/nginx/sites-enabled/" 2>/dev/null
    ln -s "/etc/nginx/sites-available/${reality_domain}" "/etc/nginx/sites-enabled/" 2>/dev/null
    ln -s "/etc/nginx/sites-available/80.conf"           "/etc/nginx/sites-enabled/" 2>/dev/null
else
    msg_err "Nginx config for ${domain} not found!" && exit 1
fi

if [[ $(nginx -t 2>&1 | grep -o 'successful') != "successful" ]]; then
    msg_err "Nginx config test failed! Check errors above." && exit 1
else
    systemctl start nginx
fi

############################### URI GENERATION ##################################################
sub_uri="https://${domain}/${sub_path}/"
json_uri="https://${domain}/${web_path}?name="

############################### XRAY KEY PAIR ###################################################
shor=($(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) \
      $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8))

############################### DB SCHEMA PREFLIGHT (Step 1c) ###################################
# Raw sqlite3 seeding is fast and works before the panel's first authenticated
# boot, but it is brittle if upstream renames/drops a column. This guard reads
# the live schema with PRAGMA table_info and aborts LOUDLY if any column the
# seeding relies on is missing, instead of letting the INSERTs corrupt state.
CHECK_DB_SCHEMA(){
    local db="$1"
    local missing=""
    if [[ ! -f "$db" ]]; then
        msg_err "Schema check: $db not found." && exit 1
    fi
    # Columns the inbound INSERTs depend on (snake_case, per the GORM model).
    local inbound_cols="user_id up down total remark enable expiry_time listen port protocol settings stream_settings tag sniffing"
    local have_inbound
    have_inbound=$(sqlite3 "$db" "PRAGMA table_info('inbounds');" 2>/dev/null | awk -F'|' '{print $2}')
    if [[ -z "$have_inbound" ]]; then
        msg_err "Schema check: 'inbounds' table not found — incompatible/empty x-ui.db." && exit 1
    fi
    local c
    for c in $inbound_cols; do
        echo "$have_inbound" | grep -qx "$c" || missing="$missing inbounds.$c"
    done
    # The settings table is a generic key/value store; just confirm its shape.
    local have_settings
    have_settings=$(sqlite3 "$db" "PRAGMA table_info('settings');" 2>/dev/null | awk -F'|' '{print $2}')
    echo "$have_settings" | grep -qx "key"   || missing="$missing settings.key"
    echo "$have_settings" | grep -qx "value" || missing="$missing settings.value"

    if [[ -n "$missing" ]]; then
        msg_err "DB schema drift detected — missing columns:$missing"
        msg_err "This 3x-ui release changed the schema this installer seeds against."
        msg_err "Refusing to INSERT to avoid corrupting the database. Update the"
        msg_err "installer's seeding block to match the new schema, then re-run."
        exit 1
    fi
    msg_ok "DB schema preflight passed (inbounds/settings columns match)."
}

############################### UPDATE X-UI DATABASE ############################################
UPDATE_XUIDB(){
if [[ -f $XUIDB ]]; then
    x-ui stop
    CHECK_DB_SCHEMA "$XUIDB"
    output=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519)
    private_key=$(echo "$output" | grep "^PrivateKey:" | awk '{print $2}')
    public_key=$(echo "$output"  | grep "^Password"   | awk '{print $3}')

    trojan_pass=$(gen_random_string 10)
    emoji_flag=$(LC_ALL=en_US.UTF-8 curl -s https://ipwho.is/ | jq -r '.flag.emoji')

    sqlite3 $XUIDB <<EOF
         INSERT INTO "settings" ("key", "value") VALUES ("subPort",  '${sub_port}');
         INSERT INTO "settings" ("key", "value") VALUES ("subPath",  '/${sub_path}/');
         INSERT INTO "settings" ("key", "value") VALUES ("subURI",   '${sub_uri}');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",  '/${json_path}');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",   '${json_uri}');
         INSERT INTO "settings" ("key", "value") VALUES ("subClashEnable",   'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subEnableRouting", 'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subEnable",        'true');
         INSERT INTO "settings" ("key", "value") VALUES ("webListen",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("webDomain",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",      '');
         INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",    '60');
         INSERT INTO "settings" ("key", "value") VALUES ("pageSize",         '50');
         INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",       '0');
         INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",      '0');
         INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",      '-ieo');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",      'false');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",   '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",      '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",        '@daily');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",      'false');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify", 'true');
         INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",            '80');
         INSERT INTO "settings" ("key", "value") VALUES ("tgLang",           'en-US');
         INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",     'Asia/Colombo');
         INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",     'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subDomain",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",      '');
         INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",       '12');
         INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",       'true');
         INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",      'true');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",  '');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",    '');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",     '');
         INSERT INTO "settings" ("key", "value") VALUES ("datepicker",       'gregorian');
         INSERT INTO "settings" ("key", "value") VALUES ("subThemeDir",      '/etc/x-ui/sub_templates/netch-glass');
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             '${emoji_flag} reality','1','0','','8443','vless',
             '{
  "clients": [],
  "decryption": "none",
  "fallbacks": []
}',
             '{
  "network": "tcp",
  "security": "reality",
  "externalProxy": [
    {"forceTls": "same","dest": "${domain}","port": 443,"remark": ""}
  ],
  "realitySettings": {
    "show": false,
    "xver": 0,
    "target": "127.0.0.1:9443",
    "serverNames": ["$reality_domain"],
    "privateKey": "${private_key}",
    "minClient": "","maxClient": "","maxTimediff": 0,
    "shortIds": [
      "${shor[0]}","${shor[1]}","${shor[2]}","${shor[3]}",
      "${shor[4]}","${shor[5]}","${shor[6]}","${shor[7]}"
    ],
    "settings": {
      "publicKey": "${public_key}",
      "fingerprint": "chrome",
      "serverName": "",
      "spiderX": "/"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": true,
    "header": {"type": "none"}
  },
  "sockopt": {
    "acceptProxyProtocol": true,
    "tcpFastOpen": true,
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "tcpcongestion": "bbr"
  }
}',
             'inbound-8443',
             '{"enabled": false,"destOverride": ["http","tls","quic","fakedns"],"metadataOnly": false,"routeOnly": false}'
         );

         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             '${emoji_flag} ws','1','0','','${ws_port}','vless',
             '{"clients": [],"decryption": "none","fallbacks": []}',
             '{
  "network": "ws",
  "security": "none",
  "externalProxy": [
    {"forceTls": "tls","dest": "${domain}","port": 443,"remark": ""}
  ],
  "wsSettings": {
    "acceptProxyProtocol": false,
    "path": "/${ws_port}/${ws_path}",
    "host": "${domain}",
    "headers": {}
  },
  "sockopt": {
    "trustedXForwardedFor": ["X-Forwarded-For"],
    "tcpFastOpen": true,
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "tcpcongestion": "bbr"
  }
}',
             'inbound-${ws_port}',
             '{"enabled": false,"destOverride": ["http","tls","quic","fakedns"],"metadataOnly": false,"routeOnly": false}'
         );

         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             '${emoji_flag} xhttp','0','0',
             '/dev/shm/uds2023.sock,0666','0','vless',
             '{"clients": [],"decryption": "none","fallbacks": []}',
             '{
  "network": "xhttp",
  "security": "none",
  "externalProxy": [
    {"forceTls": "tls","dest": "${domain}","port": 443,"remark": ""}
  ],
  "xhttpSettings": {
    "path": "/${xhttp_path}",
    "host": "${domain}",
    "headers": {},
    "scMaxBufferedPosts": 30,
    "scMaxEachPostBytes": "1000000",
    "noSSEHeader": false,
    "xPaddingBytes": "100-1000",
    "mode": "packet-up"
  },
  "sockopt": {
    "trustedXForwardedFor": ["X-Forwarded-For"],
    "acceptProxyProtocol": false,
    "tcpFastOpen": true,
    "mark": 0,
    "tproxy": "off",
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "domainStrategy": "UseIP",
    "tcpMaxSeg": 1440,
    "dialerProxy": "",
    "tcpKeepAliveInterval": 0,
    "tcpKeepAliveIdle": 300,
    "tcpUserTimeout": 10000,
    "tcpcongestion": "bbr",
    "V6Only": false,
    "tcpWindowClamp": 600,
    "interface": ""
  }
}',
             'inbound-/dev/shm/uds2023.sock,0666:0|',
             '{"enabled": true,"destOverride": ["http","tls","quic","fakedns"],"metadataOnly": false,"routeOnly": false}'
         );

         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             '${emoji_flag} trojan-grpc','1','0','','${trojan_port}','trojan',
             '{"clients": [],"fallbacks": []}',
             '{
  "network": "grpc",
  "security": "none",
  "externalProxy": [
    {"forceTls": "tls","dest": "${domain}","port": 443,"remark": ""}
  ],
  "grpcSettings": {
    "serviceName": "/${trojan_port}/${trojan_path}",
    "authority": "${domain}",
    "multiMode": false
  },
  "sockopt": {
    "acceptProxyProtocol": false,
    "tcpFastOpen": true,
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "tcpcongestion": "bbr"
  }
}',
             'inbound-${trojan_port}',
             '{"enabled": false,"destOverride": ["http","tls","quic","fakedns"],"metadataOnly": false,"routeOnly": false}'
         );

         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             '${emoji_flag} vless-tls-443','1','0','','${vless_tls_port}','vless',
             '{"clients": [],"decryption": "none","fallbacks": []}',
             '{
  "network": "tcp",
  "security": "tls",
  "externalProxy": [
    {
      "forceTls": "same",
      "dest": "${domain}",
      "port": 443,
      "remark": "SNI=${VLESS_TLS_SNI}"
    }
  ],
  "tlsSettings": {
    "serverName": "${domain}",
    "minVersion": "1.2",
    "certificates": [
      {
        "certificateFile": "/root/cert/${domain}/fullchain.pem",
        "keyFile": "/root/cert/${domain}/privkey.pem",
        "ocspStapling": 3600
      }
    ],
    "alpn": ["h2","http/1.1"],
    "settings": {
      "allowInsecure": false,
      "fingerprint": "chrome"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": true,
    "header": {"type": "none"}
  },
  "sockopt": {
    "acceptProxyProtocol": true,
    "tcpFastOpen": true,
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "tcpcongestion": "bbr"
  }
}',
             'inbound-${vless_tls_port}',
             '{"enabled": true,"destOverride": ["http","tls","quic","fakedns"],"metadataOnly": false,"routeOnly": false}'
         );
EOF
    /usr/local/x-ui/x-ui setting \
        -username "${config_username}" \
        -password "${config_password}" \
        -port "${panel_port}" \
        -webBasePath "${panel_path}"
    /usr/local/x-ui/x-ui cert \
        -webCert    "/root/cert/${domain}/fullchain.pem" \
        -webCertKey "/root/cert/${domain}/privkey.pem"
    x-ui start
else
    msg_err "x-ui.db not found! Ensure 3x-ui is installed before running this script." && exit 1
fi
}

############################### ARCHITECTURE HELPER #############################################
arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64)      echo 'amd64'  ;;
        i*86 | x86)                 echo '386'    ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64'  ;;
        armv7* | armv7 | arm)       echo 'armv7'  ;;
        armv6* | armv6)             echo 'armv6'  ;;
        armv5* | armv5)             echo 'armv5'  ;;
        s390x)                      echo 's390x'  ;;
        *) echo "Unsupported CPU architecture!" && rm -f install.sh && exit 1 ;;
    esac
}

############################### POST-INSTALL CONFIG (temp defaults) #############################
config_after_install() {
    # These temporary credentials are immediately overwritten by UPDATE_XUIDB with random values.
    /usr/local/x-ui/x-ui setting \
        -username "netchadmin" \
        -password "Netch@Setup1" \
        -port "2096" \
        -webBasePath "netchui"
    /usr/local/x-ui/x-ui migrate
}

############################### 3x-UI PANEL INSTALLER ##########################################
install_panel() {
    apt-get update && apt-get install -y -q wget curl tar tzdata
    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
            | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
                | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ ! -n "$tag_version" ]]; then
                msg_err "Failed to fetch 3x-ui version from GitHub API. Try again later." && exit 1
            fi
        fi
        msg_inf "Fetched 3x-ui ${tag_version} — starting installation..."
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz \
            "https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        [[ $? -ne 0 ]] && msg_err "Download failed — check server's GitHub connectivity." && exit 1
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"
        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            msg_err "Please use at least v2.3.5 of 3x-ui." && exit 1
        fi
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz \
            "https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        [[ $? -ne 0 ]] && msg_err "Download of 3x-ui $1 failed — check if that version exists." && exit 1
    fi

    wget -O /usr/bin/x-ui-temp https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    [[ $? -ne 0 ]] && msg_err "Failed to download x-ui.sh" && exit 1

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui x-ui.sh

    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)

    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui

    config_after_install

    cp -f x-ui.service.debian /etc/systemd/system/x-ui.service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo
    msg_ok "3x-ui ${tag_version} installed successfully!"
    echo
    msg_cyan "  x-ui control commands:"
    msg_cyan "  x-ui start | stop | restart | status | update | uninstall"
    echo
}

############################### MAIN: INSTALL OR RESTART ########################################
if systemctl is-active --quiet x-ui; then
    x-ui restart
else
    install_panel
    UPDATE_XUIDB
    if ! systemctl is-enabled --quiet x-ui; then
        systemctl daemon-reload && systemctl enable x-ui.service
    fi
    x-ui restart
fi

############################### KERNEL / BBR TUNING ############################################
apt-get install -yqq --no-install-recommends ca-certificates
echo "net.core.default_qdisc=fq"           | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr"  | tee -a /etc/sysctl.conf
echo "fs.file-max=2097152"                  | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_timestamps = 1"          | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_sack = 1"               | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling = 1"     | tee -a /etc/sysctl.conf
echo "net.core.rmem_max = 16777216"         | tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216"         | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 16777216" | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216" | tee -a /etc/sysctl.conf
# --- Concurrency headroom (Step 5c) -------------------------------------------
# Sized for a target of a few hundred concurrent client connections, not a
# generic "max everything" profile:
#   somaxconn (default 4096 on modern kernels, but 128 on older ones) is the
#   ceiling for the accept() backlog. Nginx (worker_connections 4096) and Xray
#   both accept() from this queue; 4096 comfortably absorbs connection bursts
#   from ~hundreds of clients reconnecting at once (e.g. after a server
#   restart) without overflowing. Going higher wastes memory with no benefit at
#   this scale.
#   tcp_max_syn_backlog bounds half-open (SYN_RECV) connections. 8192 covers a
#   reconnect storm with margin while staying small enough that SYN-flood
#   amplification stays bounded; syncookies (default on) handle anything beyond.
echo "net.core.somaxconn = 4096"            | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 8192"  | tee -a /etc/sysctl.conf
sysctl -p

############################### sub2sing-box ####################################################
# sub2sing-box converts x-ui subscriptions to sing-box / Clash format.
# Binary from: github.com/legiz-ru/sub2sing-box
if pgrep -x "sub2sing-box" > /dev/null; then
    pkill -x "sub2sing-box"
fi
rm -f /usr/bin/sub2sing-box
wget -P /root/ https://github.com/legiz-ru/sub2sing-box/releases/download/v0.0.9/sub2sing-box_0.0.9_linux_amd64.tar.gz
tar -xvzf /root/sub2sing-box_0.0.9_linux_amd64.tar.gz -C /root/ --strip-components=1 \
    sub2sing-box_0.0.9_linux_amd64/sub2sing-box
mv /root/sub2sing-box /usr/bin/
chmod +x /usr/bin/sub2sing-box
rm /root/sub2sing-box_0.0.9_linux_amd64.tar.gz
su -c "/usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 & disown" root

############################### CAMOUFLAGE SITE #################################################
# TODO: Host your own randomfakehtml.sh in your GitHub repo (ShanudhaTirosh/netch-vpn/assets/)
# and update FAKE_SITE_SCRIPT at the top of this file.
sudo su -c "bash <(wget -qO- ${FAKE_SITE_SCRIPT})"

############################### WEB SUBSCRIPTION PAGE ##########################################
# TODO: Add your own sub page HTML and Clash YAMLs to ShanudhaTirosh/netch-vpn/assets/
# and update URL_SUB_PAGE / URL_CLASH_SUB at the top of this file.
DEST_DIR_SUB_PAGE="/var/www/subpage"
DEST_FILE_SUB_PAGE="$DEST_DIR_SUB_PAGE/index.html"
DEST_FILE_CLASH_SUB="$DEST_DIR_SUB_PAGE/clash.yaml"

sudo mkdir -p "$DEST_DIR_SUB_PAGE"
sudo curl -L "${URL_CLASH_SUB[$CLASH]}"    -o "$DEST_FILE_CLASH_SUB"
sudo curl -L "${URL_SUB_PAGE[$CUSTOMWEBSUB]}" -o "$DEST_FILE_SUB_PAGE"

sed -i "s/\${DOMAIN}/$domain/g"       "$DEST_FILE_SUB_PAGE"
sed -i "s/\${DOMAIN}/$domain/g"       "$DEST_FILE_CLASH_SUB"
sed -i "s#\${SUB_JSON_PATH}#$json_path#g" "$DEST_FILE_SUB_PAGE"
sed -i "s#\${SUB_PATH}#$sub_path#g"   "$DEST_FILE_SUB_PAGE"
sed -i "s#\${SUB_PATH}#$sub_path#g"   "$DEST_FILE_CLASH_SUB"
sed -i "s|sub.legiz.ru|$domain/$sub2singbox_path|g" "$DEST_FILE_SUB_PAGE"

############################### NATIVE SUB TEMPLATE (Step 2) ###################################
# The user-facing subscription page is now rendered by 3x-ui's built-in Go
# html/template engine (subThemeDir setting, seeded above) rather than the
# static Nginx page. The engine looks for sub.html|index.html in the theme
# directory and injects live data ({{ .links }}, {{ .download }}, {{ .expire }},
# {{ .subUrl }}, {{ .subJsonUrl }}, {{ .subClashUrl }}, ...). See
# docs/custom-subscription-templates.md.
#
# No ${DOMAIN}/${SUB_PATH} sed substitution is needed here — the engine fills
# the URLs from panel settings at render time. We only place the template file.
SUB_THEME_DIR="/etc/x-ui/sub_templates/netch-glass"
mkdir -p "$SUB_THEME_DIR"
if curl -sf --max-time 10 "${GITHUB_RAW}/sub_templates/netch-glass/index.html" \
        -o "$SUB_THEME_DIR/index.html" 2>/dev/null; then
    msg_ok "Netch glassmorphism sub template deployed (native engine)"
else
    msg_err "Could not fetch native sub template from repo."
    msg_inf "  Place sub_templates/netch-glass/index.html in the repo, or copy it"
    msg_inf "  to $SUB_THEME_DIR/ manually. Panel falls back to its default page"
    msg_inf "  until the template is present (subThemeDir is already set)."
fi
chown -R root:root "$SUB_THEME_DIR" 2>/dev/null || true

############################### FAVICON — NovaNetchX / ShanuFX #################################
# Step 3: ship the REAL NovaNetchX brand favicon (navy #03061D / #02051D base,
# teal #289DB7 accent) — no more purple #7c3aed placeholder.
#
# Source of truth is the brand asset committed at assets/favicon.svg + .ico in
# the netch-vpn repo. The installer fetches those first; if the repo is
# unreachable at install time it falls back to a compact, brand-accurate
# inline SVG (still navy/teal, never the old purple mark) so the panel/sub
# pages always get an on-brand icon.
mkdir -p /var/www/html
FAVICON_OK="n"

# 1) Preferred: the real brand assets from the repo.
if curl -sf --max-time 8 "${GITHUB_RAW}/assets/favicon.svg" -o /var/www/html/favicon.svg 2>/dev/null; then
    msg_ok "Brand favicon.svg fetched from repo"
    FAVICON_OK="y"
fi
if curl -sf --max-time 8 "${GITHUB_RAW}/assets/favicon.ico" -o /var/www/html/favicon.ico 2>/dev/null; then
    msg_ok "Brand favicon.ico fetched from repo"
    FAVICON_OK="y"
fi

# 2) Offline fallback: compact brand-accurate SVG (navy field + teal "N").
if [[ "$FAVICON_OK" != "y" ]]; then
    msg_inf "  Repo favicon unreachable — writing brand-accurate inline fallback"
    cat > /var/www/html/favicon.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="netch" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#03061D"/>
      <stop offset="100%" stop-color="#02051D"/>
    </linearGradient>
  </defs>
  <rect width="32" height="32" rx="7" fill="url(#netch)"/>
  <text x="16" y="23" text-anchor="middle"
        font-family="Arial Black,Arial,sans-serif"
        font-weight="900" font-size="19" fill="#289DB7">N</text>
</svg>
SVGEOF
    # Derive an .ico from the fallback SVG so the panel still has both formats.
    command -v convert &>/dev/null || apt-get install -yqq imagemagick 2>/dev/null
    if command -v convert &>/dev/null; then
        convert -background transparent /var/www/html/favicon.svg \
            -define icon:auto-resize=16,32,48 /var/www/html/favicon.ico 2>/dev/null \
            || cp /var/www/html/favicon.svg /var/www/html/favicon.ico
    else
        cp /var/www/html/favicon.svg /var/www/html/favicon.ico
    fi
fi
# ─────────────────────────────────────────────────────────────────────────────

############################### PANEL THEME (CSS injection) ###################################
# Deploy the brand glassmorphism stylesheet that Nginx sub_filter injects into
# the stock 3x-ui SPA (the official prebuilt binary, so no source rebuild). The
# <link> to /netch-theme.css is added to the panel vhost's sub_filter above.
if curl -sf --max-time 8 "${GITHUB_RAW}/assets/netch-theme.css" -o /var/www/html/netch-theme.css 2>/dev/null; then
    chmod 644 /var/www/html/netch-theme.css
    msg_ok "Panel theme CSS deployed (glassmorphism + teal brand)"
else
    msg_inf "  Could not fetch netch-theme.css from repo — panel keeps stock theme"
    msg_inf "  (favicon + functionality unaffected). Add assets/netch-theme.css to the repo."
fi

# Runtime rebrand: 3X-UI -> SX-UI in the SPA (text nodes only; injected too).
if curl -sf --max-time 8 "${GITHUB_RAW}/assets/netch-brand.js" -o /var/www/html/netch-brand.js 2>/dev/null; then
    chmod 644 /var/www/html/netch-brand.js
    msg_ok "Panel rebrand script deployed (3X-UI -> SX-UI)"
else
    msg_inf "  Could not fetch netch-brand.js from repo — panel keeps stock 3X-UI label"
fi

nginx -s reload 2>/dev/null || true

############################### CRON JOBS #######################################################
crontab -l | grep -v "certbot\|x-ui\|cloudflareips" | crontab -
(crontab -l 2>/dev/null; echo '@reboot /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 > /dev/null 2>&1') | crontab -
(crontab -l 2>/dev/null; echo '@daily x-ui restart > /dev/null 2>&1 && nginx -s reload;') | crontab -
(crontab -l 2>/dev/null; echo '@monthly certbot renew --nginx --non-interactive --post-hook "nginx -s reload" > /dev/null 2>&1;') | crontab -

############################### FIREWALL ########################################################
ufw disable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

############################### FINAL OUTPUT ####################################################
if systemctl is-active --quiet x-ui; then
    clear
    echo
    msg_inf  '   _____ _                       _______  __  '
    msg_inf  '  / ____| |                     |  ___|  __ \ '
    msg_inf  ' | (___ | |__   __ _ _ __  _   _| |_  | |__/ '
    msg_inf  '  \___ \| |_ \ / _` | `_ \| | | |  _| |  \   '
    msg_inf  '  ____) | | | | (_| | | | | |_| | |   | |__\ '
    msg_inf  ' |_____/|_| |_|\__,_|_| |_|\__,_|_|   |____/ '
    echo
    msg_cyan ' ┌──────────────────────────────────────────────────────────┐'
    msg_cyan ' │   Netch Solutions  ·  VPN Installer v1.2.4               │'
    msg_cyan ' │   Installation Complete!                                  │'
    msg_cyan ' └──────────────────────────────────────────────────────────┘'
    echo

    msg_inf  " ─── Server Info ──────────────────────────────────────────────"
    printf   '   IPv4 : %s\n'   "$IP4"
    [[ -n $IP6 ]] && printf '   IPv6 : %s\n' "$IP6"
    echo

    msg_inf  " ─── SSL Certificates ────────────────────────────────────────"
    nginx -T | grep -i 'ssl_certificate\|ssl_certificate_key'
    echo
    certbot certificates | grep -i 'Path:\|Domains:\|Expiry Date:'
    echo

    msg_inf  " ─── Panel Access ────────────────────────────────────────────"
    msg_inf  "   URL      :  https://${domain}/${panel_path}/"
    echo -e  "   Username :  ${config_username}"
    echo -e  "   Password :  ${config_password}"
    echo

    msg_inf  " ─── Subscription Links ──────────────────────────────────────"
    msg_inf  "   Native Sub    :  https://${domain}/${sub_path}/SUBID   (glass theme)"
    msg_inf  "   JSON Sub      :  https://${domain}/${json_path}/SUBID"
    msg_inf  "   Web Sub Page  :  https://${domain}/${web_path}?name=CLIENT_NAME"
    msg_inf  "   sub2sing-box  :  https://${domain}/${sub2singbox_path}/"
    echo

    msg_inf  " ─── Protocol Summary ────────────────────────────────────────"
    printf   "   %-24s  Port: %s\n"  "VLESS + REALITY"       "8443  →  443 (SNI: ${reality_domain})"
    printf   "   %-24s  Port: %s\n"  "VLESS + TLS-Vision"    "${vless_tls_port}  →  443 (SNI: ${VLESS_TLS_SNI})"
    printf   "   %-24s  Port: %s\n"  "VLESS + WebSocket"     "${ws_port}  →  443 (CDN-friendly)"
    printf   "   %-24s  Port: %s\n"  "VLESS + XHTTP"         "Unix socket  →  443"
    printf   "   %-24s  Port: %s\n"  "Trojan + gRPC"         "${trojan_port}  →  443"
    echo
    msg_inf  " ─── Client SNI Guide ────────────────────────────────────────"
    printf   "   REALITY    : sni=%s\n"   "${reality_domain}"
    printf   "   TLS-Vision : sni=%s  (set allowInsecure or trust server cert)\n" "${VLESS_TLS_SNI}"
    printf   "   WS / XHTTP : sni=%s\n"  "${domain}"
    echo

    msg_inf  " ─── Cloudflare WARP (selective routing — one-click) ─────────"
    msg_cyan "   WARP egress is NOT enabled by default. To turn it on:"
    printf   "     1. Panel → Xray Configuration → Outbounds → 'Warp' button\n"
    printf   "     2. Click 'Create Account' then 'Add Outbound'  (tag: warp)\n"
    printf   "     3. Routing tab → add a rule:  geosite:openai, geosite:netflix\n"
    printf   "        → outboundTag 'warp'. Everything else stays direct.\n"
    printf   "   Helper + exact JSON:  %s\n" "${GITHUB_REPO}/blob/main/scripts/warp.md"
    printf   "   Quick CLI helper:     bash <(curl -fsSL %s/scripts/netch-warp-setup.sh)\n" "${GITHUB_RAW}"
    echo

    msg_ok   " Save these credentials now — they will not be shown again! "
    echo
else
    nginx -t
    printf '0\n' | x-ui | grep --color=never -i ':'
    msg_err "x-ui or nginx check failed. Try on a clean Ubuntu 20/22 installation."
fi
######################################### Powered by Netch Solutions ############################
