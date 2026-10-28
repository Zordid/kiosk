"""Rebuild the public WAWIS tables with Btrieve itself.

usage: python3 -I tools/rebuild-btrieve.py PRIVATE OUT BTRIEVE

  PRIVATE  the original files (as for make-public-data.py)
  OUT      the public copy made by make-public-data.py; its Btrieve files
           are replaced
  BTRIEVE  a directory with BTRIEVE.EXE and BUTIL.EXE (Btrieve 5.x for DOS,
           not included in this repository); dosbox-x must be on the PATH

make-public-data.py patches the tables byte by byte, and Btrieve's index
pages then no longer fit the records (status 2). For every table whose
public copy differs from the original, this script lets Btrieve save the
live records of the original (BUTIL -SAVE), takes each record's public
version from the same place in the public copy, creates an empty table
with the same definition (BUTIL -CLONE) and loads the records into it
(BUTIL -LOAD). Deleted records and old index pages are gone afterwards.

Check: every text in a rebuilt table must occur in the public copy too.
"""
import re, shutil, subprocess, sys, tempfile
from pathlib import Path


def dosbox(work, *commands):
    bat = ['@echo off', r'BTRIEVE /P:1024 /M:64 > nul'] + list(commands)
    (work / 'RUN.BAT').write_bytes(('\r\n'.join(bat) + '\r\n').encode('ascii'))
    subprocess.run(['dosbox-x', '-silent', '-nogui', '-set', 'dosbox quit warning=false', '-set', 'sdl output=surface',
                    '-set', 'cpu cycles=max', '-set', 'dosbox memsize=16', '-set', 'dos ems=false',
                    '-c', f'mount c "{work}"', '-c', 'c:', '-c', 'run.bat', '-c', 'exit',
                    '-time-limit', '120'], cwd=work, capture_output=True)
    log = work / 'LOG.TXT'
    return log.read_bytes().decode('cp437') if log.exists() else ''


def read_seq(b):
    """BUTIL's sequential format: length, comma, record, CR LF; ^Z at the end."""
    records, i = [], 0
    while i < len(b) and b[i:i + 1].isdigit():
        comma = b.index(b',', i)
        n = int(b[i:comma])
        records.append(b[comma + 1:comma + 1 + n])
        i = comma + 1 + n + 2
    return records


def write_seq(records):
    return b''.join(str(len(r)).encode() + b',' + r + b'\r\n' for r in records) + b'\x1a'


def texts(b):
    return {m.group() for m in re.finditer(rb'[\x20-\x7e\xc0-\xfe]{4,}', b)}


def main():
    src, dest, btrieve = (Path(a) for a in sys.argv[1:4])
    tables = [p.relative_to(dest) for p in sorted(dest.rglob('*.WD'))
              if (src / p.relative_to(dest)).read_bytes() != p.read_bytes()]
    failed = False
    for rel in tables:
        private, public = (src / rel).read_bytes(), (dest / rel).read_bytes()
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            for exe in ('BTRIEVE.EXE', 'BUTIL.EXE'):
                shutil.copy(btrieve / exe, work)
            (work / 'OLD.WD').write_bytes(private)
            dosbox(work, 'BUTIL -SAVE OLD.WD OLD.SEQ > LOG.TXT')
            records = read_seq((work / 'OLD.SEQ').read_bytes())
            new = []
            for r in records:
                pos = private.find(r)
                if pos < 0 or private.find(r, pos + 1) >= 0:
                    sys.exit(f'{rel}: a record is not unique in the file')
                new.append(public[pos:pos + len(r)])
            (work / 'OLD.SEQ').unlink()
            (work / 'NEW.SEQ').write_bytes(write_seq(new))
            log = dosbox(work, 'BUTIL -CLONE NEW.WD OLD.WD > LOG.TXT', 'del OLD.WD',
                         'BUTIL -LOAD NEW.SEQ NEW.WD >> LOG.TXT', 'BUTIL -STAT NEW.WD >> LOG.TXT')
            m = re.search(r'Total Records = (\d+)', log)
            rebuilt = (work / 'NEW.WD').read_bytes() if (work / 'NEW.WD').exists() else b''
        left = {t for t in texts(rebuilt) if t not in public}
        ok = m and int(m.group(1)) == len(records) and not left
        print(f'{rel}: {len(records)} records, {len(public)} -> {len(rebuilt)} bytes'
              + ('' if ok else f', FAILED ({len(left)} unknown texts)'))
        if ok:
            (dest / rel).write_bytes(rebuilt)
            shutil.copystat(src / rel, dest / rel)
        failed |= not ok
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
