#!/usr/bin/env bash
# demo_defender.sh ROM_FOLDER: Defender's logo trap (WCURS), genuine Red label against the control: the logo colour
# operand changed ($C6F8, ORB #$0F -> #$03, file defend.9 +6F8, 0F -> 03; palette slot $03 has no red), built from your
# own defender.zip by scripts/patchzip.py. About 200 s of emulated time each (attract, then about 80 s of scripted
# play). Genuine: WCURS 6245, no bomb writes. Changed colour: WCURS stays 0000 and the game writes random bytes into its
# own variables ($A0xx). Nothing is poked; the only change is that one ROM byte.
# Runs through scripts/mame.sh (each zip alone on its rompath; a few minutes). Logs go to williams/out/ (not
# committed). No GIF: the bomb writes have no reliable visible effect. Needs MAME (0.285 used, 0.277 ROM sets).
set -euo pipefail
ROMS=${1:?usage: williams/demo_defender.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
GEN=$(python3 scripts/patchzip.py "$ROMS" defender defend.9:6F8:0F:0F)   # unchanged copy: loaded the same way
EDIT=$(python3 scripts/patchzip.py "$ROMS" defender defend.9:6F8:0F:03)
trap 'rm -rf "$GEN" "$EDIT"' EXIT
mkdir -p williams/out
run() {  # name rompath
  scripts/mame.sh 900 defender -rompath "$2" -nothrottle -frameskip 10 -debug -debugger none -seconds_to_run 200 \
    -autoboot_script williams/defender_bomb.lua 2>&1 | grep "^\[lua\]" > "williams/out/defender_$1.log" || true
}
run genuine "$GEN" & run colour "$EDIT" & wait
for s in genuine colour; do echo "== $s"; cat "williams/out/defender_$s.log"; done
