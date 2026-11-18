#!/usr/bin/env bash
# demo_mayday.sh ROM_FOLDER: Hoei's Mayday (set `maydaya`), with MAME's answer to the protection reads ("with chip")
# against a Lua read tap that returns plain RAM instead ("no chip"), switched on at frame 3000, after the attract-mode
# check has passed. No ROM is changed: both sides load an unchanged copy of your own mayday.zip (scripts/patchzip.py,
# "-"). The same scripted game on both; at the first object destroyed the no-chip side reads $00 against $62 at $EEC0
# and the picture freezes from then on; the side with the chip plays on.
# Runs through scripts/mame.sh (a minute or so). Logs, snapshots and the GIF go to williams/out/ (not committed).
# Needs MAME (0.285 used, 0.277 ROM sets) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: williams/demo_mayday.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
GEN=$(python3 scripts/patchzip.py "$ROMS" mayday -)
trap 'rm -rf "$GEN"' EXIT
mkdir -p williams/out
run() {  # name nochip
  rm -rf "williams/out/maydaya_$1"; mkdir -p "williams/out/maydaya_$1"
  MAYDAY_NOCHIP=$2 scripts/mame.sh 900 maydaya -rompath "$GEN" -nothrottle -debug -debugger none -seconds_to_run 160 \
    -snapshot_directory "williams/out/maydaya_$1" -autoboot_script williams/mayday_nochip.lua 2>&1 \
    | grep "^\[lua\]" > "williams/out/maydaya_$1.log" || true
}
run chip 0 & run nochip 1 & wait
for s in chip nochip; do echo "== $s"; grep -v "SNAP" "williams/out/maydaya_$s.log"; done
python3 scripts/gif_pair.py williams/out/maydaya_chip.log williams/out/maydaya_chip/maydaya "maydaya, protection answered f{f}" \
  williams/out/maydaya_nochip.log williams/out/maydaya_nochip/maydaya "maydaya, no chip f{f}" \
  williams/out/maydaya-nochip-pair.gif 4900-5400
