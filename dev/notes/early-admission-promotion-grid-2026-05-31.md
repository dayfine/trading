# Early-admission promotion-confirmation grid — recommend ma=13 (with caveat)

**Date:** 2026-05-31
**Mechanism:** `Stage.config.early_admission_ma_period` (PR #1378; ACCEPT recorded
`dev/experiments/_ledger/2026-05-30-early-admission-surface-v2.sexp`).
**Process:** first application of `.claude/rules/promotion-confirmation.md`.
**Outcome:** **ma=13** is the grid-robust value; **ma=10 is overfit and rejected**;
the global-default flip is teed up for human go-ahead (it re-baselines all
goldens + changes live behaviour).

## Why a grid

The ACCEPT came from one surface (15y SP500), whose DSR-1.0 winner was **ma=10**.
A single-window winner is the classic overfit trap (continuation #1366,
hysteresis #1366). The confirmation grid re-runs the `{7,10,13}` surface across
4 independent (period × universe) contexts and promotes only a value robust
across all of them.

## The grid — mean Sharpe (and Pareto-frontier membership)

| value | 15y SP500 2010-26 (31f) | 5y SP500 2019-23 (9f) | early SP500 2011-16 (11f) | top-3000 2019-23 (9f) |
|---|---|---|---|---|
| baseline | 0.622 | 0.435 | 0.972 | 0.756 |
| ma=7 | 0.637 ◆ | 0.606 ◆ | 0.811 | 0.355 |
| ma=10 | **0.816 ◆** | 0.463 | **1.122 ◆** | 0.435 |
| ma=13 | 0.815 (tied) | **0.615 ◆** | 1.080 ◆ | **0.632 ◆** |

◆ = on the Pareto frontier (Sharpe↑ / Calmar↑ / MaxDD↓) for that context.

**Frontier robustness:** ma=13 is on the frontier in 3/4 and tied-for-frontier
in the 4th (15y: 0.815 vs ma=10's 0.816 — a rounding-width behind). ma=10 is on
the frontier in 2/4 and **dominated in the other 2** (5y, top-3000). ma=7 is
below baseline in 2/4. By the decision rule (robust across the grid, never badly
dominated), **ma=13 is the only promotable value.**

## The nuance the grid surfaced — universe-dependent character

On the **broad top-3000** universe, *no* early-admission cell beats baseline on
raw Sharpe (baseline 0.756 is highest). ma=13 reaches the frontier there via
**return + Calmar**, not Sharpe:

| top-3000 | Sharpe | Calmar | MaxDD% | Return% |
|---|---|---|---|---|
| baseline | **0.756** | 1.152 | **16.71** | 19.97 |
| ma=13 | 0.632 | **1.846** | 21.77 | **49.47** |

So the mechanism's *character* shifts with universe quality:
- **SP500-like (narrower, higher-quality):** a Sharpe improver + drawdown
  reducer (ma=13 beats baseline Sharpe on all three SP500 windows; cuts MaxDD).
- **Broad (top-3000, includes small/low-quality names):** a return booster with
  *higher* drawdown (ma=13 return 49% vs 20%, but MaxDD 21.8 vs 16.7, Sharpe
  slightly below baseline).

Intuition: early admission buys earlier off bottoms. On quality names that's a
clean risk-reducer; on a broad junky pool the earlier entries add return but
also more whipsaw/drawdown.

## Recommendation

1. **Promotable value: ma=13.** For the system's **default SP500-class
   universe** it is a clear, regime-robust improvement (Sharpe +0.11..+0.19 over
   baseline on all three SP500 windows; lower MaxDD; on the frontier of all 4
   contexts). **Do NOT promote ma=10** — it is dominated on 2 of 4 contexts.
2. **The default-flip is high-stakes** (`None → Some 13` on
   `Stage.default_config` re-baselines every golden — 5y, 15y, custom-universe —
   and changes live-strategy behaviour). It is teed up for explicit go-ahead,
   not auto-merged.
3. **Document the universe caveat at promotion:** on broad/low-quality universes
   the mechanism trades Sharpe for return+drawdown. If broad-universe trading is
   a goal, treat the period as a per-universe tunable rather than a global
   constant.

## Provenance

All cells: `{7,10,13}` `Variant_matrix` surfaces on the GSPC-repaired golden
(PR #1383, issue #1380), `TRADING_DATA_DIR` → repo `trading/test_data`, ranked
by `Variant_ranking` (Pareto) + `Backtest_stats.Deflated_sharpe`. Specs:
`trading/test_data/walk_forward/ea-grid-*.sexp` (ephemeral) +
`early-admission-surface-v2` / `-5y-confirm`. Per-cell DSR (best active):
15y ma=10 1.000, 5y ma=13 0.898, early ma=10 1.000, top-3000 ma=13 1.000 —
note DSR rewards the per-window best, which is exactly why it must not be the
promotion criterion; the cross-grid frontier robustness is.
