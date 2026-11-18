#!/usr/bin/env bash
# demo_stargate.sh ROM_FOLDER: Stargate's hidden ROM sums, genuine against one sampled byte changed ($8C40, file
# stargate_rom_9-a_3002-9.a6 +C40, 00 -> 01, inside the CHKS1 sample), built from your own stargate.zip by
# scripts/patchzip.py. No Stargate bootleg is in MAME, so this is simulated. About 200 s of emulated time each.
# Genuine: CHKS1 37, CHKS2 56, no corrupting write in play. Changed: CHKS1 38, and the game corrupts random bytes of its
# own variables ($9Cxx) when a random roll allows: at a wave end (GEXBON) and when it prints text (WORD$). Both sides also show one write to
# $9C00 just after power-up: Williams' own bug (WORD$ compares CHKS1 before it has been computed), with the fresh NVRAM
# that scripts/mame.sh gives every run. LABELLED POKE: the enemy counters are zeroed for 150 frames from frames 3900,
# 5400, 6900, 8400 and 9900 so that waves end; nothing else is written.
# Runs through scripts/mame.sh (each zip alone on its rompath; a few minutes). Logs, snapshots and the still go to
# williams/out/ (not committed). The still shows the power-up ROM test, Williams' ordinary self-test, which also catches
# this edit; the hidden sums have no visible effect. Needs MAME (0.285 used, 0.277 ROM sets) and Pillow.
set -euo pipefail
ROMS=${1:?usage: williams/demo_stargate.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
R9=stargate_rom_9-a_3002-9.a6
GEN=$(python3 scripts/patchzip.py "$ROMS" stargate $R9:C40:00:00)   # unchanged copy: loaded the same way
EDIT=$(python3 scripts/patchzip.py "$ROMS" stargate $R9:C40:00:01)
trap 'rm -rf "$GEN" "$EDIT"' EXIT
mkdir -p williams/out
run() {  # name rompath
  rm -rf "williams/out/stargate_$1"; mkdir -p "williams/out/stargate_$1"
  scripts/mame.sh 900 stargate -rompath "$2" -nothrottle -debug -debugger none -seconds_to_run 200 \
    -snapshot_directory "williams/out/stargate_$1" -autoboot_script williams/stargate_sums.lua 2>&1 \
    | grep "^\[lua\]" > "williams/out/stargate_$1.log" || true
}
run genuine "$GEN" & run edited "$EDIT" & wait
for s in genuine edited; do echo "== $s"; grep -v "SNAP" "williams/out/stargate_$s.log"; done
# The still: genuine at frame 600 ("ALL SYSTEMS GO") beside the edited set 800 frames later ("ROM ERROR 9"; its RAM
# and ROM tests take longer). GIF_OFFSET shifts the right-hand side.
GIF_OFFSET=800 python3 scripts/gif_pair.py williams/out/stargate_genuine.log williams/out/stargate_genuine/stargate \
  "Genuine f{f}" williams/out/stargate_edited.log williams/out/stargate_edited/stargate "\$8C40 changed f{f}" \
  williams/out/stargate_powerup.gif 300-1200 --still 600 williams/out/stargate-rom-test.png
