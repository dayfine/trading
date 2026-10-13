#!/bin/sh
# weekly.sh <SYM> [<through date>]: weekly CSV for one symbol on stdout (see weekly.awk).
# With a through date (YYYY-MM-DD) the daily input is truncated at that date first (the causality check uses it).
# DATA = the daily store (default data); symbol path data/<first char>/<last char>/<SYM>/.
set -e
s=$1; thr=${2:-9999-12-31}
DATA=${DATA:-data}; S=$(dirname "$0")
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=$DATA/$a/$b/$s
[ -f "$p/data.csv" ] || { echo "weekly.sh: no data for $s" >&2; exit 2; }
sp=$p/splits.csv; [ -f "$sp" ] || sp=/dev/null
awk -F, -v t="$thr" 'NR == 1 || $1 <= t' "$p/data.csv" > "${TMPDIR:-/tmp}/fe-weekly-$$.csv"
awk -F, -v t="$thr" 'NR == 1 || $1 <= t' "$DATA/S/Y/SPY/data.csv" > "${TMPDIR:-/tmp}/fe-spy-$$.csv"
awk -F, -f "$S/days.awk" -f "$S/weekly.awk" "${TMPDIR:-/tmp}/fe-spy-$$.csv" "${TMPDIR:-/tmp}/fe-weekly-$$.csv" "$sp"
rm -f "${TMPDIR:-/tmp}/fe-weekly-$$.csv" "${TMPDIR:-/tmp}/fe-spy-$$.csv"
