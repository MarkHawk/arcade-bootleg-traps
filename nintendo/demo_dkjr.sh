#!/usr/bin/env bash
# demo_dkjr.sh ROM_FOLDER: Donkey Kong Jr.'s copyright check, three runs with the same fixed inputs (walk right, jump
# at the first vine, hold Up; nintendo/dkjr_vine.lua):
#   jrking   a working bootleg whose copyright line is blanked in the graphics ROM: the checked bytes are intact,
#            the check sums to 00 and Jr. climbs
#   edited   genuine dkongjr with one checked tile changed (#37FC, file djr1-c_5b_f-2.5b +17FC, C6 -> C7), built
#            from your own dkongjr.zip by scripts/patchzip.py: the check sums to 01, the vine table at #6300 is left
#            empty and Jr. drops back to the ground
#   genuine  unpatched dkongjr (control): climbs
# Runs through scripts/mame.sh (the edited zip alone on the rompath; about 20 seconds). Logs, snapshots and the GIF go
# to nintendo/out/ (not committed). Needs MAME (0.285 used, 0.277 ROM sets) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: nintendo/demo_dkjr.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
EDIT=$(python3 scripts/patchzip.py "$ROMS" dkongjr djr1-c_5b_f-2.5b:17FC:C6:C7)
trap 'rm -rf "$EDIT"' EXIT
mkdir -p nintendo/out
export DKJR_SCRIPT="R:30,RJ:2,U:200" DKJR_SEQ=1140-1320 DKJR_STEP=3
run() {  # name set rompath
  rm -rf "nintendo/out/dkjr_$1"; mkdir -p "nintendo/out/dkjr_$1"
  DKJR_LOG=$PWD/nintendo/out/dkjr_$1.log scripts/mame.sh 120 "$2" -rompath "$3" -nothrottle -seconds_to_run 30 \
    -snapshot_directory "nintendo/out/dkjr_$1" -autoboot_script nintendo/dkjr_vine.lua > "nintendo/out/dkjr_$1.txt" 2>&1 || true
}
run jrking jrking "$ROMS" & run edited dkongjr "$EDIT" & run genuine dkongjr "$ROMS" & wait
for s in jrking edited genuine; do
  echo "== $s"; grep -h "LOADED\|CHECK\|PLAY\| t\(40\|100\|200\) " "nintendo/out/dkjr_$s.log"
done
GIF_FOOTER="Same inputs on both: walk right, jump at the vine, hold Up." python3 scripts/gif_pair.py \
  nintendo/out/dkjr_jrking.log nintendo/out/dkjr_jrking/jrking "bootleg jrking (no copyright line) f{f}" \
  nintendo/out/dkjr_edited.log nintendo/out/dkjr_edited/dkongjr "genuine, one checked tile changed f{f}" \
  nintendo/out/dkjr_jrking_pair.gif 1140-1320
