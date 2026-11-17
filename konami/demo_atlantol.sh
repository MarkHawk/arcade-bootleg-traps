#!/usr/bin/env bash
# demo_atlantol.sh natural|check6|recovery ROM_FOLDER: Konami's check 6 on Atlant Olimpic (atlantol), a 1996 bootleg
# of Hyper Olympic that moved the copyright line. Genuine sets only: nothing is edited. Each run goes through
# scripts/mame.sh with one folder on the ROM path: an unchanged copy of the set made by scripts/patchzip.py (your
# trackfld.zip if your sets are merged; atlantol.zip or hyprolym.zip plus their parent trackfld.zip if split). The
# Lua logs the loaded copyright entry ($A6B6: hyprolym 36 CA, atlantol 37 F0).
# Run from the repo root. Logs and snapshots go to konami/out/ (not committed). Every run starts from an empty NVRAM
# folder, except step 2 of "recovery", which reuses the NVRAM the first step saved (that is what it tests; the
# wrapper's MAME_KEEP_NVRAM).
#   natural    atlantol alone, MAME's default DIPs, coins and player inputs only; no RAM writes at all. A 3-player
#              game with continues sets the check 6 flag at the round 1 high jump; when that game ends the board
#              freezes at the first attract demo. About 20 minutes of wall-clock time (875,000 frames).
#              Extra environment: TF_N (3 or 4 players), TF_FRAMES, TF_SEQ="over+0-6000/8,fail+8-900/8" (snapshots).
#   check6     genuine hyprolym against atlantol, side by side, with the NVRAM flag forced by a RAM poke at frame 200
#              (the genuine game has no continues, so its flag can't be set by play): hyprolym's attract demos carry
#              on, atlantol freezes at its first demo. A minute or two.
#   recovery   atlantol, three runs: (1) flag forced, board freezes; (2) the same NVRAM kept (switched off and on):
#              frozen again; (3) a fresh, empty NVRAM (battery cleared): runs normally.
# Optional: TF_WATCHDOG=180 simulates a 3-second watchdog in check6/recovery (MAME disables atlantol's).
set -euo pipefail
MODE=${1:?usage: konami/demo_atlantol.sh natural|check6|recovery ROM_FOLDER}; ROMS=${2:?usage: konami/demo_atlantol.sh MODE ROM_FOLDER}
cd "$(dirname "$0")/.."
mkdir -p konami/out
copy() {  # copy SET: print a one-folder rompath holding SET (and its parent, for split sets)
  if [ -f "$ROMS/$1.zip" ]; then python3 scripts/patchzip.py "$ROMS" "$1" - --with trackfld
  else python3 scripts/patchzip.py "$ROMS" trackfld -; fi
}
RP_ATL=$(copy atlantol); RP_HYP=$(copy hyprolym)
trap 'rm -rf "$RP_ATL" "$RP_HYP"' EXIT
run() {   # run NAME SET SCRIPT SECONDS NVRAMDIR|- [env assignments...]   (- = a fresh NVRAM from the wrapper)
  local name=$1 set=$2 script=$3 secs=$4 nv=$5 rp; shift 5
  [ "$set" = hyprolym ] && rp=$RP_HYP || rp=$RP_ATL
  rm -rf "konami/out/$name"; mkdir -p "konami/out/$name"
  env TF_TAG="$name" TF_OUT=konami/out "$@" MAME_KEEP_NVRAM="$([ "$nv" = - ] || echo "$nv")" \
    scripts/mame.sh $((secs * 3 + 600)) "$set" -rompath "$rp" -nothrottle -debug -debugger none \
    -snapshot_directory "konami/out/$name" -autoboot_script "$script" -seconds_to_run "$secs" \
    > "konami/out/$name.txt" 2>&1 || true
}
show() { grep -v "SNAP\|snapshot\|re-run" "$1" | cut -c1-200; }
case $MODE in
natural)
  run atlantol_natural atlantol konami/demo_atlantol.lua 17000 - TF_N="${TF_N:-3}" TF_FRAMES="${TF_FRAMES:-1000000}" \
      TF_END_AFTER_FAIL="${TF_END_AFTER_FAIL:-900}" TF_SEQ="${TF_SEQ:-}"
  grep -E 'FLAG SET|game over|check 6|SUMMARY' konami/out/atlantol_natural.log | cut -c1-200 ;;
check6)
  run check6_genuine hyprolym konami/demo_check6.lua 200 - TF_WATCHDOG="${TF_WATCHDOG:-0}" &
  run check6_atlantol atlantol konami/demo_check6.lua 200 - TF_WATCHDOG="${TF_WATCHDOG:-0}" &
  wait
  for n in genuine atlantol; do echo "== $n"; show "konami/out/check6_$n.log"; done ;;
recovery)
  mkdir -p tmp; st=$(mktemp -d "$PWD/tmp/nvram_XXXXXX")   # the one NVRAM folder kept between steps 1 and 2
  run recovery_1_arm atlantol konami/demo_check6.lua 100 "$st" TF_FRAMES=1500 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 1: flag forced"; show konami/out/recovery_1_arm.log
  run recovery_2_kept atlantol konami/demo_check6.lua 100 "$st" TF_NOFORCE=1 TF_FRAMES=1500 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 2: same NVRAM kept"; show konami/out/recovery_2_kept.log
  rm -rf "$st"
  run recovery_3_cleared atlantol konami/demo_check6.lua 100 - TF_NOFORCE=1 TF_COINAT=1000 TF_FRAMES=3000 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 3: empty NVRAM"; show konami/out/recovery_3_cleared.log ;;
*) echo "mode must be natural, check6 or recovery"; exit 1 ;;
esac
