# Centipede (Atari, 1980) – free credits on boards without a genuine POKEY

MAME set `centiped` (revision 4) and clones. 6502 CPU. Program ROMs 136001-407 to -410 at $2000–$3FFF; POKEY at
$1000 (`$100A` = random number, `$100F` = SKCTL). Credit count: **`$C8`**, a plain
binary count (no `SED` is in force in any code that touches it): coins add to it with `INC $C8` (`$3487`, and
`$3489` for a second credit), Start takes 1 with `DEC $C8` (`$2600`), the CREDITS display (`$25CD`) shows a "1" and
then `$C8` − 10 when it is 10 or more, and the interrupt handler (`$38F9`) caps it at 18, and hangs if it ever
reaches 37.

**This one is already documented**: the commented disassembly at
[6502disassembly.com](https://6502disassembly.com/va-centipede/Centipede_rev4.html) labels it *"add credits if it's
not a POKEY"*. What's added here is how the bootleggers dealt with it, and a demonstration in MAME.

## In short

At power-up and at the start of every game, Centipede puts its POKEY sound chip into reset, which freezes the
chip's random-number register. It then reads that register twice and adds the difference to the credit count:

```
28A2  LDA $100A        ; POKEY random number
28A5  EOR $100A        ; ... again: 0 on a genuine POKEY in reset
28A8  CLC
28A9  ADC $C8
28AB  STA $C8          ; credits = credits + difference
```

This one is known: the commented disassembly at
[6502disassembly.com](https://6502disassembly.com/va-centipede/Centipede_rev4.html) calls it "add credits if it's
not a POKEY". What the MAME sets add is the bootleggers' side. Six Centipede bootlegs replace the POKEY with a cheaper General
Instrument sound chip. **Caterpillar** and one set of **Magic Worm** (the bootleg Atari took to court) changed these
two reads to read the same byte twice, so the difference is always 0; the other Magic Worm set removed the check;
three more bootlegs left it alone.

## The check ($2876, at power-up and at the start of every game)

```
2891  LDA #$00
2893  STA $100F        ; SKCTL = 0: POKEY into reset, its random-number generator stops
 ...                   ; (clear sound channels and scores)
28A2  LDA $100A        ; read the random number
28A5  EOR $100A        ; ... and again: on a real POKEY in reset, the same value, so this is 0
28A8  CLC
28A9  ADC $C8
28AB  STA $C8          ; credits = credits + difference
28AD  LDA #$03
28AF  STA $100F        ; POKEY back on
```

On a genuine POKEY the two reads are identical and nothing is added. On a board whose random register doesn't stop
(no POKEY, or something standing in for one), the reads differ and the game adds the difference to the credits,
every time a game starts. MAME's POKEY emulation follows the real chip: in reset the generator is held, and reads
return the same value.

All of Atari's sets carry it: revision 4 at `$28A2`, revisions 1 and 2 three bytes earlier (and so does Centipede Dux,
a 1989 hack).

## What the bootlegs did

Six Centipede bootlegs in MAME 0.277 replace the POKEY with a cheaper General Instrument AY-3-8910/8912 sound chip.
Two changed the two reads, one removed the check, and three left it as Atari wrote it:

| Set | Sound chip | Code at the check |
|---|---|---|
| `centiped` (Atari) | POKEY | `LDA $100A / EOR $100A` |
| `magworm`, Magic Worm set 1 (Sidam bootleg) | AY-3-8912 | removed: the bytes now set up the AY chip (`LDA #$07 / STA $1001 / LDA #$31 / STA $1003`, then `JSR $3069 / NOP / NOP / NOP`) |
| `magworma`, Magic Worm set 2 (bootleg) | AY-3-8912 | `LDA $E2 / NOP / EOR $E2 / NOP`: reads a RAM byte twice, always 0 |
| `caterplr`, Caterpillar (Olympia bootleg) | AY-3-8910 | `LDA $289F / EOR $289F`: reads a ROM byte twice, always 0 |
| `centipdb`, Centipede bootleg set 1 | AY-3-8910 | unchanged |
| `centipdb2`, Centipede bootleg set 2 | AY-3-8910 | unchanged (it shares this ROM, `e1`, with set 1) |
| `millpac`, Millpac (Valadon Automation bootleg) | AY-3-8910 | unchanged |

Leaving it in can be harmless: if address `$100A` returns the same value twice on the bootleg board, Atari's code
adds nothing. What `$100A` reads on each of these real boards isn't known, so neither is why three changed or removed
the check and three didn't.

### The three that kept the check, in MAME

In MAME 0.285, `centipdb`, `centipdb2` and `millpac` map only the AY chip in that area (`$1000`–`$1001`, mirrored at
`$5000`). `$1002`–`$100F` is mapped as a do-nothing read, so both reads of `$100A` return `00`, the difference is 0,
and nothing is added. On the genuine set both reads return `FF` (the POKEY's frozen random register).

Run with a fresh NVRAM, a coin every 30 seconds and Start pressed every 10 seconds (`atari/centipede_probe.lua`, which logs
each read at the check and every change to `$C8`; the ROMs are not changed):

| Set | Check runs (power-up + game starts) | Values read at the check | Reads that differed | Credits added by the check |
|---|---|---|---|---|
| `centiped` (genuine, for comparison) | 1 + 12 | `FF` | 0 | 0 |
| `centipdb` | 1 + 15 | `00` | 0 | 0 |
| `centipdb2` | 1 + 15 | `00` | 0 | 0 |
| `millpac` | 1 + 13 | `00` | 0 | 0 |

To repeat a run, from the repo root (each run gets a fresh temporary folder, so it starts from an empty NVRAM):

```bash
st=$(mktemp -d)
mame centipdb -rompath ~/roms -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" \
     -video none -sound none -nothrottle -seconds_to_run 1200 -autoboot_script atari/centipede_probe.lua
rm -rf "$st"
```

It prints the read handlers MAME has at `$1000`–`$10FF`, each pair of reads at the check, every credit change, and a
summary line at the end. Swap `centipdb` for `centipdb2`, `millpac` or `centiped`.

So none of the three pays out in the emulator, because MAME returns 0 for an address with nothing behind it. That
is emulation only. On a real board the read hits nothing, and what an unconnected read returns depends on the board:
on a 6502 it is often the last byte on the data bus, here `$10` (the high byte of the address), which would also be
the same both times, but that hasn't been checked on hardware. That is only a possibility, but it could explain why
three bootleggers left the check alone: if it never fired on their boards, there was nothing to fix.

Magic Worm is the bootleg that Atari took to court using Centipede's hidden Morse-code signature
([Arcade Blogger](https://arcadeblogger.com/2019/06/29/atari-centipedes-hidden-code-trap/)).

## In MAME

`atari/centipede_trap.lua` changes only the two reads at `$28A2`/`$28A5` so that they differ by 3, as on a board
whose random register kept running. (Faking the random register everywhere doesn't work: Centipede checks for a
genuine POKEY in other places too, and resets.) `NOPOKEY=0` runs the genuine board.

| Genuine POKEY | Random register not frozen |
|---|---|
| ![Centipede at power-up, genuine: no credits](img/centiped-genuine-powerup.png) | ![Centipede at power-up, reads differ: CREDITS 3](img/centiped-nopokey-powerup.png) |

*Straight after power-up, before any coin. Made with `atari/centipede_trap.lua`, which makes only those two
reads differ. The check also runs at power-up, so the second board starts with 3
credits. After that, each coin adds 1 and each Start costs 1 but adds 3: 6, 9, 12... On the genuine board each Start costs
a credit as normal.*
