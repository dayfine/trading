#!/bin/sh
# Per-list twin decision for the pairs twin-scan.sh confirmed (#3266). POSIX sh + awk, host-only.
#
# Usage: sh window-drops.sh <scan-out-dir>    (reads twins.txt + cooccur.txt there; writes windows.txt + drops.txt)
#   env DATA (bar store), EXCLUDE (pairs file of known non-twins, "A B" per line, default exclude-pairs.txt beside
#   this script).
#
# A held twin needs both legs in the SAME list and the same bars while that list governs. The whole-history run
# criterion (twin-scan.sh) finds every pair that was one instrument for >= 250 days at SOME point; many such pairs are
# one instrument only for a segment (a ticker reused by a second company, a warrant file carrying the common's quotes,
# a backfilled spin-off history). Dropping a leg from every list would delete a real second company from the years in
# which it was distinct. So the decision is made per list: for each list holding both legs, the two series are compared
# over the window that list governs, [May 31 of its year, May 31 of the next year) (the D1/D2 dating; the last list is
# open-ended), with the detector's unit (return pairs on consecutive shared dates, |ra - rb| <= 1e-3).
#   drop     >= MIN_MOVING (20) matching units in the window are real moves (|r| >= 0.3 %, so two flat dead series
#            never pair up, #2823) AND (window match >= MATCH (0.95) OR the longest run of consecutive matches in the
#            window >= MIN_WRUN (60, about three months: CMN/CMD are one series from June to December 2015 and differ
#            only after CMD's file switches instrument in January 2016; a double buy needs days, not a whole year)).
#            The loser leg (twins.txt column 1, the detector's later-last-bar survivor rule) leaves that list only.
#   keep     otherwise: in that window the two symbols are different series, so holding both is not a double hold.
# Pairs in EXCLUDE are never dropped (share classes of one issuer, trading/test_data/share_classes.sexp, handled by the
# #3015 strategy flag; IAC/MTCH, a spin-off, #2782).
#
# windows.txt: "LIST DROPPED SURVIVOR pairs=N match=F moving=M run=R same_close=K decision";
# drops.txt: "LIST DROPPED SURVIVOR".
set -eu

OUT=${1:?usage: window-drops.sh <scan-out-dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
DATA=${DATA:-/Users/difan/Projects/trading-1/data}
EXCLUDE=${EXCLUDE:-$HERE/exclude-pairs.txt}
MIN_MOVING=20; MATCH=0.95; MIN_WRUN=60; RET_EPS=1e-3

csv_of() {
  f=$(printf %s "$1" | cut -c1)
  l=$(printf %s "$1" | sed 's/.*\(.\)$/\1/')
  echo "$DATA/$f/$l/$1/data.csv"
}

excluded() {
  [ -f "$EXCLUDE" ] || return 1
  grep -v '^#' "$EXCLUDE" | awk -v a="$1" -v b="$2" '($1 == a && $2 == b) || ($1 == b && $2 == a) { f = 1 } END { exit !f }'
}

# $1 a, $2 b, $3 window start (inclusive), $4 window end (exclusive; "9999" = open)
window_stats() {
  awk -F, -v lo="$3" -v hi="$4" -v eps="$RET_EPS" '
    FNR == 1 { f++ }
    f == 1 && $1 ~ /^[0-9]/ { aa[$1] = $6 + 0; ca[$1] = $5; next }
    f == 2 && $1 ~ /^[0-9]/ && ($1 in aa) {
      if ($1 >= lo && $1 < hi) {
        if ($5 == ca[$1]) same++
        if (pd != "" && aa[pd] > 0 && pbv > 0) {
          u++; x = (aa[$1] / aa[pd] - 1) - (($6 + 0) / pbv - 1); if (x <= eps && x >= -eps) {
            mt++; run++; if (run > best) best = run
            ra = aa[$1] / aa[pd] - 1; if (ra >= 0.003 || ra <= -0.003) mv++
          } else run = 0
        }
      }
      pd = $1; pbv = $6 + 0
    }
    END { printf "pairs=%d match=%.4f moving=%d run=%d same_close=%d\n", u, (u ? mt / u : 0), mv + 0, best + 0, same }' "$(csv_of "$1")" "$(csv_of "$2")"
}

: > "$OUT/windows.txt"
while IFS=: read -r pair lists; do
  set -- $pair; d=$1; s=$2
  for L in $lists; do
    [ "$L" = none ] && continue
    y=$(echo "$L" | sed 's/.*-//')
    lo="$y-05-31"; hi="$((y + 1))-05-31"; [ "$y" = 2025 ] && hi=9999
    st=$(window_stats "$d" "$s" "$lo" "$hi")
    if excluded "$d" "$s"; then dec=keep-excluded
    else dec=$(echo "$st" | awk -v mm="$MIN_MOVING" -v mf="$MATCH" -v mr="$MIN_WRUN" '{ split($2, m, "="); split($3, v, "="); split($4, r, "="); print (v[2] + 0 >= mm && (m[2] + 0 >= mf || r[2] + 0 >= mr)) ? "drop" : "keep" }')
    fi
    echo "$L $d $s $st $dec"
  done
done < "$OUT/cooccur.txt" >> "$OUT/windows.txt"
awk '$NF == "drop" { print $1, $2, $3 }' "$OUT/windows.txt" | LC_ALL=C sort > "$OUT/drops.txt"
echo "windows: $(wc -l < "$OUT/windows.txt" | tr -d ' ') list x pair cells; drop $(wc -l < "$OUT/drops.txt" | tr -d ' ') in $(awk '{ print $2, $3 }' "$OUT/drops.txt" | sort -u | wc -l | tr -d ' ') pairs" >&2
