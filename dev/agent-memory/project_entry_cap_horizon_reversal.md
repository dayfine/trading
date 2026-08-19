---
name: project-entry-cap-horizon-reversal
description: "entry_extension_max_pct: the 1-year-fold surface said tighter dominates (1.0 won Calmar 13/16); 3-year folds reverse it — 1.0 falls below baseline on return/Sharpe/Calmar, every variant fails the gate, and the MaxDD advantage flips to the LOOSE caps. Fold length was the whole effect."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-19T22:49:27.027Z
---

**A one-year fold cannot price a no-fill.** The axis
(`entry_extension_max_pct` ∈ {1,2,5,10,15}, sp500 armed-StopLimit base, 2010-2026)
run at `test_days 365` and again at `test_days 1095`, everything else identical:

| cap | 1y Return μ | 3y Return μ | 1y Sharpe | 3y Sharpe | 1y Calmar wins | 3y Calmar wins |
|---|---:|---:|---:|---:|---:|---:|
| **1.0** | 8.68 (best) | 43.76 (**below baseline**) | 0.685 (best) | 0.961 | **13/16** | 2/5 |
| 2.0 = baseline | 7.87 | **45.49 (best)** | 0.613 | **0.998** | 0 | 0 |
| 5.0 | 6.44 | 37.52 (worst) | 0.514 | 0.837 | 4/16 | 1/5 |
| 10.0 | 6.74 | 39.62 | 0.557 | 0.908 | 3/16 | 2/5 |
| 15.0 (live) | 6.68 | 39.54 | 0.551 | 0.907 | 3/16 | 2/5 |

At 3 years **every variant FAILS the 3-of-5 Calmar gate**; baseline is beaten by
nothing. Null tripwire passed both times (2.0 ≡ baseline, bit-identical).

## The mechanism

A tighter cap's failure mode is a **no-fill**, which forgoes the stock's
*entire* subsequent run. A 1-year fold **truncates** that run at the boundary,
so the miss is understated while the avoided chase is counted in full. Extend
the fold and the forgone run lands inside the window — fold-004 (2022-2024)
costs `1.0` **−10.9pp** against baseline on one fold.

**The drawdown story inverts, it does not merely compress.** At 1y, tight won
MaxDD 15/16. At 3y the lowest mean MaxDD belongs to the **loose** caps
(12.60 vs baseline 14.42), driven by fold-002 (2016-2018) where they take
15.18% against baseline's 21.45%. Tight wins narrowly and often; loose wins
rarely and by a lot — a per-fold win count and a mean can disagree, and here
they do.

`5.0` is the worst value on **both** horizons. The response is not monotone in
the cap, so no single-point probe of this knob can be read as a trend.

## Transferable

- **A risk-metric-led win is a position-count signal until proven otherwise.**
  The 1y surface's strongest signal was MaxDD, which fits "takes fewer
  positions" rather than "picks better" — and the longer horizon confirmed it.
  Whenever a knob wins on MaxDD first, suspect exposure, not selection.
- **Fold length is an experiment-design axis, not a cost knob.** Any mechanism
  whose failure mode is *not entering* must be measured on folds long enough to
  contain what it forgoes. This is `project_edge_is_the_fat_tail` in the
  measurement layer: a horizon shorter than the tail cannot see the tail.
- The discrimination itself (fewer positions vs better picks) remains
  **unanswerable from any WF surface today** — `fold_actual` carries no trade
  count and no max single-trade P&L. Harness gap **#2412**.

## Standing state

`2.0` (81 of 89 committed sexp occurrences) survives both horizons. Live's
`15.0` is below it on return and Calmar at both. That points at moving **live
to 2.0** rather than re-pinning specs to 15.0 — a fidelity decision for the
user, not a promotion: one universe, one base, no confirmation grid.

Record: `dev/experiments/entry-cap-horizon-2026-08-19/`, PR #2413, issue #2404.
Related: [[project-honest-tradeable-baseline]] ("horizon-sweep before tail
verdicts" — this is that rule paying out), [[project-edge-is-the-fat-tail]],
[[feedback-run-the-null-control-first]].
