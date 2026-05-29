# P1 retracted — `laggard_rotation` disable hurts on full-universe panel scenarios

**Date:** 2026-05-29
**Status:** P1 RETRACTED. Branch `feat/cell-e-no-laggard-rotation-2026-05-29` discarded.
**Supersedes:** § P1 of `next-session-priorities-2026-05-29.md`.

## TL;DR

Ablation #1352 showed `enable_laggard_rotation = true` was the dominant alpha-killer on a 12-symbol diagnostic universe (SPY + 11 sector ETFs). The synthesis doc generalized this to "disable as new Cell-E default" (P1).

We re-ran the two panel scenarios (sp500-2019-2023 and sp500-2010-2026) with `enable_laggard_rotation false` and measured. **The hypothesis fails on production-scale universes.** Laggard rotation HELPS on 500-symbol universes and HURTS on tiny universes. We are NOT shipping the Cell-E default change.

## Measured impact

### 5y panel: sp500-2019-2023 (500 symbols, full Cell-E config)

| Metric | with laggard (Cell-E pin) | no laggard | Δ |
|---|---|---|---|
| total_return_pct | 50.66 | 41.63 | **−9.0pp** |
| sharpe_ratio | 0.56 | 0.48 | **−0.08** |
| max_drawdown_pct | 21.56 | 24.98 | **+3.42pp** (worse) |
| calmar_ratio | 0.40 | 0.29 | **−0.11** |
| sortino_ratio_annualized | 0.75 | 0.62 | **−0.13** |
| total_trades | 264 | 173 | −34% |
| avg_holding_days | 40.78 | 62.77 | +54% |
| ulcer_index | 8.41 | 9.19 | +9% (worse) |

5y verdict: **regression on every risk-adjusted metric**, including Calmar (which was the reframe's primary metric).

### 15y panel: sp500-2010-2026 (510 symbols, full Cell-E config)

| Metric | with laggard (Cell-E pin) | no laggard | Δ |
|---|---|---|---|
| total_return_pct | 341.69 | 296.49 | **−45.2pp** |
| sharpe_ratio | 0.78 | 0.74 | **−0.04** |
| max_drawdown_pct | 18.36 | 15.85 | **−2.51pp** (better) |
| calmar_ratio | 0.52 | 0.555 | **+0.04** (marginal better) |
| sortino_ratio_annualized | 1.25 | 1.14 | **−0.11** |
| total_trades | 806 | 389 | −52% |
| avg_holding_days | 44.68 | 83.15 | +86% |
| ulcer_index | 7.48 | 5.50 | −26% (better) |

15y verdict: **mixed.** MaxDD improves and Calmar improves marginally (+0.04 = within noise), but Sharpe + Sortino + return all degrade. The Calmar improvement is too small to motivate the change against the −45pp return cost.

## Why the universe-dependence

Reading the synthesis doc more carefully:

> `laggard_rotation` is the load-bearing alpha-killer. On SPY-only it acts as "go-to-cash" signal (no rotation target); on sector-ETF it churns highly-correlated peers and dissipates trend alpha. Disabling produces 5-47× CAGR lift.

The mechanism the ablation captured is specific to its 12-symbol diagnostic universe:
1. **No rotation target:** with only 12 candidates, the screener often has no eligible "buy" candidate to rotate INTO, so a "rotate out of the weakest holding" decision turns into "sit in cash."
2. **Correlated peers:** the 11 SPDR sector ETFs are highly correlated; rotating from one to another doesn't capture trend alpha because the next sector ETF in the queue is moving the same direction.

On the production 500-symbol universe these two failure modes don't apply:
- There are usually dozens of eligible Stage 2 candidates to rotate INTO. Cash exposure stays low.
- The candidate pool is broadly diversified. Rotating from a weakening holding to a fresh strong holding captures real cross-sectional alpha.

The mechanism the ablation captured was real for narrow universes but the wrong load-bearing claim for production.

## Where the synthesis doc went wrong

The synthesis's "Updated alpha-source attribution" table at § 4.6 leaped from ablation-universe data to a production-config recommendation:

| Mechanism layer | Effect | Action (synthesis claim) | Reality (this re-test) |
|---|---|---|---|
| `laggard_rotation` | STRONG negative (in ablation) | Disable as new Cell-E default | Disable HURTS on production panel |

The ablation result is correct as a diagnostic; the generalization to "new Cell-E default" was an overreach. The 47×/5.5× lift was a tiny-universe artifact, not a portable strategy improvement.

## What this changes upstream

### P1 (laggard disable as Cell-E default)
**RETRACTED.** Cell-E retains `enable_laggard_rotation = true` on the panel scenarios. No code change ships from P1.

The diagnostic finding survives in a narrower form: **on narrow-universe runs (SPY-only, sector-ETF-only), `laggard_rotation` should be disabled.** This matters for future per-symbol diagnostic experiments (don't enable laggard on them) but is not a global default.

### P2 (Calmar/Sortino as primary gate)
**STILL VALID.** Independent of laggard. The reframe to risk-adjusted metrics stands. Updated motivation:
- Per-symbol § 4.6: stage analysis delivers risk-adjusted alpha (Calmar 6/12 wins), absolute-CAGR loses on most symbols
- Therefore the gate should reward risk-adjusted gains rather than Sharpe-only
- P2 proceeds against the existing Cell-E baseline (laggard ON)

The 15y panel actual.sexp now has Calmar 0.52 + Sortino 1.25 in its headers — usable directly for the P2 pin.

### P3 (trade-autopsy tool)
**UNCHANGED.** The autopsy is still the right next move: figure out WHICH gain-capture mode dominates so the targeted fix is data-driven, not vibes-driven. The fact that laggard isn't the universal alpha-killer makes P3 MORE important, not less — we still don't know where the −2.31pp avg CAGR loss vs BAH actually comes from.

## Process lesson

Per `feedback_strategy_mechanic_changes_too_explorative.md`: don't commit a strategy mechanic change on a single diagnostic data source. The ablation diagnostic universe and the production panel have qualitatively different mechanics. Either:
1. Run the ablation directly on the production-panel universe before generalizing, OR
2. Treat narrow-universe ablations as hypothesis generators only — confirm on production panel before shipping.

The 1-hour re-test cost was tiny vs the harm of shipping a Sharpe regression to main. The reframe was right about the meta-claim ("measure risk-adjusted"); wrong about the specific mechanism change (laggard-off).
