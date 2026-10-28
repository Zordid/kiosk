"""Extract all files from a FAT12 floppy image, keeping the DOS dates.

usage: python3 -I tools/fat12.py IMAGE OUTDIR

Reads the image directly (no mounting, no emulator). Deleted entries,
volume labels and long file names are skipped.
"""
import os, struct, sys, time

img, out = sys.argv[1], sys.argv[2]
d = open(img, 'rb').read()
bps, spc, res, nfats, nroot, total, _, spf = struct.unpack_from('<HBHBHHBH', d, 11)
fat = d[res * bps:(res + spf) * bps]
root_off = (res + nfats * spf) * bps
data_off = root_off + nroot * 32
csize = spc * bps


def next_cluster(c):
    v = struct.unpack_from('<H', fat, c * 3 // 2)[0]
    return v >> 4 if c & 1 else v & 0xFFF


def chain(c):
    while 2 <= c < 0xFF8:
        yield c
        c = next_cluster(c)


def read(c, size=None):
    b = b''.join(d[data_off + (x - 2) * csize:data_off + (x - 1) * csize] for x in chain(c))
    return b if size is None else b[:size]


def entries(raw):
    for i in range(0, len(raw), 32):
        e = raw[i:i + 32]
        if e[0] == 0:
            break
        if e[0] == 0xE5 or e[11] == 0x0F or e[11] & 0x08:
            continue
        name = e[0:8].decode('cp437').rstrip()
        ext = e[8:11].decode('cp437').rstrip()
        t, dt, c, size = struct.unpack_from('<HHHI', e, 22)
        yield (name + ('.' + ext if ext else '')), e[11], c, size, t, dt


def walk(raw, path):
    for name, attr, c, size, t, dt in entries(raw):
        if name in ('.', '..'):
            continue
        p = os.path.join(path, name)
        if attr & 0x10:
            os.makedirs(p, exist_ok=True)
            walk(read(c), p)
        else:
            with open(p, 'wb') as f:
                f.write(read(c, size) if size else b'')
            ts = time.mktime((1980 + (dt >> 9), (dt >> 5) & 15, dt & 31, t >> 11, (t >> 5) & 63, (t & 31) * 2, 0, 0, -1))
            os.utime(p, (ts, ts))
            print(f'{size:9} {p}')


os.makedirs(out, exist_ok=True)
walk(d[root_off:data_off], out)
