"""Check relative links and heading anchors in README.md and docs/*.md.

Run from the repo root: python3 scripts/linkcheck.py

External links are never fetched. tcrf.net links are listed as "not checked,
by request" (TCRF does not allow automated or AI access; see CLAUDE.md).
"""
import re
from pathlib import Path
from urllib.parse import urlparse


def slug(h):
    h = re.sub(r'`', '', h.strip().lower())
    h = re.sub(r'[^\w\- ]', '', h, flags=re.UNICODE)
    return h.replace(' ', '-')


def anchors(path):
    out = set()
    for line in Path(path).read_text().split('\n'):
        m = re.match(r'#{1,6}\s+(.*)', line)
        if m:
            out.add(slug(m.group(1)))
    return out


def is_tcrf(url):
    host = (urlparse(url).hostname or '').lower()
    return host == 'tcrf.net' or host.endswith('.tcrf.net')


files = [Path('README.md')] + sorted(Path('docs').glob('*.md'))
bad = n = 0
tcrf, other = set(), set()
for f in files:
    t = f.read_text()
    targets = (re.findall(r'\]\(((?:[^()\s]|\([^()\s]*\))+)(?:\s+"[^"]*")?\)', t)
               + re.findall(r'(?:src|href)="([^"]+)"', t))
    for tg in targets:
        n += 1
        if tg.startswith('http'):
            (tcrf if is_tcrf(tg) else other).add(tg)
            continue
        pth, _, frag = tg.partition('#')
        dest = (f.parent / pth) if pth else f
        if pth and not dest.exists():
            print('MISSING FILE', f, '->', tg)
            bad += 1
            continue
        if frag and dest.suffix == '.md' and frag not in anchors(dest) and slug(frag) not in anchors(dest):
            print('MISSING ANCHOR', f, '->', tg)
            bad += 1

print(f'{n} link targets seen; {bad} relative-link problems')
print(f'{len(other)} other external links: not fetched (this tool only checks relative links)')
print(f'{len(tcrf)} tcrf.net links: not checked, by request')
for u in sorted(tcrf):
    print('  not checked, by request:', u)
