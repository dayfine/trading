# Cell E 15y is impractical at h=2 — engineering blocker

## What happened

After the Cell E 4-of-4 generalization (#1002) + 7-of-8 walk-forward (#1005)
landed, I dispatched a local 15y Cell E run for the third confirmation
(`dev/experiments/cell-e-15y-2026-05-09/scenarios/sp500-2010-2026-cell-E.sexp`).
After 2h45m wall-time, the run had only completed 54% of cycles (476 of 882).
Killed it.

## Why it's impractical

Cell E with `laggard_rotation_config.hysteresis_weeks=2` on the 15y / 510-symbol
window generates **enormous trade volume**:

| Metric | Vanilla 15y | Cell E 15y (partial) |
|--------|-------------|----------------------|
| trades by mid-2018 | ~150 (estimate) | **1,994** |
| projected total trades | 302 (full) | **3,700+** |

The runtime is dominated by something **O(trades²)** or O(trades × symbols)
— the rate of cycle completion fell from ~30 cycles/min in early years (low
trade count) to ~1 cycle every 30 min by mid-2018. Projected: ~200+ hours
to finish a single Cell E 15y run.

## Partial result (informational)

Despite incompleteness, the equity curve is encouraging:

| | At 2018-07-13 (partial) |
|---|---|
| Cycles completed | 476 / 882 (54%) |
| Trades so far | 1,994 |
| Current equity | $2,495,534 (+150% from $1M start) |
| Compound annual rate | ~12% over 8.5 years |

Vanilla 15y new pin (#1006): +110.84% over 16 years = **6.4% CAGR**.

Cell E partial 8.5y at +150% = **12% CAGR** — nearly 2× the vanilla pace.
Directionally consistent with the small-window 4-of-4 + walk-forward 7-of-8
generalization signal: Cell E outperforms substantially.

But not measurable to completion at the current implementation's runtime
profile.

## Engineering follow-up

The hot path is almost certainly one of:

1. **Trade-audit list growth.** `Trade_audit.t` accumulates a `trades` list
   that grows linearly. Lookups, filters, or fold operations over it become
   O(trades) per call. At 1,994 trades, single-day rebalance touches all of
   them, and there are 4,400 trading days remaining.
2. **Laggard rotation re-scoring.** `Laggard_rotation.evaluate` likely
   re-scores all open positions every Friday cycle. With a fast turnover,
   the open-position list is large + churning; re-scoring may scan trade
   history.
3. **Step-history retention.** Q1 Fix B (#993) projected
   `step_result.portfolio` to a skinny summary. But `step_history` itself
   may still grow linearly. At 4,400 days × full history, the fold over
   `step_history` for end-of-run analytics may also be quadratic.

Recommended diagnostic: profile a 5y Cell E run with `--memtrace` (the
existing memtrace flag from PR #538) and look for the function with
allocation rate that scales with cumulative trade count.

Once the hot path is identified, fix it (likely with a bounded ring buffer
or lazy fold), then retry Cell E 15y.

## Alternative path while engineering blocker is open

Run **Cell D** (Stage3-k1 + Laggard h=4, less aggressive) on 15y.
Cell D had ~164 trades over 5y vs Cell E's 196, so the trade-rate is lower.
Cell D underperformed Cell E at 5y (+37% vs +120%) but could be a
**measurable Cell** on 15y — useful intermediate data point.

Or run Cell B (Stage3-only) or Cell C (Laggard-h4-only) on 15y — both lower
trade frequency, both still beat Cell A at 5y.

## Implication for "flip defaults" recommendation

The walk-forward + 4-of-4 evidence still holds. **Cell E h=2 is not the
right default** because:

1. It can't be measured on 15y due to runtime scaling.
2. Live deployment of Cell E h=2 would require commission/slippage modeling
   that handles 200-400 trades/year per portfolio.

Recommended revised flip:
- **Stage3 force-exit ON** (k=1) — moderate trade-rate increase, big
  generalization win
- **Laggard rotation ON, h=4** (not h=2) — less aggressive but should
  measurable on 15y AND closer to a realistic ops target

Re-run the cell-A vs cell-D vs cell-E pattern on small-universe + walk-forward
to confirm cell-D is "good enough" to be the default. Then flip with `h=4`.

## Next concrete actions

1. Profile Cell E 5y for trade-audit O(N²) hotspot (memtrace).
2. Fix the hotspot — likely a single function on `Trade_audit` or
   `Laggard_rotation`.
3. Re-run Cell D (h=4) on 15y to validate scalability + win.
4. Re-run Cell E (h=2) on 15y to complete the original measurement.
5. Then flip defaults with the right h value.
