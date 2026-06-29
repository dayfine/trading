# Candidate-ranking tiebreak — WF-CV findings (Phase 2)

**Date:** 2026-06-29 · **Mechanism:** `Screener.config.candidate_ranking` (PR #1786, default-off)
**Framing:** faithfulness/realism fix (RS-for-selection is a Weinstein spine item), **not** a
return-seeking lever. Success bar = **do-no-harm + robustness**, NOT beat-baseline.

## Cell 1 — top-1000 PIT-1998, 2000-2026, 13 folds (2-yr non-overlapping)

Warehouse: `dev/data/snapshots/wfcv-top1000-1998` (514 of 1000 had bars + 13 context syms).

| Variant | Sharpe μ | Calmar μ | MaxDD% μ | Frontier | DSR | Return σ | Sharpe σ |
|---|---|---|---|---|---|---|---|
| baseline (Alphabetical, default) | 0.660 | 0.690 | 17.29 | yes | 0.983 | 15.50 | 0.462 |
| quality (RS→earliness→volume) | 0.666 | 0.669 | 15.17 | yes | 0.997 | 10.21 | 0.350 |

m-of-n gate (Sharpe, 7/13, Δ0.30): **FAIL** (6/13 wins; worst fold-010 Δ0.668) — but that is the
return-BEAT criterion; under the do-no-harm bar this is a **PASS**.

### Two findings
1. **Material backtest impact.** Per-fold returns differ substantially (fold-010 44.9 vs 14.8;
   fold-012 **-10.6 vs +8.9**). The alphabetical tiebreak **did** materially affect prior
   broad-universe backtest results — the corpus was NOT robust to it. (Corrects the earlier
   "magnitude bounded / rarely bites" prior — in a heavily over-subscribed broad universe it
   bites hard.)
2. **Do-no-harm, mildly risk-favorable.** Mean Sharpe tied (0.666 vs 0.660); quality has lower
   MaxDD (15.2 vs 17.3), much lower dispersion (Return σ 10.2 vs 15.5; Sharpe σ 0.35 vs 0.46),
   no negative-Sharpe fold (baseline has one), higher DSR. Both on the Pareto frontier; only
   Calmar marginally favors baseline.

### The WHY (transferable)
RS-led tiebreak **cannot add return** (you still can't pre-pick the fat-tail monster — consistent
with `edge_is_the_fat_tail`), but it **trims left-tail duds** among tied-score candidates →
**same mean, lower dispersion + drawdown**. The faithful fix is a **risk-reducer, not a
return-adder**. This refines the standing prior: entry-selection can't add return, but it CAN
reduce idiosyncratic risk/dispersion.

## Confirmation grid (breadth axis) — the decisive result

| Cell | base Sharpe | qual Sharpe | base Calmar | qual Calmar | base MaxDD | qual MaxDD | qual frontier? | qual DSR |
|---|---|---|---|---|---|---|---|---|
| top-500 (narrow, 327) | 0.667 | **0.636** | 0.850 | **0.676** | 14.79 | 15.17 | **NO (dominated)** | 0.997 |
| top-1000 (mid, 514) | 0.660 | 0.666 | 0.690 | 0.669 | 17.29 | 15.17 | yes | 0.997 |
| top-3000 (broad, 1065) | 0.735 | **0.667** | 0.861 | **0.761** | 15.72 | 15.66 | yes | 0.997 |

## Decision: REJECT for default-flip — keep `candidate_ranking=Alphabetical`

Quality (RS-primary tiebreak) does **NOT** clear do-no-harm across the breadth grid:
- **Lower Calmar in ALL 3 cells**; lower Sharpe in 2 of 3; **dominated in the narrow cell**.
- The only consistent gain is **lower dispersion** (higher DSR ~0.997, lower Sharpe σ) — insufficient
  to offset the return-adjusted degradation.
- The **top-1000 cell (the run that triggered the grid) was the favorable EXCEPTION**, not the rule —
  a textbook promotion-confirmation save (cf. early-admission 2026-05-30).

### Why (transferable)
RS-magnitude-**primary** picks the highest-RS = most **extended** (already-run-up) names among ties —
the very "don't buy extended Stage-2" setups the book warns against — mildly taxing the fat tail /
Calmar. Alphabetical, random w.r.t. RS, picks a more diversified cross-section that does as well or
better. Consistent with `project_edge_is_the_fat_tail`: ranking that chases strength can
**select-against** the fat tail.

### Distortion question — answered (reassuring)
The alphabetical tiebreak **does** materially reshuffle per-fold broad-universe results (10–30pp fold
deltas), **but it is NOT inferior** — marginally *better* on return-adjusted metrics. So the **prior
backtest corpus is not degraded by the alphabetical default; no re-pin needed.**

### Outcome
- `candidate_ranking` stays merged as a **default-off config axis** (#1786) — no revert.
- **No re-pin** (default unchanged). Ledger: `2026-06-29-candidate-ranking-tiebreak-grid` (verdict Reject).
- **Forward directive** (capitalize-findings): if revisited, test an **earliness-PRIMARY** ordering
  (prefer fresh breakouts over extended — the faithful reading of "don't buy extended"); the current
  Quality key relegates earliness behind RS, the likely cause of the underperformance.
