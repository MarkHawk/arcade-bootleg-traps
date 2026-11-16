#!/usr/bin/env bash
# demo_tp84.sh onebyte|sumkept ROM_FOLDER: run konami/demo_tp84.lua on the genuine Time Pilot '84 (tp84) and on an
# edited set built by konami/build_tp84.py, side by side, each with a fresh, empty NVRAM folder.
#   onebyte  "KONAMI" -> "KNNAMI": the board's power-on ROM test catches it ("ROM2 BAD"); the game never starts
#   sumkept  the same edit plus the year's last digit, so the ROM sums still add up: the hidden checks fire
# Run from the repo root (about two minutes). Prints both logs; logs and snapshots go to konami/out/ (not committed).
#   python3 konami/build_tp84.py ~/roms
#   konami/demo_tp84.sh sumkept ~/roms
#   python3 konami/gif_pair.py ...     (optional side-by-side GIF; see docs/konami-time-pilot-84.md#rerun)
# Extra environment: TF_POKE (frame of the $5235 poke, default 1000), TF_FRAMES (default 2200),
# TF_SEQ_A/TF_SEQ_B and TF_SEQ2_A/TF_SEQ2_B: frame windows to snapshot every frame (sumkept: 975-1035 and
# 2000-2001; onebyte: 300).
set -euo pipefail
V=${1:?usage: konami/demo_tp84.sh onebyte|sumkept ROM_FOLDER}; ROMS=${2:?usage: konami/demo_tp84.sh onebyte|sumkept ROM_FOLDER}
cd "$(dirname "$0")/.."
case $V in onebyte|sumkept) ;; *) echo "variant must be onebyte or sumkept"; exit 1;; esac
[ -d "konami/roms/tp84_$V/tp84" ] || { echo "build the edited ROMs first: python3 konami/build_tp84.py $ROMS"; exit 1; }
mkdir -p konami/out
if [ "$V" = onebyte ]; then : "${TF_SEQ_A:=300}" "${TF_SEQ_B:=300}"; else : "${TF_SEQ_A:=975}" "${TF_SEQ_B:=1035}" "${TF_SEQ2_A:=2000}" "${TF_SEQ2_B:=2001}"; fi
export TF_SEQ_A TF_SEQ_B TF_SEQ2_A=${TF_SEQ2_A:-0} TF_SEQ2_B=${TF_SEQ2_B:--1} TF_FRAMES=${TF_FRAMES:-2200} TF_POKE=${TF_POKE:-1000}
run() {
  local side=$1 rp=$2 st
  st=$(mktemp -d)                                  # fresh NVRAM and config for every run
  rm -rf "konami/out/tp84_${V}_$side"; mkdir -p "konami/out/tp84_${V}_$side"
  TF_CPU=cpu1 TF_TAG="${V}_$side" TF_OUT=konami/out timeout -s KILL 900 mame tp84 -rompath "$rp" -video none -sound none \
    -nothrottle -skip_gameinfo -debug -debugger none -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" \
    -diff_directory "$st/diff" -snapshot_directory "konami/out/tp84_${V}_$side" \
    -autoboot_script konami/demo_tp84.lua -seconds_to_run 300 > "konami/out/tp84_${V}_$side.txt" 2>&1 || true
  rm -rf "$st"
}
run genuine "$ROMS" &
run edited "konami/roms/tp84_$V;$ROMS" &
wait
for side in genuine edited; do
  echo "== $side"; grep -v "SNAP\|re-run\|FIRST CHANGE" "konami/out/tp84_${V}_$side.log" | cut -c1-200
done
