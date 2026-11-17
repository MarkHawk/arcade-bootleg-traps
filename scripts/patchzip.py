#!/usr/bin/env python3
"""Build a one-folder rompath holding an edited copy of one of your own MAME zips, for the demos.

Usage: python3 scripts/patchzip.py ROM_FOLDER SET MEMBER:OFFSET:OLD:NEW[,...] [--with ZIP ...]

  ROM_FOLDER  your MAME ROM folder (it is only read, never written)
  SET         the set to edit; ROM_FOLDER/SET.zip is copied with the changes
  MEMBER:OFFSET:OLD:NEW  file inside the zip, hex offset in that file, the byte it must hold now, the byte to write.
              If the byte is not OLD the script stops: your set is a different version from the one the demo expects.
  --with ZIP  also copy ROM_FOLDER/ZIP.zip unchanged (a parent set or a device ROM the set needs; e.g. m68705p3)

Prints the new folder, a fresh one under tmp/ in the repo. Use it as the ONLY -rompath (scripts/mame.sh refuses a
";" rompath): with the real ROM folder as a second path, MAME rejects the edited file on its CRC and silently loads
the genuine one. Nothing ROM-derived is written anywhere else; tmp/ is not committed. Each change is printed to stderr.
"""
import os
import sys
import tempfile
import zipfile


def main():
    args = sys.argv[1:]
    extra = []
    while '--with' in args:
        i = args.index('--with')
        extra.append(args[i + 1])
        del args[i:i + 2]
    if len(args) != 3:
        sys.exit(__doc__)
    roms, name, spec = args
    src = os.path.join(os.path.expanduser(roms), name + '.zip')
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(os.path.join(here, 'tmp'), exist_ok=True)
    work = tempfile.mkdtemp(prefix='patch_%s_' % name, dir=os.path.join(here, 'tmp'))
    want = {}
    for p in spec.split(','):
        member, off, old, new = p.rsplit(':', 3)
        want.setdefault(member, []).append((int(off, 16), int(old, 16), int(new, 16)))
    done = 0
    with zipfile.ZipFile(src) as zi, zipfile.ZipFile(os.path.join(work, name + '.zip'), 'w') as zo:
        for n in zi.namelist():
            d = bytearray(zi.read(n))
            for off, old, new in want.get(n, []):
                if d[off] != old:
                    sys.exit('%s +%X holds %02X, expected %02X: a different version of %s' % (n, off, d[off], old, name))
                d[off] = new
                done += 1
                print('patched %s +%04X: %02X -> %02X' % (n, off, old, new), file=sys.stderr)
            zo.writestr(n, bytes(d))
    if done != sum(len(v) for v in want.values()):
        sys.exit('not every change was applied: is each MEMBER named as in %s?' % src)
    for z in extra:
        with open(os.path.join(os.path.expanduser(roms), z + '.zip'), 'rb') as f, \
                open(os.path.join(work, z + '.zip'), 'wb') as g:
            g.write(f.read())
    print(work)


if __name__ == '__main__':
    main()
