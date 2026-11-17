#!/usr/bin/env bash
# demo_bzone.sh credits|100k ROM_FOLDER: Battlezone (bzone), genuine against one copyright letter changed, "ATARI" to
# "ATARO" ($6F34, file 036411-01.k1 +0734, 26 -> 32), built from your own bzone.zip by scripts/patchzip.py.
#   credits  one coin, Start twice: genuine 1 -> 0 and the second Start is ignored; ATARO 1 -> 27 -> 53 (about 2 minutes)
#   100k     score poked to 99,000 at each game start, the next kill natural: genuine plays on, ATARO stops for good
#            (about 4 minutes; the scripted player needs a kill, which it got in its first game in our runs)
# Every run goes through scripts/mame.sh; the edited zip is alone on the rompath. Logs, snapshots and the GIF go to
# atari/out/ (not committed). Needs MAME (results here are from 0.285 with 0.277 ROM sets) and Pillow for the GIF.
set -euo pipefail
MODE=${1:?usage: atari/demo_bzone.sh credits|100k ROM_FOLDER}; ROMS=${2:?usage: atari/demo_bzone.sh credits|100k ROM_FOLDER}
cd "$(dirname "$0")/.."
case $MODE in
  credits) LUA=atari/bzone_credits.lua; SECS=115; export BZ_START2=100 BZ_SEQ=240-460,4060-4300 BZ_STEP=4 ;;
  100k)    LUA=atari/bzone_100k.lua; SECS=400; export BZ_STEP=20 ;;
  *) echo "mode must be credits or 100k"; exit 1 ;;
esac
EDIT=$(python3 scripts/patchzip.py "$ROMS" bzone 036411-01.k1:734:26:32)
trap 'rm -rf "$EDIT"' EXIT
mkdir -p atari/out
run() {  # side rompath
  rm -rf "atari/out/bzone_${MODE}_$1"; mkdir -p "atari/out/bzone_${MODE}_$1"
  scripts/mame.sh $((SECS + 120)) bzone -rompath "$2" -nothrottle -seconds_to_run $SECS \
    -snapshot_directory "atari/out/bzone_${MODE}_$1" -autoboot_script $LUA > "atari/out/bzone_${MODE}_$1.log" 2>&1 || true
}
run genuine "$ROMS" & run ataro "$EDIT" & wait
for s in genuine ataro; do
  echo "== $s"; grep -v "^SNAP\|ALSA\|^\s*$\|EXPECTED\|FOUND:" "atari/out/bzone_${MODE}_$s.log" | head -30
done
L=atari/out/bzone_${MODE}_genuine; R=atari/out/bzone_${MODE}_ataro
if [ "$MODE" = credits ]; then
  GIF_SCALE=1 GIF_FOOTER='One coin, then Start at 9 s and at 100 s. Credits read from RAM: Battlezone does not show them on screen.' \
  python3 scripts/gif_pair.py $L.log $L/bzone "genuine bzone  f{f}  credits {c}" $R.log $R/bzone '"ATARI" -> "ATARO"  f{f}  credits {c}' \
    atari/out/bzone_credits_pair.gif 240-4300
else
  # line the two kills up: the right side is shown OFFSET frames later (the frame each side's $0345 was set, rounded to 20)
  a=$(awk '/\$0345 <- FF/{print $1; exit}' $L.log); b=$(awk '/\$0345 <- FF/{print $1; exit}' $R.log)
  [ -n "$a" ] && [ -n "$b" ] || { echo "no kill past 100,000 on one side: run again, or lengthen the run"; exit 1; }
  a=$(( a / 20 * 20 )); b=$(( b / 20 * 20 ))
  GIF_OFFSET=$(( b - a )) GIF_SCALE=1 GIF_MS=120 GIF_FOOTER="Score poked to 99,000 at game start; the kill that passes 100,000 is the game's own. Free play." \
  python3 scripts/gif_pair.py $L.log $L/bzone "genuine bzone  f{f}" $R.log $R/bzone '"ATARI" -> "ATARO"  f{f}' \
    atari/out/bzone_100k_pair.gif $(( a - 60 ))-$(( a + 700 ))
fi
