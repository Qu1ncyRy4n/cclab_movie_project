#!/usr/bin/env bash
# Stage a portable rig package on the NAS from the lab computer (WSL).
# Checks both repositories are clean, pulls them, initializes the MATLAB-tools
# submodule, then runs stage_rig_package.ps1 through Windows PowerShell.
# Extra arguments pass through, e.g. ./stage_to_nas.sh -Destination E:\pkg
set -euo pipefail

MOVIE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="${BENCH:-$MOVIE/../../research_infra/mat_vs_py_bench}"
BENCH="$(cd "$BENCH" && pwd)"

for repo in "$MOVIE" "$BENCH"; do
    if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        echo "Uncommitted changes in $repo; commit or stash them first:" >&2
        git -C "$repo" status --short >&2
        exit 1
    fi
    echo "== pull $(basename "$repo")"
    git -C "$repo" pull --ff-only
done
git -C "$MOVIE" submodule update --init --recursive

powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(wslpath -w "$MOVIE/stage_rig_package.ps1")" \
    -BenchSource "$(wslpath -w "$BENCH")" "$@"
