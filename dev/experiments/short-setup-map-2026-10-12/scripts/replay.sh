#!/bin/sh
# Weekly stage replay for every PIT top-3000 v12 symbol (short setup map, dev/plans/short-setup-map-2026-10-12.md).
# Runs inside trading-1-dev. One CSV per symbol: stages/<SYM>.csv (week,date,close,ma,stage,weeks_in_stage,late).
cd /workspaces/trading-1 || exit 1
EXE=trading/_build/default/analysis/scripts/stage_chart/bin/stage_chart.exe
O=.sweep-output/short-setup-map
export QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp
cat $O/symbols.txt | xargs -P 4 -I{} sh -c '
  s={}; O=.sweep-output/short-setup-map; EXE=trading/_build/default/analysis/scripts/stage_chart/bin/stage_chart.exe
  [ -s "$O/stages/$s.csv" ] && exit 0
  "$EXE" "$s" 1998-01-01 2026-06-26 /workspaces/trading-1/data /tmp/ssm-$s.png >/dev/null 2>&1 && mv /tmp/ssm-$s.png.csv "$O/stages/$s.csv" || echo "$s" >> "$O/fail.txt"
  rm -f /tmp/ssm-$s.png /tmp/ssm-$s.png.csv'
echo DONE > $O/_done
