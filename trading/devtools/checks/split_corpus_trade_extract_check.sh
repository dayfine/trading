#!/bin/sh
# split_corpus_trade_extract_check.sh -- the review_pack trade extraction
# column of the split corpus (issue #2973).
#
# Runs dev/lib/review_pack/trade_extract.awk over every trading/test_data/
# split_corpus/<entry>/bars.csv with a synthetic trade held across the entry's
# first ex-date: a long (then a short) filled at the raw close 10 bars before
# the ex-date and exited at the raw close 15 bars after it, with an installed
# stop far from the tape (50 % below a long's fill, 2x above a short's). One
# basis invariant per entry, the suite's rule for every basis consumer:
#   - fe / fx are the entry / exit bars' adjusted/raw factors;
#   - the fills sit inside their bars (codes 1) and are not "past the last bar";
#   - MAE / MFE are measured on the ADJUSTED tape, equal to an independent
#     recomputation (a raw-basis read would show the split as a -67 % MAE);
#   - the far stop is never breached (breach lag -1): the breach line is raw,
#     moved by the split since entry, so a split must not trip it.
set -eu
. "$(dirname "$0")/_check_lib.sh"

ROOT="$(repo_root)"
AWK="$ROOT/dev/lib/review_pack/trade_extract.awk"
CORPUS="$ROOT/trading/test_data/split_corpus"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
checked=0

for dir in "$CORPUS"/*/; do
  name=$(basename "$dir")
  bars="$dir/bars.csv"
  ex=$(grep -o 'ex_date [0-9-]*' "$dir/meta.sexp" | head -1 | cut -d' ' -f2)
  exline=$(grep -n "^$ex," "$bars" | cut -d: -f1)
  if [ -z "$exline" ] || [ "$exline" -le 12 ]; then
    echo "FAIL: $name: ex-date $ex not found with 10 bars before it"; fail=1; continue
  fi
  ed=$(sed -n "$((exline - 10))p" "$bars" | cut -d, -f1)
  xd=$(sed -n "$((exline + 15))p" "$bars" | cut -d, -f1)
  ec=$(sed -n "$((exline - 10))p" "$bars" | cut -d, -f5)
  xc=$(sed -n "$((exline + 15))p" "$bars" | cut -d, -f5)
  # independent adjusted-basis MFE / MAE (percent) over [ed, xd] vs the entry bar
  want=$(awk -F, -v ed="$ed" -v xd="$xd" 'NR > 1 && $1 >= ed && $1 <= xd {
      if ($1 == ed) ae = $6
      r = ($6 / ae - 1) * 100
      if (n == 0 || r > mx) mx = r
      if (n == 0 || r < mn) mn = r
      n++ } END { printf "%.2f %.2f", mx, mn }' "$bars")
  for side in LONG SHORT; do
    if [ "$side" = LONG ]; then es=$(awk -v c="$ec" 'BEGIN { printf "%.4f", c * 0.5 }')
    else es=$(awk -v c="$ec" 'BEGIN { printf "%.4f", c * 2 }'); fi
    out="$TMP/$name-$side.tsv"; : > "$out"
    awk -v pid=T -v side="$side" -v ed="$ed" -v xd="$xd" -v ep="$ec" -v xp="$xc" -v qty=100 \
        -v sid=0.5 -v es="$es" -v out_tr="$out" -v out_ex=/dev/null -v out_dy= -f "$AWK" "$bars"
    got=$(awk -F'\t' -v side="$side" -v want="$want" '
      function near(a, b) { d = a - b; return d < 0.011 && d > -0.011 }
      { split(want, w, " ")
        mfe_w = (side == "LONG") ? w[1] : -w[2]; mae_w = (side == "LONG") ? w[2] : -w[1]
        ok = ($10 == 1 && $11 == 1 && $12 == 1 && $13 == 1 && $19 == -1 && $25 == 0)
        # the extractor measures the path on the adjusted close; the tape check is the independent one
        ok = ok && near($4, mfe_w) && near($5, mae_w)
        print ok ? "ok" : "bad: " $0 }' "$out")
    checked=$((checked + 1))
    if [ "$got" != ok ]; then echo "FAIL: $name $side: $got (want mfe/mae from tape: $want)"; fail=1; fi
  done
done

if [ "$checked" -lt 20 ]; then echo "FAIL: only $checked corpus runs checked (expected >= 20)"; fail=1; fi
[ "$fail" -eq 0 ] && echo "OK: $checked trade-extract runs over the split corpus"
exit "$fail"
