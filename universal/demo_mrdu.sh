#!/usr/bin/env bash
# demo_mrdu.sh ROM_FOLDER: Mr. Do! (mrdo, genuine) against the bootleg Mr. Du! (mrdu), the same scripted game, up to
# the diamond (SPECIAL) award. Genuine: credits 00 -> 01. mrdu: 00 -> 41 (BCD), because its check B fails.
# No ROM is edited: mrdu is a real dumped bootleg. One RAM write per side, the same on both: the random state at the
# first natural diamond roll (see universal/mrdu_diamond.lua). Runs through scripts/mame.sh (about 30 seconds).
# Logs, snapshots and the GIF go to universal/out/ (not committed). Needs MAME (0.285 used, with 0.277 ROM sets: the
# genuine and bootleg sets are in mrdo.zip, or mrdo.zip plus mrdu.zip in a split set) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: universal/demo_mrdu.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
mkdir -p universal/out
export MRDO_SEED=${MRDO_SEED:-64} MRDO_WIN="6885-6945:3,7470-7510:2"
run() {  # set check-B-address
  rm -rf "universal/out/$1"; mkdir -p "universal/out/$1"
  MRDO_CHK=$2 MRDO_LOG=$PWD/universal/out/$1.log scripts/mame.sh 300 "$1" -rompath "$ROMS" -nothrottle -seconds_to_run 130 \
    -snapshot_directory "universal/out/$1" -autoboot_script universal/mrdu_diamond.lua > "universal/out/$1.txt" 2>&1 || true
}
run mrdo 74BB & run mrdu 74D2 & wait
for s in mrdo mrdu; do echo "== $s"; grep -v "^SNAP" "universal/out/$s.log"; done
# The captions carry the credit count read from RAM (0xE006): the SPECIAL screen shows at most 9.
GIF_FOOTER="Credits read from RAM (the screen shows at most 9). One RAM write: the random roll at a natural apple break." \
python3 scripts/gif_pair.py universal/out/mrdo.log universal/out/mrdo/mrdo "Genuine Mr. Do!  f{f}  credits {c}" \
  universal/out/mrdu.log universal/out/mrdu/mrdu "Bootleg Mr. Du!  f{f}  credits {c}" universal/out/mrdu_special_pair.gif 6885-7510
