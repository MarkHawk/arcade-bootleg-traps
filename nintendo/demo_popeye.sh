#!/usr/bin/env bash
# demo_popeye.sh ROM_FOLDER: Popeye's high-score ROM sum. Genuine popeye against the same set with one unused ROM byte
# changed (0x76F0, FF -> FE, written into MAME's decrypted copy of the program at frame 30: the ROM files are
# encrypted, so no zip is edited). Same inputs; the score is poked to 05xxxx so that a top-five name entry follows the
# game over. After it the edited board's sum fails and its lives setting becomes 4 (a random 1 to 4; MAME gives 4
# every time here). The next game: genuine 3 lives, edited 4 (shown as "=2" against "=3" on Olive's house).
# Runs through scripts/mame.sh (about 40 seconds). Logs, snapshots and the GIF go to nintendo/out/ (not committed).
# Needs MAME (0.285 used, 0.277 ROM sets) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: nintendo/demo_popeye.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
mkdir -p nintendo/out
run() {  # name edit
  rm -rf "nintendo/out/popeye_$1"; mkdir -p "nintendo/out/popeye_$1"
  POP_EDIT=$2 POP_LOG=$PWD/nintendo/out/popeye_$1.log scripts/mame.sh 300 popeye -rompath "$ROMS" -nothrottle \
    -seconds_to_run 135 -snapshot_directory "nintendo/out/popeye_$1" -autoboot_script nintendo/popeye_lives.lua \
    > "nintendo/out/popeye_$1.txt" 2>&1 || true
}
run genuine 0 & run edited 1 & wait
for s in genuine edited; do echo "== $s"; grep -v "^SNAP" "nintendo/out/popeye_$s.log"; done
GIF_FOOTER="Score poked to 50,800. After the name entry the edited board's ROM sum fails: lives setting 3 -> 4 (random 1-4)." \
python3 scripts/gif_pair.py nintendo/out/popeye_genuine.log nintendo/out/popeye_genuine/popeye "genuine popeye f{f}" \
  nintendo/out/popeye_edited.log nintendo/out/popeye_edited/popeye "one unused ROM byte changed f{f}" \
  nintendo/out/popeye_lives_pair.gif 6960-7500
