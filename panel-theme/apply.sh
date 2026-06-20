#!/bin/bash
##########################################################################
#  Netch VPN — panel theme overlay applier
#  Copies the Netch glassmorphism / brand-token files over a 3x-ui source
#  checkout's frontend, so a `npm run build` produces a themed panel.
#
#  Usage:
#    bash apply.sh /path/to/3x-ui            # repo root (contains frontend/)
#    bash apply.sh /path/to/3x-ui/frontend   # or the frontend dir directly
##########################################################################
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
[[ -z "$TARGET" ]] && { echo "Usage: bash apply.sh /path/to/3x-ui"; exit 1; }
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET"; exit 1; }

# Accept either the repo root or the frontend dir.
if [[ -d "$TARGET/frontend/src" ]]; then
    FE="$TARGET/frontend"
elif [[ -d "$TARGET/src" ]]; then
    FE="$TARGET"
else
    echo "Could not find a 3x-ui frontend (looked for frontend/src or src) under: $TARGET"
    exit 1
fi

OVERLAY="$HERE/frontend/src"
declare -a FILES=(
  "hooks/useTheme.tsx"
  "styles/page-shell.css"
  "styles/page-cards.css"
)

echo "Applying Netch panel theme overlay to: $FE/src"
for f in "${FILES[@]}"; do
    dest="$FE/src/$f"
    if [[ ! -f "$dest" ]]; then
        echo "  ! upstream file missing (3x-ui version mismatch?): src/$f"
        echo "    Review manually — the overlay targets the current 3x-ui frontend layout."
        continue
    fi
    cp -f "$dest" "$dest.netch-bak" 2>/dev/null || true
    cp -f "$OVERLAY/$f" "$dest"
    echo "  + src/$f   (backup: src/$f.netch-bak)"
done

echo
echo "Done. Next:"
echo "  cd $FE && npm ci && npm run build"
echo "Then rebuild the Go binary (or replace the bundled web assets) and serve"
echo "that build instead of the stock 3x-ui release. See panel-theme/README.md."
