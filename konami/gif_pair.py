#!/usr/bin/env python3
"""Side-by-side captioned GIF and still strip from two MAME snapshot sequences (needs Pillow: pip install pillow).

The picture is doubled (each pixel to 2x2) with a 40-pixel caption strip underneath, one GIF frame per emulator frame
shown for 70 ms, the last frame held for 2 s, 64 colours. The same emulator frames are shown left and right.

Usage: konami/gif_pair.py LOG_L DIR_L CAPTION_L LOG_R DIR_R CAPTION_R OUT.gif FROM-TO [--still F,F,... OUT.png]
  LOG_*      a demo log with "SNAP nnnn seq fFFFF" lines (konami/out/tp84_sumkept_genuine.log)
  DIR_*      the folder MAME wrote the snapshots to (konami/out/tp84_sumkept_genuine/tp84)
  CAPTION_*  the caption; {f} is replaced by the emulator frame
Example (after konami/demo_tp84.sh sumkept ~/roms), as in docs/konami-time-pilot-84.md:
  python3 konami/gif_pair.py konami/out/tp84_sumkept_genuine.log konami/out/tp84_sumkept_genuine/tp84 "genuine f{f}" \
      konami/out/tp84_sumkept_edited.log konami/out/tp84_sumkept_edited/tp84 "KNNAMI 1985 f{f}" pair.gif 990-1012
"""
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SCALE, STRIP, FRAME_MS, HOLD_MS = 2, 40, 70, 2000
BG, FG = (32, 32, 32), (255, 255, 255)


def font(size):
    for name in ("DejaVuSansMono.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default(size)


def frame(pic, text):
    pic = pic.convert("RGB")
    # an exact integer upscale; BOX gives the same pixels as nearest-neighbour here
    pic = pic.resize((pic.width * SCALE, pic.height * SCALE), Image.Resampling.BOX)
    out = Image.new("RGB", (pic.width, pic.height + STRIP), BG)
    out.paste(pic, (0, 0))
    d = ImageDraw.Draw(out)
    d.fontmode = "1"
    size = 20
    f = font(size)
    while d.textlength(text, font=f) > out.width - 16 and size > 8:
        size -= 1
        f = font(size)
    d.text(((out.width - d.textlength(text, font=f)) / 2, pic.height + (STRIP - size) / 2 - 2), text, font=f, fill=FG)
    return out


def save(frames, path):
    q = [im.quantize(colors=64, dither=Image.Dither.NONE) for im in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=[FRAME_MS] * (len(q) - 1) + [HOLD_MS],
              loop=0, optimize=True, disposal=1)


def load(log, folder):
    seq = {}
    for line in open(log):
        m = re.search(r"SNAP (\d{4}) seq f(\d+)", line)
        if m:
            seq[int(m.group(2))] = "%s/%s.png" % (folder, m.group(1))
    return seq


def pair(left, right, f, cap_l, cap_r):
    a = frame(Image.open(left[f]), cap_l.replace("{f}", str(f)))
    b = frame(Image.open(right[f]), cap_r.replace("{f}", str(f)))
    out = Image.new("RGB", (a.width + b.width + 12, a.height), BG)
    out.paste(a, (0, 0))
    out.paste(b, (a.width + 12, 0))
    return out


def main():
    args = sys.argv[1:]
    still = None
    if "--still" in args:
        i = args.index("--still")
        still = (args[i + 1].split(","), args[i + 2])
        del args[i:i + 3]
    if len(args) != 8:
        sys.exit(__doc__)
    log_l, dir_l, cap_l, log_r, dir_r, cap_r, out, window = args
    left, right = load(log_l, dir_l), load(log_r, dir_r)
    a, b = (int(x) for x in window.split("-"))
    frames = [f for f in sorted(left) if a <= f <= b and f in right]
    if not frames:
        sys.exit("no frames in %s that both logs snapshotted" % window)
    save([pair(left, right, f, cap_l, cap_r) for f in frames], out)
    print("%s: %d frames" % (out, len(frames)))
    if still:
        rows = [pair(left, right, int(f), cap_l, cap_r) for f in still[0]]
        sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows) + 6 * (len(rows) - 1)), BG)
        y = 0
        for r in rows:
            sheet.paste(r, (0, y))
            y += r.height + 6
        sheet.save(still[1])
        print("%s: frames %s" % (still[1], ",".join(still[0])))


if __name__ == "__main__":
    main()
