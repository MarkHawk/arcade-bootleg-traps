#!/usr/bin/env bash
# demo.sh N ROM_FOLDER: run konami/demo_checkN.lua (N = 1 or 2) on the genuine trackfldu and on the
# one-byte edit built by konami/build_roms.py, side by side, each with a fresh, empty NVRAM.
# Run from the repo root. Prints both logs; logs and snapshots go to konami/out/ (not committed).
#   python3 konami/build_roms.py ~/roms
#   konami/demo.sh 2 ~/roms
# Extra environment: TF_SEQ="from-to,..." also snapshots every 4 frames in those windows.
set -euo pipefail
N=${1:?usage: konami/demo.sh N ROM_FOLDER}; ROMS=${2:?usage: konami/demo.sh N ROM_FOLDER}
cd "$(dirname "$0")/.."
[ -d "konami/roms/check$N/trackfldu" ] || { echo "build the edited ROMs first: python3 konami/build_roms.py $ROMS"; exit 1; }
mkdir -p konami/out
run() {
  local side=$1 rp=$2 st
  st=$(mktemp -d)                                  # fresh NVRAM and config for every run
  rm -rf "konami/out/check${N}_$side"; mkdir -p "konami/out/check${N}_$side"
  TF_SIDE=$side TF_OUT=konami/out timeout -s KILL 900 mame trackfldu -rompath "$rp" -video none -sound none \
    -nothrottle -skip_gameinfo -debug -debugger none -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" \
    -diff_directory "$st/diff" -snapshot_directory "konami/out/check${N}_$side" \
    -autoboot_script "konami/demo_check$N.lua" -seconds_to_run 600 > "konami/out/check${N}_$side.txt" 2>&1 || true
  rm -rf "$st"
}
run genuine "$ROMS" &
run edited "konami/roms/check$N;$ROMS" &
wait
for side in genuine edited; do
  echo "== $side"; grep -v "SNAP" "konami/out/demo_check${N}_$side.log"
done
