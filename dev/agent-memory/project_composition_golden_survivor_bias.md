---
name: Composition goldens are coverage-clean but survivor-biased
description: top-500-2019 returns +175% (~8σ above random 500-from-top-3000 mean +13%). Strategy mechanics universe-invariant; returns dominated by post-hoc selection.
type: project
originSessionId: a9aafef3-9945-4a99-9675-c3109601e13e
---
# Composition Golden Survivor Bias

Empirical finding from PRs #1179/#1180/#1181 (2026-05-17/18 session).

## Headline

`top-500-2019.sexp` (and all sibling composition goldens) is a *forward-known-winner* selection:
- Inventory built from 2026 EODHD coverage
- Symbols ranked by 2019-05-31 market cap AMONG SURVIVORS to 2026
- Any name that delisted/M&A'd between 2019 and 2026 is invisible

Running Cell-E Weinstein over `top-500-2019` returns **+174.69%** (2019-2023 window).
Running the same strategy over **5 random 500-symbol subsets of `top-3000-2019.sexp`** returns:
- Range: -9.98% .. +30.42%
- Mean: +12.66%, σ ≈ 20pp
- top-500-2019's +175% is ~8σ above the random mean

## Why: Strategy is universe-invariant

Across all 7 cells (5 random + sp500-2019-2023 + top-500-2019):
- Win rate clusters 26.5–31.5%
- Trade count clusters 248–328
- Holding days cluster 31–41

Weinstein's filter/sizing/stops fire identically; only the universe's intrinsic up-side changes.

## Why: Coverage is NOT the problem

Bar-coverage audit (PR #1181, `dev/reports/composition-golden-bar-coverage-2026-05-18.md`):
- top-500 / top-1000 goldens: 99.6-100.3% mean coverage; 0-0.7% sub-threshold
- top-3000 goldens: 96.4-100.0% mean coverage; 1.6-8.3% sub-threshold
- All goldens pass the priorities-doc "flag at >10%" criterion

Coverage is clean *by construction*: names without bars couldn't be ranked into the top-N in the first place. The universe doesn't shrink — it never included the missing names.

## How to apply

**When pinning baselines on composition goldens:**
- Bands are valid as bridge-wiring + mechanical-regression nets (catch trade-count / win-rate / DD bugs)
- Bands are NOT valid as strategy-alpha claims (selection bias inflates returns)
- The `weinstein-2019-top-500.sexp` header (post-#1180) explicitly disclaims this

**When evaluating "Weinstein has alpha":**
- Composition-golden cells alone are insufficient evidence
- Need point-in-time universes (knowable at start date, no forward knowledge)
- That's unblocked by the IWV / Russell-3000 historical-membership scrape — see `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`

**When sampling experiments:**
- Random subsets from `top-3000-{year}.sexp` are a poor-man's preview of what proper synthetic universes (Q2-B decomposition path) will enable. The bridge wired by #1174 + #1179 + #1180 is the substrate.

## Reproducibility

- Random universe sexps committed: `trading/test_data/backtest_scenarios/universes/random-2019/sample-{1..5}.sexp` (seeded awk-srand 43..47)
- Scenario sexps + outputs are ad-hoc, not committed; rerun via the command in `dev/notes/random-universe-sweep-2026-05-18.md` §Reproducibility.

## Files

- `dev/notes/random-universe-sweep-2026-05-18.md` — full random-sample writeup
- `dev/reports/composition-golden-bar-coverage-2026-05-18.md` — coverage audit
- `trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-top-500.sexp` — header carries the bridge-smoke-test warning
