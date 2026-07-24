#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2155
##########################################################################
#  lib/deps.sh — NovaNetchX system-level dependencies
#  Source after lib/utils.sh and lib/panel.sh (needs $ARCH).
#  Expects: $Pak  $panel_port  $ARCH
#  Provides: install_deps()  tune_kernel()  setup_fail2ban()
#            install_sub2singbox()  setup_firewall()
#            setup_logrotate()  setup_crons()
##########################################################################

# Install every tool the installer and the running server need.
# Idempotent — safe to call on a server that already has these packages.
install_deps() {
    local version
    version=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release 2>/dev/null)
    msg_inf "  OS version: ${version:-unknown} — ensuring dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    $Pak -y update
    $Pak -y install curl wget jq bash sudo nginx-full certbot \
                    python3-certbot-nginx sqlite3 ufw netcat-openbsd \
                    psmisc openssl ca-certificates
    systemctl daemon-reload
    systemctl enable --now nginx 2>/dev/null || true

    # Hard preflight — fail early with a clear message rather than deep in SSL
    local _missing=""
    for _bin in certbot nginx sqlite3 jq curl wget openssl fuser; do
        command -v "$_bin" >/dev/null 2>&1 || _missing="$_missing $_bin"
    done
    if [[ -n "$_missing" ]]; then
        msg_err "Missing required tool(s):$_missing"
        msg_err "Install them manually and re-run:"
        msg_err "  apt-get install -y nginx-full certbot python3-certbot-nginx sqlite3 jq curl wget openssl psmisc"
        exit 1
    fi
    msg_ok "All dependencies satisfied"
}

# Write kernel tuning parameters to a dedicated drop-in file.
# Idempotent: the heredoc overwrites /etc/sysctl.d/99-netch.conf on each run.
tune_kernel() {
    $Pak -yqq install --no-install-recommends ca-certificates 2>/dev/null || true
    cat > /etc/sysctl.d/99-netch.conf << 'SYSCTL'
net.core.default_qdisc          = fq
net.ipv4.tcp_congestion_control = bbr
fs.file-max                     = 2097152
net.ipv4.tcp_timestamps         = 1
net.ipv4.tcp_sack               = 1
net.ipv4.tcp_window_scaling     = 1
net.core.rmem_max               = 16777216
net.core.wmem_max               = 16777216
net.ipv4.tcp_rmem               = 4096 87380 16777216
net.ipv4.tcp_wmem               = 4096 65536 16777216
net.core.somaxconn              = 4096
net.ipv4.tcp_max_syn_backlog    = 8192
SYSCTL
    sysctl --system >/dev/null
    msg_ok "Kernel tuning applied (BBR + buffer sizing)"
}

# Install fail2ban and configure an x-ui login-failure jail.
# Bans an IP for 1 h after 5 failed panel login attempts.
setup_fail2ban() {
    apt-get install -y -q fail2ban

    cat > /etc/fail2ban/filter.d/x-ui.conf << 'F2B_FILTER'
[Definition]
failregex = .*"msg"\s*:\s*"wrong user name or password".*"ip"\s*:\s*"<HOST>".*
            .*web login fail.*ip\s*:\s*<HOST>
ignoreregex =
F2B_FILTER

    cat > /etc/fail2ban/jail.d/x-ui.conf << F2B_JAIL
[x-ui]
enabled   = true
port      = ${panel_port}
filter    = x-ui
logpath   = /usr/local/x-ui/access.log
            /var/log/x-ui/*.log
maxretry  = 5
findtime  = 300
bantime   = 3600
action    = iptables-multiport[name=x-ui, port="${panel_port},443,80", protocol=tcp]
F2B_JAIL

    systemctl enable fail2ban --quiet
    systemctl restart fail2ban
    msg_ok "fail2ban active — x-ui jail: 5 failures → 1 h ban"
}

# Download and start the latest sub2sing-box binary.
# Converts x-ui subscriptions to sing-box / Clash Meta format.
install_sub2singbox() {
    if pgrep -x "sub2sing-box" > /dev/null; then pkill -x "sub2sing-box"; fi
    rm -f /usr/bin/sub2sing-box

    local S2SB_VER S2SB_TAG
    S2SB_VER=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/legiz-ru/sub2sing-box/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' 2>/dev/null \
        || echo "0.0.9")
    S2SB_TAG="v${S2SB_VER}"
    msg_inf "  Installing sub2sing-box ${S2SB_TAG}..."

    wget -q -P /root/ \
        "https://github.com/legiz-ru/sub2sing-box/releases/download/${S2SB_TAG}/sub2sing-box_${S2SB_VER}_linux_amd64.tar.gz"
    tar -xzf "/root/sub2sing-box_${S2SB_VER}_linux_amd64.tar.gz" -C /root/ \
        --strip-components=1 "sub2sing-box_${S2SB_VER}_linux_amd64/sub2sing-box"
    mv /root/sub2sing-box /usr/bin/
    chmod +x /usr/bin/sub2sing-box
    rm -f "/root/sub2sing-box_${S2SB_VER}_linux_amd64.tar.gz"

    su -c "/usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 & disown" root
    msg_ok "sub2sing-box ${S2SB_TAG} installed and started"
}

# Open the minimum required ports and enforce IPv6 coverage.
setup_firewall() {
    # IPV6=yes ensures ufw allow rules apply to [::]:443 as well as 0.0.0.0:443
    sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
    ufw disable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw --force enable
    msg_ok "UFW enabled (22 + 80 + 443 tcp/udp, IPv4 + IPv6)"
}

# Write a logrotate config that keeps x-ui logs manageable.
# postrotate restarts x-ui so it re-opens the log file descriptor.
setup_logrotate() {
    cat > /etc/logrotate.d/x-ui << 'LOGROTATECFG'
/usr/local/x-ui/access.log
/var/log/x-ui/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        x-ui restart > /dev/null 2>&1 || true
    endscript
}
LOGROTATECFG
    msg_ok "Log rotation configured — daily, 7-day retain, compressed"
}

# Register all crontab entries the server needs.
# Idempotent: greps out any existing matching lines before adding.
setup_crons() {
    local crontab_current
    crontab_current=$(crontab -l 2>/dev/null)

    echo "$crontab_current" \
        | grep -v 'sub2sing-box\|x-ui restart\|certbot renew' \
        | { cat; \
            echo '@reboot /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 > /dev/null 2>&1'; \
            echo '@daily x-ui restart > /dev/null 2>&1 && nginx -s reload;'; \
            echo '@monthly certbot renew --nginx --non-interactive --post-hook "nginx -s reload && x-ui restart" > /dev/null 2>&1;'; \
          } | crontab -

    msg_ok "Cron jobs registered (sub2sing-box @reboot, daily restart, monthly cert renewal)"
}
