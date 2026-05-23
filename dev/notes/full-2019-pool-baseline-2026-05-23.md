# Full-pool 2019 baseline — Cell-E on top-3000-2019 (2026-05-23)

Settles the methodology question raised in
`dev/notes/random-universe-sweep-2026-05-18.md`: instead of n=5 uniform
500-of-2549 random subsets, run Cell-E **once** on the full
top-3000-2019 composition pool. This is the correct control — one
deterministic full-pool result vs. a small-N random distribution that
has its own sampling noise.

## Scenario

- **Fixture:** `trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-full-pool.sexp`
- **Universe:** `top-3000-2019.sexp` — 3000-symbol composition snapshot
  built from EODHD market-cap inventory as of 2019-05-31, delisted-aware
  (rebuilt via #1184-#1187). Same fixture family as `top-500-2019.sexp`
  (which is `top-3000-2019.sexp` sliced to the top 500 by market cap).
- **Period:** 2019-01-02 → 2023-12-29 (identical to comparison cells).
- **Strategy:** Cell-E config (`max_position_pct_long=0.14`,
  `max_long_exposure_pct=0.70`, `min_cash_pct=0.30`,
  `enable_stage3_force_exit=true` with `hysteresis_weeks=1`,
  `enable_laggard_rotation=true` with `hysteresis_weeks=2`).
- **Cost model:** None (matches `weinstein-2019-top-500.sexp` —
  comparable to its +78.34% measurement). NOTE: `sp500-2019-2023.sexp`
  carries a `retail_default` overlay but the overlay is byte-equal to
  None under current wiring (only `apply_per_trade_commission` is
  hooked), so the comparison is fair.
- **Tag:** `;; perf-tier: research` — explicitly NOT a tier-3 CI
  regression cell. Will not be picked up by
  `golden-runs-custom-universe.yml`'s postsubmit (which greps
  `^;; perf-tier: 3`).

## Result

Measured 2026-05-23 on the full top-3000-2019 composition pool:

| Metric                    | Full-pool 2019 |
|---------------------------|----------------|
| total_return_pct          | **+32.37%**    |
| total_trades              |  278           |
| win_rate                  |  33.09%        |
| sharpe_ratio              |  0.37          |
| max_drawdown_pct          | 32.48%         |
| avg_holding_days          | 32.22          |
| open_positions_value      | $1,308,524     |
| unrealized_pnl            | $321,183       |
| sortino_ratio_annualized  |  0.43          |
| calmar_ratio              |  0.18          |
| ulcer_index               | 14.71          |
| CAGR                      |  5.78%         |
| profit_factor             |  0.97          |
| volatility_annualized_pct | 18.83          |
| wall_seconds              | 2,158 (~36 min) |

`force_liquidations_count = 0`, `crashed = false`. Final NAV $1.324M
(from $1.000M starting cash).

## Comparison vs. existing baselines

All four runs use **identical** Cell-E config, **identical**
2019-01-02 → 2023-12-29 window. Only the universe differs.

| Universe                    | Size  | Return  | Trades | WinRate | Sharpe | MaxDD  | Sortino | Calmar | Ulcer | Source / Note |
|-----------------------------|-------|---------|--------|---------|--------|--------|---------|--------|-------|---------------|
| **Full pool (top-3000)**    | 3000  | **+32.37%** |  278  |  33.09  |  0.37  |  32.48 |   0.43  |  0.18  | 14.71 | THIS run, 2026-05-23 |
| top-500-2019 (composition)  |  500  | +78.34% |  263   |  31.94  |  0.69  |  42.17 |   0.96  |  0.29  | 19.01 | `weinstein-2019-top-500.sexp`, re-pin 2026-05-18 (delisted-aware) |
| sp500-2019-2023             |  491  | +50.66% |  264   |  37.50  |  0.56  |  21.56 |   0.75  |  0.40  |  8.41 | `goldens-sp500/sp500-2019-2023.sexp`, post-#1052 |
| Random sample mean (n=5)    |  500  | +12.66% |  ~304  |  29.0   |  0.20  |  46.1  |   0.15  |  0.07  | 22.8  | `random-universe-sweep-2026-05-18.md`, σ≈20pp |

## Interpretation

### Does the top-500 +78% still look anomalous vs. full-pool?

**Yes, but the gap is much smaller than the random-sample analysis
made it appear.** The full-pool baseline lands at +32.37% — roughly
midway between the random-sample mean (+12.66%) and the survivor-
biased top-500 (+78.34%):

- top-500 minus full-pool: **+46 pp** (+78.34 − +32.37). top-500
  outperforms by ~1.4×.
- Full-pool minus random-mean: **+19.7 pp**. The full-pool itself
  outperforms an average uniform 500-of-2549 sample by ~2.6×, just
  because more breadth = more chances to catch the winners that drive
  the bull market.
- top-500 minus random-mean: **+65.7 pp**. The "top-500 = monster
  outperformance vs. random" claim is real but conflates two effects:
  selection bias (the names top-500 over-weights) *and* universe
  breadth advantage (size-weighted vs. uniform-weighted).

The full-pool result decomposes the gap. **About 30% of the
+65.7 pp top-500-vs-random gap is "size-weighted universe is
inherently richer than uniform-weighted"; the remaining 70% is the
true selection-bias premium from concentrating in 2019's mega-caps
that survived to 2026.**

### Why does Sharpe drop in the full-pool run?

Full-pool Sharpe (0.37) is *worse* than both top-500 (0.69) and the
~491-symbol SP500 (0.56) — and only modestly better than the random-
sample mean (0.20). Three things are happening:

1. **Risk/return ratio degrades when widening the universe**. Adding
   the 500-3000-th symbols brings in noisier, less-liquid names
   whose breakouts are more likely to fail and stop out for losses.
   MaxDD is 32% — closer to top-500's 42% than SP500's 22%, despite
   total trades dropping (278 vs. 263 for top-500 and 264 for SP500).
2. **Trade count is *lower*, not higher**, than the 500-symbol cells.
   This is counterintuitive — 6× more symbols should yield ~6× more
   eligible breakouts. The cap on simultaneously-open positions
   (`max_position_pct_long=0.14` ⇒ 7.1 max) is the binding constraint,
   not the universe. Cell-E is *already* operating at its position-
   budget ceiling on the 500-symbol cell; widening the pool just
   means the strategy gets to pick more selectively, but it picks
   *worse* on average because the wider pool dilutes the cap-weighted
   "obvious winner" candidates with marginal names.
3. **Win rate is flat across all cells** (29-33%) — confirming the
   universe-invariance of strategy mechanics observed in
   `random-universe-sweep-2026-05-18.md`. Returns differ because what
   the universe *contains* differs; the strategy's selection and exit
   behavior does not.

### Updated survivor-bias narrative

The previous narrative (per `random-universe-sweep-2026-05-18.md`)
was: "top-500's +175% sat 8σ above the random mean of +13%, indicating
extreme selection bias." After the 2026-05-18 delisted-aware rebuild,
top-500 dropped to +78%, narrowing the gap to ~3σ.

**This full-pool baseline replaces the random-sample reference point
entirely.** A full-pool run is the correct null — it eliminates the
sampling-noise dimension that confounded the n=5 random study. The
new comparison is simpler:

- Full-pool (the correct null for a 2019-snapshot universe) = +32.37%
- top-500 (cap-weighted slice of full-pool) = +78.34%
- Delta: **+46 pp (1.4×)** is the selection-bias premium of
  cap-weighting the universe.

The narrative becomes: "Cap-weighted slices of the same delisted-
aware pool earn roughly 1.4× the full-pool return because
cap-weighting concentrates the universe in 2019's mega-caps
(AMZN/NVDA/TSLA/etc.) that disproportionately drove the 2019-2023
bull market." This is a real, mechanical bias, but it's not the
extreme 8σ outlier the n=5 random study suggested.

### Recommendation on random-universe-sweep doc

**Supersede, do not delete.** `random-universe-sweep-2026-05-18.md`
captures useful context (the n=5 random samples are still data
points, the prior narrative arc is part of the record), but its
headline claim — "+174.69% is 8σ above random mean" — is doubly
stale: the +174.69% number got re-measured to +78.34%, and the
random-sample distribution is the wrong null. The doc should be
updated with a header pointer to **this** baseline doc and an
acknowledgment that the full-pool run replaces the random-sample
reference. The body can remain as-is (historical record).

The `top-500-2019.sexp` header docstring's "WARNING — this is a
BRIDGE SMOKE TEST, NOT a strategy alpha benchmark" claim is still
correct — top-500 is still survivor-biased relative to a true
point-in-time universe (which is what the Phase 1.4 IWV scrape work
unblocks). But the body of that docstring still cites the obsolete
+174% number and the 8σ random framing; both should be refreshed.

## Drift discovery — top-500 docstring header is stale

The header docstring on `weinstein-2019-top-500.sexp` still narrates
the original +174.69% result + 8σ-above-random claim from the
2026-05-17 first-measurement. The actual pin was moved to ±15-20%
around +78.34% via the 2026-05-18 delisted-aware rebuild (#1184-#1187),
and the docstring records both the new and prior measurements. But
the "survivor-bias narrative" prose still treats +174.69% as the
load-bearing number. After this baseline lands, that prose should be
refreshed to:

1. Cite the new full-pool measurement (+32.37%) as the principal
   comparison — full-pool dilutes the top-500's selection bias by
   construction.
2. Drop the "8σ above random sample mean" framing — random samples
   have wide sampling noise (σ≈20pp on n=5) and the full-pool result
   is a single deterministic number, not a distribution.
3. Keep the bridge-smoke-test framing (top-500 is still useful for
   pinning the `Universe_file → Universe_snapshot` wiring even though
   its return reflects selection bias, not strategy alpha).

This refresh is OUT OF SCOPE for this PR — kept as a follow-up so the
research baseline lands cleanly without modifying the regression cell
in the same PR.

## Reproducibility

The scenario fixture is committed at
`trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-full-pool.sexp`.

Reproduce via:

```sh
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && \
  eval $(opam env) && \
  mkdir -p /tmp/full-pool-run-dir && \
  cp trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-full-pool.sexp /tmp/full-pool-run-dir/ && \
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /tmp/full-pool-run-dir \
    --parallel 1 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
    --no-emit-all-eligible'
```

Output: `dev/backtest/scenarios-<timestamp>/weinstein-2019-full-pool-composition/{actual.sexp,trades.csv,equity_curve.csv,summary.sexp}`.
The output dir is gitignored (`dev/backtest/scenarios-*/`) — only the
scenario sexp + this note are committed.

Wall time was 2,158s (~36 min) on the 2026-05-23 container; expect
2-4× on CI runners.
