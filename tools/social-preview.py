"""Make the GitHub social preview: a 160x40 text screen, 1280x640 pixels.

usage: python3 social-preview.py <font.bin> <out.png>

font.bin is the 8x16 VGA font as dumped by scrdump (tools/run-kiosk.py
leaves one in RUN/S). The screen is drawn in the colours of Kiosk 1.2C's
Turbo Vision desktop; the big title comes from the same font, one
half-block character per font pixel, two characters wide. Needs Pillow and
render.py of the Power-Choice repository next to this one.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'powerchoice' / 'tools'))
from render import PAL, pixels
from PIL import Image

COLS, ROWS = 160, 40
BLACK, BLUE, GREEN, CYAN, RED, GRAY, DGRAY, LCYAN, YELLOW, WHITE = 0, 1, 2, 3, 4, 7, 8, 11, 14, 15
font = open(sys.argv[1], 'rb').read()
cells = bytearray([0xB0, GRAY << 4 | BLUE] * COLS * ROWS)          # the desktop: blue on grey


def put(x, y, s, fg, bg):
    for i, ch in enumerate(s.encode('cp437')):
        if 0 <= x + i < COLS:
            cells[(y * COLS + x + i) * 2:(y * COLS + x + i) * 2 + 2] = bytes([ch, bg << 4 | fg])


def fill(x, y, w, h, bg, fg=WHITE, ch=' '):
    for r in range(y, y + h):
        put(x, r, ch * w, fg, bg)


def shadow(x, y, w, h):
    """Turbo Vision's shadow: two columns right, one row below, dark grey."""
    for r in range(y + 1, y + h + 1):
        for c in range(x + 2, x + w + 2):
            if r == y + h or c >= x + w:
                i = (r * COLS + c) * 2
                cells[i + 1] = BLACK << 4 | DGRAY


def window(x, y, w, h, title, fg, bg):
    shadow(x, y, w, h)
    fill(x, y, w, h, bg)
    put(x, y, '╔' + '═' * (w - 2) + '╗', fg, bg)
    put(x + 1, y, '[■]', fg, bg)
    for r in range(y + 1, y + h - 1):
        put(x, r, '║', fg, bg)
        put(x + w - 1, r, '║', fg, bg)
    put(x, y + h - 1, '╚' + '═' * (w - 2) + '╝', fg, bg)
    put(x + (w - len(title) - 2) // 2, y, f' {title} ', fg, bg)


def hotline(x, y, s, fg, hot, bg):
    """Text where ~X~ marks a hotkey, as in Turbo Vision."""
    parts = s.split('~')
    for n, part in enumerate(parts):
        put(x, y, part, hot if n % 2 else fg, bg)
        x += len(part)


def big(y, s, fg, shadow_fg, bg):
    """The text in the 8x16 font, two font rows per character row, each font
    pixel two characters wide."""
    bits = [[font[ord(ch) * 16 + fy] & (0x80 >> fx) for ch in s for fx in range(8)] for fy in range(16)]
    w = len(s) * 16
    x0 = (COLS - w) // 2
    for dx, dy, col in ((2, 1, shadow_fg), (0, 0, fg)):
        for r in range(8):
            for c in range(len(s) * 8):
                top, bottom = bits[2 * r][c], bits[2 * r + 1][c]
                if not (top or bottom):
                    continue
                ch = 0xDB if top and bottom else 0xDF if top else 0xDC
                for k in range(2):
                    i = ((y + r + dy) * COLS + x0 + 2 * c + k + dx) * 2
                    if col == shadow_fg or ch == 0xDB:
                        cells[i:i + 2] = bytes([ch, bg << 4 | col])
                    else:                                            # half block over the shadow
                        under = cells[i + 1] & 15 if cells[i] == 0xDB else bg
                        cells[i:i + 2] = bytes([ch, under << 4 | col])


# menu bar and status line of Kiosk 1.2C
fill(0, 0, COLS, 1, GRAY)
hotline(2, 0, '~S~ystem  ~B~estellungen  ~O~rdersätze  ~S~tammdaten  ~F~enster', BLACK, RED, GRAY)
fill(0, ROWS - 1, COLS, 1, GRAY)
hotline(1, ROWS - 1, '~F4~ Bestellung annehmen  ~F8~ Aktuelle Bestellungen  ~F10~ Menü  ~Alt-X~ Ende',
        BLACK, RED, GRAY)
put(COLS - 25, ROWS - 1, 'github.com/Zordid/kiosk', BLACK, GRAY)

# the title in an order view: yellow on blue
window(20, 3, 120, 19, 'Kioskverwaltung für Norkus & Blaaß', WHITE, BLUE)
big(5, 'KIOSK', YELLOW, BLACK, BLUE)
for y, s, fg in ((15, 'Order management for the Quickbox kiosks', LCYAN),
                 (17, 'and WAWIS, its Windows successor', WHITE),
                 (19, 'by Olaf Gottschalk  ·  1991 - 1995', WHITE)):
    put((COLS - len(s)) // 2, y, s, fg, BLUE)

# a dialog as the table of contents
bx, by, bw, bh = 38, 25, 84, 11
window(bx, by, bw, bh, 'Information', WHITE, GRAY)
items = [('~K~iosk 1.2C', 'MS-DOS, Turbo Pascal 6.0 and Turbo Vision, 1993'),
         ('~W~AWIS 1.1 ', 'Windows 3.1, Borland Pascal 7.0 and Btrieve, 1995'),
         ('~T~he story ', 'Barsinghausen, 1991: an order by phone'),
         ('T~r~y it    ', 'Kiosk running in your browser')]
for n, (name, text) in enumerate(items):
    hotline(bx + 4, by + 2 + n * 2, f'{name}   {text}', BLACK, RED, GRAY)
fill(bx + bw - 15, by + 9, 10, 1, GREEN)
put(bx + bw - 12, by + 9, 'OK', WHITE, GREEN)
put(bx + bw - 5, by + 9, '▄', BLACK, GRAY)
put(bx + bw - 14, by + 10, '▀' * 10, BLACK, GRAY)

rows = pixels(font, COLS, ROWS, cells)
img = Image.frombytes('P', (COLS * 8, ROWS * 16), b''.join(rows))
img.putpalette([v for rgb in PAL for v in rgb])
img.convert('RGB').save(sys.argv[2], optimize=True)
print(sys.argv[2], img.size)
