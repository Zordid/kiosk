"""Pack a directory into a js-dos bundle (.jsdos) for the browser demo.

usage: python3 make-bundle.py <out.jsdos> <dir> <autoexec line>...

The directory becomes drive C:. The autoexec lines run after "mount c ."
and "c:"; drive letters other than C: can be mounted from subdirectories,
e.g. "mount a disk -t floppy". It prints a fingerprint of the bundle; the
demo page appends it to the bundle URL so browsers never use a stale copy.
"""
import hashlib, os, sys, zipfile

out, root, *autoexec = sys.argv[1:]
conf = """[sdl]
autolock=false
usescancodes=true

[dosbox]
machine=svga_s3
memsize=16

[cpu]
core=auto
cputype=auto
cycles=auto

[render]
aspect=false
scaler=none

[autoexec]
mount c .
c:
""" + '\n'.join(autoexec) + '\n'

def add(z, name, data):
    # fixed timestamp and permissions: the same input gives the same bundle
    info = zipfile.ZipInfo(name, date_time=(1993, 11, 25, 0, 0, 0))
    info.external_attr = (0o40755 << 16 | 0x10) if name.endswith('/') else 0o644 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    z.writestr(info, data)

with zipfile.ZipFile(out, 'w') as z:
    add(z, '.jsdos/dosbox.conf', conf.replace('\n', '\r\n'))
    add(z, '.jsdos/jsdos.json', '{"version": "8"}\n')
    for base, dirs, files in sorted(os.walk(root)):
        dirs.sort()
        rel = os.path.relpath(base, root)
        if rel != '.':
            add(z, rel.replace(os.sep, '/') + '/', b'')
        for f in sorted(files):
            if f.startswith('.'):
                continue
            path = os.path.join(base, f)
            add(z, os.path.relpath(path, root).replace(os.sep, '/'), open(path, 'rb').read())
fingerprint = hashlib.sha256(open(out, 'rb').read()).hexdigest()[:8]
print(out, os.path.getsize(out), 'bytes, fingerprint', fingerprint,
      '(use it as the ?xxxxxxxx in docs/index.html)')
