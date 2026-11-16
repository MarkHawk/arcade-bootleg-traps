#!/usr/bin/env bash
# demo_atlantol.sh natural|check6|recovery ROM_FOLDER: Konami's check 6 on Atlant Olimpic (atlantol), a 1996 bootleg
# of Hyper Olympic that moved the copyright line. Genuine sets only: nothing is edited, so no ROM building is needed.
# Run from the repo root. Logs and snapshots go to konami/out/ (not committed). Every run starts from an empty NVRAM
# folder, except step 2 of "recovery", which reuses the NVRAM the first step saved (that is what it tests).
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
run() {   # run NAME SET SCRIPT SECONDS STATEDIR [env assignments...]
  local name=$1 set=$2 script=$3 secs=$4 st=$5; shift 5
  mkdir -p "$st"; rm -rf "konami/out/$name"; mkdir -p "konami/out/$name"
  env TF_TAG="$name" TF_OUT=konami/out "$@" timeout -s KILL $((secs * 3 + 600)) mame "$set" -rompath "$ROMS" -video none \
    -sound none -nothrottle -skip_gameinfo -debug -debugger none -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" \
    -diff_directory "$st/diff" -snapshot_directory "konami/out/$name" -autoboot_script "$script" \
    -seconds_to_run "$secs" > "konami/out/$name.txt" 2>&1 || true
}
show() { grep -v "SNAP\|snapshot\|re-run" "$1" | cut -c1-200; }
case $MODE in
natural)
  st=$(mktemp -d)
  run atlantol_natural atlantol konami/demo_atlantol.lua 17000 "$st" TF_N="${TF_N:-3}" TF_FRAMES="${TF_FRAMES:-1000000}" \
      TF_END_AFTER_FAIL="${TF_END_AFTER_FAIL:-900}" TF_SEQ="${TF_SEQ:-}"
  rm -rf "$st"
  grep -E 'FLAG SET|game over|check 6|SUMMARY' konami/out/atlantol_natural.log | cut -c1-200 ;;
check6)
  s1=$(mktemp -d); s2=$(mktemp -d)
  run check6_genuine hyprolym konami/demo_check6.lua 200 "$s1" TF_WATCHDOG="${TF_WATCHDOG:-0}" &
  run check6_atlantol atlantol konami/demo_check6.lua 200 "$s2" TF_WATCHDOG="${TF_WATCHDOG:-0}" &
  wait; rm -rf "$s1" "$s2"
  for n in genuine atlantol; do echo "== $n"; show "konami/out/check6_$n.log"; done ;;
recovery)
  st=$(mktemp -d)
  run recovery_1_arm atlantol konami/demo_check6.lua 100 "$st" TF_FRAMES=1500 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 1: flag forced"; show konami/out/recovery_1_arm.log
  run recovery_2_kept atlantol konami/demo_check6.lua 100 "$st" TF_NOFORCE=1 TF_FRAMES=1500 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 2: same NVRAM kept"; show konami/out/recovery_2_kept.log
  rm -rf "$st"; st=$(mktemp -d)
  run recovery_3_cleared atlantol konami/demo_check6.lua 100 "$st" TF_NOFORCE=1 TF_COINAT=1000 TF_FRAMES=3000 TF_WATCHDOG="${TF_WATCHDOG:-0}"
  echo "== 3: empty NVRAM"; show konami/out/recovery_3_cleared.log
  rm -rf "$st" ;;
*) echo "mode must be natural, check6 or recovery"; exit 1 ;;
esac
