# trapscan

Tools for finding hidden credit routines ("free-play backdoors") in 8080 Space Invaders-family
arcade ROMs: Taito, Midway and their bootlegs, 1978–81.

They came out of reverse-engineering two 1979 Taito games, where both turned out to contain
anti-bootleg traps that hand out credits on a secret button combination: see the main README.

Pure Python 3 (3.8+). No dependencies for the 8080 games, except Pillow if you want screenshots (`pip install pillow`).
Z80 mode needs `z80dis` (see below), so "no dependencies" is not quite true.

## Quick start

```bash
# Scan one set, or a whole folder of MAME zips
python3 trapscan.py scan lrescue.zip
python3 trapscan.py scan ~/roms/*.zip

# Run a set in the emulator, hold buttons, poke RAM, watch bytes, count executions
python3 trapscan.py run lrescue.zip --frames 1720 \
    --poke 20ed=1@600 --hold start1+fire+right@1600-1700 \
    --watch 20eb --break 47e9 --shot 150
```

`scan` prints a report and writes a full disassembly to `out/<set>.asm`.

## Every maker at a glance

These are the commands the main README used to list in full; it now keeps one example per maker.

ROMs are not included; use your own MAME sets (the results here are from MAME 0.277 sets; Konami's and the five games
added in November 2026 from MAME 0.285, with 0.277 sets).

**Taito** (pure Python 3: a disassembler, a signature scanner and an 8080 emulator of the Space Invaders board):

```bash
python3 trapscan.py scan lrescue.zip invadpt2.zip     # report + disassembly
python3 trapscan.py run lrescue.zip --frames 1720 --patch 4676=13 \
    --hold start1+fire+right@1600-1700 --watch 20eb     # bootleg simulation -> credits 03
python3 scripts/verify.py ~/roms                       # check every Taito listing against the ROMs
```

In MAME's debugger:

- **Lunar Rescue:** after **both** title screens (~10 s from power-on), enter `b@20ed=1`, then hold
  P1 Start + Fire + Right once the demo starts.
- **Space Invaders Part II:** the board check clears the flag again and again during attract mode, so set it at
  the moment the trap reads it: `bpset 418c,1,{b@20e3=1;g}`. Reset, and hold P1 Start + P2 Start + Fire + Left
  from power-on; the trap runs about 4 seconds in, and the credits go to 2.

**Atari** (MAME's Lua scripting; the scripts play by themselves and print the credit count):

```bash
mame astdelux1 -autoboot_script atari/astdelux_trap.lua              # copyright changed: +2 credits at some game overs
TAMPER=none mame astdelux1 -autoboot_script atari/astdelux_trap.lua  # genuine: never
mame centiped -autoboot_script atari/centipede_trap.lua              # reads differ: +3 credits per game start
python3 atari/verify_atari.py ~/roms                                 # check every Atari listing against the ROMs
python3 atari/slamscan.py ~/roms -o slamscan.md                      # the slam-switch scan
```

Add `-nothrottle` to run faster than real time. On Windows PowerShell, set the variable first: `$env:TAMPER="none"`.
More on the Atari scripts: [Atari tools](#atari-tools-atari) below.

**Konami** (MAME's Lua scripting and debugger; the Konami results are from MAME 0.285):

```bash
python3 konami/build_roms.py ~/roms          # one-byte edits of trackfldu, built from your own set into konami/roms/
konami/demo.sh 2 ~/roms                      # "KONAMI" -> "KNNAMI", counter at 1,499: genuine passes, edited boot-loops
konami/demo.sh 1 ~/roms                      # $C418 changed: genuine plays on, edited freezes in the high jump
konami/demo_repair.sh ~/roms                 # check 2 armed: battery kept, Erase on Reset, good ROM back, flat battery
konami/demo_atlantol.sh check6 ~/roms        # Atlant Olimpic against genuine Hyper Olympic, check 6 armed: genuine carries on, atlantol freezes
konami/demo_atlantol.sh recovery ~/roms      # frozen; still frozen with the NVRAM kept; running with it cleared
konami/demo_atlantol.sh natural ~/roms       # no RAM writes: a 3-player game sets the flag itself (about 20 minutes)
python3 konami/build_tp84.py ~/roms          # two edited Time Pilot '84 sets, built from your own set into konami/roms/
konami/demo_tp84.sh onebyte ~/roms           # "KONAMI" -> "KNNAMI": the power-on ROM test halts the board ("ROM2 BAD")
konami/demo_tp84.sh sumkept ~/roms           # the edit with the ROM sums kept: lives lost, screen flips, controls swap, message printed
```

Each run goes through `scripts/mame.sh`, starts from an empty NVRAM and writes its log to `konami/out/` (the
exceptions, which reuse the NVRAM an earlier step saved, are step 2 of the `recovery` demo and runs 2 to 4 of
`demo_repair.sh`). Every run has one folder on the ROM path: your own, or a one-folder copy made by
`konami/build_roms.py`, `konami/build_tp84.py` or `scripts/patchzip.py`. The Atlant Olimpic demos need no edited ROMs; the Time Pilot '84 ones are
built from your own `tp84.zip` by `konami/build_tp84.py`. `konami/gif_pair.py` (needs Pillow) makes the side-by-side
GIF. More on the Konami demos: [konami-track-and-field.md](konami-track-and-field.md#rerun),
[konami-time-pilot-84.md](konami-time-pilot-84.md#rerun).

**Battlezone, Space Dungeon, Mr. Do!, Donkey Kong Jr. and Popeye** (MAME's Lua scripting; each script runs both sides
through `scripts/mame.sh`, prints the logs and writes a side-by-side GIF; see [below](#the-november-2026-demos)):

```bash
atari/demo_bzone.sh credits ~/roms     # Battlezone: genuine 1 -> 0, "ATARO" 1 -> 27 -> 53 (about 20 s)
atari/demo_bzone.sh 100k ~/roms        # score poked to 99,000, the next kill natural: genuine plays on, ATARO stops (about 1 min)
taito/demo_sdungeon.sh ~/roms          # Space Dungeon: counter poked to 63, the 64th event natural; edited sum 6B, penalty (about 30 s)
universal/demo_mrdu.sh ~/roms          # Mr. Do! against Mr. Du!: credits 00 -> 01 against 00 -> 41 at frame 7491 (about 30 s)
nintendo/demo_dkjr.sh ~/roms           # jrking climbs, genuine with #37FC changed drops back, unedited genuine climbs (about 20 s)
nintendo/demo_popeye.sh ~/roms         # Popeye: lives setting 3 against 4 after the high-score sum fails (about 1 min)
```

To search a whole collection, any manufacturer, for the Taito trap code and its arming checks: `sigsearch.py`
([below](#search-a-whole-mame-collection-for-the-trap-code)).

## Batch: a whole folder into one report

```bash
python3 batch.py ~/roms                    # writes report.md and out/<set>.asm
python3 batch.py ~/roms -o taito.md --no-asm
```

Every `.zip` (or folder) is a set; merged zips also yield each clone inside them. Sets are ranked SUSPICIOUS → CHECK →
EASTER EGG? → CLEAN → OTHER HW? → ERROR. A set that fails to load is reported and skipped.
Which sets to collect: [ROMLIST.md](ROMLIST.md).

## Search a whole MAME collection for the trap code

```bash
python3 sigsearch.py /path/to/mame/roms -o sigsearch.csv
```

Byte-searches every zip (clone folders included) for the exact trap routines, their arming checks, a
relocated/edited version of each, and any `ANI $76` combo check. It doesn't need to lay out or run anything,
so it covers games on any board. Zips over 4 MB are skipped (`--max-zip-mb` to change).

### Big collections: skip what's out of scope

A full modern MAME set is mostly hardware this search isn't aimed at. `sigsearch.py` takes:

- `--max-zip-mb 1`: 1978–84 sets are small, so this skips most later games without reading them (default 4);
- `--skip-nonarcade`: skip fruit machines (Barcrest MPU, JPM, Maygay, BFM Scorpion, Astra), video poker,
  PlayChoice-10, Mega-Tech and Game & Watch sets, by name prefix;
- `--skip a,b,c`: your own extra prefixes.

On a 13,000-zip MAME 0.277 set, `--max-zip-mb 1 --skip-nonarcade` cuts a run to a fraction of the time. Big merged golden-age sets (Galaxian, Pac-Man with all their clones) can be over 1 MB; run those on
their own if so.

## Merged ROM sets and clones

Merged MAME sets keep each clone's differing ROMs in a sub-folder of the parent zip (e.g. `lrescue.zip` →
`desterth/…`). trapscan expands every clone automatically and places each clone ROM by **matching its content**
against the parent (or a sibling set, when the clone shares files with it). Bootleg ROMs typically match at 90–100%;
ROMs with no counterpart (extra code) go in the next free slot. Pick one clone with `--set`:

```bash
python3 trapscan.py scan lrescue.zip --set desterth
python3 trapscan.py run lrescue.zip --set desterth --hold start1+fire+right@1000-2500 --watch 20eb
```

Unknown parents are laid out by **self-location**: each ROM's own jump/call targets show where it loads.

## Z80 mode (Taito SJ System, Crazy Balloon)

Sets with 4 KB/8 KB ROMs are detected automatically. Main-CPU ROMs are separated from sound and graphics ROMs,
banked ROMs at $6000–$7FFF are scanned as bank 0 and bank 1, and inputs are read from $D400–$D40F. Disassembly
needs `z80dis` (`python3 -m pip install z80dis`). There's no Z80 emulator, so `run` is 8080-only.

## Boot check

`batch.py` runs each 8080 set for 4 seconds and reports **Boots**. Some boards check input port 0 at power-up, so it
tries several values and notes the one that worked (Galaxy Wars needs `$40`, Lupin III `$03`, the TV-version Space
Invaders `$01`). Pass the same with `run --port0`.

## What `scan` looks for

| Tag | Meaning | Why it matters |
|---|---|---|
| `COMBO` | Controls read, then `ANI mask / CPI value` with 3+ buttons | One exact button combination. "then MVI M,.." means it writes RAM straight after – **look here first** |
| `CREDIT` | Direct writes to the credit counter (found automatically from the coin routine) | Normal: coin + start. Anything else is interesting |
| `POINTER` | An address built at run time (`MVI L,$EA / INR L` = $EB) | Used to hide credit writes from anyone searching for `$20EB` |
| `SHADOW` | Interrupt code comparing credits with a second copy, restarting on mismatch | Stops simple RAM pokes |
| `VRAMCMP` | Screen memory compared with constants | Copyright-text check (Lunar Rescue arms its trap this way) |
| `ROMCMP` | ROM bytes compared with constants | Patch detection |
| `RESET` | Input read, then jump to $0000/$0003 | Board/hardware checks |

Hits are leads, not proof. Confirm in the `.asm`, then in the emulator.

## ROM layouts

Known sets (`invaders`, `invadpt2`, `lrescue`) load with exact MAME layouts. Anything else gets a
**heuristic** layout: 2 KB files are program ROMs, the one that looks like a reset ROM goes to $0000,
four fill $0000–$1FFF, and the rest go to $4000+. The layout is always printed. If it's wrong, override it:

```bash
python3 trapscan.py scan ballbomb.zip --map 0000=tn01 0800=tn02 1000=tn03 1800=tn04 4000=tn05-1
```

(MAME's `-listroms <set>` or the driver source gives the real addresses.)

## The `run` command

| Option | Example | |
|---|---|---|
| `--frames` | `1800` | 60 frames = 1 second |
| `--hold` | `start1+fire+right@1600-1700` | Buttons: coin, start1, start2, fire, left, right, or `0xNN` |
| `--poke` | `20ed=1@600` | Write RAM at a frame |
| `--patch` | `4676=13` | Change a ROM byte before starting (simulate a bootleg) |
| `--watch` | `20eb` | Print whenever the byte changes |
| `--break` | `47e9` | Count executions of an address |
| `--shot` | `150` | Screenshot at a frame (Pillow) |
| `--port0/--port2` | `02` | Raw input values (DIPs, odd wiring) |

Hardware model: 8080 at ~2 MHz, RST 1 mid-frame and RST 2 at vblank, shift register on
ports 2/4 → 3, RAM $2000–$3FFF. Games that use different I/O will scan fine but may not run correctly.

## Reproducing the findings

```bash
# Lunar Rescue: arm the trap (normally cleared by the copyright check), hold the combo in the demo
python3 trapscan.py run lrescue.zip --frames 1720 --poke 20ed=1@600 \
    --hold start1+fire+right@1600-1700 --watch 20eb --break 47e9
#   -> credits 03 at frame 1600 (then 02 as the held Start begins a game)

# Same, as a bootleg would: alter one letter of "TAITO" so the check never disarms it
python3 trapscan.py run lrescue.zip --frames 1720 --patch 4676=13 \
    --hold start1+fire+right@1600-1700 --watch 20eb

# Space Invaders Part II: one port-0 line high arms the trap
python3 trapscan.py run invadpt2.zip --frames 400 --port0 02 \
    --hold start1+start2+fire+left@200-260 --watch 20eb --watch 20cc --break 419d
#   -> credits 02 at frame 233 (the held 2P Start may then spend them)
```

In MAME instead: open the debugger. For Lunar Rescue, after **both** title screens (~10 s from
power-on) do `b@20ed=1`, then hold P1 Start + Fire + Right once the demo is running. For Part II,
the board check clears the flag again and again in attract mode, so set it as the trap reads it:
`bpset 418c,1,{b@20e3=1;g}`, reset, and hold P1 Start + P2 Start + Fire + Left from power-on.

## Screenshots

```bash
python3 scripts/trapdemo.py ROM_FOLDER         # needs Pillow; ROM_FOLDER is required; writes docs/img/
python3 scripts/trapdemo.py ROM_FOLDER --gif   # also a short captioned GIF per case (same names)
```

Runs the five cases shown in the README (genuine and bootleg Lunar Rescue, Moon Lander set 2, Part II with
genuine and one-line-high port 0), holds the combination in the attract demo, lets go when the credit counter
(`$20EB`) first changes, and saves the first frame where the screen shows the new CREDIT value. `--only NAME`
saves one; `--out DIR` changes the folder. It prints the counter it found for each image and exits non-zero
if one is not what the README says.

`--gif` also writes `NAME.gif` for each case: 2x, about 14 frames a second, with a caption strip under the
picture naming the buttons held ("Holding P1 Start + Fire + Right", then "Released"). It runs from 1.5 s before
the buttons go down to 2 s after the counter changes (a nothing-happens case never ends before its still, so the
CREDIT line is on screen) and holds the last frame for 2 s. The GIFs come from the same run as the stills.
`ROM_FOLDER` needs `lrescue.zip`, `invadpt2.zip` and, for Moon Lander set 2, a standalone `mlandera.zip`.

```bash
python3 scripts/eggdemo.py invaders.zip --gif  # taito-cop.png and taito-cop.gif, in the current folder
python3 scripts/eggdemo.py sstrangr.zip --gif  # hoei-cop.png and hoei-cop.gif
```

The easter-egg demo takes the zip itself (not a folder), and its GIF has the same caption strip, naming each of
the two combinations as it is held.

## Sanity check

```bash
python3 scripts/verify.py ROM_FOLDER           # about 2 minutes; ROM_FOLDER is required
```

Checks the code listings and emulator results in the README and `docs/` against your ROMs: the trap and
board-check bytes in every Lunar Rescue and Part II set, the Moon Lander 25-byte difference, and the combo
results (credits, `$47E9`, `$419D`, the port-0 reset, Moon Base's dead trap). One PASS/FAIL line each; exit
status is non-zero if any fail, and a set it cannot find counts as a failure. It needs `lrescue.zip`,
`invadpt2.zip` and `mlandera.zip` in the folder.

## Atari tools (`atari/`)

The Atari findings use MAME itself (tested with 0.264) rather than this repo's 8080 emulator. Each
script plays the game unattended: it inserts a coin and presses Start every 2 minutes, leaves the controls alone,
and prints the credit count as it changes.

```bash
mame astdelux1 -autoboot_script atari/astdelux_trap.lua               # copyright changed to "ACME": the trap
TAMPER=none mame astdelux1 -autoboot_script atari/astdelux_trap.lua   # genuine board
mame centiped -autoboot_script atari/centipede_trap.lua               # the two POKEY reads differ by 3
NOPOKEY=0 mame centiped -autoboot_script atari/centipede_trap.lua     # genuine board
```

What the check reads on the bootlegs that kept it (nothing changed; a fresh temporary folder per run, so each
starts from an empty NVRAM):

```bash
st=$(mktemp -d)
mame centipdb -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" -video none -sound none \
     -nothrottle -seconds_to_run 1200 -autoboot_script atari/centipede_probe.lua    # also centipdb2, millpac, centiped
rm -rf "$st"
```

Add `-nothrottle` to run faster than real time, or `-video none -sound none -nothrottle -seconds_to_run 1000` to
run headless. With `-debug -debugger none`, `astdelux_trap.lua` also logs when the copyright comparison and the
payout code run. On Windows PowerShell, set variables first: `$env:TAMPER="none"`.

```bash
python3 atari/verify_atari.py ROM_FOLDER       # needs astdelux.zip and centiped.zip
python3 atari/slamscan.py ROM_FOLDER -o slamscan.md --csv slamscan.csv
```

`verify_atari.py` checks every Atari listing in the README and `docs/` byte for byte. `slamscan.py` looks for a
"kick me" trap: it finds Atari's standard coin routine in each set, then lists every other read of the slam switch
and every write to the credit count, and flags `SLAM->CREDIT` if a slam read leads to a credit write. Byte-pattern
search, so it needs no ROM layout: addresses in its report are offsets inside
each ROM file.

## The November 2026 demos

Five demos, one per game, each reproducing the GIF its section of the README leads with:

| Script | Lua | Sets needed | Edited ROM |
|---|---|---|---|
| `atari/demo_bzone.sh credits\|100k` | `atari/bzone_credits.lua`, `atari/bzone_100k.lua` | `bzone` | `036411-01.k1` +`0x734` `26` -> `32` ("ATARI" to "ATARO") |
| `taito/demo_sdungeon.sh` | `taito/sdungeon_delayed.lua` (uses MAME's debugger) | `sdungeon`, `m68705p3` | `sd15.u15` +`0xDDA` `40` -> `41` |
| `universal/demo_mrdu.sh` | `universal/mrdu_diamond.lua` | `mrdo` (with `mrdu`) | none: Mr. Du! is a real dump |
| `nintendo/demo_dkjr.sh` | `nintendo/dkjr_vine.lua` | `dkongjr` (with `jrking`) | `djr1-c_5b_f-2.5b` +`0x17FC` `C6` -> `C7` |
| `nintendo/demo_popeye.sh` | `nintendo/popeye_lives.lua` | `popeye` | none on disk: one byte in MAME's decrypted copy, from Lua |

How they run:

- Every MAME call goes through `scripts/mame.sh`, which adds a memory cap (when `systemd-run` is available), a hard
  time limit, a fresh empty NVRAM and cfg folder per run, and headless video and sound, and refuses a rompath with more
  than one folder. Snapshots still work from Lua.
- An edited set is built by `scripts/patchzip.py ROM_FOLDER SET MEMBER:OFFSET:OLD:NEW [--with ZIP]` into a fresh folder
  under `tmp/`, which is then the **only** folder on the ROM path. If the byte at OFFSET is not OLD, it stops: your set
  is a different version. `--with` copies another zip unchanged (Space Dungeon needs the 68705 device ROM). The folder
  is deleted when the demo ends; `tmp/` is not committed.
- Why one folder: with the real ROM folder as a second path, MAME rejects the edited file on its checksum and silently
  loads the genuine one, so the run looks like "no effect". Every Lua script therefore also logs the bytes MAME loaded.
- Logs, snapshots and the GIF go to `atari/out/`, `taito/out/`, `universal/out/` or `nintendo/out/` (not committed).
  `scripts/gif_pair.py` (needs Pillow) makes the GIF; it is `konami/gif_pair.py` with a footer, a scale, a frame offset
  for events at different frames, and a `{c}` caption field for a value from the log.

## Files

```
trapscan.py            command line
trapscan/disasm.py     8080 disassembler
trapscan/scanner.py    signature scanner
trapscan/emu8080.py    8080 CPU + Invaders-family board model
trapscan/romload.py    zip/folder loading, known layouts, heuristic layout
trapscan/audit.py      credit counter from a coin test; every instruction that can write it
trapscan/boards.py     other board models (Space Stranger)
trapscan/z80mode.py    Z80 detection, layout and static scan (Taito SJ, Crazy Balloon)
trapscan/skiplist.py   name prefixes for --skip-nonarcade
batch.py               folder -> one Markdown report
sigsearch.py           byte-search a whole collection for the trap code
scripts/eggdemo.py     trigger TAITO COP / HOEI COP and save a screenshot (and with --gif, a GIF)
scripts/gifutil.py     caption strip and GIF writer used by trapdemo.py
scripts/trapdemo.py    screenshots (and with --gif, GIFs) of the credit traps firing (or not) in attract mode
scripts/verify.py      check the README and docs against the real ROMs (about 2 minutes)
atari/astdelux_trap.lua    MAME script: Asteroids Deluxe rev 1, genuine or copyright changed
atari/centipede_trap.lua   MAME script: Centipede, genuine POKEY or reads that differ
atari/centipede_probe.lua  MAME script: what Centipede's POKEY check reads on any set (bootlegs included)
atari/verify_atari.py      check the Atari listings against the real ROMs
atari/slamscan.py          scan Atari 6502 games for a slam-switch credit trap
atari/demo_bzone.sh        Battlezone demo (credits, 100k); Lua: atari/bzone_credits.lua, atari/bzone_100k.lua
taito/demo_sdungeon.sh     Space Dungeon demo; Lua: taito/sdungeon_delayed.lua
universal/demo_mrdu.sh     Mr. Do! against Mr. Du!; Lua: universal/mrdu_diamond.lua
nintendo/demo_dkjr.sh      Donkey Kong Jr. demo; Lua: nintendo/dkjr_vine.lua
nintendo/demo_popeye.sh    Popeye demo; Lua: nintendo/popeye_lives.lua
scripts/mame.sh            the MAME wrapper every MAME demo above uses (Konami's included)
scripts/patchzip.py        an edited copy of one of your zips, in a one-folder rompath under tmp/
scripts/gif_pair.py        side-by-side captioned GIF from two runs' snapshots
docs/                  write-ups and this guide
```

ROMs are not included. Use your own dumps.
