#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2155
##########################################################################
#  lib/ssl.sh — NovaNetchX TLS certificate issuance
#  Source after lib/utils.sh.
#  Expects: $domain  $reality_domain  $IP4  $AUTODOMAIN
#  Provides: resolve_to_ip()  issue_certs()
##########################################################################

# Returns 0 if the given hostname's first A record matches $IP4.
resolve_to_ip() {
    local host="$1"
    local a
    a=$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}')
    [[ -n "$a" ]] && [[ "$a" == "$IP4" ]]
}

# Issue Let's Encrypt certs for $domain and $reality_domain, then create
# /root/cert/<domain>/ symlinks that x-ui and nginx reference.
# Exits with an error if either cert cannot be obtained.
issue_certs() {
    # Validate DNS resolution when auto-domain mode is active
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

    # Stop nginx and clear ports 80/443 so certbot's standalone mode can bind
    systemctl stop nginx 2>/dev/null || true
    fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null || true

    # Panel domain cert
    certbot certonly --standalone --non-interactive --agree-tos \
        --register-unsafely-without-email -d "$domain"
    if [[ ! -d "/etc/letsencrypt/live/${domain}/" ]]; then
        systemctl start nginx >/dev/null 2>&1
        msg_err "SSL for $domain failed — check DNS/IP and retry." && exit 1
    fi
    msg_ok "TLS cert issued for $domain"

    # REALITY domain cert (separate so it can have a different SNI)
    certbot certonly --standalone --non-interactive --agree-tos \
        --register-unsafely-without-email -d "$reality_domain"
    if [[ ! -d "/etc/letsencrypt/live/${reality_domain}/" ]]; then
        systemctl start nginx >/dev/null 2>&1
        msg_err "SSL for $reality_domain failed — check DNS/IP and retry." && exit 1
    fi
    msg_ok "TLS cert issued for $reality_domain"

    # Symlinks used by x-ui's cert config
    mkdir -p "/root/cert/${domain}"
    ln -sf "/etc/letsencrypt/live/${domain}/fullchain.pem" "/root/cert/${domain}/fullchain.pem"
    ln -sf "/etc/letsencrypt/live/${domain}/privkey.pem"   "/root/cert/${domain}/privkey.pem"
    chmod 755 /root/cert/*

    msg_ok "Cert symlinks → /root/cert/${domain}/"
}
