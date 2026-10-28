#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

QUALITY="${QUALITY:-3}"
DRY_RUN="${DRY_RUN:-false}"
REMOVE_OPUS="${REMOVE_OPUS:-false}"
ASSUME_YES="${ASSUME_YES:-false}"

usage() {
    cat <<'EOF'
Usage: tools/convert_opus_to_ogg.sh [options]

Converts every .opus under asset/drumSfx and Songs to .ogg (44100 Hz stereo).
An .ogg that already exists is skipped, not re-encoded.

Options:
  -r, --remove-opus   Delete the .opus source once a valid .ogg exists.
                      Only applies to Songs/ -- the git-tracked
                      asset/drumSfx/*.opus originals are always kept.
                      Covers both freshly converted and already-converted files.
  -y, --yes           Do not ask for confirmation before deleting.
  -h, --help          Show this help.

Environment (overridden by the options above):
  QUALITY=3           Vorbis quality (-q) for oggenc/libvorbis.
  DRY_RUN=false       true = list actions without writing or deleting.
  REMOVE_OPUS=false   Same as --remove-opus.
  ASSUME_YES=false    Same as --yes.

A delete only happens if the .ogg is non-empty and starts with the OggS magic
bytes, and the removal is confirmed once before the first deletion.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -r|--remove-opus) REMOVE_OPUS=true ;;
        -y|--yes)         ASSUME_YES=true ;;
        -h|--help)        usage; exit 0 ;;
        *)                echo "Error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

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

if ! command -v vorbiscomment >/dev/null 2>&1; then
    echo "Note: vorbiscomment not found. Install vorbis-tools to strip invalid Ogg comments."
fi

strip_ogg_comments() {
    if command -v vorbiscomment >/dev/null 2>&1; then
        vorbiscomment -w -c /dev/null "$1" 2>/dev/null || true
    fi
}

CONFIRMED=false
DECLINED=false
count=0
skipped=0
removed=0
kept=0

# Solo se borran fuentes .opus de Songs/; los .opus de asset/drumSfx estan
# versionados en git y son el original de la conversion, asi que se conservan.
is_removable_path() {
    case "$1" in
        Songs/*) return 0 ;;
        *)       return 1 ;;
    esac
}

is_valid_ogg() {
    [ -s "$1" ] || return 1
    [ "$(head -c 4 -- "$1" 2>/dev/null || true)" = "OggS" ]
}

confirm_removal() {
    if [ "$ASSUME_YES" = "true" ] || [ "$CONFIRMED" = "true" ]; then
        return 0
    fi
    if [ "$DECLINED" = "true" ]; then
        return 1
    fi
    echo
    printf 'About to delete .opus sources under Songs/ (replaced by .ogg). Type yes to continue: ' >&2
    local answer=""
    # 2>/dev/null va antes del redirect de entrada para tapar el error del
    # propio shell cuando no hay terminal de control; sin respuesta se cancela.
    read -r answer 2>/dev/null < /dev/tty || true
    if [ "$answer" != "yes" ]; then
        echo "Not confirmed; .opus sources will be kept." >&2
        DECLINED=true
        return 1
    fi
    CONFIRMED=true
    return 0
}

maybe_remove_opus() {
    local opus="$1"
    local ogg="${opus%.opus}.ogg"

    if [ "$REMOVE_OPUS" != "true" ]; then
        return 0
    fi
    if ! is_removable_path "$opus"; then
        echo "KEEP (tracked source): $opus"
        kept=$((kept + 1))
        return 0
    fi
    if [ "$DRY_RUN" = "true" ]; then
        # En dry-run el .ogg puede no existir todavia porque la conversion no
        # se ejecuto, asi que un .ogg ausente se considera "se creara".
        if [ ! -e "$ogg" ] || is_valid_ogg "$ogg"; then
            echo "DRY-RUN: would remove $opus"
        else
            echo "KEEP (no valid .ogg): $opus"
            kept=$((kept + 1))
        fi
        return 0
    fi
    if ! is_valid_ogg "$ogg"; then
        echo "KEEP (no valid .ogg): $opus"
        kept=$((kept + 1))
        return 0
    fi
    if ! confirm_removal; then
        echo "KEEP (not confirmed): $opus"
        kept=$((kept + 1))
        return 0
    fi
    rm -f -- "$opus"
    echo "REMOVE: $opus"
    removed=$((removed + 1))
}

while IFS= read -r -d '' opus; do
    ogg="${opus%.opus}.ogg"
    if [ -f "$ogg" ]; then
        echo "SKIP (exists): $ogg"
        strip_ogg_comments "$ogg"
        skipped=$((skipped + 1))
        maybe_remove_opus "$opus"
        continue
    fi
    if [ "$DRY_RUN" = "true" ]; then
        echo "DRY-RUN: $opus -> $ogg"
        count=$((count + 1))
        maybe_remove_opus "$opus"
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
    strip_ogg_comments "$ogg"
    count=$((count + 1))
    maybe_remove_opus "$opus"
done < <(find asset/drumSfx Songs -name '*.opus' -not -path '*/.*' -print0 2>/dev/null)

if [ "$REMOVE_OPUS" = "true" ]; then
    echo "Done. Converted $count files (skipped $skipped, removed $removed .opus, kept $kept)."
else
    echo "Done. Converted $count files (skipped $skipped)."
fi
