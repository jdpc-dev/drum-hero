#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

count=0
while IFS= read -r -d '' opus; do
    ogg="${opus%.opus}.ogg"
    if [ -f "$ogg" ]; then
        echo "SKIP (exists): $ogg"
        continue
    fi
    echo "CONVERT: $opus -> $ogg"
    ffmpeg -y -i "$opus" -c:a libvorbis -q:a 3 "$ogg" 2>/dev/null
    count=$((count + 1))
done < <(find asset/drumSfx Songs -name '*.opus' -not -path '*/.*' -print0 2>/dev/null)

echo "Done. Converted $count files."