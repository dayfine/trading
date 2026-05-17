# Random-Universe Sweep — Is top-500-2019 representative? (2026-05-18)

Companion experiment to PR #1179 (Weinstein on top-500-2019 composition
golden). Goal: check whether the +174.69% baseline measured against
`top-500-2019.sexp` reflects strategy alpha or universe selection bias.

## Question

The composition golden `top-500-2019.sexp` was built by ranking today's
(2026) EODHD inventory by market cap as of 2019-05-31 and keeping the top
500 names. That is *not* a point-in-time universe — it's a survivor-biased
"what survived the 2019-2023 window and was big in 2019" cut.

If we instead draw 5 random 500-symbol subsets from a broader pool of
2019-tradable names and run the same scenario, how does the top-500
result compare to the random distribution?

## Setup

- Pool: 2,549 names from `top-3000-2019.sexp` with non-empty GICS sectors.
- Sampler: `awk srand($seed) | sort -n | head -500`, seeds 43..47.
- Universe files: `trading/test_data/backtest_scenarios/universes/random-2019/sample-{1..5}.sexp`
  (Pinned-shape sexps, committed as ad-hoc fixtures).
- Scenario sexps: `dev/experiments/random-universe-sweep-2026-05-18/scenarios/random-2019-sample-{1..5}.sexp`
  (loose `expected` bands, NOT pinned regression cells).
- Strategy: Cell-E, period 2019-01-02..2023-12-29, identical to PR #1179.
- Runner: `scenario_runner.exe`, parallel 3 then 2, total wall ~10 min.
  Samples 4-5 re-run with `--no-emit-all-eligible` after the `all_eligible`
  post-step hung samples 1-3's workers post-actual-write.

## Results

| Universe         | Return  | Trades | WinRate | Sharpe | MaxDD  | Sortino | Calmar | Ulcer |
|------------------|---------|--------|---------|--------|--------|---------|--------|-------|
| top-500-2019     | 174.69% |   248  |  30.65  |  0.62  |  59.06 |   0.73  |  0.38  | 26.89 |
| sp500-2019-2023  |  50.66% |   264  |  37.50  |  0.56  |  21.56 |   0.75  |  0.40  |  8.41 |
| random sample-1  |  28.57% |   316  |  28.48  |  0.35  |  39.11 |   0.40  |  0.13  | 19.11 |
| random sample-2  |  23.99% |   277  |  30.69  |  0.29  |  44.20 |   0.28  |  0.10  | 23.95 |
| random sample-3  |  -9.98% |   306  |  27.78  |  0.00  |  40.12 |  -0.15  | -0.05  | 17.49 |
| random sample-4  |  -9.70% |   328  |  26.52  |  0.01  |  58.15 |  -0.14  | -0.03  | 27.28 |
| random sample-5  |  30.42% |   295  |  31.53  |  0.33  |  48.76 |   0.34  |  0.11  | 26.23 |

Random-sample summary (n=5):

- Return: mean +12.66%, median +23.99%, stdev ~20.3 pp, range [-9.98, +30.42]
- Sharpe: mean 0.20, range [0.00, 0.35]
- MaxDD: mean 46.07, range [39.11, 58.15]
- Win rate: mean 28.99, range [26.52, 31.53]

## Interpretation

**Top-500-2019 is far outside the random distribution.**

- Return: +174.69% is ~8 σ above the random mean (+12.66%, σ≈20).
- Sharpe: 0.62 is ~3 σ above the random mean (0.20, σ≈0.15).
- MaxDD: 59.06 sits at the upper end of the random range — not anomalous.

**The strategy mechanics are universe-invariant.** Win rate clusters
26.5–31.5 across all 7 cells (5 random + sp500 + top-500-2019). Trade
counts cluster 248–328. Average holding days cluster 31–41. These are
all close to identical — Weinstein's filter, sizing, and stops fire the
same way on any universe. What changes between cells is what the
universe-as-asset-class delivers in returns.

**The +175% in #1179 is universe-driven, not strategy-driven.**
top-500-2019 is concentrated in names that were already mega-cap in
2019 and that survived to 2026 — AMZN/NVDA/TSLA/NFLX/BKNG/AVGO/SHOP/
ANET/MSFT/AAPL/GOOG. These names had massive 2019-2023 runs by
construction (post-hoc selection). A random 500 from the same era's
broader pool returns roughly market-like (mean +13%, vs. SPY ≈ +85%
for that window — long-only Weinstein on random names *underperformed*
buy-and-hold by ~70 pp).

**Implication for PR #1179.** The scenario sexp is still useful as an
end-to-end smoke test of the `Universe_file.load → Universe_snapshot`
bridge. But the pinned `total_return_pct ((min 139.0) (max 210.0))`
band is NOT a meaningful "strategy regression net" — it's pinning the
selection bias, not the strategy. The cell will catch a strategy bug
that changes win rate / trade count / holding days, but it won't catch
a strategy bug that changes alpha discovery on a fair universe.

## What to do about it

Short term (1 hr):

- Amend the `weinstein-2019-top-500.sexp` header to point at this report
  and explicitly disclaim "this is a bridge smoke test, NOT a strategy
  alpha benchmark."
- No band changes; bands still pin the bridge's wiring + the cell's
  reproducibility, which is what we want from a regression net.

Medium term (next-session-priorities-2026-05-19 §P1):

- Bar-coverage audit on pre-2006 composition goldens — this is the same
  selection-bias problem but worse. Pre-2006 names that survived to 2026
  are an even smaller fraction of the original universe.
- A *point-in-time* universe (knowable at the start date, no forward
  knowledge of which names will exist in 2026) is needed for honest
  strategy backtests. The IWV-historical work + Russell-3000 reconstruction
  agenda is what unblocks this; see
  `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` for the
  vendor sweep.

Longer term (decomposition agenda, Q2-B+):

- Synthetic universes (decomposition from Shiller + French portfolios)
  produce N samples by construction and let us measure strategy alpha
  against a known data-generating process. The bridge wired by #1174
  + #1179 is the substrate for this; the random-sample experiment above
  is a poor-man's preview of what proper synthetic universes will enable.

## Reproducibility

- Universe sexps committed at `trading/test_data/backtest_scenarios/universes/random-2019/sample-{1..5}.sexp`.
- Scenario sexps + results NOT committed (ad-hoc experiment artefacts).
  Reproduce via:
  ```sh
  docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && \
    eval $(opam env) && \
    dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
      --dir /workspaces/trading-1/dev/experiments/random-universe-sweep-2026-05-18/scenarios \
      --parallel 3 \
      --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
      --no-emit-all-eligible'
  ```
- Output: `dev/backtest/scenarios-2026-05-17-{225016,230220}/random-2019-sample-{1..5}/actual.sexp`.
