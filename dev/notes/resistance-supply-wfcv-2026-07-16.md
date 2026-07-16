# resistance-v2 PR-E — w_overhead_supply WF-CV surface (2026-07-16)

**The false virgins were LUCK, not structure.** Fold-honest evaluation of
honestly-priced overhead supply IMPROVES risk-adjusted results monotonically
with positive weight — the 07-14 armed single-path collapse (−55% vs Run D)
was a compounding-path artifact (same class as the Run-E-capped sizing
lottery), not evidence that honest resistance data destroys the edge.

Ledger: `dev/experiments/_ledger/2026-07-16-resistance-supply-weight-surface.sexp`
(verdict **Inconclusive** — promising, unpowered, boundary winner; no
promotion). Sweep: `/tmp/sweeps/resist-supply-w-v1` (65 fold-runs, exit 0,
~15h wall). Spec: `test_data/walk_forward/resistance-supply-weight-BROAD-2000-2026.sexp`.

## Setup

- Warehouse: `/tmp/snap_top3000_dedup_v3_sketch` — dedup-v2 twin flags +
  37-column sketch schema (#1975) + deep-history feed (#1982; verified: IBM
  2000-01-03 `Res_bars_seen = 520`, raw 10y max 246 = pre-split high).
- Base: record convention (ext-stop 2.0/0.25, declining-MA gate, catstop,
  liquidity, stale-exit — the Run D dial set), PIT top-3000, 13 × 2y folds
  2000-2026 (broad geometry precedent), snapshot mode, parallel 1.
- Axis: `w_overhead_supply ∈ {−15, 0, 15, 30}` with `overhead_supply` armed
  at `Resistance_supply` defaults (min_history_bars 0 — insufficient-floor
  deliberately excluded to isolate ONE mechanism); baseline = weight None =
  today's binary path.

## Results (fold means, n=13)

| variant | Sharpe | Calmar | Return % | MaxDD % | Sharpe wins | MaxDD wins |
|---|---:|---:|---:|---:|---:|---:|
| baseline (binary) | 0.691 | 0.921 | 31.7 | 16.6 | — | — |
| w = −15 (prefer overhead) | 0.685 | 0.866 | 25.1 | 17.9 | 7/13 | 5/13 |
| w = 0 (signal deleted) | 0.691 | 0.993 | 27.9 | 15.5 | 5/13 | 7/13 |
| w = 15 | 0.787 | 1.151 | 28.7 | 14.1 | 7/13 | 12/13 |
| w = 30 | **0.860** | **1.218** | **33.2** | **14.0** | 9/13 | 10/13 |

- **Monotone in weight** on Sharpe/Calmar/MaxDD, and w=30 wins on RETURN
  too — penalizing supply-laden breakouts is NOT a fat-tail tax at fold-mean
  granularity (the winners it demotes are replaced by cleaner ones, not
  lost).
- **Prefer-overhead (w<0) refuted** — worse on every aggregate. The
  crash-recovery-monster direction does not generalize.
- **Signal-deleted (w=0) ≈ neutral** (Sharpe flat, DD slightly better,
  return lower) — consistent with the Run C min-hist result: the BINARY
  virgin signal on honest data carries ~no net ranking value.

## Why no ACCEPT

- Fold gate FAILs for all variants, but ONLY on `worst_delta = 0` (a single
  losing fold disqualifies — w30's worst is fold-007, −0.45 Sharpe). The
  m-of-n substance passes for w30 (9/13 ≥ 7).
- Paired per-fold Sharpe (w30 − baseline): mean +0.169, sd 0.402 → t ≈ 1.5
  at n=13 — not significant even before deflating for best-of-4 selection.
- The winner sits on the tested boundary (w=30 = max) — the surface is not
  interior, so the response curve is unfinished.

## Forward guidance (the transferable why)

1. The resistance-v2 mechanism is REAL enough to keep searching and safe to
   leave default-off: extend the axis {45, 60} + add the
   `min_history_bars`/`insufficient_score` axes (the honest-history floor was
   deliberately off here).
2. The false-virgin episode reclassifies as the third path-lottery artifact
   (E-capped sizing lottery, resist520 armed run, now fold-honest
   refutation) — single-path 28y deltas on this strategy are dominated by
   WHICH monster compounds; only fold-mean comparisons are decision-grade.
3. Do-no-harm confirmed operationally: baseline folds on the new 37-col
   deep-feed warehouse behave in line with prior record-convention runs
   (weight None path untouched); the sketch columns cost nothing at query
   time (~14 min/fold, same as pre-sketch broad folds).

## Standing state

- `w_overhead_supply` and `overhead_supply` stay default-off (R3: no
  default flip without ACCEPT + confirmation grid).
- Live weekly-review continues with `resistance_lookback_bars 520` armed
  for text honesty; live ranking still v1 binary (CSV path get_sketch=None).
- Warehouse of record for sketch-consuming experiments:
  `/tmp/snap_top3000_dedup_v3_sketch`.
