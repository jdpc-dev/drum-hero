#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

QUALITY="${QUALITY:-3}"
DRY_RUN="${DRY_RUN:-false}"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found. Install it and try again." >&2
    exit 1
fi

count=0
skipped=0
while IFS= read -r -d '' opus; do
    ogg="${opus%.opus}.ogg"
    if [ -f "$ogg" ]; then
        echo "SKIP (exists): $ogg"
        skipped=$((skipped + 1))
        continue
    fi
    if [ "$DRY_RUN" = "true" ]; then
        echo "DRY-RUN: $opus -> $ogg"
    else
        echo "CONVERT: $opus -> $ogg"
        ffmpeg -hide_banner -loglevel warning -y -i "$opus" -c:a libvorbis -q:a "$QUALITY" "$ogg" </dev/null
    fi
    count=$((count + 1))
done < <(find asset/drumSfx Songs -name '*.opus' -not -path '*/.*' -print0 2>/dev/null)

echo "Done. Converted $count files (skipped $skipped)."