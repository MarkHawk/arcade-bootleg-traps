#!/usr/bin/env python3
"""Build the two edited Time Pilot '84 sets used by konami/demo_tp84.sh, from your own genuine MAME set.

Both edits change one chip, 388_05.8j (CPU addresses $A000-$BFFF of the main CPU), in the copyright text at
$BD5F that Konami's hidden checks sum:
  onebyte   $BD60  4F -> 4E   "KONAMI" -> "KNNAMI". The board's own power-on ROM test sums each 8 KB block, so
                              this one-byte change is caught first: "ROM2 BAD", the board halts and resets.
  sumkept   $BD60  4F -> 4E   and $BD69  34 -> 35 (the last digit of the year, "1984" -> "1985"), so the 8 KB block
                              sum is unchanged: the ROM test passes and only the hidden checks can notice.
                              This stands in for a pirate who rebalanced the ROM checksum.

Output: konami/roms/tp84_<name>/tp84/388_05.8j (only the changed chip; konami/roms/ is not committed). Run MAME with
  -rompath "konami/roms/tp84_<name>;<your rom folder>"
so the changed chip is found first and everything else comes from your set. MAME will warn about a wrong
checksum for that chip: that is the point.

Usage: python3 konami/build_tp84.py ROM_FOLDER   (reads tp84.zip there; ROM_FOLDER required)
"""
import os
import sys
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
CHIP, BASE, CRC = "388_05.8j", 0xA000, 0x4B4629A4          # genuine tp84 main-CPU chip loaded at $A000
EDITS = {
    "onebyte": [(0xBD60, 0x4F, 0x4E)],
    "sumkept": [(0xBD60, 0x4F, 0x4E), (0xBD69, 0x34, 0x35)],
}


def read_chip(rompath):
    p = os.path.join(rompath, "tp84.zip")
    if os.path.exists(p):
        with zipfile.ZipFile(p) as zf:
            for member in (CHIP, "tp84/" + CHIP):
                if member in zf.namelist():
                    return zf.read(member)
    d = os.path.join(rompath, "tp84", CHIP)
    if os.path.exists(d):
        return open(d, "rb").read()
    sys.exit("can't find tp84 %s under %s" % (CHIP, rompath))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    genuine = read_chip(os.path.expanduser(sys.argv[1]))
    got = zlib.crc32(genuine)
    if got != CRC:
        sys.exit("%s: CRC %08X, expected %08X: not the genuine tp84 chip" % (CHIP, got, CRC))
    for tag, edits in EDITS.items():
        data = bytearray(genuine)
        for addr, old, new in edits:
            if data[addr - BASE] != old:
                sys.exit("%s: $%04X is %02X, expected %02X" % (tag, addr, data[addr - BASE], old))
            data[addr - BASE] = new
        out = os.path.join(HERE, "roms", "tp84_" + tag, "tp84")
        os.makedirs(out, exist_ok=True)
        open(os.path.join(out, CHIP), "wb").write(data)
        print("%s: %s; 8 KB block sum changes by %+d; CRC %08X" % (
            tag, ", ".join("$%04X %02X->%02X" % e for e in edits), sum(data) - sum(genuine), zlib.crc32(data)))


if __name__ == "__main__":
    main()
