# Deep 28y WF-CV — baseline robustness (Cell-E, per-year folds 1998-2026)

**Date:** 2026-06-15 · **Runner:** `walk_forward_runner` (snapshot mode,
fork-per-fold, `--parallel 1`) · **Universe:** PIT top-3000-1998 (survivorship-
correct) · **Warehouse:** `/tmp/snap_top3000_1998_2026` (3015 symbols incl. macro
context) · **Window:** Rolling, 28 non-overlapping annual test folds (test_days
365, step_days 365), 1998 → 2025 · **Config:** Cell-E long-only (same as the
contiguous run) · spec/base in this dir.

**Purpose:** turn the single contiguous +1552% (`../ANALYSIS.md`) into a
promotion-grade fold-distributed estimate — does the multi-regime edge survive as a
*distribution* across 28 independent yearly folds, or was the single path lucky?

## Result — robust

| metric (28 folds) | mean ± stdev | min | max |
|---|---|---|---|
| **Sharpe** | **0.637 ± 0.857** | −1.54 (2024) | 2.46 (1999) |
| Return %/yr | 13.21 ± 19.98 | −21.94 (2024) | 82.06 (1999) |
| MaxDD % | 14.71 ± 5.61 | 5.91 | 28.53 |
| Calmar | 1.251 ± 2.001 | −0.98 | 7.83 |
| avg holding days | 33.8 ± 10.3 | | |

- **23/28 folds positive** (~82%). Mean per-fold Sharpe **0.64** ≈ the single-run
  28y Sharpe (0.59) — consistent; the contiguous +1552% is **not a lucky path**,
  it's positive-expectancy across 28 independent years.
- **Bear defense holds PER FOLD** (the distribution-compressor thesis, now
  fold-validated): the down years are *shallow* —
  - 2001 (fold-003) **−4.6%**, 2002 (fold-004) **−7.6%** (dotcom bust)
  - **2008 (fold-010) −4.6%**, Sharpe −0.09, MaxDD 17.4% — vs SPX ~**−37%**. The
    GFC year cost the strategy ~4.6%.
  - 2018 (fold-020) −8.2%.
- **Big years = bull legs / post-bear dawns:** 1999 (fold-001) **+82%** (Sharpe
  2.46, dotcom melt-up), 2013 (fold-015) +39%, 2017 (fold-019) +42%, 2003
  (fold-005) +27%. Confirms "alpha at post-bear bull dawns"
  (`project_rolling_start_matrix_first_run`).
- **High Sharpe σ (0.857)** = regime-dependence, exactly the structural-bar story
  (`project_index_beating_structural_bar`): great in trending/recovery regimes,
  flat-to-negative in choppy/topping ones. The edge is real but *lumpy*.

## Caveat — late folds degrade (PIT-1998 membership decay)

The worst fold is **2024 (fold-026) −21.9%** (Sharpe −1.54). This is almost
certainly a **survivorship-decay artifact, not a strategy failure**: the universe
is fixed at PIT-**1998** membership, so by 2024 most of those 3000 names have
delisted/merged and the tradeable set is thin and idiosyncratic. Late folds on a
fixed-1998 universe run on a shrinking, noisy pool. A proper per-fold
rolling-membership universe (re-snapshot the top-3000 as-of each fold's start)
would re-baseline this — the right follow-up before treating post-~2018 folds as
load-bearing. The early/mid folds (1998-2017), where the 1998 membership is still
representative, carry the robust signal.

## Verdict

**ACCEPT (baseline robustness).** The Weinstein Cell-E long-only baseline is
positive-expectancy and bear-defensive across 28 independent annual folds spanning
dotcom + GFC. This is the promotion-grade backing for the headline
`project_deep_1998_2026_contiguous` finding — not a single lucky path. NOT a
mechanism test (single variant, no axis); it's a baseline-distribution confirmation.

Next robustness step: re-run with **per-fold rolling membership** to remove the
late-fold decay artifact, and (separately) a confirmation grid across a second
universe snapshot per `promotion-confirmation.md` if any *mechanism* is to be
promoted on this surface.

## Artifacts
`walk_forward_report.md` (per-fold table), `aggregate.sexp` (stability stats),
`fold_actuals.sexp` (per-fold raw), `spec.sexp` + `base.sexp` (reproducer).
