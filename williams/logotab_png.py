#!/usr/bin/env python3
"""Draw the WILLIAMS handwriting tables decoded by williams/logotab.lua, one row per set (needs Pillow).

Usage: python3 williams/logotab_png.py OUT.png LOG...   (each LOG is williams/out/logotab_<set>.log)
Each row: the set name, the end cursor and CUREND, the strokes in red at 3x, and a blue box on the end point.
"""
import os
import re
import sys

from PIL import Image, ImageDraw

W, H, S = 230, 50, 3


def main():
    out, logs = sys.argv[1], sys.argv[2:]
    if not logs:
        sys.exit(__doc__)
    img = Image.new('RGB', (W * S, (H * S + 16) * len(logs)), 'white')
    d = ImageDraw.Draw(img)
    for n, log in enumerate(logs):
        name = os.path.basename(log)[len('logotab_'):-len('.log')]
        text = open(log).read()
        head = re.search(r'end x \$(\w+) y \$(\w+), CUREND \$(\w+)', text)
        px = [tuple(map(int, p)) for p in re.findall(r'PX (\d+) (\d+)', text)]
        oy = n * (H * S + 16)
        d.text((4, oy + 2), '%s  end x=$%s y=$%s  CUREND $%s' % ((name,) + head.groups()), fill='black')
        for x, y in px:
            X, Y = (x - 0x20) * S, oy + 16 + (y - 0x2C) * S
            if 0 <= X < W * S and Y < oy + 16 + H * S:
                d.rectangle([X, Y, X + S - 1, Y + S - 1], fill='red')
        ex, ey = int(head.group(1), 16), int(head.group(2), 16)
        X, Y = (ex - 0x20) * S, oy + 16 + (ey - 0x2C) * S
        d.rectangle([X - 2, Y - 2, X + S + 1, Y + S + 1], outline='blue')
    img.save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
