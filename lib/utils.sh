#!/bin/bash
# shellcheck disable=SC2034,SC2155
##########################################################################
#  lib/utils.sh — NovaNetchX shared utilities
#  Source this at the top of install.sh:
#    source "$(dirname "$0")/lib/utils.sh"
#
#  Provides: colour output, drun(), gen_random_string(),
#            get_port(), port_in_use(), make_port()
#
#  Expects: DRY_RUN variable to be set by the caller before sourcing,
#           or defaults to "n" (execute normally).
##########################################################################

# ── Colour output ────────────────────────────────────────────────────────
msg_ok()   { echo -e "\e[1;42m $1 \e[0m"; }
msg_err()  { echo -e "\e[1;41m $1 \e[0m"; }
msg_inf()  { echo -e "\e[1;35m$1\e[0m"; }
msg_cyan() { echo -e "\e[1;36m$1\e[0m"; }

# ── Dry-run wrapper ──────────────────────────────────────────────────────
# When DRY_RUN=y, prints what would run instead of running it.
# Usage:  drun rm -rf /etc/x-ui
#         drun systemctl stop x-ui
drun() {
    if [[ "${DRY_RUN:-n}" == "y" ]]; then
        msg_inf "  [DRY-RUN] would run: $*"
    else
        "$@"
    fi
}

# ── Random port in ephemeral range 10000-59151 ───────────────────────────
get_port() {
    echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
}

# ── Random alphanumeric string ───────────────────────────────────────────
# Usage: gen_random_string <length>
gen_random_string() {
    local length="$1"
    head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
    echo
}

# ── Port probe ───────────────────────────────────────────────────────────
# Returns 0 (bash-true) when the port IS occupied.
# Natural read at call site:  if ! port_in_use "$PORT"; then use it; fi
port_in_use() {
    local port=$1
    if command -v ss &>/dev/null; then
        ss -ltnuH 2>/dev/null | awk '{print $5}' | grep -qE "[:.]${port}$" && return 0
        return 1
    elif command -v nc &>/dev/null; then
        nc -z 127.0.0.1 "$port" &>/dev/null
        return $?
    else
        return 1   # assume free if neither tool available
    fi
}

# ── Random free port picker ──────────────────────────────────────────────
make_port() {
    local PORT
    while true; do
        PORT=$(get_port)
        if ! port_in_use "$PORT"; then
            echo "$PORT"
            break
        fi
    done
}
