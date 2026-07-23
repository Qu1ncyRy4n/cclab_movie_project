#!/usr/bin/env bash
# encode_mp4.sh — re-encode all .mpg files in video_all to H.264 .mp4
#
# Run from WSL. Output goes to a sibling folder (video_all_mp4/) so originals
# are untouched. Copy video_all_mp4/ contents to the NAS when done.
#
# Usage:
#   bash encode_mp4.sh
#   bash encode_mp4.sh --crf 18        # higher quality / larger files
#   bash encode_mp4.sh --jobs 4        # parallel encodes (default: 2)

set -euo pipefail

SRC="/mnt/c/Users/qmryan/Desktop/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all"
DST="/mnt/c/Users/qmryan/Desktop/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all_mp4"
CRF=20
JOBS=2

# Parse optional args
while [[ $# -gt 0 ]]; do
    case $1 in
        --crf)   CRF="$2";  shift 2 ;;
        --jobs)  JOBS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$DST"

encode_one() {
    local src="$1"
    local base
    base=$(basename "$src" .mpg)
    local dst="$DST/${base}.mp4"

    if [[ -f "$dst" ]]; then
        if ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
                -of default=noprint_wrappers=1 "$dst" &>/dev/null; then
            echo "[skip] $base.mp4 already exists and is valid"
            return
        else
            echo "[redo] $base.mp4 exists but is corrupt/incomplete — re-encoding"
        fi
    fi

    echo "[encode] $base.mpg → $base.mp4"
    ffmpeg -y -i "$src" \
        -c:v libx264 -crf "$CRF" -preset slow \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        "$dst" \
        -loglevel error -stats
}

export -f encode_one
export DST CRF

total=$(find "$SRC" -maxdepth 1 -name '*.mpg' | wc -l)
echo "Found $total .mpg files. Encoding to CRF $CRF with $JOBS parallel jobs..."
echo "Output: $DST"
echo ""

find "$SRC" -maxdepth 1 -name '*.mpg' | \
    xargs -P "$JOBS" -I{} bash -c 'encode_one "$@"' _ {}

echo ""
echo "Done. Encoded files in: $DST"
echo "Copy to NAS with:"
echo "  cp -r \"$DST\"/* \"/path/to/nas/video_all/\""
