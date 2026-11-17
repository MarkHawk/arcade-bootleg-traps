#!/usr/bin/env bash
# demo_repair.sh ROM_FOLDER: the "For repairers" runs in docs/konami-track-and-field.md, on the check 2 edit
# ("KONAMI" -> "KNNAMI", konami/roms/check2, built by konami/build_roms.py). Every run goes through scripts/mame.sh
# with one folder on the ROM path. Runs 1 to 4 share one battery-backed RAM folder (MAME_KEEP_NVRAM), in order:
#   1 arm       edited, empty RAM: the 1,500th game arms check 2, which then fails
#   2 kept      edited, the same RAM (switched off and on): fails soon after power-on, resets again and again
#   3 erase     edited, the same RAM, DIP "World Records" at "Erase on Reset": still fails
#   4 goodrom   genuine ROM (your folder), the same RAM, still armed: a game is played; check 2 runs and passes
#   5 empty     edited, an empty RAM (a flat battery): a game is played; check 2 doesn't run (not armed)
# Logs: konami/out/demo_check2_repair_*.log (not committed). A few minutes.
set -euo pipefail
ROMS=${1:?usage: konami/demo_repair.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
ls konami/roms/check2/*.zip >/dev/null 2>&1 || { echo "build the edited ROMs first: python3 konami/build_roms.py $ROMS"; exit 1; }
mkdir -p konami/out tmp
K=$(mktemp -d "$PWD/tmp/nvram_XXXXXX"); trap 'rm -rf "$K"' EXIT
run() {  # name rompath nvram|- secs [env...]
  local name=$1 rp=$2 nv=$3 secs=$4; shift 4
  env TF_SIDE="repair_$name" TF_OUT=konami/out "$@" MAME_KEEP_NVRAM="$([ "$nv" = - ] || echo "$nv")" \
    scripts/mame.sh 900 trackfldu -rompath "$rp" -nothrottle -debug -debugger none -seconds_to_run "$secs" \
    -snapshot_directory "konami/out/repair_$name" -autoboot_script konami/demo_repair.lua \
    > "konami/out/repair_$name.txt" 2>&1 || true
  echo "== $name"; grep -v SNAP "konami/out/demo_check2_repair_$name.log" | cut -c1-160
}
run 1_arm konami/roms/check2 "$K" 600 TF_ARM=1 TF_FRAMES=5400
run 2_kept konami/roms/check2 "$K" 300 TF_FRAMES=1200
run 3_erase konami/roms/check2 "$K" 300 TF_ERASE=1 TF_FRAMES=1200
run 4_goodrom "$ROMS" "$K" 300 TF_PLAY=300 TF_FRAMES=6000
run 5_empty konami/roms/check2 - 300 TF_PLAY=300 TF_FRAMES=6000
