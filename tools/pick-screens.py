"""usage: python3 -I tools/pick-screens.py RUN OUTDIR name=regex ...\n\nRenders the last screen of a tools/run-kiosk.py run whose text matches\nregex to OUTDIR/name.png (640x400, the font DOSBox-X had).\n"""
import sys, re, pathlib, subprocess
run, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
render = str(pathlib.Path(__file__).resolve().parents[2]/'powerchoice'/'tools'/'render.py')
bins = sorted((run/'S').glob('S*.BIN'))
texts = {b: subprocess.run(['python3', '-I', render, '--text', str(b)], capture_output=True, text=True).stdout for b in bins}
for spec in sys.argv[3:]:
    name, rx = spec.split('=', 1)
    hits = [b for b in bins if re.search(rx, texts[b], re.S)]
    if not hits: print('no match', name); continue
    subprocess.run(['python3', '-I', render, str(run/'S'/'FONT.BIN'), str(out/f'{name}.png'), str(hits[-1])], check=True)
    print(name, hits[-1].name)
