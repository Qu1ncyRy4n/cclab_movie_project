#!/usr/bin/env bash
# Generate a disjoint candidate, cache its videos locally, then run VLC review.
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
"$script_dir/SYNC_exp00_qc_videos.sh" "$output_dir/qc_source_windows.csv" "$video_root"
"$script_dir/REVIEW_exp00_windows.sh" "$output_dir/qc_source_windows.csv" "$video_root"
