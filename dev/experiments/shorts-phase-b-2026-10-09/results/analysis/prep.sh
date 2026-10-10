#!/bin/sh
# Stage the flat inputs every other script reads, into $WORK. Read-only on the repo.
#   $WORK/<cell>.audit.tsv  audit_flat.awk rows (T/S/C) per cell, when the trade audit exists
#   $WORK/divs.csv          sym,ex_date,unadjusted_amount,adjusted_amount  (traded symbols only)
#   $WORK/bars.csv          sym,date,open,high,low,close,adj_close  (traded symbols, entry -800d .. exit +100d; sorted)
#   $WORK/spy.csv           date,close,adj_close  (full SPY history from the host store)
#   $WORK/macro.txt         date trend  (weekly macro screen, identical across cells; v0 s0's copy)
# usage: sh prep.sh   (env: R, AUD_A, AUD_B, DATA, DIVROOT, WORK; defaults in common.sh)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
mkdir -p "$WORK"
for c in $CELLS; do
  a=$(audit_of "$c")
  if [ -f "$a" ]; then awk -f "$HERE/audit_flat.awk" "$a" > "$WORK/$c.audit.tsv"; else : > "$WORK/$c.audit.tsv"; fi
done
# windows per position (all cells), as sym,from,to
for c in $CELLS; do tail -n +2 "$R/$c-v12-trades.csv"; done | awk -F, '{print $1 "," $3 "," $4}' |
  awk -F, 'function jdn(s,  y,m,d,a){y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0; a=int((14-m)/12); y=y+4800-a; m=m+12*a-3
             return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045}
           {print $1 "," jdn($2)-800 "," jdn($3)+100}' | LC_ALL=C sort -u > "$WORK/windows.csv"
: > "$WORK/bars.csv"; : > "$WORK/divs.csv"
cut -d, -f1 "$WORK/windows.csv" | LC_ALL=C sort -u | while read -r s; do
  f=$(bars_of "$s"); d=$(divs_of "$s")
  [ -f "$f" ] || { echo "WARN no bars for $s" >&2; continue; }
  awk -F, -v s="$s" 'function jdn(x,  y,m,dd,a){y=substr(x,1,4)+0; m=substr(x,6,2)+0; dd=substr(x,9,2)+0; a=int((14-m)/12); y=y+4800-a; m=m+12*a-3
        return dd+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045}
      NR==FNR { if ($1==s) { n++; lo[n]=$2; hi[n]=$3 } next }
      FNR>1 { j=jdn($1); for (i=1;i<=n;i++) if (j>=lo[i] && j<=hi[i]) { print s "," $1 "," $2 "," $3 "," $4 "," $5 "," $6; break } }' \
    "$WORK/windows.csv" "$f" >> "$WORK/bars.csv"
  if [ -f "$d" ]; then awk -F, -v s="$s" 'FNR>1 && $2!="" {print s "," $1 "," $2 "," $3}' "$d" >> "$WORK/divs.csv"; fi
done
LC_ALL=C sort -t, -k1,1 -k2,2 -u "$WORK/bars.csv" -o "$WORK/bars.csv"
awk -F, 'FNR>1 {print $1 "," $5 "," $6}' "$SPY_CSV" > "$WORK/spy.csv"
sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\).*/\1 \2/p' "$R/v0-26-s0-v12-macro_trend.sexp" > "$WORK/macro.txt"
for c in $CELLS; do
  sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\).*/\1 \2/p' "$R/$c-v12-macro_trend.sexp" | cmp -s - "$WORK/macro.txt" ||
    echo "WARN macro_trend differs in $c" >&2
done
echo "prep: $(wc -l < "$WORK/bars.csv" | tr -d ' ') bar rows, $(wc -l < "$WORK/divs.csv" | tr -d ' ') dividend rows, $(cut -d, -f1 "$WORK/windows.csv" | sort -u | wc -l | tr -d ' ') symbols, $(wc -l < "$WORK/macro.txt" | tr -d ' ') macro weeks"
