#!/usr/bin/env bash
# Play each QC window in macOS VLC and record a resumable manual review.
# Usage: ./REVIEW_exp00_windows.sh /path/to/qc_source_windows.csv /path/to/video_all
set -euo pipefail

qc_csv="${1:?Usage: $0 /path/to/qc_source_windows.csv [/path/to/video_all]}"
video_root="${2:-$HOME/Desktop/video_ebm_dataset/video_all}"
vlc="/Applications/VLC.app/Contents/MacOS/VLC"

[[ -f "$qc_csv" ]] || { printf 'QC CSV not found: %s\n' "$qc_csv" >&2; exit 1; }
[[ -d "$video_root" ]] || { printf 'Video folder not found: %s\n' "$video_root" >&2; exit 1; }
[[ -x "$vlc" ]] || { printf 'VLC not found: %s\n' "$vlc" >&2; exit 1; }

review_file="$(dirname "$qc_csv")/qc_review.csv"
if [[ ! -f "$review_file" ]]; then
    printf 'Video,Category,Start_s,End_s,Status,Notes\n' > "$review_file"
fi

while IFS=, read -r video category start_s end_s; do
    [[ "$video" == 'Video' ]] && continue
    [[ -n "$video" ]] || continue
    if rg -Fq "\"$video\",\"$category\",\"$start_s\",\"$end_s\",\"PASS\"" "$review_file" || \
       rg -Fq "\"$video\",\"$category\",\"$start_s\",\"$end_s\",\"REJECT\"" "$review_file"; then
        continue
    fi

    video_file="$video_root/$video"
    [[ -f "$video_file" ]] || { printf 'Video not found: %s\n' "$video_file" >&2; exit 1; }
    duration="$(bc -l <<< "$end_s - $start_s")"
    printf '\n%s: %s, %s to %s s\n' "$category" "$video" "$start_s" "$end_s"
    "$vlc" "--start-time=$start_s" "--run-time=$duration" --play-and-exit --no-video-title-show "$video_file"

    while true; do
        read -r -p 'Result: [p]ass, [r]eject, [s]kip, or [q]uit: ' response
        response="${response,,}"
        case "$response" in
            p) status='PASS'; note=''; break ;;
            r) status='REJECT'; read -r -p 'Brief rejection reason: ' note; break ;;
            s) status='SKIP'; note=''; break ;;
            q) printf 'Review saved: %s\n' "$review_file"; exit 0 ;;
        esac
    done
    note="${note//\"/\"\"}"
    printf '"%s","%s","%s","%s","%s","%s"\n' "$video" "$category" "$start_s" "$end_s" "$status" "$note" >> "$review_file"
done < "$qc_csv"

printf 'Review saved: %s\n' "$review_file"
