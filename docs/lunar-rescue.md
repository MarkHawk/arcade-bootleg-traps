# Lunar Rescue (Taito, 1979) – hidden credit routine

[Back to the README](../README.md)

ROM map: lrescue.1–.4 at $0000–$1FFF, lrescue.5–.6 at $4000–$4FFF. 8080 CPU, Space Invaders-style I/O.
Work RAM $2000–$23FF, video RAM $2400–$3FFF.

## The Taito traps at a glance

| Game | Secret combo (attract mode) | Gives | Armed when… |
|---|---|---|---|
| **Lunar Rescue** | P1 Start + Fire + Right | 3 credits | the "© TAITO CORPORATION" text on the title screen has been altered |
| **Space Invaders Part II** | P1 Start + P2 Start + Fire + Left | 2 credits | one of two unused input lines on the board reads high (i.e. it isn't running on the expected hardware) |
| Space Invaders Part II, second trap | P1 Start + P2 Start + Fire + Right | nothing (bug) | the game's own ROM has been patched |
| Space Invaders (1978; MAME's `invaders`, the Midway set) | none | – | no trap, just the known "TAITO COP" easter egg |

Combos must be exact: the other buttons have to be released, or nothing happens.

## Credits
- Credit count: **$20EB** (BCD, capped at 9).
- Normal writers: coin in the interrupt routine ($0038), coin while music plays ($4DA9),
  start deducts 1 or 2 ($00B2), RAM init at reset (from ROM table $1AA3).
- **Hidden writer: $47E9**, which sets credits to **3**.

## The routine ($47D8)

The game keeps its credit count in RAM at `$20EB`. Besides the normal coin and start-button code,
there's one more place that writes it, tucked into the extra ROM at `$4000`:

```
47D8  call $037C        ; read player-1 controls (port 1)
47DB  ani  $76          ; keep bits 1,2,4,5,6
47DD  cpi  $54          ; need: Start1(b2) + Fire(b4) + Right(b6), with Left(b5) and Start2(b1) released
47DF  rnz
47E0  mvi  l,$ED        ; HL = $20ED "armed" flag, built in two halves, so "$20ED" never appears in the code
47E2  mvi  h,$20
47E4  mov  a,m / ana a
47E6  rz                ; not armed -> do nothing
47E7  dcx h / dcx h     ; -> $20EB credits
47E9  mvi  m,$03        ; credits = 3
```
Called once per loop from the attract-mode demo loop ($474E–$478F, call at $4760): it runs on every pass of the
attract-mode demo.

## The arming condition ($4686)
- $20ED is set to 1 at power-up (RAM init table).
- Each time a title screen draws "© TAITO CORPORATION", $4686 checks three bytes of
  screen memory inside the word "TAITO" ($2B47=$7F, $2C47=$44, $2E27=$40).
  If they match, $20ED is cleared and the routine is dead.
- So the combo only works if the copyright line has been **changed** (e.g. a bootleg relabelled
  with another company's name). On a genuine board it never fires.
- A second check at $46A0 (called from $43D0 during play) sums another column of that text
  and diverts to $0362 if it's wrong. This looks like more anti-bootleg logic.

**What arms it:** the flag at `$20ED` is set to 1 at power-up. Each time the title screen draws
"© TAITO CORPORATION", a routine reads three bytes of screen memory *inside the letters of "TAITO"*
and compares them with what they should be. If they match, the flag is cleared and the trap is dead.

So on a genuine board, the trap disarms itself 2.6 seconds after switch-on. But if a bootlegger
changed the copyright line, which they routinely did to sell copies under another name, the check
fails, the flag stays set, and anyone who knows the combo gets free games on the bootlegger's
machine.

| Genuine `lrescue` | Bootleg `desterth` (Destination Earth) |
|---|---|
| <img src="img/lrescue-genuine.gif" width="360" alt="lrescue, buttons held then released: the credit counter stays at 0"> | <img src="img/lrescue-desterth.gif" width="360" alt="desterth, buttons held then released: the credit counter goes to 03"> |

*Same buttons (P1 Start + Fire + Right) held in the attract demo, then released once the credit counter changes. Genuine: nothing. Destination Earth: 3 credits. Made with `scripts/trapdemo.py --gif`.*

Which real bootlegs pay out: [bootleg-results.md](bootleg-results.md).

## Emulator results (custom 8080 emulator, inputs held for ~100 frames during the attract demo)
| ROM | Inputs held | Result |
|---|---|---|
| Genuine | Start1 + Fire + Right | nothing; flag cleared at frame 156 |
| One "TAITO" letter altered | Start1 + Fire + Right | credits set to 3, the held Start then starts a game → 2 left |
| Altered | Start1+Right, Fire+Right, Start1+Fire | nothing |
| Altered | combo + Left, or combo + Start2 | nothing (they must be released) |

## Try it in MAME
1. Debugger: `bpset 47e9` – genuine set never hits it.
2. Simulate the bootleg: the copyright check runs on **both** title screens (frames ~156 and ~496),
   so set `b@20ed=1` after the second one (~10 s from power-on). When the attract demo starts
   (~27 s), hold P1 Start + Fire + Right. Credits jump to 3.
3. Or with trapscan: `python3 trapscan.py run lrescue.zip --poke 20ed=1@600 --hold start1+fire+right@1600-1700 --watch 20eb`
