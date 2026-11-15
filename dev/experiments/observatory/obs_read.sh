#!/bin/sh
# obs_read.sh -- the axis observatory's mechanical pair reader (dev/plans/axis-observatory-2026-11-14.md §1, §3).
# Reads arm A against the base S for every seed of one run, writes the price-derived detail (weekly D(t), steps, the
# keyed trades diff) to a PRIVATE out dir, and appends one mark-free row to surface.tsv. README.md beside this file has
# the inputs, outputs, columns, the public/private split and the flag rule.
#
# usage: sh obs_read.sh -r RUN_DIR -p PREFIX -a ARM -l LABEL -v OVERLAY|@FILE -c COMMIT -O OUT_DIR
#                       [-b BASE] [-k "0 1 2 3 4"] [-y SPY_YEARS] [-t SURFACE]
# A seed K's files are RUN_DIR/[kK/]PREFIX-<arm>-kK[-<salt>]-<kind>, e.g. results/k0/pbc1-S-k0-s0-equity_curve.csv.
# Exit: 0 row appended; 1 usage / missing input / refused out dir / failed V6; 2 unpaired curves; 3 a level leaked.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd); LIB=$HERE/read/lib; TAB=$(printf '\t')
die() { echo "obs_read: $*" >&2; exit 1; }
usage() { sed -n '7,9p' "$0" >&2; exit 1; }
RUN= PREFIX= ARM= LABEL= OVERLAY= COMMIT= OUT= BASE=S SEEDS="0 1 2 3 4" YEARS= SURF=$HERE/surface.tsv
while getopts r:p:a:l:v:c:O:b:k:y:t: o; do
  case $o in
    r) RUN=$OPTARG ;; p) PREFIX=$OPTARG ;; a) ARM=$OPTARG ;; l) LABEL=$OPTARG ;; v) OVERLAY=$OPTARG ;;
    c) COMMIT=$OPTARG ;; O) OUT=$OPTARG ;; b) BASE=$OPTARG ;; k) SEEDS=$OPTARG ;; y) YEARS=$OPTARG ;; t) SURF=$OPTARG ;;
    *) usage ;;
  esac
done
for v in RUN PREFIX ARM LABEL OVERLAY COMMIT OUT; do eval "[ -n \"\$$v\" ]" || usage; done
[ -d "$RUN" ] || die "no run dir $RUN"
[ "$ARM" != "$BASE" ] || die "arm and base are both $ARM"
case $OVERLAY in @*) [ -f "${OVERLAY#@}" ] || die "no overlay file ${OVERLAY#@}"; OVERLAY=$(cat "${OVERLAY#@}") ;; esac
[ -z "$YEARS" ] || [ -f "$YEARS" ] || die "no SPY years file $YEARS"
one_line() { printf '%s' "$1" | tr '\t\n\r' '   '; }

# The out dir holds price-derived files (EODHD terms, project_eodhd_terms_private_bucket): refuse a path git would track.
guard_out() {
  d=$1; rest=
  while [ ! -d "$d" ]; do rest=$(basename "$d")${rest:+/$rest}; d=$(dirname "$d"); done
  command -v git > /dev/null 2>&1 || return 0
  git -C "$d" rev-parse --is-inside-work-tree > /dev/null 2>&1 || return 0
  git -C "$d" check-ignore -q "${rest:+$rest/}obs_read.probe" ||
    die "out dir $1 is inside a git work tree and not ignored; D(t) is price-derived: use e.g. .sweep-output/observatory/<arm>"
}

tag_of() { # $1 arm letter, $2 seed -> dir/tag of the one cell whose equity curve matches
  n=0; hit=
  for f in "$RUN/k$2/$PREFIX-$1-k$2"-*-equity_curve.csv "$RUN/k$2/$PREFIX-$1-k$2"-equity_curve.csv \
    "$RUN/$PREFIX-$1-k$2"-*-equity_curve.csv "$RUN/$PREFIX-$1-k$2"-equity_curve.csv; do
    [ -f "$f" ] && { n=$((n + 1)); hit=${f%-equity_curve.csv}; }
  done
  [ "$n" -eq 1 ] || { echo "obs_read: $n equity curves match $PREFIX-$1-k$2 under $RUN (need exactly 1)" >&2; return 1; }
  echo "$hit"
}

guard_out "$OUT"; mkdir -p "$OUT"
rm -f "$OUT"/D-k*.tsv "$OUT"/steps-k*.tsv "$OUT"/years-k*.tsv "$OUT"/firstdiff-k*.tsv
YF=${YEARS:-/dev/null}; HAVE_Y=$([ -n "$YEARS" ] && echo 1 || echo 0)
: > "$OUT/seeds.tsv"; nseeds=0; v6n=0
for K in $SEEDS; do
  bt=$(tag_of "$BASE" "$K") || exit 1; at=$(tag_of "$ARM" "$K") || exit 1
  for f in "$bt-trades.csv" "$at-trades.csv" "$bt-open_positions.csv" "$at-open_positions.csv" "$bt-summary.sexp" \
    "$at-summary.sexp" "$bt-macro_trend.sexp"; do [ -f "$f" ] || die "missing $f"; done
  if [ -f "$at.v6diff-$BASE.log" ]; then   # the chain's V6 diff of this pair (plan §5): read only a passing pair
    [ "$(tail -1 "$at.v6diff-$BASE.log")" = exit=0 ] || die "V6 gate failed: $at.v6diff-$BASE.log; not appending"
    v6n=$((v6n + 1))
  fi
  awk -v seed="k$K" -v out="$OUT" -v have_years="$HAVE_Y" -f "$LIB/common.awk" -f "$LIB/pair.awk" \
    role=Y "$YF" role=M "$bt-macro_trend.sexp" role=SE "$bt-equity_curve.csv" role=AE "$at-equity_curve.csv" \
    role=ST "$bt-trades.csv" role=AT "$at-trades.csv" role=SO "$bt-open_positions.csv" role=AO "$at-open_positions.csv" \
    role=SS "$bt-summary.sexp" role=AS "$at-summary.sexp" >> "$OUT/seeds.tsv" || exit 2
  LC_ALL=C sort -s -t "$TAB" -k1,1 -k2,2 -o "$OUT/firstdiff-k$K.tsv" "$OUT/firstdiff-k$K.tsv"
  nseeds=$((nseeds + 1))
done
[ "$nseeds" -gt 0 ] || die "no seeds read"
V6=$([ "$v6n" -eq "$nseeds" ] && echo ok || { [ "$v6n" -eq 0 ] && echo unchecked || echo partial; })

# One weekly D(t) table, a column per seed.
awk -F'\t' 'FNR == 1 { c++; s = FILENAME; sub(/.*\/D-/, "", s); sub(/\.tsv$/, "", s); h = h "\t" s; next }
  { if (!($1 in r)) { n++; o[n] = $1; r[$1] = 1 }; v[$1, c] = $2 }
  END { print "date" h; for (i = 1; i <= n; i++) { l = o[i]; for (j = 1; j <= c; j++) l = l "\t" v[o[i], j]; print l } }' \
  "$OUT"/D-k*.tsv > "$OUT/D.tsv" && rm -f "$OUT"/D-k*.tsv

HDR=$(awk -v header=1 -f "$LIB/common.awk" -f "$LIB/row.awk" < /dev/null)
if [ -s "$SURF" ]; then
  [ "$(head -1 "$SURF")" = "$HDR" ] || die "$SURF header differs from this reader's columns; not appending"
  runs=$(awk 'NR > 1 && NF' "$SURF" | wc -l | tr -d ' ')
else runs=0; fi
ROW=$(OBS_LABEL=$(one_line "$LABEL") OBS_OVERLAY=$(one_line "$OVERLAY") OBS_COMMIT=$(one_line "$COMMIT") \
  awk -v arms_run=$((runs + 1)) -v v6="$V6" -f "$LIB/common.awk" -f "$LIB/row.awk" "$OUT/seeds.tsv") || exit 3
[ -s "$SURF" ] || printf '%s\n' "$HDR" > "$SURF"
printf '%s\n' "$ROW" >> "$SURF"
printf '%s\n%s\n' "$HDR" "$ROW" > "$OUT/row.tsv"
SUMMARY=$(printf '%s\n' "$ROW" | awk -F'\t' '{ print "median D_end " $8 ", flag " $NF }')
echo "obs_read: $LABEL row $((runs + 1)) -> $SURF: $SUMMARY; detail in $OUT"
