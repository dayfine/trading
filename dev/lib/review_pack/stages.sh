#!/bin/sh
# Per-trade weekly stage replay via stage_chart.exe. Runs INSIDE trading-1-dev
# (GNU date; the built exe). ~1.3 s per trade; skips trades already replayed.
# usage: stages.sh <repo-root> <salt-dir>     (salt-dir relative to repo-root)
# Writes <salt-dir>/stage/<position_id>.png plus its .png.csv sidecar
# (week,date,close,ma,stage,weeks_in_stage,late); failures -> stage/_fail.txt.
set -u
ROOT=$1; D=$2
cd "$ROOT" || exit 1
mkdir -p "$D/stage"
EXE=trading/_build/default/analysis/scripts/stage_chart/bin/stage_chart.exe
export QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp
tail -n +2 "$D/trades.csv" | while IFS=, read -r sym _side ed xd _days _ep _xp _qty _pnl _pct _es _xs _trig _stg _vr sid rest; do
  pid=$(echo "$rest" | cut -d, -f4)
  out="$D/stage/$pid.png"
  [ -s "$out.csv" ] && continue
  s=$(date -d "$ed -400 days" +%F); e=$(date -d "$xd +200 days" +%F)
  "$EXE" "$sym" "$s" "$e" "$ROOT/data" "$out" "$ed" "$xd" "${sid:-0.08}" >/dev/null 2>&1 || echo "$pid FAIL" >> "$D/stage/_fail.txt"
done
echo DONE > "$D/stage/_done"
