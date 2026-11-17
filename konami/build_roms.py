#!/usr/bin/env python3
"""Build the six edited trackfldu sets used by the demos, from your own genuine MAME set.

Each edit changes one byte that one of Konami's copy checks reads (trackfldu addresses):
  check1  $C418  B1 -> B4   the byte the high jump mole check compares; nothing else reads it
  check2  $A6BD  4F -> 4E   "KONAMI" -> "KNNAMI" in the copyright line (also read by checks 4, 5)
  check3  $A6C0  4D -> 4E   "KONAMI" -> "KONANI" (also read by checks 2, 4, 5)
  check4  $A6C6  33 -> 34   "1983" -> "1984" (also read by check 5)
  check5  $FC6D  00 -> 01   colour of the copyright and licence lines (also read by check 6)
  check6  $A6B9  0A -> 0B   the copyright's screen address: one column to the right (only check 6)

Output: konami/roms/<name>/, a complete one-folder ROM path (konami/roms/ is not committed): a copy of your zip with
the one chip changed (trackfld.zip if your sets are merged; trackfldu.zip plus an unchanged copy of its parent
trackfld.zip if they are split), built by scripts/patchzip.py. Run MAME with -rompath konami/roms/<name> and nothing
else on the ROM path (konami/demo.sh does, through scripts/mame.sh): with your own folder as a second path, MAME would
reject the edited chip on its checksum and silently load the genuine one. MAME warns "WRONG CHECKSUMS" for that chip:
that is the point.

Usage: python3 konami/build_roms.py ROM_FOLDER   (reads trackfld.zip or trackfldu.zip there; ROM_FOLDER required)
"""
import os
import subprocess
import sys
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
# trackfldu program chips: name, CPU address, MAME CRC32
CHIPS = [("361_105.a7", 0x6000, 0xC813F140), ("361_104.a6", 0x8000, 0xB785E7EE),
         ("361_103.a5", 0xA000, 0x060C16E6), ("361_102.a4", 0xC000, 0x46BDE4EA),
         ("361_101.a2", 0xE000, 0xB2D8BE9A)]
EDITS = {
    "check1": (0xC418, 0xB1, 0xB4, "$C418 B1->B4 (high jump mole check byte)"),
    "check2": (0xA6BD, 0x4F, 0x4E, "\"KONAMI\" -> \"KNNAMI\""),
    "check3": (0xA6C0, 0x4D, 0x4E, "\"KONAMI\" -> \"KONANI\""),
    "check4": (0xA6C6, 0x33, 0x34, "\"1983\" -> \"1984\""),
    "check5": (0xFC6D, 0x00, 0x01, "copyright colour 0 -> 1 (LDD #$0100 -> #$0101 at $FC6B)"),
    "check6": (0xA6B9, 0x0A, 0x0B, "copyright screen address $370A -> $370B"),
}


def read_chip(rompath, name):
    for z in ("trackfldu.zip", "trackfld.zip"):
        p = os.path.join(rompath, z)
        if not os.path.exists(p):
            continue
        with zipfile.ZipFile(p) as zf:
            for member in (name, "trackfldu/" + name):
                if member in zf.namelist():
                    return zf.read(member)
    d = os.path.join(rompath, "trackfldu", name)
    if os.path.exists(d):
        return open(d, "rb").read()
    sys.exit("can't find trackfldu %s under %s" % (name, rompath))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rompath = os.path.expanduser(sys.argv[1])
    for name, base, crc in CHIPS:
        got = zlib.crc32(read_chip(rompath, name))
        if got != crc:
            sys.exit("%s: CRC %08X, expected %08X: not the genuine trackfldu chip" % (name, got, crc))
    for tag, (addr, old, new, what) in EDITS.items():
        name, base, _ = next(c for c in CHIPS if c[1] <= addr < c[1] + 0x2000)
        data = bytearray(read_chip(rompath, name))
        if data[addr - base] != old:
            sys.exit("%s: $%04X is %02X, expected %02X" % (tag, addr, data[addr - base], old))
        data[addr - base] = new
        change = "%X:%02X:%02X" % (addr - base, old, new)
        if os.path.exists(os.path.join(rompath, "trackfldu.zip")):      # split sets: the clone's zip plus its parent
            args = [rompath, "trackfldu", name + ":" + change, "--with", "trackfld"]
        else:                                                            # merged sets: everything is in trackfld.zip
            args = [rompath, "trackfld", "trackfldu/" + name + ":" + change]
        subprocess.run([sys.executable, os.path.join(HERE, "..", "scripts", "patchzip.py")] + args +
                       ["--out", os.path.join(HERE, "roms", tag)], check=True, stdout=subprocess.DEVNULL)
        print("%s: %s, chip %s offset $%04X, CRC %08X" % (tag, what, name, addr - base, zlib.crc32(data)))


if __name__ == "__main__":
    main()
