#!/usr/bin/env bash
# demo_logotab.sh ROM_FOLDER: decode the WILLIAMS handwriting table (LGOTAB) in genuine Defender (Red label) and the
# five bootlegs that carry the logo trap, from the ROMs MAME loads (williams/logotab.lua), print each table's length,
# stroke and pixel counts, last 10 bytes and end point (CUREND), and draw them (williams/logotab_png.py). Every one ends
# at $6245. Reads your ROM folder (the Defender zip with its clones); changes nothing. Output in williams/out/ (not
# committed). Needs MAME (0.285 used, 0.277 ROM sets) and Pillow.
set -euo pipefail
ROMS=${1:?usage: williams/demo_logotab.sh ROM_FOLDER}
cd "$(dirname "$0")/.."
mkdir -p williams/out
logs=()
# set:table address in bank 1 (Red layout; attackf follows the Blue label; defence and galwars2 are their own build)
for s in defender:C941 defenseb:C941 defenderom:C941 attackf:C923 defence:C944 galwars2:C944; do
  set_=${s%%:*}
  LOGOTAB_AT=${s##*:} scripts/mame.sh 120 "$set_" -rompath "$ROMS" -seconds_to_run 1 \
    -autoboot_script williams/logotab.lua 2>&1 | grep "^\[lua\]" > "williams/out/logotab_$set_.log" || true
  printf '%-11s %s\n' "$set_" "$(grep -m1 LGOTAB "williams/out/logotab_$set_.log" | sed 's/^\[lua\] //')"
  logs+=("williams/out/logotab_$set_.log")
done
python3 williams/logotab_png.py williams/out/defender-logo-tables.png "${logs[@]}"
