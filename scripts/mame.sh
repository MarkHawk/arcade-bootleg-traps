#!/usr/bin/env bash
# The MAME wrapper used by the demos in atari/ (Battlezone), universal/, nintendo/ and taito/. It enforces the run
# rules here rather than in each caller:
#   - a memory cap (systemd-run --user --scope -p MemoryMax=8G, when systemd-run is available), nice -n 10, and a
#     hard wall-clock kill (timeout -s KILL);
#   - emulation runs must pass -seconds_to_run, and get a fresh, empty NVRAM and cfg folder (made under tmp/ in the
#     repo and deleted afterwards), so no saved state carries over between runs;
#   - always headless (-video none -sound none); snapshots still work from Lua;
#   - a rompath must be ONE folder (no ";"). With a patched zip first and the real ROM folder second, MAME rejects
#     the patched file on its CRC and silently loads the genuine one from the second folder, so a "no effect" result
#     would be meaningless. Every demo Lua script also logs the loaded bytes it depends on.
# Usage: scripts/mame.sh SECONDS mame-args...      (SECONDS is the wall-clock kill limit)
#   Info verbs (-listxml, -listclones, -verifyroms, -listfull, -listroms) must name a set.
set -euo pipefail
[ $# -ge 2 ] || { echo "usage: $0 SECONDS mame-args..." >&2; exit 2; }
secs=$1; shift
[[ $secs =~ ^[0-9]+$ ]] || { echo "SECONDS must be an integer" >&2; exit 2; }
MAME=${MAME:-mame}
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope -q true >/dev/null 2>&1; then
  run=(systemd-run --user --scope -q -p MemoryMax=8G nice -n 10 timeout -s KILL "$secs" "$MAME")
else
  run=(nice -n 10 timeout -s KILL "$secs" "$MAME")
fi
case "$1" in
  -listxml|-listclones|-verifyroms|-listfull|-listroms)
    [ $# -ge 2 ] || { echo "refusing $1 without a set name (would scan everything)" >&2; exit 2; }
    exec "${run[@]}" "$@" ;;
  -*) exec "${run[@]}" "$@" ;;
esac
args=" $* "
[[ $args == *" -seconds_to_run "* ]] || { echo "refusing emulation run without -seconds_to_run" >&2; exit 2; }
for bad in " -nvram_directory " " -cfg_directory " " -video " " -window "; do
  [[ $args != *"$bad"* ]] || { echo "refusing:$bad is set by this wrapper" >&2; exit 2; }
done
prev=""; for a in "$@"; do
  if [ "$prev" = "-rompath" ] && [[ $a == *";"* ]]; then echo "refusing multi-folder rompath ($a)" >&2; exit 2; fi
  prev=$a; done
here=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$here/tmp"
fresh=$(mktemp -d "$here/tmp/run_XXXXXX")
trap 'rm -rf "$fresh"' EXIT
mkdir -p "$fresh/nvram" "$fresh/cfg" "$fresh/diff"
"${run[@]}" "$@" -nvram_directory "$fresh/nvram" -cfg_directory "$fresh/cfg" -diff_directory "$fresh/diff" \
  -video none -sound none -skip_gameinfo
