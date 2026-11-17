#!/usr/bin/env bash
# demo_sdungeon.sh ROM_FOLDER: Space Dungeon's delayed checksum, genuine against one byte changed in the code that
# prints the copyright ($BDDA, LDY #$2C40 -> #$2C41, file sd15.u15 +0DDA, 40 -> 41), built from your own sdungeon.zip by
# scripts/patchzip.py (with the 68705 device ROM, m68705p3.zip, copied alongside). In the attract demo, with the
# check's counter poked to 63 at frame 4400 and the 64th event natural (frame 4455): genuine sum 6A, nothing happens;
# edited sum 6B, the penalty runs and the thief is drawn as a cut-down shape. No message is printed.
# Runs through scripts/mame.sh (the edited zip alone on the rompath; about 30 seconds). Logs, snapshots and the GIF go
# to taito/out/ (not committed). Needs MAME (0.285 used, 0.277 ROM sets) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: taito/demo_sdungeon.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
GEN=$(python3 scripts/patchzip.py "$ROMS" sdungeon sd15.u15:DDA:40:40 --with m68705p3)   # unchanged copy: loaded the same way
EDIT=$(python3 scripts/patchzip.py "$ROMS" sdungeon sd15.u15:DDA:40:41 --with m68705p3)
trap 'rm -rf "$GEN" "$EDIT"' EXIT
mkdir -p taito/out
run() {  # name rompath
  rm -rf "taito/out/sdungeon_$1"; mkdir -p "taito/out/sdungeon_$1"
  scripts/mame.sh 300 sdungeon -rompath "$2" -nothrottle -debug -debugger none -seconds_to_run 200 \
    -snapshot_directory "taito/out/sdungeon_$1" -autoboot_script taito/sdungeon_delayed.lua 2>&1 \
    | grep "^\[lua\]" > "taito/out/sdungeon_$1.log" || true
}
run genuine "$GEN" & run edited "$EDIT" & wait
for s in genuine edited; do echo "== $s"; grep -v "SNAP" "taito/out/sdungeon_$s.log"; done
python3 scripts/gif_pair.py taito/out/sdungeon_genuine.log taito/out/sdungeon_genuine/sdungeon "Genuine f{f}" \
  taito/out/sdungeon_edited.log taito/out/sdungeon_edited/sdungeon "Copyright-print code changed (counter poked to 63) f{f}" \
  taito/out/sdungeon_delayed_pair.gif 4380-4720
