#!/usr/bin/env bash
# demo_gyruss.sh ROM_FOLDER: Gyruss (gyruss, genuine) against a copy with "KONAMI" edited to "KNNAMI" and the ROM
# sums kept, the same inputs on both sides (konami/gyruss_free.lua): no coin, 1P Start at frame 2000.
#   genuine  attract mode carries on; Start with no coin is ignored; credits 00
#   knnami   the screen check on "K", "O", "N" fails in the attract demo (about frame 788) and the board drops to
#            "PUSH START BUTTON" with 0 credits; Start with no coin starts a game and the credits become 99
# The edit, built from your own gyruss.zip by scripts/patchzip.py (file gyrussk.2 is the main Z80's $2000-$3FFF):
#   gyrussk.2 +17AE  B1 -> 47   $37AE, the "O" of KONAMI becomes "N"
#   gyrussk.2 +17BD  6F -> 99   $37BD, in the copyright block
#   gyrussk.2 +188A  FF -> 3F   $388A, an unused filler byte
# Together the last two keep the sum over $37A8-$38A7 (C02), the XOR over $3778-$37F7 (C05) and the whole-ROM sum
# (C29, the power-on ROM test) unchanged.
# Nothing is poked: the script only presses Start and reads memory. Runs through scripts/mame.sh (each zip alone on
# the rompath, the bytes MAME loaded logged first; about 20 seconds). Logs, snapshots and the GIF go to konami/out/
# (not committed). Needs MAME (0.285 used, 0.277 ROM sets: gyruss.zip) and Pillow for the GIF.
set -euo pipefail
ROMS=${1:?usage: konami/demo_gyruss.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
GEN=$(python3 scripts/patchzip.py "$ROMS" gyruss -)
EDIT=$(python3 scripts/patchzip.py "$ROMS" gyruss gyrussk.2:17AE:B1:47,gyrussk.2:17BD:6F:99,gyrussk.2:188A:FF:3F)
trap 'rm -rf "$GEN" "$EDIT"' EXIT
mkdir -p konami/out
run() {  # side rompath
  rm -rf "konami/out/gyruss_$1"; mkdir -p "konami/out/gyruss_$1"
  G_LOG=$PWD/konami/out/gyruss_$1.log G_FRAMES=3000 scripts/mame.sh 300 gyruss -rompath "$2" -nothrottle \
    -seconds_to_run 400 -snapshot_directory "konami/out/gyruss_$1" -autoboot_script konami/gyruss_free.lua \
    > "konami/out/gyruss_$1.txt" 2>&1 || true
}
run genuine "$GEN" & run knnami "$EDIT" & wait
for s in genuine knnami; do
  echo "== $s"; grep -h "LOADED\|CREDITS\|STATE\|end" "konami/out/gyruss_$s.log"
done
GIF_SCALE=${GIF_SCALE:-2} GIF_MS=${GIF_MS:-80} \
GIF_FOOTER="No coin. 1P Start at f2000. Right: KONAMI edited to KNNAMI, ROM sums kept." python3 scripts/gif_pair.py \
  konami/out/gyruss_genuine.log konami/out/gyruss_genuine/gyruss "genuine  f{f}  credit {c}" \
  konami/out/gyruss_knnami.log konami/out/gyruss_knnami/gyruss "KNNAMI  f{f}  credit {c}" \
  konami/out/gyruss_knnami_pair.gif 740-2200 --still 780,800,1996,2040 konami/out/gyruss_knnami.png
