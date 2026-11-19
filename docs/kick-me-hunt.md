# The "kick me for a free game" story – looked for, not found

[Back to the README](../README.md)

## In short

Ned Batchelder [heard a story](https://nedbatchelder.com/blog/200404/arcade_copy_protection) at General Computer
(Ms. Pac-Man's developers) in 1982: a game that, if its copyright notice is missing, shows "KICK ME FOR A FREE GAME"
and gives a credit each time the cabinet's slam switch trips. I looked for it in the games closest to the story
(Missile Command, General Computer's Super Missile Attack, Ms. Pac-Man), searched every 1975–85 set for the
wording, and scanned all 112 sets that use Atari's standard coin routine for a slam-switch read that leads to a
credit. **Not found**: in every one, the slam switch only blocks coins for a moment, and Ms. Pac-Man's board has
no slam switch at all. That search is what turned up Asteroids Deluxe and Centipede. A second search then went
through General Computer's own games (Ms. Pac-Man, Jr. Pac-Man, Food Fight, Quantum and Super Missile Attack),
see [General Computer's own games](#general-computers-own-games): also **not found**.

## The story

Ned Batchelder [heard this story](https://nedbatchelder.com/blog/200404/arcade_copy_protection) during a summer at
General Computer (the company behind Ms. Pac-Man) in 1982: a game that, after 100 plays, checks screen memory for
its copyright notice and, if it's missing, shows "KICK ME FOR A FREE GAME" and gives a credit every time the
cabinet's slam switch trips. He adds: "I don't know if it is true, but it sounds good." The setting is ROM swaps
that upgrade older machines, which is what Space Invaders Part II's board check guards against, and what General
Computer itself sold at first (Super Missile Attack for Missile Command; Crazy Otto, which became Ms. Pac-Man).

## Where I looked

**Text.** Every 1975–85 set in a MAME 0.277 collection (2,497 zips) and a MAME 0.78 collection, searched for
"KICK ME", "FREE GAME" and "FREE CREDIT" in whatever letter codes each game uses (the encoding is confirmed from
ordinary words such as SCORE and CREDIT first, so four random letters don't count). Not found.

**The games closest to the story**, by hand:

| Game | Slam / tilt switch | What writes the credit count | Result |
|---|---|---|---|
| Missile Command (Atari, 1980), all revisions | `$4900` bit 5 | coin, Start (1 or 2), free play (sets 2), a cap at 40 | clean: the slam switch only blocks coins for a moment (Atari's standard coin routine); the copyright text is only ever printed; the only ROM check is in the self-test |
| Super Missile Attack (General Computer, 1981) | same | same four, and the coin, Start and slam code is byte for byte Atari's | clean; it adds "SUPER ATTACK" and "GENCOMP © 1981" |
| Ms. Pac-Man (Midway / General Computer, 1981) | **none**: Pac-Man's board has no slam or tilt input | coin (including the service button), Start, free play | clean; the hidden "GENERAL COMPUTER CORPORATION Hello, Nakamura!" text is never read; General Computer's own protection is in hardware (the extra board's ROMs are encrypted, and decoding switches on and off at set addresses) |

**Every Atari game that uses Atari's coin routine.** `atari/slamscan.py` finds the slam check inside Atari's
standard coin routine, which tells it where the slam switch is read and which byte holds the credits, then lists
every other read of the slam switch and every other write to the credit count. In the same MAME 0.277 collection,
112 sets use the routine (Asteroids, Asteroids Deluxe, Battlezone, Black Widow, Centipede, Crystal Castles,
Gravitar, Liberator, Lunar Lander, Major Havoc, Millipede, Missile Command, Red Baron, Space Duel, Tempest, Warlords
and others, with their clones). **In none of them does a slam-switch read lead to a credit.**

(The first version of the scanner flagged 22 sets. All were mistakes in the scanner: Centipede's clones and Maze
Invaders read a different bit of the same input, the Start button; Crystal Castles passes its input byte to the
coin routine, and the "credit write" after it is the cap at 18 credits. Both are fixed.)

## What the hunt found instead

Going through every remaining credit write in that report by hand turned up two traps of a different kind, both
built on the same idea as Lunar Rescue: a copy check that quietly gives free credits instead of stopping the game.

- [Asteroids Deluxe](asteroids-deluxe.md), revisions 1 and 2: a changed copyright line arms a 1-in-3 chance of
  2 free credits at every game over on the high-score table. Not found documented.
- [Centipede](centipede.md): free credits at every game start on a board without a genuine POKEY. Already
  documented; of the six bootlegs that replaced the POKEY, three patched it out and three left it alone.

## General Computer's own games

The first search covered Atari's coin routine, which none of General Computer's own games except Super Missile
Attack share. So the games General Computer itself made were looked at separately: Ms. Pac-Man (`mspacman`, Z80),
Jr. Pac-Man (`jrpacman`, Z80), Food Fight (`foodf`, 68000), Quantum (`quantum`, 68000) and Super Missile Attack
(`suprmatk` and `suprmatkd`, 6502). All in MAME 0.285, from 0.277 ROM sets, nothing edited. Hex addresses are CPU
addresses with a `$` prefix. A set's program is the memory MAME loads: Ms. Pac-Man's decoded bank, Jr. Pac-Man after
MAME's decryption, Super Missile Attack after its own decode step.

### What was searched

- **Text, in every encoding I could think of.** The words "KICK ME", "FREE GAME", "FOR A FREE", "ME FOR A", "KICKME"
  and "FREEGAME" (spaces as wildcards), found by matching the differences between letters, so any constant offset
  counts (ASCII, minus `$30`, `$37` or `$40`, a game's own tile codes). Upper, lower and Title case, forwards and
  backwards, one byte or two bytes a character. Also packed text: 5, 6 and 7 bits a character at every bit
  position, and three 5-bit characters in a 16-bit word. **Controls**: the same search finds CREDIT and GAME in each
  game's own encoding (plain ASCII in the Pac-Man boards, Quantum and Missile; ATARI and FOOD in Food Fight), and
  finds Food Fight's packed CREDIT as 6 bits a character.
- **Food Fight's packed text, decoded.** Most of Food Fight's screen text is not ASCII: a routine at `$78F6` unpacks
  6 bits a character (three bytes make four characters, the code plus `$20`, with `$3E` ending the string). All 324
  messages, in four languages, were decoded and read. Nothing about kicking, and no "free game".
- **Quantum's string table.** Quantum's text is ASCII, in four languages, drawn through a character table. All
  about 170 strings were read. The only "free" words are the statistics lines FREE CREDS and FREE LIVES. A search for
  runs of that character table's vector calls that would spell the words found none, but it has no control (the game
  builds all its text from ASCII), so it counts for little.
- **Graphics ROMs rendered.** Every tile and sprite sheet of the three games that have them (Ms. Pac-Man, Jr. Pac-Man,
  Food Fight) was drawn with the driver's own layout and looked through, for lettering, a boot or foot, or any
  message-like picture. Quantum and the Missile boards have no graphics ROM (vectors and a bitmap).
- **Every input bit the program reads**, compared with MAME's labels, with what the code does after each read. The
  Pac-Man boards were found by scanning for the opcodes that read `$5000-$50FF` and checked with a MAME read tap;
  Food Fight and Quantum, whose code reaches their ports through pointer cells in the ROM, by a read tap and by
  reading the routines it named; Super Missile Attack by tracing the code from its vectors and diffing it against
  Atari's revision 2.
- **Games counters.** Where a count of plays is kept, and every compare of anything against 99, 100 or 101.
- **Copyright read-backs.** Every read of video memory (a MAME read tap over 95 seconds of attract mode for the two
  Pac-Man boards, the code for the rest), looking for one that compares the screen with the copyright text.

### Result: not found in any of the five

- **No such text** in any program ROM, in any form above, and none in the graphics.
- **No slam or tilt input is modelled by MAME** for four of them: Ms. Pac-Man, Jr. Pac-Man, Food Fight and Quantum
  (Quantum's input bit 6 is "unknown" in MAME, and no code I found reads it). Super Missile Attack has one, bit 5 of
  `$4900`. Its code is Atari's coin routine unchanged: a slam sets a four-second timer (`$5F`) that wipes the
  pending coins, and nothing gives a credit. Of the 45 places where it differs from Atari's revision 2, none is in
  the input or coin code.
- **No games counter that is compared with a limit.** The Pac-Man boards and Super Missile Attack have no
  battery-backed memory at all, so a count of "the first 100 games" could only be a count since power-on. Food
  Fight and Quantum keep statistics (games, coins, free credits) in battery-backed RAM, but those counters are only
  added to and shown on the statistics screens. The compares with 100 that exist are for ghost positions in the
  tunnel, for choosing a three-digit layout, and for clamping a position.
- **No read of the copyright line.** Video memory is read only by Pac-Man's own routines (the dot count, the power
  pellet flash, maze tiles) and the like. Nothing compares it with a string.
- **Two inputs that give a credit, but are not a kick trap.** Food Fight's bit 4 (the driver calls it "Aux coin";
  MAME labels it Service 1; the self-test lists AUX COIN) and Quantum's bit 1 (MAME: Coin 3) each give one credit
  every time the switch is triggered. Shown in MAME on the genuine sets, four presses each, nothing poked: credits
  1, 2, 3, 4 in both. In Food Fight the credit ignores the coinage switches (with the coinage changed, Coin 1 gave
  2 credits a press and Aux coin still 1). The code has no condition on either: no counter, no copyright check and
  no message, so they work from the first game. Interpretation: they are service credit switches, and the story
  does not describe them. Ms. Pac-Man's IN0 bit 7 is likewise a credit input, not a slam.
- **Odd but unrelated.** The hidden text "GENERAL COMPUTER CORPORATION Hello, Nakamura!" is in both Ms. Pac-Man and
  Jr. Pac-Man (at `$97D0`) and no code refers to it. DSW1 bit 7, "unused" in MAME, is read by the Pac-Man code into
  a text offset; Interpretation: a leftover of Pac-Man's ghost-name option.

Interpretation: nothing here matches the story. Either the scheme never shipped in these games, or it was in a
different product, or the account has grown in the telling (Batchelder says he does not know if it is true). A
search of ROMs cannot rule out a check written in an idiom I did not look for.

### Caveats for this section

- **The Missile slam run was inconclusive.** I tried to show the slam switch not giving a credit in MAME (two coins,
  then five tilt presses, on `missile2` and `suprmatk`), but I read the wrong byte as the credit count, and even the
  control showed nothing usable. No claim rests on it; the slam result is from tracing the code.
- **Unused graphics were not checked.** I looked at the graphics sheets but did not trace which tiles and sprites
  code ever draws, so a picture that nothing displays could still be there. Candidates seen: Food Fight's three "hi
  Jon" sprites (the known message) and one unreadable block of marks among Jr. Pac-Man's sprites.
- **The Pac-Man input audit is by opcode scan and read taps**, not a full trace of the code, so a read reached only
  through a table could be missed. The two 68000 listings are linear, so data inside code can misalign. Quantum's
  DSW1 bits were not traced.
- No game was run for 100 plays: with no counter or text to aim at, a run could not have shown anything. Other
  revisions and other General Computer products (such as Crazy Otto) were not checked.
- Results are for MAME 0.285, not real boards.

## Limits

- The scanner only covers games that use Atari's coin routine. A kick-me trap in another maker's game, or in an
  Atari game with different coin code, wouldn't be seen. (General Computer's own games were searched separately,
  above.)
- In the story the trap only arms after 100 plays. A static search still sees the credit write, so this doesn't
  hide it, but nothing here was run for 100 games.
- The story may describe a scheme that never shipped.

## Prior art and sources checked

This list was written after the fact, from the sources the README names (its Prior art and Caveats) and the ones this doc already cites. It is not a log of searches made at the time.

For General Computer's own games, the sources are the ROMs themselves (searched as above), MAME 0.285's drivers (`pacman.cpp`, `jrpacman.cpp`, `foodf.cpp`, `quantum.cpp`, `missile.cpp`, [mame0285](https://github.com/mamedev/mame/tree/mame0285/src/mame)) for the memory maps and input labels, and a web search for other tellings of the story, which found only Batchelder's post. General histories of General Computer's kits and the Atari lawsuit ([Golden Age Arcade Historian](https://allincolorforaquarter.blogspot.com/2012/12/ms-pac-man-and-super-missile-attack.html), [Game Developer](https://www.gamedeveloper.com/business/upgrade-kits-lawsuits-and-lite-brite-how-i-ms-pac-man-i-was-made), [MAME wiki, General Games FAQ](https://wiki.mamedev.org/index.php/FAQ:General_Games)) mention encrypted plug-in boards, not a kick-me trap; their search summaries were read, not each page in full. TCRF was not checked: TCRF does not allow automated or AI access.

The story is Ned Batchelder's, second-hand: [Arcade copy protection](https://nedbatchelder.com/blog/200404/arcade_copy_protection) (2004), cited above.

Sources: that page, plus Computer Archeology, 6502disassembly.com and the arcade history databases, as the README's Caveats name them. The searches of ROM text and code are listed under "Where I looked" above, and are the work of this repo, not a source. TCRF: TCRF does not allow automated or AI access. Its pages were consulted earlier, before TCRF's policy on automated access was known, and were not rechecked.
