#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2155
##########################################################################
#  lib/xray.sh — NovaNetchX Xray / 3x-ui database management
#  Source after lib/utils.sh and lib/panel.sh.
#  Expects: $XUIDB $domain $reality_domain $sub_port $sub_path $sub_uri
#           $json_path $json_uri $web_path $ws_port $trojan_port
#           $vless_tls_port $xhttp_path $trojan_path $panel_port
#           $panel_path $WS_CDN_HOST $WS_CDN_PORT $VLESS_TLS_SNI
#           $config_username $config_password $TG_BOT_TOKEN $TG_CHAT_ID
#  Provides: CHECK_DB_SCHEMA()  UPDATE_XUIDB()
##########################################################################

# Verify that the x-ui.db schema still has every column the INSERT block
# references.  Exits loudly on mismatch instead of silently corrupting state.
CHECK_DB_SCHEMA() {
    local db="$1"
    if [[ ! -f "$db" ]]; then
        msg_err "Schema check: $db not found." && exit 1
    fi

    local missing=""

    # Inbound table columns
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

    # Settings table is a generic key/value store — just confirm key + value exist
    local have_settings
    have_settings=$(sqlite3 "$db" "PRAGMA table_info('settings');" 2>/dev/null | awk -F'|' '{print $2}')
    echo "$have_settings" | grep -qx "key"   || missing="$missing settings.key"
    echo "$have_settings" | grep -qx "value" || missing="$missing settings.value"

    if [[ -n "$missing" ]]; then
        msg_err "DB schema drift — missing columns:$missing"
        msg_err "The 3x-ui schema changed.  Update the seeding block to match, then re-run."
        exit 1
    fi
    msg_ok "DB schema preflight passed (inbounds/settings columns match)"
}

# Seed the 3x-ui database with all panel settings and the five inbound configs.
# Safe to re-run — deletes existing rows first to avoid duplicate stacking.
UPDATE_XUIDB() {
if [[ -f $XUIDB ]]; then
    x-ui stop

    # Back up the live DB before touching it
    local _bak="/root/x-ui-backup-$(date +%Y%m%d-%H%M%S).db"
    cp "$XUIDB" "$_bak" && msg_ok "DB backed up → $_bak"

    CHECK_DB_SCHEMA "$XUIDB"

    # Generate x25519 key pair for the REALITY inbound
    local output private_key public_key
    output=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519)
    private_key=$(echo "$output" | grep "^Private key:" | awk '{print $3}')
    public_key=$(echo "$output"  | grep "^Public key:"  | awk '{print $3}')

    # Short IDs for REALITY (8 random 8-hex values)
    local shor
    shor=($(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) \
          $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8))

    # ── Settings seed ──────────────────────────────────────────────────────
    sqlite3 $XUIDB <<EOF
         DELETE FROM "settings";
         DELETE FROM "inbounds" WHERE user_id='1';

         INSERT INTO "settings" ("key", "value") VALUES ("subPort",           '${sub_port}');
         INSERT INTO "settings" ("key", "value") VALUES ("subPath",           '/${sub_path}/');
         INSERT INTO "settings" ("key", "value") VALUES ("subURI",            '${sub_uri}');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",       '/${json_path}');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",        '${json_uri}');
         INSERT INTO "settings" ("key", "value") VALUES ("subClashEnable",    'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subEnableRouting",  'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subEnable",         'true');
         INSERT INTO "settings" ("key", "value") VALUES ("webListen",         '');
         INSERT INTO "settings" ("key", "value") VALUES ("webDomain",         '');
         INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",     '60');
         INSERT INTO "settings" ("key", "value") VALUES ("pageSize",          '50');
         INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",        '0');
         INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",       '0');
         INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",       '-ieo');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",       'false');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",        '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",    '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",       '');
         INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",         '@daily');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",       'false');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify",  'true');
         INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",             '80');
         INSERT INTO "settings" ("key", "value") VALUES ("tgLang",            'en-US');
EOF

    # Telegram bot — only seed token/chat if flags were supplied
    if [[ -n "${TG_BOT_TOKEN}" && -n "${TG_CHAT_ID}" ]]; then
        sqlite3 $XUIDB <<BOT
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",  '${TG_BOT_TOKEN}');
         INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId", '${TG_CHAT_ID}');
         INSERT OR REPLACE INTO "settings" ("key", "value") VALUES ("tgBotEnable", 'true');
BOT
        msg_ok "Telegram bot configured (notifications enabled)"
    fi

    sqlite3 $XUIDB <<EOF
         INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",   'Asia/Colombo');
         INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",   'false');
         INSERT INTO "settings" ("key", "value") VALUES ("subDomain",      '');
         INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",    '');
         INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",     '');
         INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",     '12');
         INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",     'true');
         INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",    'true');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",'');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",  '');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",     '');
         INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",   '');
         INSERT INTO "settings" ("key", "value") VALUES ("datepicker",     'gregorian');
         INSERT INTO "settings" ("key", "value") VALUES ("subThemeDir",    '/etc/x-ui/sub_templates/netch-glass');

         -- ── REALITY inbound (port 8443, SNI = reality_domain) ─────────────
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             'NovaNetX REALITY','1','0','','8443','vless',
             '{"clients":[],"decryption":"none","fallbacks":[]}',
             '{
  "network": "tcp",
  "security": "reality",
  "externalProxy": [{"forceTls":"same","dest":"${domain}","port":443,"remark":""}],
  "realitySettings": {
    "show": false, "xver": 0,
    "target": "127.0.0.1:9443",
    "serverNames": ["${reality_domain}"],
    "privateKey": "${private_key}",
    "minClient":"","maxClient":"","maxTimediff":0,
    "shortIds": ["${shor[0]}","${shor[1]}","${shor[2]}","${shor[3]}","${shor[4]}","${shor[5]}","${shor[6]}","${shor[7]}"],
    "settings": {"publicKey":"${public_key}","fingerprint":"chrome","serverName":"","spiderX":"/"}
  },
  "tcpSettings": {"acceptProxyProtocol":true,"header":{"type":"none"}},
  "sockopt": {"acceptProxyProtocol":true,"tcpFastOpen":true,"tcpMptcp":true,"tcpNoDelay":true,"tcpcongestion":"bbr"}
}',
             'inbound-8443',
             '{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
         );

         -- ── VLESS+WS inbound (CDN-front, domain-as-path) ─────────────────
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             'NovaNetX WS','1','0','','${ws_port}','vless',
             '{"clients":[],"decryption":"none","fallbacks":[]}',
             '{
  "network": "ws",
  "security": "none",
  "externalProxy": [{"forceTls":"same","dest":"${WS_CDN_HOST}","port":${WS_CDN_PORT},"remark":"CDN-front"}],
  "wsSettings": {"acceptProxyProtocol":false,"path":"/${domain}","host":"${domain}","headers":{}},
  "sockopt": {"trustedXForwardedFor":["X-Forwarded-For"],"tcpFastOpen":true,"tcpMptcp":true,"tcpNoDelay":true,"tcpcongestion":"bbr"}
}',
             'inbound-${ws_port}',
             '{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
         );

         -- ── VLESS+XHTTP inbound (unix socket) ────────────────────────────
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             'NovaNetX XHTTP','0','0',
             '/dev/shm/uds2023.sock,0666','0','vless',
             '{"clients":[],"decryption":"none","fallbacks":[]}',
             '{
  "network": "xhttp",
  "security": "none",
  "externalProxy": [{"forceTls":"tls","dest":"${domain}","port":443,"remark":""}],
  "xhttpSettings": {
    "path":"/${xhttp_path}","host":"${domain}","headers":{},
    "scMaxBufferedPosts":30,"scMaxEachPostBytes":"1000000",
    "noSSEHeader":false,"xPaddingBytes":"100-1000","mode":"packet-up"
  },
  "sockopt": {"trustedXForwardedFor":["X-Forwarded-For"],"acceptProxyProtocol":false,
    "tcpFastOpen":true,"tcpMptcp":true,"tcpNoDelay":true,"tcpcongestion":"bbr",
    "tcpKeepAliveIdle":300,"tcpUserTimeout":10000,"tcpWindowClamp":600}
}',
             'inbound-/dev/shm/uds2023.sock,0666:0|',
             '{"enabled":true,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
         );

         -- ── Trojan+gRPC inbound ───────────────────────────────────────────
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             'NovaNetX Trojan','1','0','','${trojan_port}','trojan',
             '{"clients":[],"fallbacks":[]}',
             '{
  "network": "grpc",
  "security": "none",
  "externalProxy": [{"forceTls":"tls","dest":"${domain}","port":443,"remark":""}],
  "grpcSettings": {"serviceName":"/${trojan_port}/${trojan_path}","authority":"${domain}","multiMode":false},
  "sockopt": {"acceptProxyProtocol":false,"tcpFastOpen":true,"tcpMptcp":true,"tcpNoDelay":true,"tcpcongestion":"bbr"}
}',
             'inbound-${trojan_port}',
             '{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
         );

         -- ── VLESS+TLS inbound (SNI-routed from port 443) ─────────────────
         INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1','0','0','0',
             'NovaNetX TLS','1','0','','${vless_tls_port}','vless',
             '{"clients":[],"decryption":"none","fallbacks":[]}',
             '{
  "network": "tcp",
  "security": "tls",
  "externalProxy": [{"forceTls":"same","dest":"${domain}","port":443,"remark":"SNI=${VLESS_TLS_SNI}"}],
  "tlsSettings": {
    "serverName":"${domain}","minVersion":"1.2",
    "certificates":[{"certificateFile":"/root/cert/${domain}/fullchain.pem","keyFile":"/root/cert/${domain}/privkey.pem","ocspStapling":3600}],
    "alpn":["h2","http/1.1"],
    "settings":{"allowInsecure":false,"fingerprint":"chrome"}
  },
  "tcpSettings": {"acceptProxyProtocol":true,"header":{"type":"none"}},
  "sockopt": {"acceptProxyProtocol":true,"tcpFastOpen":true,"tcpMptcp":true,"tcpNoDelay":true,"tcpcongestion":"bbr"}
}',
             'inbound-${vless_tls_port}',
             '{"enabled":true,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
         );
EOF

    # Apply panel credentials and cert paths
    /usr/local/x-ui/x-ui setting \
        -username "${config_username}" \
        -password "${config_password}" \
        -port     "${panel_port}" \
        -webBasePath "${panel_path}"
    /usr/local/x-ui/x-ui cert \
        -webCert    "/root/cert/${domain}/fullchain.pem" \
        -webCertKey "/root/cert/${domain}/privkey.pem"
    x-ui start
else
    msg_err "x-ui.db not found — install 3x-ui first (run install_panel)." && exit 1
fi
}
