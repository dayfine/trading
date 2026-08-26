#!/bin/sh
# run_dissection.sh — attribute the P1 holding/exit shape to a mechanism.
#
# Usage: sh run_dissection.sh <repo-root>
# Writes results/{stopwidth,ratchet,pinned-entry-features}.txt.
#
# The split is on stop_initial_distance_pct, which separates the two stop
# provenances without needing the (uncommitted, 13MB) trade_audit:
#   fallback  = entry x initial_stop_buffer x (1 - max_stop_pct); a constant
#               width per basis -- 4.00% on the pinned basis (buffer 1.0),
#               2.08% on the retired one (buffer 1.02). See
#               project_fallback_stop_half_book_band.
#   structural = a real support level was found, so the width is whatever the
#               chart gave -- always wider here, and variable.
# Bucket edge sits above the constant and below any real support distance.
set -eu

ROOT=$1
HERE="$ROOT/dev/experiments/rep-trade-audit-2026-08-26"
REC="$ROOT/dev/experiments/record-baseline-2026-08-24/results/record-baseline-trades.csv"
PRE="$ROOT/dev/experiments/instrumented-record-2026-08-23/results/instr-null-trades.csv"
FEAT="$ROOT/dev/experiments/instrumented-record-2026-08-23/results"
OUT="$HERE/results"
mkdir -p "$OUT"

# Bucket edges: just above each basis's constant fallback width.
dissect() {
  csv=$1; tag=$2; edge=$3
  awk -v tag="$tag" -v edge="$edge" -F, '
    NR==1{for(i=1;i<=NF;i++){if($i=="stop_initial_distance_pct")s=i
                             if($i=="days_held")d=i
                             if($i=="exit_trigger")x=i
                             if($i=="pnl_percent")p=i
                             if($i=="n_stop_raises")r=i}; next}
    {
      b = ($s+0 <= edge) ? "fallback" : "structural"
      n[b]++
      if($d+0 >= 91) w13[b]++
      if($d+0 <= 7)  q7[b]++
      if($x == "stop_loss") sl[b]++
      if($r+0 >= 1) raise[b]++
      sum[b] += $p+0
    }
    END{
      printf "-- %s (bucket edge %.4f)\n", tag, edge
      printf "   %-11s %6s %8s %8s %9s %9s %10s\n",
             "bucket","n","<=7d",">=13wk","stop_loss","raised>=1","mean pnl%"
      for (b in n)
        printf "   %-11s %6d %7.1f%% %7.1f%% %8.1f%% %8.1f%% %9.2f\n",
               b, n[b], 100*q7[b]/n[b], 100*w13[b]/n[b],
               100*sl[b]/n[b], 100*raise[b]/n[b], sum[b]/n[b]
    }' "$csv"
}

{
  echo "== P1 holding/exit shape by STOP PROVENANCE =="
  echo "(fallback width is constant per basis: 4.00% pinned, 2.08% retired)"
  echo
  dissect "$REC" "record-baseline (pinned)" 0.0401
  echo
  dissect "$PRE" "instr-null (retired)" 0.0209
} > "$OUT/stopwidth.txt"

{
  echo "== ratchet liveness: share of round-trips with n_stop_raises >= 1 =="
  for f in "$REC:record-baseline(pinned)" "$PRE:instr-null(retired)"; do
    csv=${f%%:*}; tag=${f##*:}
    awk -v tag="$tag" -F, '
      NR==1{for(i=1;i<=NF;i++) if($i=="n_stop_raises") r=i; next}
      {n++; if($r+0>=1) k++; if($r+0>=2) k2++}
      END{printf "%-26s n=%d  >=1 raise %.1f%%  >=2 raises %.1f%%\n",
            tag, n, 100*k/n, 100*k2/n}' "$csv"
  done
} > "$OUT/ratchet.txt"

# Entry-side features restricted to the entries that SURVIVE on the pinned basis.
# feat-p1 rows are keyed (symbol, date) and are pure functions of the weekly
# bars, so re-using them for the pinned subset is valid; only coverage changes.
# NOTE: trades.csv column 2 is `side`, not `entry_date` -- resolve both key
# columns by NAME, never by position.
awk -F, 'NR==FNR{
           if(FNR==1){for(i=1;i<=NF;i++){if($i=="symbol")s=i; if($i=="entry_date")e=i}; next}
           k[$s"|"$e]=1; next
         }
         FNR==1{print; next}
         (($1"|"$2) in k){print}' \
  "$REC" "$FEAT/feat-p1.csv" > "$OUT/feat-p1-pinned-subset.csv"

{
  echo "== entry features on the PINNED-basis subset of executed trades =="
  echo "(feat-p1 rows whose (symbol, entry_date) also appears in the pinned run)"
  sh "$HERE/quantiles.sh" "$OUT/feat-p1-pinned-subset.csv" vol_ratio_at_date "  fill-week vol ratio"
  sh "$HERE/quantiles.sh" "$OUT/feat-p1-pinned-subset.csv" base_weeks_at_date "  base_weeks"
  echo
  echo "== share of executed fills clearing the book's 2x volume bar AT FILL =="
  for f in "$OUT/feat-p1-pinned-subset.csv:p1 pinned subset" \
           "$FEAT/feat-p1.csv:p1 retired basis" \
           "$FEAT/feat-p2kept.csv:p2 kept" \
           "$FEAT/feat-p2eject.csv:p2 ejected" \
           "$FEAT/feat-p3.csv:p3 funding-death"; do
    csv=${f%%:*}; tag=${f##*:}
    awk -v tag="$tag" -F, '
      NR==1{for(i=1;i<=NF;i++) if($i=="vol_ratio_at_date") v=i; next}
      $v ~ /^[0-9.]+$/ {n++; if($v+0 >= 2.0) k++}
      END{printf "  %-22s n=%-5d clears 2x: %5.1f%%\n", tag, n, 100*k/n}' "$csv"
  done
} > "$OUT/pinned-entry-features.txt"

echo "wrote $OUT/{stopwidth,ratchet,pinned-entry-features}.txt + feat-p1-pinned-subset.csv"
