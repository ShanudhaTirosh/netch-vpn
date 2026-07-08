#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2155
##########################################################################
#  lib/panel.sh — NovaNetchX 3x-ui panel management
#  Source after lib/utils.sh.
#  Provides: arch()  fresh_install_cleanup()
#            config_after_install()  install_panel()
##########################################################################

# Maps uname -m to the architecture string used in 3x-ui release tarballs.
arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64)            echo 'amd64'  ;;
        i*86 | x86)                       echo '386'    ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64'  ;;
        armv7* | armv7 | arm)             echo 'armv7'  ;;
        armv6* | armv6)                   echo 'armv6'  ;;
        armv5* | armv5)                   echo 'armv5'  ;;
        s390x)                            echo 's390x'  ;;
        *) msg_err "Unsupported CPU architecture: $(uname -m)" && exit 1 ;;
    esac
}
# Cache once — every downstream reference uses $ARCH instead of spawning a subshell.
readonly ARCH=$(arch)

# Remove all x-ui and nginx state before a fresh install.
# MUST be called explicitly — never runs at source time.
fresh_install_cleanup() {
    msg_inf "  Removing previous x-ui / nginx config before fresh install..."
    drun systemctl stop x-ui 2>/dev/null || true
    drun rm -rf /etc/systemd/system/x-ui.service
    drun rm -rf /usr/local/x-ui
    drun rm -rf /etc/x-ui
    drun rm -rf /etc/nginx/sites-enabled/*
    drun rm -rf /etc/nginx/sites-available/*
    drun rm -rf /etc/nginx/stream-enabled/*
}

# Set temporary bootstrap credentials so x-ui can start while UPDATE_XUIDB
# seeds the real ones.  Values are random — the window where these are active
# is a few seconds at most.
config_after_install() {
    local _tmp_user _tmp_pass
    _tmp_user=$(gen_random_string 10)
    _tmp_pass=$(gen_random_string 20)
    /usr/local/x-ui/x-ui setting \
        -username "${_tmp_user}" \
        -password "${_tmp_pass}" \
        -port     "2096" \
        -webBasePath "netchui"
    /usr/local/x-ui/x-ui migrate
}

# Download, extract, and start 3x-ui.
# Pass a version tag (e.g. v2.5.0) to pin a release; omit to use latest.
# Minimum supported version: v2.3.5
install_panel() {
    fresh_install_cleanup
    apt-get update && apt-get install -y -q wget curl tar tzdata
    cd /usr/local/ || exit 1

    local tag_version
    if [[ $# -eq 0 ]]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
            | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        # IPv4 fallback
        [[ -z "$tag_version" ]] && \
            tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
                | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        [[ -z "$tag_version" ]] && \
            msg_err "Failed to fetch 3x-ui version from GitHub API." && exit 1
        msg_inf "  Installing 3x-ui ${tag_version}..."
        wget -N -O /usr/local/x-ui-linux-${ARCH}.tar.gz \
            "https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-${ARCH}.tar.gz" \
            || { msg_err "Download failed."; exit 1; }
    else
        tag_version="$1"
        local tag_numeric min_version="2.3.5"
        tag_numeric="${tag_version#v}"
        if [[ "$(printf '%s\n' "$min_version" "$tag_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            msg_err "Minimum supported version is v${min_version}." && exit 1
        fi
        wget -N -O /usr/local/x-ui-linux-${ARCH}.tar.gz \
            "https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-${ARCH}.tar.gz" \
            || { msg_err "Download of 3x-ui ${tag_version} failed."; exit 1; }
    fi

    # Download the x-ui management script
    wget -O /usr/bin/x-ui-temp \
        https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh \
        || { msg_err "Failed to download x-ui.sh"; exit 1; }

    # Remove any existing install before extracting
    [[ -d /usr/local/x-ui/ ]] && { systemctl stop x-ui; rm -rf /usr/local/x-ui/; }

    tar zxvf "x-ui-linux-${ARCH}.tar.gz"
    rm -f "x-ui-linux-${ARCH}.tar.gz"
    cd x-ui || exit 1
    chmod +x x-ui x-ui.sh

    # ARM 32-bit: xray binary must be named xray-linux-arm
    if [[ $ARCH == "armv5" || $ARCH == "armv6" || $ARCH == "armv7" ]]; then
        mv "bin/xray-linux-${ARCH}" bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui "bin/xray-linux-${ARCH}"

    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui

    config_after_install

    cp -f x-ui.service.debian /etc/systemd/system/x-ui.service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    msg_ok "3x-ui ${tag_version} installed"
    msg_cyan "  x-ui start | stop | restart | status | update | uninstall"
}
