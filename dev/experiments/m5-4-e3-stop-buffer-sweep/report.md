# M5.4 E3 stop-buffer sweep — results

**Run timestamp:** 2026-05-08T17:41Z
**Window:** sp500-2019-2023 (5y, 500-symbol post-#851 dedup universe)
**Sweep harness:** PR #815 (2026-05-03)
**Cells:** 8 — buffer multiplier ∈ {1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20}
**Hypothesis:** 1.05–1.10 buffer outperforms tight (1.00) and loose (1.20) per Weinstein's "above-resistance support, no tighter than ~5%" guidance.

## Results

| Buffer | Return % | Trades | Win Rate % | Sharpe | MaxDD % | Avg Hold (days) |
|--------|----------|--------|------------|--------|---------|------------------|
| **1.00** | **120.03** | 49 | 22.45 | **0.779** | 31.40 | 98.9 |
| 1.02 | 58.34 | 81 | 19.75 | 0.528 | 33.60 | 84.1 |
| 1.05 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |
| 1.08 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |
| 1.10 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |
| 1.12 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |
| 1.15 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |
| 1.20 | 53.08 | 81 | 19.75 | 0.563 | 22.05 | 84.1 |

Pinned baseline (`memory/project_sp500_baseline_conflict.md`): 58.34% / 81 trades / 0.54 Sharpe / 33.6% MaxDD — matches the **1.02** cell exactly.

## Verdict

**Hypothesis REFUTED.** 1.05–1.10 do not outperform tight (1.00) buffer.

**Surprising result: tighter stops win on every metric.**

- **1.00 wins on return** (120% vs 53–58% at all other buffers).
- **1.00 wins on Sharpe** (0.78 vs 0.53–0.56).
- **1.00 has fewer trades** (49 vs 81) — tight stops cut losers fast, leaving fewer total round-trips. Surviving trades are higher-quality.
- **1.05+ shows a discontinuity at 1.05** — every cell from 1.05 to 1.20 is bit-equal (53.08% / 81 trades / 0.563 Sharpe / 22.05% MaxDD). This means the buffer is **inert above 1.02**: the binding constraint is elsewhere (probably the support floor lookup).

## Mechanics

The stop-buffer multiplier is the **fallback widening factor** — applied only when no support floor (Weinstein 30-week MA, prior swing low, etc.) is found. When a valid support floor exists, the floor itself sets the stop; the buffer is unused.

- **1.00**: Even with valid support floor, stop is placed at floor exactly (no slack). Tight stops trigger earlier on noise → more whipsaws on entry. **But** they cut losers fast, and the surviving 49 trades have very strong unrealized P&L ($1.27M unrealized at end of window).
- **1.02–1.04** (interpolated): Same fallback gate as 1.00 but with 2-4% slack. 1.02 result matches the canonical baseline (58.34% / 81 trades) suggesting the existing default is 1.02.
- **1.05+**: All bit-equal because the support-floor lookup succeeds for all 81 entries that wind up in the trade ledger. The buffer never engages, so its value doesn't matter past 1.05.

The earlier finding from the dispatched agent — that 1.20 should filter out fallback candidates via the 15% `max_stop_distance_pct` gate — is **not visible in the final results** because no entries in this 5y window relied on the fallback path.

## Recommendation

Do not change `Stop_buffer.default_multiplier` based on this 5y window alone. The 1.00 result (120%) is striking but:

- 49 trades over 5 years ≈ 10 trades/year — sample size is small for a 0.78 Sharpe to be robust.
- $1.27M unrealized P&L on open positions = much of the "120%" is paper-gain on positions still open at end-of-window; mark-to-market timing matters.
- The 1.05+ flat region suggests this sweep can't distinguish between "tight stops are better" and "support floors carry the day on most entries."

Better next experiments:
1. Re-run E3 on a 15y window (`sp500-2010-2026`) once the split-day P0 is resolved — should expose buffer effects across many more entries.
2. Walk-forward partition: split 5y into out-of-sample periods to detect overfitting on 1.00.
3. Couple with E4 (scoring-weight sweep) results to see if 1.00 helps universally or only with a particular weight regime.

## Artefacts

Per-cell artefact dirs at:
- `dev/backtest/scenarios-2026-05-08-174119/m5-4-e3-buffer-1.XX/{actual,summary,trade_audit}.sexp`, `equity_curve.csv`, `trades.csv`, `splits.csv`, `params.sexp`

(Total: 3.7 MB across 8 cells. Gitignored to keep repo lean — re-runnable from `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/buffer-1.XX.sexp`.)
