#!/bin/sh
# episode.sh SYM FROM TO [x]: trace one episode (README §3.3-3.6). Run from the repo root; SWEEP points at the
# .sweep-output dir holding the run's weekly series and our stage CSVs (not committed).
SWEEP=${SWEEP:-.sweep-output}
W=$(cd "$(dirname "$0")" && pwd)
WK=$SWEEP/fresh-eyes/forward/weekly
ST=$SWEEP/short-setup-map/stages
F=$W/..
S=$W/../../../scripts
s=$1; a=$2; b=$3
echo "--- weekly"
awk -F, -v a=$a -v b=$b -v s=$s -f $S/days.awk -f $W/episode.awk $ST/$s.csv $F/decisions.csv $WK/$s.csv
if [ -z "$4" ]; then
echo "--- reader decisions"
awk -F, -v s=$s -v a=$a -v b=$b '$1==s && $2>=a && $2<=b' $F/decisions.csv | cut -c1-600
fi
echo "--- trades"
awk -F, -v s=$s -v a=$a -v b=$b '$1==s && $3>=a && $3<=b' $F/trades.csv
