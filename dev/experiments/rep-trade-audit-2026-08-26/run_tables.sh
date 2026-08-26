#!/bin/sh
# run_tables.sh — regenerate every distribution table in this writeup.
#
# Usage: sh run_tables.sh <repo-root>
# Writes results/*.txt. Read-only over committed artifacts; no backtest is run.
set -eu

ROOT=$1
HERE="$ROOT/dev/experiments/rep-trade-audit-2026-08-26"
Q="sh $HERE/quantiles.sh"
REC="$ROOT/dev/experiments/record-baseline-2026-08-24/results/record-baseline-trades.csv"
PRE="$ROOT/dev/experiments/instrumented-record-2026-08-23/results/instr-null-trades.csv"
FEAT="$ROOT/dev/experiments/instrumented-record-2026-08-23/results"
OUT="$HERE/results"
mkdir -p "$OUT"

# --- Realized-trade distributions: pinned basis vs the retired pre-flip basis ---
{
  echo "== P1 executed, PINNED record baseline (record-baseline-2026-08-24, 780 round-trips) =="
  for c in days_held pnl_percent entry_volume_ratio stop_initial_distance_pct \
           n_stop_raises screener_score_at_entry stop_fill_distance_pct; do
    $Q "$REC" "$c" "$c"
  done
  echo
  echo "== P1 executed, RETIRED pre-flip basis (instr-null, 1182 round-trips) =="
  for c in days_held pnl_percent entry_volume_ratio stop_initial_distance_pct \
           n_stop_raises screener_score_at_entry stop_fill_distance_pct; do
    $Q "$PRE" "$c" "$c"
  done
} > "$OUT/p1-realized.txt"

# --- Exit-reason mix (the book's own exit is the Stage 3/4 transition) ---
{
  echo "== exit_trigger mix =="
  for f in "$REC:record-baseline(pinned)" "$PRE:instr-null(retired)"; do
    csv=${f%%:*}; tag=${f##*:}
    echo "-- $tag"
    awk -F, 'NR==1{for(i=1;i<=NF;i++) if($i=="exit_trigger") x=i; next}
             {c[$x]++; t++}
             END{for(k in c) printf "  %-26s %5d  %5.1f%%\n", k, c[k], 100*c[k]/t;
                 printf "  %-26s %5d\n", "TOTAL", t}' "$csv" | sort -k2 -rn
  done
  echo
  echo "== stop_trigger_kind mix =="
  for f in "$REC:record-baseline(pinned)" "$PRE:instr-null(retired)"; do
    csv=${f%%:*}; tag=${f##*:}
    echo "-- $tag"
    awk -F, 'NR==1{for(i=1;i<=NF;i++) if($i=="stop_trigger_kind") x=i; next}
             {c[$x]++; t++}
             END{for(k in c) printf "  %-26s %5d  %5.1f%%\n", k, c[k], 100*c[k]/t;
                 printf "  %-26s %5d\n", "TOTAL", t}' "$csv" | sort -k2 -rn
  done
  echo
  echo "== entry_stage mix (spine item 2: buy ONLY in Stage 2) =="
  for f in "$REC:record-baseline(pinned)" "$PRE:instr-null(retired)"; do
    csv=${f%%:*}; tag=${f##*:}
    echo "-- $tag"
    awk -F, 'NR==1{for(i=1;i<=NF;i++) if($i=="entry_stage") x=i; next}
             {c[$x]++; t++}
             END{for(k in c) printf "  %-26s %5d  %5.1f%%\n", k, c[k], 100*c[k]/t}' "$csv"
  done
} > "$OUT/p1-mix.txt"

# --- Holding-survival curve: the book's population lives months-to-years ---
{
  echo "== survival: share of round-trips still open at N weeks =="
  printf "%-26s %8s %8s %8s %8s %8s %8s\n" basis n ">=4wk" ">=13wk" ">=26wk" ">=52wk" "<=7d"
  for f in "$REC:record-baseline(pinned)" "$PRE:instr-null(retired)"; do
    csv=${f%%:*}; tag=${f##*:}
    awk -v tag="$tag" -F, '
      NR==1{for(i=1;i<=NF;i++) if($i=="days_held") x=i; next}
      {n++; d=$x+0
       if(d>=28) w4++; if(d>=91) w13++; if(d>=182) w26++; if(d>=364) w52++; if(d<=7) q++}
      END{printf "%-26s %8d %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%%\n",
            tag, n, 100*w4/n, 100*w13/n, 100*w26/n, 100*w52/n, 100*q/n}' "$csv"
  done
} > "$OUT/p1-survival.txt"

# --- Entry-side decision-time features, all four populations ---
# vol_ratio_at_date / base_weeks_at_date are pure functions of the weekly bars
# (monster_scan -pairs, 4wk x 2.0 book basis), so they are comparable across
# arms even though the entry SETS come from different config bases.
{
  echo "== decision-time entry features (monster_scan -pairs, book 4wk x 2.0 basis) =="
  for p in p1 p2eject p2kept p3; do
    echo "-- $p"
    $Q "$FEAT/feat-$p.csv" vol_ratio_at_date "  fill-week vol ratio"
    $Q "$FEAT/feat-$p.csv" base_weeks_at_date "  base_weeks"
    awk -F, 'NR==1{for(i=1;i<=NF;i++) if($i=="stage_at_date") x=i; next}
             {c[$x]++; t++}
             END{for(k in c) printf "  stage %-20s %5d  %5.1f%%\n", k, c[k], 100*c[k]/t}' \
      "$FEAT/feat-$p.csv" | sort -k3 -rn
  done
} > "$OUT/entry-features.txt"

# --- Does the pinned basis keep the same entries? join feat-p1 onto record-baseline ---
# feat-p1 keys are (symbol, entry_date) drawn from the RETIRED arm's entry set;
# the overlap measures how much of the pinned population inherits a computed
# feature row, and is itself the headline coverage caveat.
{
  echo "== (symbol, entry_date) overlap: pinned record baseline vs feat-p1 feature rows =="
  awk -F, 'NR==FNR{if(FNR>1) k[$1"|"$2]=1; next}
           FNR==1{for(i=1;i<=NF;i++){if($i=="symbol")s=i; if($i=="entry_date")e=i}; next}
           {n++; if(($s"|"$e) in k) hit++}
           END{printf "pinned entries n=%d, with a feat-p1 row: %d (%.1f%%)\n", n, hit, 100*hit/n}' \
    "$FEAT/feat-p1.csv" "$REC"
} > "$OUT/coverage.txt"

echo "wrote $OUT/{p1-realized,p1-mix,p1-survival,entry-features,coverage}.txt"
