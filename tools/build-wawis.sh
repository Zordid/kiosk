#!/bin/zsh
# Build WAWIS at a git tag with Borland Pascal 7.0 in DOSBox-X.
#
# usage: tools/build-wawis.sh TAG OUTDIR
#
#   BP7_DISKS  environment variable: directory with the eleven Borland
#              Pascal 7.0 install disk images BP7_1.img ... BP7_11.img
#
# Takes BPC.EXE, the DPMI runtime, the Windows runtime library and the
# ObjectWindows and Windows 3.1 units from the disk images, converts the
# sources back to Windows-1252 and compiles WAWIS.EXE with BPC /CW (the
# 8087 mode {$N+} was a global option in the 1995 IDE). Also builds the
# stand-in WBTRCALL.DLL from lib/wawis. Prints the log.
set -e
TAG=$1; OUT=${2:A}; REPO=${0:A:h:h}; D=${BP7_DISKS:?set BP7_DISKS to the BP7 disk images}
rm -rf $OUT; mkdir -p $OUT/disks $OUT/BP/BIN $OUT/BP/UNITS $OUT/SRC $OUT/git
for i in {1..11}; do python3 -I $REPO/tools/fat12.py $D/BP7_$i.img $OUT/disks/$i >/dev/null; done
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/1/BPC.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/6/DPMISYS.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/6/WTPL.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/UNITS $OUT/disks/7/OWL.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/UNITS $OUT/disks/11/WIN31.ZIP >/dev/null
git -C $REPO archive $TAG wawis | tar -x -C $OUT/git
for f in $OUT/git/wawis/*.(PAS|pas|INC|RC); do iconv -f UTF-8 -t CP1252 $f > $OUT/SRC/${${f:t}:u}; done
cp $OUT/git/wawis/*.RES $OUT/SRC/
for f in $REPO/lib/wawis/*.PAS; do iconv -f UTF-8 -t CP1252 $f > $OUT/SRC/${f:t}; done
printf '@echo off\r\ncd \\src\r\nc:\\bp\\bin\\bpc /CW /M /Q /$N+ /Uc:\\bp\\units /Rc:\\bp\\units WAWIS.PAS > c:\\build.log\r\nc:\\bp\\bin\\bpc /CW /Q WBTRCALL.PAS >> c:\\build.log\r\n' > $OUT/BUILD.BAT
dosbox-x -silent -nogui -set "dosbox quit warning=false" -set "sdl output=surface" -set "cpu cycles=max" -set "dosbox memsize=32" \
  -c "mount c $OUT" -c "c:" -c "build.bat" -c "exit" -time-limit 120 >/dev/null 2>&1 || true
tr -d '\r' < $OUT/BUILD.LOG | iconv -f CP437 -t UTF-8
ls $OUT/SRC/WAWIS.EXE $OUT/SRC/WBTRCALL.DLL
