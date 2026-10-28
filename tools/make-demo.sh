#!/bin/zsh
# Make the js-dos bundle of the browser demo (docs/play/kiosk12c.jsdos).
#
# usage: tools/make-demo.sh BUILD DATA OUT.jsdos
#
#   BUILD  output directory of tools/build-tp6.sh v1.2c
#   DATA   the pseudonymised kiosk/TEST made by tools/make-public-data.py
#
# Kiosk itself enters two made-up customers (the test data has none, only
# the order of 1992), takes an order from each of them (with articles in
# common, so that "Zusammenfassen" has something to add up) and is then
# ended with Alt-X, so that it writes its index files. The resulting files, KIOSK.EXE and KIOSK.REZ become drive C:
# of the bundle; the DOS clock starts on 26 November 1993. Prints the
# fingerprint to put into docs/index.html.
set -e
BUILD=${1:A}; DATA=${2:A}; OUT=${3:A}
REPO=${0:A:h:h}; RUN=$(mktemp -d); trap 'rm -rf $RUN' EXIT
SEQ=(w:2.5 enter w:2.5 esc w:1 alt-s w:1 "t:k" w:1.5 ins w:1.2 "t:Puffreis" w:0.4 tab "t:Pit" tab tab
     "t:O-4212 Schkopau" tab "t:0037 017 118890" tab "t:C+C" tab "t:31170" tab "t:HANSA" tab "t:2740" w:1.5 enter
     w:1.5 ins w:1.2 "t:Salmiak" w:0.4 tab "t:Susi" tab "t:Bahnhofstr. 1" tab "t:W-3013 Barsinghausen" tab
     "t:05105 / 06213" tab "t:C+C" tab "t:20517" tab "t:HANSA" tab "t:3381" tab "t:TABAK" tab "t:1094" w:1.5 enter
     w:2 esc
     w:1.5 f4 w:1.5 enter w:2 "t:1" w:0.6 enter w:1 "t:3" w:0.6 enter w:1 "t:6" w:0.6 enter w:1 "t:4" w:0.6 enter
     w:1 "t:1" w:0.3 "t:2" w:0.6 enter w:1 "t:6" w:0.6 enter w:1.5 f2 w:1.2 enter
     w:1.5 f4 w:1.5 down w:0.5 enter w:2 "t:1" w:0.6 enter w:1 "t:5" w:0.6 enter w:1 "t:4" w:0.6 enter w:1 "t:2" w:0.6 tab
     w:0.3 "t:Bitte kalt" w:1 enter w:1 "t:1" w:0.3 "t:2" w:0.6 enter w:1 "t:10" w:0.6 enter w:1.5 f2 w:1.2 enter
     w:2 alt-x w:2 enter)
KIOSK_DATA=$DATA python3 -I $REPO/tools/run-kiosk.py $BUILD $RUN/run 120 11/26/1993 $SEQ | head -1
mkdir -p $RUN/c/KIOSK
for f in $RUN/run/K/*; do
  case ${f:t} in MAKEREZ.EXE|KIOSK.ERR) ;; *) cp -p $f $RUN/c/KIOSK/ ;; esac
done
rm -f $OUT
python3 -I $REPO/tools/make-bundle.py $OUT $RUN/c "date 11-26-1993" "cd \\KIOSK" "KIOSK.EXE"
