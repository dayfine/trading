# Cross-cycle Weinstein validation — M2 result + decision-tree resolution

Date: 2026-05-20.

Companion to `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md`.

## Headline

M2 (French 49-industry rotation, 1926-2025) **PASSES the decision-tree
gate**. Industry rotation profits in every regime tested. **M3
(synthesised per-stock) is therefore DEFERRED** per the plan's own
gating logic.

## What M2 shipped

PR #1211 (`feat/french-weinstein-rotation-m2`, merged 2026-05-20):

- Loader for Kenneth French 49-industry daily series (1926-07-01 to
  2026-04-30, 26,212 trading days).
- Stage classifier on 30-week MA (per book canonical).
- Cross-sectional ranking: 13-week relative-strength vs equal-weight
  industry composite.
- Strategy: long top-5 Stage-2 industries by RS, rebalance weekly,
  equal-weight.
- 5 OUnit2 tests + CLI binary at
  `trading/analysis/scripts/french_weinstein_rotation`.

## 100-year headline numbers

| Metric | Rotation | B&H VW market |
|---|---:|---:|
| CAGR | 13.55% | 9.83% |
| Sharpe (annual) | 0.81 | 0.45 |
| MaxDD | -64.4% | -85.0% |
| β vs market | 0.708 | 1.000 |

## Per-decade highlights

| Decade | Rotation CAGR | B&H CAGR | Rotation Sharpe | Note |
|---|---:|---:|---:|---|
| 1930s | 4.59% | 4.15% | 0.31 | Marginal edge in depression |
| 1940s | 7.06% | 11.59% | 0.51 | **Lags recovery** |
| 1970s | 12.96% | 5.93% | 0.99 | **Crushes stagflation** |
| 1980s | 16.42% | 17.05% | 1.08 | Tied with secular bull |
| 1990s | 13.92% | 16.85% | 0.94 | Tracks secular bull |
| 2000s | 5.94% | -0.95% | 0.42 | Beats lost decade |
| 2010s | 11.30% | 11.96% | 0.84 | Tracks B&H |

## Decision-tree application

Per `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md` §Decision tree:

```
M1 → framework profits in every regime (Shiller, MA=10mo: CAGR +1.59pp, Sharpe 2×, MaxDD -34 vs -85%)
  ↓
M2 → industry rotation works EVERYWHERE; doesn't collapse in any decade
  ↓
M3 → NOT load-bearing. Plan: "M3 becomes load-bearing IF industry
       rotation ALSO collapses in same regimes". Industry rotation
       did NOT collapse. M3 is deprioritized.
```

The only soft spot is the **1940s lag** (7% vs 11.6% B&H). Hypothesis:
post-WWII recovery favored sleeves Weinstein doesn't reward — broad
recovery rallies make Stage-2 RS-ranking less discriminating when most
sectors rally together. This is a known weakness of trend-following in
mean-reverting recovery regimes, not a framework collapse.

**1970s outperformance** (Sharpe 0.99 vs B&H 0.48) is the central
finding: cross-sectional rotation IS Weinstein's edge in
regime-volatile environments. The production strategy's 0.94 Sharpe
on 15y SP500 is consistent with this — it operates in a similar
regime-volatile post-GFC + 2022-hike environment.

## What this validates about production strategy (cell-E)

1. **Stage 2 + RS-ranking is the cross-sectional value-add**, not a
   2010-2026 artifact. Holds for 100y across 5 secular regimes.
2. **0.20 Sharpe gap** (M1 reduction 0.75 → cell-E production 0.94)
   is plausibly attributable to per-stock granularity + ETF universe
   diversification on top of the industry-rotation core.
3. **β = 0.708** indicates the framework provides ~30% beta-reduction
   for free. Drawdown protection (-64% vs B&H -85%) is meaningful.

## Open questions M2 did NOT answer

- Per-stock dispersion within an industry: industry-level rotation
  hides whether bottom-quartile stocks within a Stage-2 industry drag
  returns. Production cascade handles this per-symbol via the screener.
- Universe survivorship at the index level: French portfolios are
  reconstituted regularly; sp500-2010-2026 has its own survivor bias
  (already audited in #1180/#1191).
- Short-side performance pre-1980s: M2 long-only by construction.

These are M3 territory (synthesised per-stock) but per the decision
tree above, M3 isn't load-bearing for the *framework validation*
question. M3 may still be worth pursuing as **strategy refinement**
input (e.g. per-stock vs industry-level position sizing), but it's
no longer "blocking confidence in the strategy".

## Priority now

1. **V2 Bayesian sweep** (launched 2026-05-20 ~09:30 PT) — widens
   knob bounds per v1 REJECT verdict. Result expected ~10 hr from
   launch. Output at
   `dev/experiments/bayesian-production-sweep-2026-05-18/output-v2-parallel4/`.
2. **Hold-period probes P4/P5** — per-stage hold dispersion + composite
   scorer (#1196). P4 is data-heavy; P5 blocks on #1196 draft.
3. **Plan #1196 (composite scorer)** — load-bearing if V2 also rejects.

M3 stays parked. Revisit if V2 also rejects AND P5 composite scorer
fails to find a Pareto improvement.

## Cross-references

- `dev/plans/cross-cycle-weinstein-validation-2026-05-19.md` — original plan
- `dev/notes/bayesian-prod-v1-result-2026-05-20.md` — v1 sweep REJECT verdict
- `dev/reviews/feat-french-weinstein-rotation-m2.md` — M2 qc-behavioral
- `trading/analysis/scripts/french_weinstein_rotation/` — M2 implementation
