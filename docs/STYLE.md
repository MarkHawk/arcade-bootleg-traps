# Style guide for adding a game

How to add a new game to this repo so it matches the existing sections. Every new game gets: a README section, a row in each summary table it belongs in, a doc in `docs/`, a demo script, its GIFs, and an entry in `docs/USAGE.md` and `docs/ROMLIST.md`. Check each item against this guide before committing.

## Language

- UK English (colour, licence, neutralised). No em dashes anywhere: use a colon, a comma, or two sentences. The one dash in use is a spaced en dash between a doc's title and its tagline (see Doc), and en dashes in year ranges (1979–84).
- Plain words first. Explain a term the first time it appears in a section, or link it to [Terms used](README.md#terms-used). Add new terms to that list.
- Short sentences. One idea per sentence where possible.
- Set names in backticks (`mrdu`), game names in plain text, a bootleg's on-screen name in bold the first time (**Mr. Du!**).
- Hex with a `$` prefix (`$6245`), the same across README and doc: this is what every doc uses except two. Donkey Kong Jr.'s doc uses `#` (`#2441`) to match the dkdasm listing it was checked against; Mr. Do!'s doc uses `0x` (`0xE006`). A new doc uses `$`. Quote source-code labels exactly, in backticks (`WCURS`).
- Numbers: digits with thousands separators (1,500), "1 in 512" for odds.

## Honesty rules

These matter more than anything else on this page.

- **Never "new", "first" or "undocumented".** Write "not found in the sources checked", and list the sources in the doc.
- **Already published comes first.** If any part of a game's check is published, say so in the section's first paragraph and credit the author by name with a link. Then say what this repo adds.
- **Emulation is not hardware.** Results are "in MAME". A bootleg's ROMs "trip the check in MAME"; never "caught a real board" unless a real board was tested.
- **Label interpretation.** Anything about intent ("meant to", "designed to", "deliberate") starts with "Interpretation:" and, where there is a reasonable alternative, gives it.
- **Say what was poked.** Every demo that writes to RAM or edits a ROM says exactly what, and what happened naturally: "score poked to 99,000; the kill that passed 100,000 was the game's own". Use the same wording in the caption, the doc and Caveats.
- **Never fetch tcrf.net**, by any tool or script. Existing TCRF links stay as they are, unchecked. Don't cite a TCRF page that wasn't read; where a TCRF page is the only known source, say "TCRF was not checked (it doesn't allow AI agents)" and rest nothing on it.
- Figures in the README must match the doc. If they differ, the doc (built from the run logs) wins.

## README section

Heading: `## Game (Maker, Year)`, for example `## Mr. Do! (Universal, 1982)`. Sections run in year order; within a year, add the new one after the existing ones. Anchors are GitHub's: `#mr-do-universal-1982`.

Body, in this order, two or three short paragraphs:

1. **What the check does.** What it reads (copyright text, drawn logo, code, a chip), when it runs, and what failure does. Lead with what is already published, credited.
2. **What the bootlegs did.** Tripped, dodged, removed, or unaffected, with set names. If there's no bootleg in MAME, say so and say the demonstration is simulated.
3. **The GIF**, then its caption, then the doc link.

GIF block:

```markdown
<img src="docs/img/<game>-<what>-pair.gif" width="720" alt="<what the reader sees on each side, and the outcome>">

*Left: genuine `set`. Right: <the other side>. <Inputs, what was poked, what was natural>. <The outcome in numbers>. Made with `<maker>/demo_<game>.sh`.*

Full details: [docs/<maker>-<game>.md](docs/<maker>-<game>.md).
```

## Tables

**The short version** (top of the README): one row, columns `Game | Maker | Year | What the protection does | What the bootlegs did | Demo`. The game name is bold and links to its doc. The Demo cell links to the game's README section as `[GIF](#anchor)`, or `[still](#anchor)` where the demo is a still image. Put "in MAME" on any bootleg result, or "simulated here" where there is no bootleg. Rows run in year order, except that the standout (Mr. Do!) leads. Keep cells short.

**It worked on real bootlegs** ("other makers" table): one row per bootleg set or group, columns `Set | Copy of | What it did with the protection | Result`. Results use one of: **tripped**, **dodged**, protection removed, unaffected, nothing tripped. Then update the sentence under the table that counts how many bootlegs tripped a check.

**The makers in brief**: add or extend the maker's paragraph. Makers run in year order. Mark opinion "Interpretation:".

**The opening and the verification paragraph** (top of the README): update the count of games and the list of games checked in MAME, and name the listings the verify scripts cover.

**Was this policy?**: add or extend the maker's bullet, with interpretation labelled.

**Terms used**: add any new term, and link to it from the section.

**Prior art**: one bullet per published source, saying exactly what it covers. Then update the "Not found in the sources checked" paragraph at the end of Prior art. TCRF entries keep the wording already used there: read by hand earlier, before TCRF's policy on automated access was known, and not rechecked.

**Caveats**: one bullet per game: what was poked, which MAME version (0.285), how far scripted play got, any set not tested.

**Try it yourself**: add the sets the demo needs, if they are not already listed (in `docs/USAGE.md` under "The November 2026 demos" and in `docs/ROMLIST.md`).

**References**: the driver source (a link pinned to the MAME version used, for example `.../blob/mame0285/src/mame/universal/mrdo.cpp`) and every external source cited.

## Doc (`docs/<maker>-<game>.md`)

Older docs omit the maker in the file name (`centipede.md`); new ones use it. The title line has a spaced en dash and a short tagline. The link back to the README comes under the title, then a paragraph naming the MAME sets, the CPU, how addresses are written and the MAME version.

```markdown
# Game (Maker, Year) – what the check does, in a phrase

[Back to the README](../README.md)

MAME sets `x`, `y`. One Z80. Addresses are CPU addresses in `x`. MAME 0.285, ROMs from 0.277 sets.

## In short
## <the topic sections: the check, the device, the sums>
## The bootlegs
## In MAME
## Rerun
## Prior art and sources checked
## Caveats
```

- **In short**: what is already published first (credited, linked), then what this repo adds, then the GIF with its caption.
- **Topic sections**: name them for what they explain ("The check", "The protection chip"). Section names vary by game, and the in-MAME section is called "In MAME", "Tests in MAME" or "Demonstration (MAME 0.285)" in different docs; use "In MAME". Tables with genuine and edited (or bootleg) side by side, frame numbers, values read from RAM.
- **Controls**: where a published check could be reproduced, or a known edit found, say so in the text (as Donkey Kong Jr. does with Donkey Kong's check). Where there is no control, say that too (as Mr. Do! does).
- **Prior art and sources checked**: "Published, and not claimed here:" with one bullet per source, then "Not found in the sources checked:" and every source searched, including the ones that said nothing. Say "TCRF was not checked (it doesn't allow AI agents)" where that applies. This is what "not found in the sources checked" rests on.

## Demo script

- `<maker>/demo_<game>.sh <rompath>`, with the Lua script beside it (`universal/mrdu_diamond.lua`), run through `scripts/mame.sh`: any edited zip alone on the ROM path, the bytes MAME loaded logged at the start of every run. Logs and GIFs go to `<maker>/out/` (not committed). Add the script and its Lua to the file list in `docs/USAGE.md`.
- Edits are built from the reader's own ROM set (`scripts/patchzip.py`) into a temporary folder. The script holds addresses and replacement byte values only, never ROM data. If MAME's decrypted memory is edited instead (encrypted ROMs), say so in the script, the caption and Caveats.
- Prints the log lines the README quotes, so a reader can compare.
- Test it end to end from a clean checkout before committing.

## GIFs and images

- `docs/img/<game>-<what>-pair.gif`, lower case, hyphens, starting with the MAME set or short game name (`mrdu-special-pair.gif`, `popeye-lives-pair.gif`). Single-side GIFs and stills drop `-pair` and use `.png` for stills.
- In the README: `<img ... width="720">` for a pair, 360 for each half of a table. The GIF is built by `scripts/gif_pair.py`.
- Pairs: genuine on the left. Same inputs on both sides. A caption bar names each side; a footer states anything poked.
- If the game doesn't show the value that matters (credits, lives), add it to the caption bar, read from RAM, and say so.
- Under about 1.5 MB each (the largest here is 1.2 MB). Alt text describes the outcome, not just the scene.

## Before committing

- [ ] Every figure matches the doc and the run logs.
- [ ] "Not found in the sources checked" and the source list are up to date, in the doc and in Prior art.
- [ ] Everything poked or edited is stated in the caption, the doc and Caveats.
- [ ] `scripts/linkcheck.py` passes; every README anchor matches a heading.
- [ ] New external links checked once each (not tcrf.net).
- [ ] `docs/USAGE.md` and `docs/ROMLIST.md` list the new demo, files and sets.
- [ ] Gitleaks and Trivy clean; no ROM data tracked.
- [ ] The demo runs from a clean checkout.
- [ ] A cold read of the new section, as a stranger.
