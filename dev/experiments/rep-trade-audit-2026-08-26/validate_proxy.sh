#!/bin/sh
# validate_proxy.sh — check the stop-width bucket against ground truth.
#
# Usage: sh validate_proxy.sh <repo-root>
#
# run_dissection.sh splits P1 on stop_initial_distance_pct because the
# authoritative field (`stop_floor_kind`, derived from trade_audit's
# entry_decision) is not committed for the pinned basis -- the pinned worktree
# that held trade_audit.sexp was reaped. The RETIRED basis DOES have it, as
# `instr-null-floorkind.tsv`, so the proxy is validated there and the accuracy
# carried over.
#
# Join key is `position_id` -- the ONLY valid one; symbols repeat across the
# 26 years (feedback_position_id_is_the_only_join_key).
set -eu

ROOT=$1
RES="$ROOT/dev/experiments/instrumented-record-2026-08-23/results"
OUT="$ROOT/dev/experiments/rep-trade-audit-2026-08-26/results"
mkdir -p "$OUT"

{
  echo "== stop-width proxy vs committed stop_floor_kind (retired basis, join on position_id) =="
  awk '
    NR==FNR { split($0, a, "\t"); kind[a[1]] = a[2]; next }
    FNR==1 {
      nf = split($0, h, ",")
      for (i = 1; i <= nf; i++) {
        if (h[i] == "position_id") pid = i
        if (h[i] == "stop_initial_distance_pct") sw = i
      }
      next
    }
    {
      nf = split($0, f, ",")
      k = kind[f[pid]]
      if (k == "") { missing++; next }
      bucket = (f[sw] + 0 <= 0.0209) ? "fallback" : "structural"
      truth  = (k == "Buffer_fallback") ? "fallback" : "structural"
      n++
      cell[bucket "/" truth]++
      if (bucket == truth) agree++
    }
    END {
      printf "  joined %d trades (%d had no floorkind row)\n", n, missing
      for (c in cell) printf "  proxy=%-24s %6d\n", c, cell[c]
      printf "  AGREEMENT: %.2f%%\n", 100 * agree / n
    }
  ' "$RES/instr-null-floorkind.tsv" "$RES/instr-null-trades.csv"
} > "$OUT/proxy-validation.txt"

cat "$OUT/proxy-validation.txt"
