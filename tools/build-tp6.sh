#!/bin/zsh
# Build Kiosk at a git tag with Turbo Pascal 6.0 in DOSBox-X.
#
# usage: tools/build-tp6.sh TAG OUTDIR [PROG...]      (default: MAKEREZ KIOSK)
#
#   TP6      environment variable: a Turbo Pascal 6.0 directory with TPC.EXE,
#            TURBO.TPL, TVISION/*.TPU and TVDEMOS/{CALC,GADGETS}.PAS, e.g. the
#            "Borland Turbo Pascal v6" folder of github.com/davidly/dos_compilers
#
# Sources and lib/ are converted back to code page 437. The reconstructed
# units in lib/ stand in for the lost originals; 1.0 and 1.2 also get
# lib/v1.0 and DATAFILE.PAS from 1.2B. Prints the compiler log.
set -e
TAG=$1; OUT=${2:A}; shift 2; PROGS=($@); (( $#PROGS )) || PROGS=(MAKEREZ KIOSK)
REPO=${0:A:h:h}; TP6=${TP6:?set TP6 to the Turbo Pascal 6.0 directory}
rm -rf $OUT; mkdir -p $OUT/TP $OUT/SRC $OUT/LIB $OUT/DEMO $OUT/git
cp "$TP6"/{TPC.EXE,TURBO.TPL} "$TP6"/TVISION/*.TPU $OUT/TP/
cp "$TP6"/TVDEMOS/{CALC,GADGETS}.PAS $OUT/DEMO/
git -C $REPO archive $TAG kiosk | tar -x -C $OUT/git
for f in $OUT/git/kiosk/*.PAS; do iconv -f UTF-8 -t CP437 $f > $OUT/SRC/${f:t}; done
for f in $REPO/lib/*.PAS; do iconv -f UTF-8 -t CP437 $f > $OUT/LIB/${f:t}; done
if [[ $TAG == v1.0 || $TAG == v1.2 ]]; then
  # 1.0/1.2: the older Fields and the view units (lib/v1.0), DataFile as found in 1.2B
  for f in $REPO/lib/v1.0/*.PAS; do iconv -f UTF-8 -t CP437 $f > $OUT/LIB/${f:t}; done
  git -C $REPO show v1.2b:kiosk/DATAFILE.PAS | iconv -f UTF-8 -t CP437 > $OUT/LIB/DATAFILE.PAS
fi
printf '@echo off\r\ncd \\src\r\n' > $OUT/BUILD.BAT
for p in $PROGS; do
  printf 'c:\\tp\\tpc /M /Q /Uc:\\tp;c:\\lib;c:\\demo /Ic:\\src %s.pas >> c:\\build.log\r\n' $p >> $OUT/BUILD.BAT
done
dosbox-x -silent -nogui -set "dosbox quit warning=false" -set "sdl output=surface" -set "cpu cycles=max" \
  -c "mount c $OUT" -c "c:" -c "build.bat" -c "exit" -time-limit 60 >/dev/null 2>&1 || true
tr -d '\r' < $OUT/BUILD.LOG
ls $OUT/SRC/*.EXE 2>/dev/null || true
