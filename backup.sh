#!/bin/bash
##########################################################################
#  Netch VPN — backup / restore
#  Snapshots the stateful parts of a Netch VPN install so you can move to a
#  new VPS or roll back: x-ui database, Nginx config, web/sub assets, the
#  native sub template, and Let's Encrypt certs.
#
#  Usage:
#    bash backup.sh backup [/path/out]     # create a snapshot tar.gz
#    bash backup.sh restore <snapshot.tar.gz>
#    bash backup.sh            # interactive menu
##########################################################################
set -euo pipefail
[[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DEFAULT="/root/netch-backup-${STAMP}.tar.gz"

PATHS=(
  /etc/x-ui
  /etc/nginx/nginx.conf
  /etc/nginx/sites-available
  /etc/nginx/sites-enabled
  /etc/nginx/stream-enabled
  /etc/nginx/snippets
  /var/www/html
  /var/www/subpage
  /etc/letsencrypt
)

do_backup() {
  local out="${1:-$OUT_DEFAULT}"
  echo "[*] Stopping x-ui for a consistent DB snapshot..."
  systemctl stop x-ui 2>/dev/null || true
  local existing=()
  local p
  for p in "${PATHS[@]}"; do [[ -e "$p" ]] && existing+=("$p"); done
  echo "[*] Creating snapshot: $out"
  tar --warning=no-file-changed -czf "$out" "${existing[@]}" 2>/dev/null || true
  systemctl start x-ui 2>/dev/null || true
  echo "[+] Backup complete: $out"
  echo "    Size: $(du -h "$out" | cut -f1)"
}

do_restore() {
  local snap="${1:-}"
  [[ -z "$snap" || ! -f "$snap" ]] && { echo "Snapshot file not found: $snap"; exit 1; }
  echo "[!] This overwrites x-ui DB, Nginx config and web assets from: $snap"
  read -rp "Type YES to continue: " ok
  [[ "$ok" == "YES" ]] || { echo "Aborted."; exit 1; }
  systemctl stop x-ui 2>/dev/null || true
  systemctl stop nginx 2>/dev/null || true
  echo "[*] Extracting..."
  tar -xzf "$snap" -C /
  echo "[*] Testing Nginx config..."
  if nginx -t; then systemctl start nginx; else echo "[!] nginx -t failed — fix before starting nginx."; fi
  systemctl start x-ui 2>/dev/null || true
  echo "[+] Restore complete. Verify the panel and 'x-ui status'."
}

case "${1:-menu}" in
  backup)  do_backup "${2:-}";;
  restore) do_restore "${2:-}";;
  menu|*)
    echo "Netch VPN backup/restore"
    echo "  1) Backup now"
    echo "  2) Restore from file"
    read -rp "Select [1-2]: " c
    case "$c" in
      1) read -rp "Output path [$OUT_DEFAULT]: " o; do_backup "${o:-$OUT_DEFAULT}";;
      2) read -rp "Snapshot path: " s; do_restore "$s";;
      *) echo "Nothing to do.";;
    esac;;
esac
