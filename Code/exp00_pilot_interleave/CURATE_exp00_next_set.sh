#!/usr/bin/env bash
# Generate a disjoint candidate, cache its videos locally, then run VLC review.
# Rejected sources are replaced in place until every QC window passes.
# Usage: ./CURATE_exp00_next_set.sh [/path/to/local/video_all]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
matlab_bin="${MATLAB_BIN:-/Applications/MATLAB_R2025a.app/bin/matlab}"
video_root="${1:-$HOME/Desktop/video_ebm_dataset/video_all}"
timestamp="$(date +%Y-%m-%d_%H%M%S)"
output_dir="$script_dir/Output_exp00_session_plan/$timestamp"

[[ -x "$matlab_bin" ]] || { printf 'MATLAB not found: %s\n' "$matlab_bin" >&2; exit 1; }
[[ ! -e "$output_dir" ]] || { printf 'Candidate output already exists: %s\n' "$output_dir" >&2; exit 1; }

"$matlab_bin" -batch "cd('$script_dir'); PREPARE_exp00_session_plan('$output_dir');"
while true; do
    "$script_dir/SYNC_exp00_qc_videos.sh" "$output_dir/qc_source_windows.csv" "$video_root"

    set +e
    "$script_dir/REVIEW_exp00_windows.sh" "$output_dir/qc_source_windows.csv" "$video_root"
    review_status=$?
    set -e
    case "$review_status" in
        0) ;;
        2)
            printf 'Review quit by operator; candidate retained without replacements: %s\n' "$output_dir"
            exit 0
            ;;
        3)
            printf 'Some QC windows were skipped; reopening review before replacing sources.\n'
            continue
            ;;
        *)
            printf 'Review failed with status %d; candidate retained: %s\n' "$review_status" "$output_dir" >&2
            exit "$review_status"
            ;;
    esac

    set +e
    "$matlab_bin" -batch "cd('$script_dir'); replacementCount = REPLACE_exp00_rejected_sources('$output_dir'); if replacementCount == 0, exit(10); end"
    replacement_status=$?
    set -e
    if [[ "$replacement_status" == 10 ]]; then
        printf 'All 36 QC windows passed: %s\n' "$output_dir"
        break
    fi
    if [[ "$replacement_status" != 0 ]]; then
        printf 'Replacement preparation failed; candidate retained: %s\n' "$output_dir" >&2
        exit "$replacement_status"
    fi
    printf 'Replacement QC windows prepared; syncing and reviewing replacements.\n'
done
