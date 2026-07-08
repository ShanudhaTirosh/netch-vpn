#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2155
##########################################################################
#  lib/nginx.sh — NovaNetchX nginx configuration
#  Source after lib/utils.sh.
#  Expects: $domain $reality_domain $panel_path $panel_port $sub_port
#           $sub_path $sub2singbox_path $web_path $json_path $ws_port
#           $xhttp_path $trojan_path $WS_CDN_HOST $WS_CDN_PORT
#           $vless_tls_port $trojan_port $CFALLOW
#  Provides: SETUP_NGINX()
##########################################################################

SETUP_NGINX() {
    mkdir -p /etc/nginx/stream-enabled \
             /etc/nginx/sites-available \
             /etc/nginx/sites-enabled \
             /etc/nginx/snippets \
             /etc/nginx/conf.d

    # ── nginx.conf global patches ─────────────────────────────────────────
    grep -xqFR "stream { include /etc/nginx/stream-enabled/*.conf; }" /etc/nginx/* || \
        echo "stream { include /etc/nginx/stream-enabled/*.conf; }" >> /etc/nginx/nginx.conf
    grep -xqFR "load_module modules/ngx_stream_module.so;" /etc/nginx/* || \
        sed -i '1s/^/load_module \/usr\/lib\/nginx\/modules\/ngx_stream_module.so; /' /etc/nginx/nginx.conf
    grep -xqFR "load_module modules/ngx_stream_geoip2_module.so;" /etc/nginx* || \
        sed -i '2s/^/load_module \/usr\/lib\/nginx\/modules\/ngx_stream_geoip2_module.so; /' /etc/nginx/nginx.conf
    grep -xqFR "worker_rlimit_nofile 16384;" /etc/nginx/* || \
        echo "worker_rlimit_nofile 16384;" >> /etc/nginx/nginx.conf
    sed -i "/worker_connections/c\\worker_connections 4096;" /etc/nginx/nginx.conf

    # ── http{} drop-ins (rate-limit zone + gzip) ─────────────────────────
    cat > /etc/nginx/conf.d/netch-security.conf << 'NGINXSEC'
limit_req_zone $binary_remote_addr zone=panel_login:10m rate=5r/m;
limit_req_status 429;
NGINXSEC

    cat > /etc/nginx/conf.d/netch-perf.conf << 'NGINXPERF'
gzip            on;
gzip_min_length 256;
gzip_comp_level 6;
gzip_types      text/plain text/yaml application/json
                application/javascript text/xml application/xml;
gzip_vary       on;
gzip_proxied    any;
NGINXPERF

    # ── Port 443 SNI stream router ────────────────────────────────────────
    cat > "/etc/nginx/stream-enabled/stream.conf" << EOF
map \$ssl_preread_server_name \$sni_name {
    hostnames;
    ${reality_domain}    xray;
    ${VLESS_TLS_SNI}     vless_tls;
    ${domain}            www;
    default              xray;
}
upstream xray      { server 127.0.0.1:8443; }
upstream www       { server 127.0.0.1:7443; }
upstream vless_tls { server 127.0.0.1:${vless_tls_port}; }
server {
    listen 443      reuseport;
    listen [::]:443 reuseport;
    proxy_pass          \$sni_name;
    ssl_preread         on;
    proxy_protocol      on;
    proxy_connect_timeout 10s;
}
EOF

    # ── HTTP → HTTPS redirect ─────────────────────────────────────────────
    cat > "/etc/nginx/sites-available/80.conf" << EOF
server {
    listen 80;
    server_name ${domain} ${reality_domain};
    return 301 https://\$host\$request_uri;
}
EOF

    # ── Main panel + subscription vhost (port 7443, TLS, proxy_protocol) ─
    cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
	server_tokens off;
	server_name ${domain};
	listen 7443 ssl http2 proxy_protocol;
	listen [::]:7443 ssl http2 proxy_protocol;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate     /etc/letsencrypt/live/${domain}/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

	# SSL session cache + OCSP stapling
	ssl_session_cache   shared:SSL:10m;
	ssl_session_timeout 10m;
	ssl_session_tickets off;
	ssl_stapling        on;
	ssl_stapling_verify on;
	ssl_trusted_certificate /etc/letsencrypt/live/${domain}/chain.pem;
	resolver            1.1.1.1 8.8.8.8 valid=300s;
	resolver_timeout    5s;

	set_real_ip_from 127.0.0.1;
	set_real_ip_from ::1;
	real_ip_header proxy_protocol;

	keepalive_timeout 1800s;
	keepalive_requests 10000;

	if (\$host !~* ^(.+\.)?${domain}\$ )     { return 444; }
	if (\$scheme ~* https)                    { set \$safe 1; }
	if (\$ssl_server_name !~* ^(.+\.)?${domain}\$ ) { set \$safe "\${safe}0"; }
	if (\$safe = 10)                          { return 444; }
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;

	# ── Panel (with NovaNetchX theme injection) ───────────────────────
	location /${panel_path}/ {
		limit_req zone=panel_login burst=10 nodelay;
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
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	location /${panel_path} {
		limit_req zone=panel_login burst=10 nodelay;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_read_timeout 3600s;
		proxy_send_timeout 3600s;
		proxy_pass https://127.0.0.1:${panel_port};
		break;
	}

	include /etc/nginx/snippets/includes.conf;
}
EOF

    # ── REALITY panel vhost (port 9443) ──────────────────────────────────
    cat > "/etc/nginx/sites-available/${reality_domain}" << EOF
server {
	server_tokens off;
	server_name ${reality_domain};
	listen 9443 ssl http2;
	listen [::]:9443 ssl http2;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate     /etc/letsencrypt/live/${reality_domain}/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/${reality_domain}/privkey.pem;
	if (\$host !~* ^(.+\.)?${reality_domain}\$ ) { return 444; }
	if (\$scheme ~* https)                        { set \$safe 1; }
	if (\$ssl_server_name !~* ^(.+\.)?${reality_domain}\$ ) { set \$safe "\${safe}0"; }
	if (\$safe = 10) { return 444; }
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;

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
		sub_filter '</head>' '<link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="stylesheet" href="/netch-theme.css"><script src="/netch-brand.js" defer></script></head>';
		sub_filter_once on;
		break;
	}
	location /${panel_path} {
		proxy_http_version 1.1;
		proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
	location / { try_files \$uri \$uri/ =404; }
}
EOF

    # ── Cloudflare IP allowlist block for WS location ─────────────────────
    local CF_ALLOW_BLOCK=""
    if [[ "${CFALLOW}" == "y" ]]; then
        msg_inf "  Fetching Cloudflare IP ranges for WS path allowlist..."
        local CF_V4 CF_V6
        CF_V4=$(curl -sf --max-time 10 https://www.cloudflare.com/ips-v4 || true)
        CF_V6=$(curl -sf --max-time 10 https://www.cloudflare.com/ips-v6 || true)
        if [[ -z "$CF_V4" ]]; then
            msg_err "  Could not fetch Cloudflare IPs — WS path will accept all IPs."
        else
            local _ip
            for _ip in $CF_V4 $CF_V6; do
                CF_ALLOW_BLOCK+="		allow ${_ip};"$'\n'
            done
            CF_ALLOW_BLOCK+="		deny all; # block direct (non-CDN) connections"
            msg_ok "  Cloudflare IP allowlist built ($(echo "$CF_V4 $CF_V6" | wc -w) ranges)"
        fi
    fi

    # ── Shared location snippets (subscriptions, WS, XHTTP, gRPC, etc.) ──
    mkdir -p /etc/nginx/snippets
    cat > "/etc/nginx/snippets/includes.conf" << EOF
	# sub2sing-box subscription converter proxy
	location /${sub2singbox_path}/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:8080/;
	}

	# VLESS+WS inbound — CDN-fronted (domain-as-path)
	location = /${domain} {
		${CF_ALLOW_BLOCK}
		proxy_http_version      1.1;
		proxy_buffering         off;
		proxy_request_buffering off;
		proxy_socket_keepalive  on;
		client_body_timeout     1d;
		proxy_read_timeout      1d;
		proxy_send_timeout      1d;
		proxy_set_header Upgrade           \$http_upgrade;
		proxy_set_header Connection        "upgrade";
		proxy_set_header Host              \$host;
		proxy_set_header X-Real-IP         \$remote_addr;
		proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_pass http://127.0.0.1:${ws_port};
	}

	# Dynamic port/path proxy router (XHTTP, gRPC, legacy WS)
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
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

    # ── Enable sites + verify config ─────────────────────────────────────
    unlink "/etc/nginx/sites-enabled/default"   >/dev/null 2>&1 || true
    rm -f  "/etc/nginx/sites-enabled/default" \
           "/etc/nginx/sites-available/default"
    ln -sf "/etc/nginx/sites-available/${domain}"         "/etc/nginx/sites-enabled/" 2>/dev/null
    ln -sf "/etc/nginx/sites-available/${reality_domain}" "/etc/nginx/sites-enabled/" 2>/dev/null
    ln -sf "/etc/nginx/sites-available/80.conf"           "/etc/nginx/sites-enabled/" 2>/dev/null

    if ! nginx -t 2>&1 | grep -q 'successful'; then
        msg_err "Nginx config test failed — check errors above." && exit 1
    fi
    systemctl start nginx
    msg_ok "Nginx configured and started"
}
