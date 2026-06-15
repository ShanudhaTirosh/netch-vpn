#!/bin/bash
##########################################################################
#  NovaNetchX — Backup & Restore Utility
#  Developer : ShanuFX  |  Company : Netch Solutions
#  github.com/ShanudhaTirosh/netch-vpn
##########################################################################

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

Purple="\033[35m"; Cyan="\033[36m"; Green="\033[32m"
Red="\033[31m"; Reset="\033[0m"
msg_ok()  { echo -e "${Green}[OK]${Reset}  ${Cyan}$1${Reset}"; }
msg_err() { echo -e "${Red}[ERR]${Reset} $1"; }
msg_inf() { echo -e "${Purple}  ▸  $1${Reset}"; }

LOG="/var/log/netch-backup.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG"; }

get_web_roots() {
    nginx -T 2>/dev/null | grep "root " | awk '{print $2}' | sed 's/;//g' | sort -u
}

############################### BACKUP #######################################################
backup() {
    while true; do
        read -p "  Backup directory [default: /backup]: " BACKUP_DIR
        BACKUP_DIR="${BACKUP_DIR:-/backup}"
        if mkdir -p "$BACKUP_DIR" 2>/dev/null; then break
        else echo "  Cannot create that directory — try again."; fi
    done

    BDATE=$(date +%F)
    BTIME=$(date +%H-%M-%S)
    BDIR="$BACKUP_DIR/$BDATE/$BTIME"
    mkdir -p "$BDIR"
    msg_inf "Saving to: $BDIR"

    while true; do
        echo
        echo "  ┌─────────────────────────────────────┐"
        echo "  │   What would you like to backup?    │"
        echo "  ├─────────────────────────────────────┤"
        echo "  │  1  Nginx configuration              │"
        echo "  │  2  3x-UI database (x-ui.db)         │"
        echo "  │  3  3x-UI config.json                │"
        echo "  │  4  Web / camouflage site files      │"
        echo "  │  5  Everything above                 │"
        echo "  │  0  Exit                             │"
        echo "  └─────────────────────────────────────┘"
        read -p "  Choice: " OPT

        case $OPT in
            1)
                msg_inf "Backing up Nginx..."
                tar -czf "$BDIR/nginx-$BTIME.tar.gz" /etc/nginx
                log "Nginx → $BDIR/nginx-$BTIME.tar.gz"
                msg_ok "Nginx backed up." ;;
            2)
                msg_inf "Backing up 3x-UI database..."
                tar -czf "$BDIR/x-ui-db-$BTIME.tar.gz" /etc/x-ui
                log "x-ui db → $BDIR/x-ui-db-$BTIME.tar.gz"
                msg_ok "3x-UI database backed up." ;;
            3)
                msg_inf "Backing up 3x-UI config.json..."
                tar -czf "$BDIR/config-$BTIME.tar.gz" /usr/local/x-ui/bin/config.json
                log "config.json → $BDIR/config-$BTIME.tar.gz"
                msg_ok "config.json backed up." ;;
            4)
                msg_inf "Backing up web files..."
                for WR in $(get_web_roots); do
                    [[ -d "$WR" ]] || continue
                    FNAME="website-${WR//\//_}-$BTIME.tar.gz"
                    tar -czf "$BDIR/$FNAME" -P "$WR"
                    log "$WR → $BDIR/$FNAME"
                    msg_ok "Backed up $WR"
                done ;;
            5)
                msg_inf "Full backup in progress..."
                tar -czf "$BDIR/nginx-$BTIME.tar.gz"       /etc/nginx
                tar -czf "$BDIR/x-ui-db-$BTIME.tar.gz"     /etc/x-ui
                tar -czf "$BDIR/config-$BTIME.tar.gz"       /usr/local/x-ui/bin/config.json 2>/dev/null
                for WR in $(get_web_roots); do
                    [[ -d "$WR" ]] || continue
                    tar -czf "$BDIR/website-${WR//\//_}-$BTIME.tar.gz" -P "$WR"
                    log "$WR backed up"
                done
                log "Full backup → $BDIR"
                msg_ok "Full backup complete → $BDIR" ;;
            0) break ;;
            *) echo "  Invalid choice." ;;
        esac
        read -p "  Press Enter to continue..."
    done
}

############################### RESTORE ######################################################
restore() {
    while true; do
        read -p "  Backup directory [default: /backup]: " BACKUP_DIR
        BACKUP_DIR="${BACKUP_DIR:-/backup}"
        [[ -d "$BACKUP_DIR" ]] && break || echo "  Directory not found — try again."
    done

    mapfile -t DATES < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    [[ ${#DATES[@]} -eq 0 ]] && { echo "  No backups found in $BACKUP_DIR."; return; }

    echo; echo "  Available backup dates:"
    select BDATE in "${DATES[@]}" "Exit"; do
        [[ "$BDATE" == "Exit" ]] && return
        [[ -n "$BDATE" ]] && break || echo "  Invalid selection."
    done

    mapfile -t TIMES < <(find "$BACKUP_DIR/$BDATE" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    [[ ${#TIMES[@]} -eq 0 ]] && { echo "  No timestamps found for $BDATE."; return; }

    echo; echo "  Select timestamp:"
    select BTIME in "${TIMES[@]}" "Exit"; do
        [[ "$BTIME" == "Exit" ]] && return
        [[ -n "$BTIME" ]] && break || echo "  Invalid selection."
    done

    BDIR="$BACKUP_DIR/$BDATE/$BTIME"
    msg_inf "Restoring from $BDIR ..."
    for F in "$BDIR"/*.tar.gz; do
        msg_inf "Extracting $F ..."
        tar -xzf "$F" -C /
        log "Restored: $F"
    done

    msg_inf "Restarting services..."
    systemctl restart nginx x-ui
    log "Services restarted after restore."
    msg_ok "Restore complete!"
    read -p "  Press Enter to continue..."
}

############################### MAIN MENU ####################################################
while true; do
    clear
    echo
    echo -e "${Purple}  ┌─────────────────────────────────────────┐${Reset}"
    echo -e "${Purple}  │   NovaNetchX  Backup & Restore Utility  │${Reset}"
    echo -e "${Purple}  │   Netch Solutions · ShanuFX             │${Reset}"
    echo -e "${Purple}  └─────────────────────────────────────────┘${Reset}"
    echo
    echo "  1  Backup"
    echo "  2  Restore"
    echo "  0  Exit"
    echo
    read -p "  Choice: " OPT
    case $OPT in
        1) backup ;;
        2) restore ;;
        0) log "Script exited by user."; echo; break ;;
        *) echo "  Invalid option." ;;
    esac
done
