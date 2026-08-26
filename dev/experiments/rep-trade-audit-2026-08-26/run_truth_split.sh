#!/bin/sh
# run_truth_split.sh — the stop-provenance split on GROUND TRUTH, retired basis.
#
# Usage: sh run_truth_split.sh <repo-root>
#
# validate_proxy.sh shows the width proxy is asymmetric: the fallback bucket is
# ~99.5% precise, but the structural bucket is only ~41% precise (232 of 392 are
# really Buffer_fallback). So the proxy's fallback-vs-structural gap is a LOWER
# BOUND on the true gap. This script computes the same split on the committed
# `stop_floor_kind` for the retired basis, to size that understatement.
#
# Join key is `position_id` (feedback_position_id_is_the_only_join_key).
set -eu

ROOT=$1
RES="$ROOT/dev/experiments/instrumented-record-2026-08-23/results"
OUT="$ROOT/dev/experiments/rep-trade-audit-2026-08-26/results"
mkdir -p "$OUT"

{
  echo "== retired basis, split on COMMITTED stop_floor_kind (ground truth) =="
  awk '
    NR==FNR { split($0, a, "\t"); kind[a[1]] = a[2]; next }
    FNR==1 {
      nf = split($0, h, ",")
      for (i = 1; i <= nf; i++) {
        if (h[i] == "position_id") pid = i
        if (h[i] == "days_held") d = i
        if (h[i] == "exit_trigger") x = i
        if (h[i] == "pnl_percent") p = i
        if (h[i] == "n_stop_raises") r = i
      }
      next
    }
    {
      nf = split($0, f, ",")
      k = kind[f[pid]]
      if (k == "") next
      b = (k == "Buffer_fallback") ? "fallback" : "structural"
      n[b]++
      if (f[d] + 0 >= 91) w13[b]++
      if (f[d] + 0 <= 7)  q7[b]++
      if (f[x] == "stop_loss") sl[b]++
      if (f[r] + 0 >= 1) raise[b]++
      sum[b] += f[p] + 0
    }
    END {
      printf "   %-11s %6s %8s %8s %9s %9s %10s\n",
             "bucket","n","<=7d",">=13wk","stop_loss","raised>=1","mean pnl%"
      for (b in n)
        printf "   %-11s %6d %7.1f%% %7.1f%% %8.1f%% %8.1f%% %9.2f\n",
               b, n[b], 100*q7[b]/n[b], 100*w13[b]/n[b],
               100*sl[b]/n[b], 100*raise[b]/n[b], sum[b]/n[b]
    }
  ' "$RES/instr-null-floorkind.tsv" "$RES/instr-null-trades.csv"
  echo
  echo "  Compare with results/stopwidth.txt's retired-basis (proxy) rows to see"
  echo "  how much the proxy's contaminated structural bucket compresses the gap."
} > "$OUT/truth-split.txt"

cat "$OUT/truth-split.txt"
