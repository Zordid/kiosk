#!/bin/zsh
# Record the Kiosk 1.2C tour as an animated GIF.
#
# usage: tools/record-kiosk.sh BUILD DATA OUT.gif [PRINTOUT.txt]
#
#   BUILD     output directory of tools/build-tp6.sh v1.2c
#   DATA      Kiosk's test data (kiosk/TEST, or the pseudonymised copy made
#             by tools/make-public-data.py)
#   PRINTOUT  optional: the printed order as text (Epson codes removed)
#   KIOSK_RUN environment: keep the run in this directory (for tools/pick-screens.py)
#
# Runs tools/run-kiosk.py with a screen dump every 3 timer ticks and turns
# the dumps into a GIF with the Power-Choice tools/gif.py (needs Pillow;
# PYTHON may name an interpreter that has it). The tour: about box,
# current orders, the article list searched by typing, a new customer with
# customer numbers at three wholesalers, an order typed by line number and
# quantity, with a remark, saving, the current orders and the order itself.
# The order is printed afterwards; the GIF ends before that.
set -e
BUILD=${1:A}; DATA=${2:A}; OUT=${3:A}; PRN=${4:+${4:A}}; PY=${PYTHON:-python3}
REPO=${0:A:h:h}
if [[ -n $KIOSK_RUN ]]; then RUN=${KIOSK_RUN:A}; mkdir -p $RUN    # keep the run (screens for pick-screens.py)
else RUN=$(mktemp -d); trap 'rm -rf $RUN' EXIT; fi
SEQ=(w:2.5 enter w:2.5 esc w:1 alt-s w:1 "t:a" w:2 "t:c" w:0.3 "t:o" w:2 esc
     w:1 alt-s w:0.8 "t:k" w:1.2 ins w:1.2 "t:Salmiak" w:0.5 tab "t:Susi" tab
     "t:Bahnhofstr. 1" tab "t:W-3013 Barsinghausen" tab "t:05105 / 06213" tab
     "t:C+C" tab "t:20517" tab "t:HANSA" tab "t:3381" tab "t:TABAK" tab "t:1094" w:2 enter w:1 esc
     w:1 f4 w:1.5 enter w:2.5 "t:1" w:0.8 enter w:1.2 "t:5" w:0.8 enter
     w:1.2 "t:4" w:0.8 enter w:1.2 "t:2" w:0.6 tab w:0.3 "t:Bitte kalt" w:2 enter
     w:1.2 "t:1" w:0.3 "t:2" w:0.8 enter w:1.2 "t:10" w:0.8 enter
     w:2.5 f2 w:1.2 enter w:2 f8 w:2.5 tab tab tab w:0.8 enter w:3 alt-d w:2 enter w:3 enter w:3 esc)
KIOSK_RATE=3 KIOSK_DATA=$DATA python3 -I $REPO/tools/run-kiosk.py $BUILD $RUN/run 100 11/26/1993 $SEQ | head -1
# the last dump that still shows the order view, before printing
CUT=$(python3 -I - $RUN/run/screens.txt <<'PY'
import re, sys
secs = re.split(r'^===== S(\d+)\.BIN\n', open(sys.argv[1], encoding='utf-8', errors='replace').read(), flags=re.M)[1:]
seen = False
for n, body in zip(secs[0::2], secs[1::2]):
    if 'Salmiak, Susi  26.11.93' in body:
        seen = True
    elif seen:
        print(int(n) - 1)
        break
PY
)
(cd $REPO/../powerchoice/tools && $PY gif.py $RUN/run/S $OUT --rate 3 --to $CUT --hold 3)
[[ -z $PRN ]] || python3 -I - $RUN/run/lpt1.txt $PRN <<'PY'
import re, sys
b = open(sys.argv[1], 'rb').read()
b = re.sub(rb'\x1b[@EFGH45]|\x1b[cxlA].', b'', b)      # Epson ESC/P: reset, bold, double strike, margins, line spacing
b = b.replace(b'\x0c', b'').replace(b'\r\n', b'\n').replace(b'\r', b'\n')
open(sys.argv[2], 'w').write(b.decode('cp437').strip('\n') + '\n')
PY
