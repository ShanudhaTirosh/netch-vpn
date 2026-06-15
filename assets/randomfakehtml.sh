#!/bin/bash
##########################################################################
#  NovaNetchX — Random Camouflage Site Installer
#  Part of: ShanuFX / Netch Solutions VPN Stack
#  github.com/ShanudhaTirosh/netch-vpn
#  ----------
#  Credits: randomfakehtml templates by GFW4Fun (github.com/GFW4Fun/randomfakehtml)
#  Installs a random decoy website into /var/www/html to disguise the
#  server as a legitimate web host against deep-packet inspection.
##########################################################################

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

Purple="\033[35m"; Cyan="\033[36m"; Red="\033[31m"
Green="\033[32m"; Reset="\033[0m"
msg_ok()  { echo -e "${Green}[OK]${Reset}  ${Cyan}$1${Reset}"; }
msg_err() { echo -e "${Red}[ERR]${Reset} $1"; }
msg_inf() { echo -e "${Purple}  ▸  $1${Reset}"; }

apt-get install -y -q unzip wget 2>/dev/null

cd "$HOME"

if [[ -d "randomfakehtml-master" ]]; then
    msg_inf "Template cache found — reusing existing download."
    cd randomfakehtml-master
else
    msg_inf "Downloading camouflage templates from GFW4Fun/randomfakehtml..."
    wget -q https://github.com/GFW4Fun/randomfakehtml/archive/refs/heads/master.zip \
        -O master.zip
    unzip -q master.zip && rm -f master.zip
    cd randomfakehtml-master
    rm -rf assets .gitattributes README.md _config.yml 2>/dev/null
fi

# Pick a random template directory
RandomHTML=$(a=(*); echo "${a[$((RANDOM % ${#a[@]}))]}" 2>&1)
msg_inf "Selected camouflage template: ${RandomHTML}"

if [[ -d "${RandomHTML}" && -d "/var/www/html/" ]]; then
    rm -rf /var/www/html/*
    cp -a "${RandomHTML}/." "/var/www/html/"
    # Inject NovaNetchX favicon into the decoy site too
    if [[ -f "/var/www/html/favicon.svg" ]]; then
        msg_inf "ShanuFX favicon already in place."
    fi
    msg_ok "Camouflage template deployed: ${RandomHTML}"
else
    msg_err "Failed to extract template '${RandomHTML}'. Check the download and try again."
    exit 1
fi
