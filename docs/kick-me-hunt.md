# The "kick me for a free game" story – looked for, not found

[Back to the README](../README.md)

## In short

Ned Batchelder [heard a story](https://nedbatchelder.com/blog/200404/arcade_copy_protection) at General Computer
(Ms. Pac-Man's developers) in 1982: a game that, if its copyright notice is missing, shows "KICK ME FOR A FREE GAME"
and gives a credit each time the cabinet's slam switch trips. I looked for it in the games closest to the story
(Missile Command, General Computer's Super Missile Attack, Ms. Pac-Man), searched every 1975–85 set for the
wording, and scanned all 112 sets that use Atari's standard coin routine for a slam-switch read that leads to a
credit. **Not found**: in every one, the slam switch only blocks coins for a moment, and Ms. Pac-Man's board has
no slam switch at all. That search is what turned up Asteroids Deluxe and Centipede.

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

## Limits

- The scanner only covers games that use Atari's coin routine. A kick-me trap in another maker's game, or in an
  Atari game with different coin code, wouldn't be seen.
- In the story the trap only arms after 100 plays. A static search still sees the credit write, so this doesn't
  hide it, but nothing here was run for 100 games.
- The story may describe a scheme that never shipped.

## Prior art and sources checked

This list was written after the fact, from the sources the README names (its Prior art and Caveats) and the ones this doc already cites. It is not a log of searches made at the time.

The story is Ned Batchelder's, second-hand: [Arcade copy protection](https://nedbatchelder.com/blog/200404/arcade_copy_protection) (2004), cited above.

Sources: that page, plus Computer Archeology, 6502disassembly.com and the arcade history databases, as the README's Caveats name them. The searches of ROM text and code are listed under "Where I looked" above, and are the work of this repo, not a source. TCRF: TCRF does not allow automated or AI access. Its pages were consulted earlier, before TCRF's policy on automated access was known, and were not rechecked.
