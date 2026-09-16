#!/usr/bin/env bash
# catalog_cuts.sh — per-video catalog of KEYFRAMES and SCENE CUTS.
#
# This is the evidence for the exp_01 segment design: where a video can be
# seeked to (keyframes) and where its content actually changes (scene cuts).
#
# COST: unlike probe_durations.sh, this reads EVERY BYTE of every file.
# The dataset is 5.5 GB.
#   - on the LAN / a lab box: ~2 minutes
#   - over the VPN at ~430 KB/s: ~3.6 HOURS
# Run it where the files are. It is resumable — cuts.csv is its own progress
# ledger, so a dropped mount costs you one file, not the whole run.
#
# Usage:
#   bash catalog_cuts.sh                        # default SRC below
#   bash catalog_cuts.sh /path/to/video_all
#   bash catalog_cuts.sh --selftest             # verify detection logic
#
# Output: video_ebm_dataset/cuts.csv
#   filename,keyframes,scene_cuts,scene_scores
#   semicolon-separated time lists, seconds

set -euo pipefail

SRC="/mnt/c/Users/qmryan/Desktop/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all"
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/video_ebm_dataset/cuts.csv"
THRESH=0.15   # scene score above which a frame counts as a cut

keyframes_of() {
    ffprobe -v error -select_streams v:0 -skip_frame nokey \
        -show_entries frame=pts_time -of csv=p=0 "$1" |
        tr -d ',' | awk '{printf "%.3f;", $1}' | sed 's/;$//'
}

scenecuts_of() {
    # Emits "times|scores" so both land in the CSV from one decode pass.
    ffmpeg -v error -i "$1" -filter:v "select='gt(scene,$THRESH)',metadata=print:file=-" \
        -f null - 2>/dev/null | paste - - |
        sed 's/.*pts_time:\([0-9.]*\).*scene_score=\([0-9.]*\).*/\1 \2/' |
        awk '{t = t sprintf("%.3f;", $1); s = s sprintf("%.3f;", $2)}
             END {sub(/;$/, "", t); sub(/;$/, "", s); printf "%s|%s", t, s}'
}

if [[ "${1:-}" == "--selftest" ]]; then
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    # Two visually distinct halves spliced together: one cut at exactly 2 s.
    # Concat must RE-ENCODE (filter_complex), not stream-copy — a -c copy splice
    # leaves no detectable discontinuity for the scene filter to find.
    ffmpeg -v error -y -f lavfi -i "testsrc=duration=2:size=320x240:rate=25" \
        -g 25 "$tmp/a.mp4"
    ffmpeg -v error -y -f lavfi -i "color=c=white:duration=2:size=320x240:rate=25" \
        -g 25 "$tmp/b.mp4"
    ffmpeg -v error -y -i "$tmp/a.mp4" -i "$tmp/b.mp4" \
        -filter_complex "[0:v][1:v]concat=n=2:v=1[o]" -map "[o]" -g 25 "$tmp/t.mp4"

    cuts=$(scenecuts_of "$tmp/t.mp4"); times=${cuts%%|*}
    keys=$(keyframes_of "$tmp/t.mp4")
    echo "selftest cuts: [$times]  keyframes: [$keys]"
    echo "$times" | awk -F';' '{
        for (i = 1; i <= NF; i++) if ($i > 1.9 && $i < 2.1) { found = 1 }
        if (!found) { print "FAIL: no cut detected near 2.0 s"; exit 1 }
    }'
    [[ -n "$keys" ]] || { echo "FAIL: no keyframes found"; exit 1; }
    echo "selftest OK"
    exit 0
fi

[[ $# -ge 1 ]] && SRC="$1"
[[ -d "$SRC" ]] || { echo "Not a directory: $SRC" >&2; exit 1; }

if [[ -s "$OUT" ]]; then
    echo "Resuming — $(( $(wc -l < "$OUT") - 1 )) files already catalogued" >&2
else
    echo "filename,keyframes,scene_cuts,scene_scores" > "$OUT"
fi

total=$(find "$SRC" -maxdepth 1 -name '*.mp4' | wc -l | tr -d ' ')
echo "Cataloguing up to $total files from $SRC" >&2
echo "This reads every byte — see the cost note at the top of this script." >&2

n=0; skipped=0
while IFS= read -r f; do
    base=$(basename "$f")
    if grep -qF "$base," "$OUT"; then skipped=$((skipped+1)); continue; fi

    keys=$(keyframes_of "$f")
    cuts=$(scenecuts_of "$f")
    times=${cuts%%|*}; scores=${cuts##*|}
    echo "$base,$keys,$times,$scores" >> "$OUT"

    n=$((n+1))
    echo "  [$n] $base — $(echo "$times" | awk -F';' '{print ($1=="" ? 0 : NF)}') cuts" >&2
done < <(find "$SRC" -maxdepth 1 -name '*.mp4' | sort)

echo "Catalogued $n files ($skipped already done) -> $OUT" >&2
echo "" >&2
echo "Cut-count histogram:" >&2
tail -n +2 "$OUT" | awk -F, '{print ($3=="" ? 0 : split($3, a, ";"))}' | sort -n | uniq -c >&2
