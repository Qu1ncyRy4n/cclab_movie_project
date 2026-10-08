#!/usr/bin/env bash
# Stage a portable Windows rig package directly from macOS to the mounted NAS.
# Usage:
#   BENCH=/path/to/mat_vs_py_bench ./stage_to_nas.sh [destination]
# The default destination gets a timestamped folder under /Volumes/cclab.
set -euo pipefail

MOVIE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${BENCH:-}" ]]; then
    for candidate in "$MOVIE/../../research_infra/mat_vs_py_bench" "$HOME/dev/research/research_infra/mat_vs_py_bench"; do
        if [[ -d "$candidate/.git" ]]; then
            BENCH="$candidate"
            break
        fi
    done
fi
if [[ -z "${BENCH:-}" || ! -d "$BENCH/.git" ]]; then
    echo "Set BENCH to the mat_vs_py_bench checkout." >&2
    exit 1
fi
BENCH="$(cd "$BENCH" && pwd)"

NAS_ROOT="/Volumes/cclab/shared/experiment_packages"
DESTINATION="${1:-$NAS_ROOT/exp00_$(date +%Y-%m-%d_%H%M%S)}"
if [[ ! -d "$NAS_ROOT" ]]; then
    echo "NAS is not mounted at $NAS_ROOT." >&2
    exit 1
fi
if [[ -e "$DESTINATION" ]]; then
    echo "Destination already exists: $DESTINATION" >&2
    exit 1
fi

for repo in "$MOVIE" "$BENCH"; do
    if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        echo "Uncommitted changes in $repo; commit or stash them first:" >&2
        git -C "$repo" status --short >&2
        exit 1
    fi
done

git -C "$MOVIE" submodule update --init --recursive
if [[ ! -f "$MOVIE/Code/cclab-matlab-tools/cclabInitDIO.m" ]]; then
    echo "cclab-matlab-tools could not be initialized." >&2
    exit 1
fi

mkdir -p "$DESTINATION/cclab_movie_project" "$DESTINATION/mat_vs_py_bench"
EXCLUDES=(
    --exclude .git --exclude .venv --exclude .direnv --exclude __pycache__
    # Pilot recordings and other run outputs remain local to the rig.
    --exclude .DS_Store --exclude 'data/' --exclude 'results/' --exclude 'Output_*'
)
rsync -a --delete "${EXCLUDES[@]}" "$MOVIE/" "$DESTINATION/cclab_movie_project/"
rsync -a --delete "${EXCLUDES[@]}" "$BENCH/" "$DESTINATION/mat_vs_py_bench/"

for staged_data in "$DESTINATION/cclab_movie_project/data" "$DESTINATION/mat_vs_py_bench/data"; do
    if [[ -d "$staged_data" ]] && [[ -n "$(find "$staged_data" -mindepth 1 -print -quit)" ]]; then
        echo "Refusing to publish local data files: $staged_data" >&2
        exit 1
    fi
done

cp "$MOVIE/rig_package/Install-CCLabRig.ps1" "$DESTINATION/"
cp "$MOVIE/rig_package/video_folder.txt" "$DESTINATION/"
for launcher in "$MOVIE"/rig_package/?_*.cmd "$MOVIE"/rig_package/Install-CCLabRig.cmd; do
    cp "$launcher" "$DESTINATION/"
done

cat > "$DESTINATION/README.txt" <<'EOF'
CCLab exp_00 Rig Package
========================

On the Windows experiment computer, run Install-CCLabRig.cmd from this folder.
It copies code locally and requires no GitHub or WSL setup on the rig.
EOF

printf 'Portable package created: %s\n' "$DESTINATION"
