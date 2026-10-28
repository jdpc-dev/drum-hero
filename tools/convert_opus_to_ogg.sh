#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

QUALITY="${QUALITY:-3}"
DRY_RUN="${DRY_RUN:-false}"

USE_OPUSDEC=false
if command -v opusdec >/dev/null 2>&1 && command -v oggenc >/dev/null 2>&1; then
    USE_OPUSDEC=true
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found. Install it and try again." >&2
    exit 1
fi

if ! "$USE_OPUSDEC" && ! command -v opusdec >/dev/null 2>&1; then
    echo "Note: opusdec not found. Install opus-tools for best compatibility."
    echo "      Using ffmpeg with two-step decode instead."
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
        count=$((count + 1))
        continue
    fi

    echo "CONVERT: $opus -> $ogg"

    if "$USE_OPUSDEC"; then
        # opusdec correctly handles Opus pre-skip
        # oggenc gives clean Vorbis encoding with explicit target sample rate
        tmp_wav="$(mktemp --tmpdir opus2wav_XXXXXX.wav)"
        opusdec --force-wav "$opus" "$tmp_wav"
        oggenc -q "$QUALITY" --resample 44100 -o "$ogg" "$tmp_wav"
        rm -f "$tmp_wav"
    else
        # Two-step ffmpeg: decode Opus→WAV (handles pre-skip), then encode WAV→OGG at 44100Hz
        # Forcing 44100 Hz matches the sample rate of all working original .ogg songs
        tmp_wav="$(mktemp --tmpdir opus2wav_XXXXXX.wav)"
        ffmpeg -hide_banner -loglevel warning -y -i "$opus" \
            -c:a pcm_s16le -ar 44100 -ac 2 "$tmp_wav" </dev/null
        ffmpeg -hide_banner -loglevel warning -y -i "$tmp_wav" \
            -c:a libvorbis -q:a "$QUALITY" -ar 44100 "$ogg" </dev/null
        rm -f "$tmp_wav"
    fi
    count=$((count + 1))
done < <(find asset/drumSfx Songs -name '*.opus' -not -path '*/.*' -print0 2>/dev/null)

echo "Done. Converted $count files (skipped $skipped)."
