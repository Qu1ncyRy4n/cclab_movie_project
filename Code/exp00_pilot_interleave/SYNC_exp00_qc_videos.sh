#!/usr/bin/env bash
# Cache only the source videos named in a QC sheet before local VLC review.
# Usage: ./SYNC_exp00_qc_videos.sh /path/to/qc_source_windows.csv [local_video_all]
set -euo pipefail

qc_csv="${1:?Usage: $0 /path/to/qc_source_windows.csv [/path/to/local/video_all]}"
source_root="/Volumes/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all"
destination_root="${2:-$HOME/Desktop/video_ebm_dataset/video_all}"

[[ -f "$qc_csv" ]] || { printf 'QC CSV not found: %s\n' "$qc_csv" >&2; exit 1; }
[[ -d "$source_root" ]] || { printf 'NAS video folder not found: %s\n' "$source_root" >&2; exit 1; }
mkdir -p "$destination_root"

synced=0
while IFS=, read -r video _; do
    [[ "$video" == 'Video' ]] && continue
    [[ -n "$video" ]] || continue
    source_file="$source_root/$video"
    destination_file="$destination_root/$video"
    [[ -f "$source_file" ]] || { printf 'NAS video missing: %s\n' "$source_file" >&2; exit 1; }
    printf 'syncing  %s\n' "$video"
    rsync -a --partial --progress "$source_file" "$destination_file"
    synced=$((synced + 1))
done < "$qc_csv"

printf 'Local QC cache ready: %s (%d files checked)\n' "$destination_root" "$synced"
