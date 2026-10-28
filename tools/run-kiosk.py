"""Run Kiosk in DOSBox-X with scripted keys and capture every screen.

usage: python3 -I tools/run-kiosk.py BUILD RUN SECONDS MM/DD/YYYY TOKEN...

  BUILD    output directory of tools/build-tp6.sh (KIOSK.EXE, MAKEREZ.EXE)
  RUN      fresh directory for this run (deleted first)
  TOKEN    keys as for the Power-Choice tools/keys.py: enter, f4, alt-d,
           ins, "t:text", "w:seconds" (delay before the following keys)
  KIOSK_DATA  environment: directory with data files to copy (optional)
  KIOSK_SKIP  environment: names of data files to leave out
  KIOSK_RATE  environment: timer ticks between screen dumps (default 9,
              about two per second; 3 for recordings)

Needs nasm, dosbox-x and the Power-Choice repository next to this one
(tools/scrdump.asm, keys.py, render.py). Writes RUN/S/S*.BIN (screens),
RUN/screens.txt (each distinct screen as text) and RUN/lpt1.txt (printer).
"""
import sys, os, shutil, subprocess, pathlib, glob
build, run, secs, date, *toks = sys.argv[1:]
PCH = pathlib.Path(__file__).resolve().parents[2]/'powerchoice'/'tools'
run = pathlib.Path(run); shutil.rmtree(run, ignore_errors=True); (run/'K').mkdir(parents=True); (run/'S').mkdir()
skip = os.environ.get('KIOSK_SKIP', '').split()
for f in glob.glob(os.path.join(os.environ.get('KIOSK_DATA', '/nonexistent'), '*')):
    if os.path.basename(f) not in skip: shutil.copy(f, run/'K')
for f in ('KIOSK.EXE', 'MAKEREZ.EXE'): shutil.copy(pathlib.Path(build)/'SRC'/f, run/'K')
subprocess.run(['nasm', '-f', 'bin', f"-DRATE={os.environ.get('KIOSK_RATE', '9')}", '-o', str(run/'SCRDUMP.COM'),
                str(PCH/'scrdump.asm')], check=True)
subprocess.run(['python3', '-I', str(PCH/'keys.py'),
                str(run/'S'/'KEYS.BIN')] + toks, check=True, stdout=subprocess.DEVNULL)
bat = ['@echo off', 'date /f > nul', f'date {date}', 'time 10:15:00', 'cd \\k', 'makerez.exe > nul', 'c:\\scrdump.com',
       'kiosk.exe']
(run/'RUN.BAT').write_bytes(('\r\n'.join(bat) + '\r\n').encode())
proc = subprocess.Popen(['dosbox-x', '-silent', '-nogui', '-set', 'dosbox quit warning=false', '-set', 'sdl output=surface', '-set', 'cpu cycles=max',
                '-set', os.environ.get('KIOSK_LPT', f'parallel1=file append:{run}/lpt1.txt'), '-c', f'mount c {run}', '-c', 'c:', '-c', 'run.bat',
                '-time-limit', secs], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try: proc.wait(timeout=int(secs) + 10)
except subprocess.TimeoutExpired:
    proc.kill(); proc.wait(); print('DOSBox-X hung, killed')
render = str(PCH/'render.py')
out, prev = [], None
for p in sorted((run/'S').glob('S*.BIN')):
    t = subprocess.run(['python3', '-I', render, '--text', str(p)], capture_output=True, text=True).stdout
    body = '\n'.join(l.rstrip() for l in t.splitlines()[1:] if l.strip(' ░'))  # ignore menu-bar clock line
    if body != prev:
        out.append(f'===== {p.name}\n' + '\n'.join(l.rstrip() for l in t.splitlines() if l.strip(' ░')))
    prev = body
(run/'screens.txt').write_text('\n'.join(out))
print(len(out), 'distinct screens; last:'); print(out[-1] if out else '')
