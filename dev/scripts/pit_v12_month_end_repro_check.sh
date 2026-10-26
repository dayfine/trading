#!/bin/sh
# Arm SM prerequisite 2 (dev/experiments/floor-nearest-2026-10-25/README.md §"Arm SM"): the month-end path of
# build_composition_universes_runner (--month-ends) must reproduce the committed pit-v12 yearly lists byte for byte,
# including pit-v12's post-processing, so monthly lists differ from the yearly ones only by date. POSIX sh.
#
# Runs INSIDE the container (the bar store is there). From the host:
#   docker exec -w /workspaces/trading-1/<tree> trading-1-dev sh dev/scripts/pit_v12_month_end_repro_check.sh
# after `dune build analysis/data/universe/bin/build_composition_universes_runner.exe` in <tree>/trading.
#
# For each year Y in YEARS it runs the builder with `--month-ends Y-05-01,Y-05-31 --true-dollar-volume` (one anchor,
# Y-05-31; the pit-v12 inputs: pit-v12/inventory.sexp, $DATA/symbol_types.sexp equity filter, $DATA/sectors.csv),
# renames top-N-Y-05-31.sexp to top-N-Y.sexp, then applies pit-v12's post-processing in its commit order:
#   1. alias-lists.pl with v11's alias2.resolved, then alias3.txt                           (#3182)
#   2. alias-lists.pl with the v12 warehouse build's alias-v12-new.txt                      (#3198)
#   3. apply-drops.sh with pit-v12/twin-drops.txt (CMN/CMD)                                 (#3391)
# and cmp's every list against pit-v12/composition/. The builder output (before step 1) is also md5'd against
# pit-v12/composition-raw.md5, so a mismatch says whether the builder/store or the post-processing moved.
# Exit 0 iff every FINAL list matches. ~1.4 min per list (pit-v12's 56 lists took ~80 min, one job).
#
# Env: YEARS ("1998 .. 2025"), SIZES ("1000 3000"), DATA (/workspaces/trading-1/data), WORK (/tmp/pit-v12-repro),
#      EXE (the tree's built runner). WORK is wiped at start.
set -eu

TREE=$(cd "$(dirname "$0")/../.." && pwd)
V12=$TREE/trading/test_data/backtest_scenarios/pit-v12
V11S4=$TREE/dev/experiments/pit-universe-2026-09-14/step4
ALIAS_PL=$V11S4/twin-scan/alias-lists.pl
DROPS_SH=$TREE/dev/experiments/v12-twin-scan-2026-10-22/apply-drops.sh
ALIAS_MAPS="$V11S4/specs/alias2.resolved $V11S4/twin-scan/alias3.txt $TREE/dev/experiments/rebaseline-v12-2026-10-08/warehouse-build/alias-v12-new.txt"
EXE=${EXE:-$TREE/trading/_build/default/analysis/data/universe/bin/build_composition_universes_runner.exe}
DATA=${DATA:-/workspaces/trading-1/data}
WORK=${WORK:-/tmp/pit-v12-repro}
SIZES=${SIZES:-1000 3000}
YEARS=${YEARS:-$(seq 1998 2025 | tr '\n' ' ')}

die() { echo "repro-check: ABORT: $*" >&2; exit 2; }
[ -x "$EXE" ] || die "runner not built: $EXE"
for f in "$ALIAS_PL" "$DROPS_SH" $ALIAS_MAPS "$V12/twin-drops.txt" "$V12/composition-raw.md5" "$V12/inventory.sexp" \
  "$DATA/symbol_types.sexp" "$DATA/sectors.csv"; do
  [ -f "$f" ] || die "missing input $f"
done
rm -rf "$WORK"; mkdir -p "$WORK/dated" "$WORK/raw" "$WORK/final"
top_ns=$(echo $SIZES | tr ' ' ',')

for y in $YEARS; do
  "$EXE" --bars-root "$DATA" --symbol-types "$DATA/symbol_types.sexp" --sectors-csv "$DATA/sectors.csv" \
    --inventory "$V12/inventory.sexp" --out-dir "$WORK/dated" --month-ends "$y-05-01,$y-05-31" \
    --top-n "$top_ns" --true-dollar-volume >> "$WORK/builder.log" 2>&1 || die "runner failed for $y (see $WORK/builder.log)"
  for n in $SIZES; do
    src=$WORK/dated/top-$n-$y-05-31.sexp
    [ -f "$src" ] || die "runner wrote no $src (see $WORK/builder.log)"
    cp "$src" "$WORK/raw/top-$n-$y.sexp"
  done
  echo "built $y"
done

# pit-v12 post-processing, in commit order, on a copy of the raw lists
cp "$WORK"/raw/*.sexp "$WORK/final/"
for m in $ALIAS_MAPS; do perl "$ALIAS_PL" "$m" "$WORK"/final/*.sexp >> "$WORK/post.log"; done
# twin drops: comments out, and only rows for lists this run built (apply-drops.sh refuses a missing list)
grep -v '^#' "$V12/twin-drops.txt" | while read -r l d s; do
  [ -f "$WORK/final/$l.sexp" ] && echo "$l $d $s"
done > "$WORK/twin-drops.txt" || true
if [ -s "$WORK/twin-drops.txt" ]; then sh "$DROPS_SH" "$WORK/twin-drops.txt" "$WORK/final" >> "$WORK/post.log"; fi

# compare
for f in "$WORK"/raw/*.sexp; do
  b=$(basename "$f")
  want=$(awk -v b="$b" '$2 == b { print $1 }' "$V12/composition-raw.md5")
  got=$(md5sum "$f" | awk '{ print $1 }')
  if [ "$want" = "$got" ]; then raw=ok; else raw=DIFF; fi
  if cmp -s "$WORK/final/$b" "$V12/composition/$b"; then fin=ok; else fin=DIFF; fi
  echo "$b raw=$raw final=$fin"
done | tee "$WORK/result.txt"
n_all=$(wc -l < "$WORK/result.txt" | tr -d ' ')
n_ok=$(grep -c 'final=ok' "$WORK/result.txt" || true)
echo "repro-check: $n_ok of $n_all lists byte-identical to pit-v12/composition (details: $WORK/result.txt)"
[ "$n_ok" = "$n_all" ] && [ "$n_all" -gt 0 ]
