#!/usr/bin/env bash
# probe_durations.sh — ffprobe every video in video_all, emit durations.csv
#
# Answers the exp_01 blocking question: are all videos 30 s, and are the
# social clips really 3 x 10 s? Run wherever the videos actually live
# (WSL box or lab rig), then commit the CSV — it is small and is the
# evidence for the split plan.
#
# Usage:
#   bash probe_durations.sh                       # default SRC below
#   bash probe_durations.sh /path/to/video_all    # explicit dir
#   bash probe_durations.sh --selftest            # verify ffprobe parsing

set -euo pipefail

SRC="/mnt/c/Users/qmryan/Desktop/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all"
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/video_ebm_dataset/durations.csv"

probe_one() {
    # filename,duration_s,width,height,fps,nb_frames
    ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,avg_frame_rate,nb_frames:format=duration \
        -of default=noprint_wrappers=1:nokey=0 "$1" 2>/dev/null |
    awk -v f="$(basename "$1")" -F= '
        {v[$1]=$2}
        END {
            fps = v["avg_frame_rate"]
            if (split(fps, p, "/") == 2 && p[2] != 0) fps = p[1] / p[2]
            printf "%s,%.3f,%s,%s,%.3f,%s\n", f, v["duration"], v["width"], v["height"], fps, v["nb_frames"]
        }'
}

if [[ "${1:-}" == "--selftest" ]]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    ffmpeg -v error -y -f lavfi -i testsrc=duration=2:size=320x240:rate=25 "$tmp/t.mp4"
    row=$(probe_one "$tmp/t.mp4")
    echo "selftest row: $row"
    IFS=, read -r _ dur w h fps _ <<< "$row"
    awk -v d="$dur" 'BEGIN{if (d < 1.9 || d > 2.1) {print "FAIL duration: " d; exit 1}}'
    [[ "$w" == "320" && "$h" == "240" ]] || { echo "FAIL dims: ${w}x${h}"; exit 1; }
    awk -v f="$fps" 'BEGIN{if (f < 24.9 || f > 25.1) {print "FAIL fps: " f; exit 1}}'
    echo "selftest OK"
    exit 0
fi

[[ $# -ge 1 ]] && SRC="$1"
[[ -d "$SRC" ]] || { echo "Not a directory: $SRC" >&2; exit 1; }

# Resume: the CSV is the progress ledger. Over the VPN this takes minutes and
# the mount can drop; re-running skips whatever is already recorded.
if [[ -s "$OUT" ]]; then
    echo "Resuming — $(( $(wc -l < "$OUT") - 1 )) rows already in $OUT" >&2
else
    echo "filename,duration_s,width,height,fps,nb_frames" > "$OUT"
fi

n=0; skipped=0
while IFS= read -r f; do
    base=$(basename "$f")
    if grep -qF "$base," "$OUT"; then skipped=$((skipped+1)); continue; fi
    probe_one "$f" >> "$OUT"
    n=$((n+1))
    (( n % 50 == 0 )) && echo "  ...$n probed" >&2
done < <(find "$SRC" -maxdepth 1 \( -name '*.mp4' -o -name '*.mpg' \) | sort)

echo "Probed $n files ($skipped already done) -> $OUT" >&2
echo "" >&2
echo "Duration histogram (rounded to 1 s):" >&2
tail -n +2 "$OUT" | awk -F, '{printf "%.0f\n", $2}' | sort -n | uniq -c | sort -rn | head -20 >&2
