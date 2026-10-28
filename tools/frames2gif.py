"""Turn a list of screenshots into an animated GIF.

usage: python3 frames2gif.py FRAMES.txt OUT.gif [--crop W H]

  FRAMES.txt  one frame per line: PNG file and display time in seconds;
              paths are relative to the list
  --crop      keep only the top-left W x H pixels (e.g. 1024 696: the WAWIS
              window without the rest of the screen); larger images, like
              a printed page, are scaled to fit the width with a margin and cut
              to height H

Windows 3.1 in 256 colours uses few of them, so the frames share one
palette and nothing is dithered. Needs Pillow.
"""
import sys
from pathlib import Path
from PIL import Image

args = sys.argv[1:]
crop = None
if '--crop' in args:
    i = args.index('--crop')
    crop = int(args[i + 1]), int(args[i + 2])
    del args[i:i + 3]
lst, out = Path(args[0]), args[1]

frames, durations = [], []
for line in lst.read_text().splitlines():
    if not line.strip():
        continue
    name, secs = line.rsplit(maxsplit=1)
    im = Image.open(lst.parent / name).convert('RGB')
    if crop:
        w, h = crop
        at = (0, 0)
        if im.width > w * 1.2:                       # a page: scale it, with a margin
            im = im.resize((w - 48, round(im.height * (w - 48) / im.width)), Image.LANCZOS)
            at = (24, 24)
        canvas = Image.new('RGB', (w, h), 'white')
        canvas.paste(im.crop((0, 0, min(w - at[0], im.width), min(h - at[1], im.height))), at)
        im = canvas
    frames.append(im)
    durations.append(round(float(secs) * 1000))

# one palette for all frames, from the colours that occur
sheet = Image.new('RGB', (frames[0].width, frames[0].height * len(frames)))
for i, f in enumerate(frames):
    sheet.paste(f, (0, i * f.height))
pal = sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
frames = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, optimize=True, disposal=1)
print(f'{len(frames)} frames, {sum(durations) / 1000:.1f}s, {Path(out).stat().st_size // 1024} KB')
