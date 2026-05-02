# M7 — Data Foundations + ML Tuning

Date: 2026-05-02 — replaces the original monolithic M7 ("Parameter Optimization") with a data-first decomposition.

Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M7.0–M7.2 (added 2026-05-02).

## Context

Original M7 was *"run grid search over config, pick best Sharpe."* Realistically, parameter optimization across 30+ years of data with proper survivorship-bias handling and ML techniques is gated by a data foundation that doesn't yet exist. This plan separates that foundation (M7.0) from the ML training (M7.1) and synthetic stress-testing (M7.2). The grid + Bayesian portion folds into M5.5.

Drift since 2026-04-01:
- All historical backtests use EODHD's *current* universe — survivorship-biased upward.
- No synthetic data exists. Strategy never tested on 1929-style 89% drawdown, 2000s lost decade, Japan 1990–2020 grind.
- ML stack: zero. Pure parametric strategy with hand-set weights.
- `optimal-strategy` track produces per-Friday counterfactual oracle — perfect supervision target for an eventual ML model, but currently unused for that purpose.

## M7.0 — Data foundations

### Goal

Three data tracks: survivorship-bias-aware historical universe, multi-market expansion, synthetic data generator.

### Track 1 — Norgate Data ingestion (US, 30+ years)

| Item | Value |
|---|---|
| Vendor | Norgate Data ($32–66/mo) |
| Coverage | US 1990-present; point-in-time S&P 500, Russell 1000, Russell 2000 membership; delisted symbols included |
| Why | EODHD's universe is *today's* universe — symbols that delisted before today are missing, biasing backtests upward. Norgate is purpose-built for backtesting with point-in-time index membership. |
| Storage | `dev/data/norgate/<sym>.csv` (gitignored — licensing) |
| Index membership | `dev/data/norgate/index_membership/<index>/<date>.csv` |

Files to touch:
- `analysis/data/sources/norgate/lib/norgate_client.{ml,mli}` (new)
- `analysis/data/sources/norgate/bin/fetch_universe.ml` (new)
- `analysis/data/sources/norgate/lib/index_membership.{ml,mli}` (new)
- `analysis/data/sources/norgate/test/test_round_trip.ml` (new)
- `.gitignore` — exclude `dev/data/norgate/`

Acceptance:
- One symbol's daily bars fetchable via Norgate path
- `index_membership("S&P 500", "2008-09-15")` returns the 500 symbols on Lehman day (cross-checked against external reference)
- Survivorship test: 2000-01–2003-12 backtest on dotcom-era S&P universe shows more failures than current EODHD baseline (qualitative)
- Licensing-respecting: data not checked into git, fetched on demand to local cache

### Track 2 — EODHD multi-market expansion

| Market | Symbol prefix | Why |
|---|---|---|
| LSE (London) | `.LSE` or `.L` | Different regime structure; Brexit, EU exposure |
| TSE (Tokyo) | `.T` | Lost-decade test bed (1990–2020) |
| ASX (Sydney) | `.AU` | Commodity-heavy regime |
| HKEX (Hong Kong) | `.HK` | Different macro driver (China policy) |
| TSX (Toronto) | `.TO` | Adjacent to US, energy-heavy |

Already paid in EODHD plan. Just wire the symbol resolution.

Files to touch:
- `analysis/data/sources/eodhd/lib/exchange_resolver.{ml,mli}` (extend to handle non-US prefixes)
- `analysis/data/sources/eodhd/test/test_multi_market.ml` (extend)

Acceptance:
- Fetch one symbol from each of the 5 markets, parse, validate OHLCV
- Calendar handling per-market (Tokyo half-days, ASX time zones)
- Currency tagging on bars (price + currency code)

### Track 3 — Synthetic data generator

The hard one. Goal: 30–80yr "plausible market" series that captures statistical attributes of real markets — vol clustering, fat tails, regime persistence — so ML training and stress-testing have data beyond what we observe.

#### Synth-v1 — Stationary block bootstrap (FIRST PR, ~250 LOC)

Resample variable-length blocks (geometric distribution of block lengths, mean ≈ 30 days) from a real source series (e.g. SPY 1993–2025). Preserves auto-correlation and vol clustering up to block-length scale.

Contract:
```ocaml
val generate_block_bootstrap :
  source:Daily_price.t list ->
  target_length_days:int ->
  mean_block_length:int ->
  seed:int ->
  Daily_price.t list
```

Files to touch:
- `analysis/data/synthetic/lib/block_bootstrap.{ml,mli}` (new)
- `analysis/data/synthetic/lib/source_loader.{ml,mli}` (new) — load SPY/index series
- `analysis/data/synthetic/test/test_block_bootstrap.ml` (new)
- `analysis/data/synthetic/bin/generate_synth.ml` (new) — CLI

Acceptance:
- 80-year synthetic SPY series generated from 32-year source
- Statistical match: skew/kurt/autocorr_lag1 within ±10% of source
- Deterministic given seed: same seed → identical output
- No look-ahead leakage: synthetic series doesn't contain real future data

#### Synth-v2 — HMM regime layer (FOLLOW-UP PR, ~800 LOC)

Hidden Markov Model with 3 regimes (Bull / Bear / Crisis). Fit transition matrix + per-regime GARCH(1,1) parameters from real history. Simulate by drawing regime path then volatility path within regime.

Captures regime persistence — the property block bootstrap misses (block boundaries break regime continuity).

Acceptance:
- HMM fit on 30y SPY history converges; transition probabilities reasonable
- 80yr simulation shows realistic regime persistence (avg bear-market length ≈ 15 months historical)
- Crisis regime (rare) appears ≈ 1–2× per 80yr run

#### Synth-v3 — Multi-symbol factor model (FOLLOW-UP PR, ~1000 LOC)

Single-factor model: each symbol = `β_i × market_return + ε_i` where `ε_i` has its own GARCH(1,1) idiosyncratic noise. Generate market via Synth-v2, then per-symbol via factor-loading distribution fitted on real cross-section.

Enables **full strategy backtest on synthetic universe** — the ultimate stress test.

Acceptance:
- 500-symbol × 80yr synthetic universe generated; cross-sectional correlation structure matches real (~0.5 avg pairwise on daily returns)
- Strategy can run on synthetic universe end-to-end; produces interpretable Sharpe/MaxDD
- Performance distribution across 100 synthetic universes shows expected variance

#### Synth-v4 — GARCH + jumps (OPTIONAL, ~600 LOC)

Bates jump-diffusion or Merton jumps to fatten tails beyond observed. Defer until v1–v3 prove insufficient for ML training.

#### Skip GAN / VAE

Modern deep-learning approaches (TimeGAN, VAE on returns) overkill at this stage. Add OCaml ML stack burden + black-box risk. Reconsider only if v1–v4 fail to surface a known stress-test failure mode.

## M7.1 — Train/test ML pipeline

### Goal

Replace hand-set scoring weights in `Screener.score` with a learned model. Walk-forward train/test, leakage-safe, OCaml-native first then FFI to xgboost/lightgbm.

### Features (from M5.2e per-trade context)

Per (symbol, Friday) input:
- Stage (one-hot: Stage1/2/3/4)
- 30-week MA slope (continuous)
- Current price / 30wk MA ratio (continuous)
- Volume ratio (4-week, continuous)
- RS vs SPY (52-week, continuous)
- Distance from breakout level (% above resistance)
- Sector strength score
- Macro regime (one-hot: Bullish/Bearish/Neutral)
- Days since last stage transition

### Label (from `optimal-strategy` oracle, MERGED 2026-04-29)

Was this symbol in the per-Friday counterfactual pick set? Binary 0/1. Or: what was the symbol's forward 4-week return? Continuous.

Two label variants → two model targets (classification + regression).

### Walk-forward protocol

| Window | Use |
|---|---|
| 1990–2017 | Train (post-Norgate, pre-COVID) |
| 2018–2022 | Validation (parameter selection) |
| 2023–2025 | Test (single-shot final eval) |
| Synth-v3 80yr × 100 runs | Stress (out-of-sample on synthetic, never tuned to it) |

Walk-forward: roll the train window in 1-year increments, retraining each year. No peeking at validation/test from training.

### Models (in order of complexity)

#### Baseline — Linear regression (~200 LOC, OCaml-native)

Simple gradient descent. Outputs interpretable coefficient per feature. Good baseline; if it doesn't beat hand-set weights, the feature set is wrong.

Files to touch:
- `trading/trading/backtest/ml/lib/linear_regression.{ml,mli}` (new)
- `trading/trading/backtest/ml/test/test_linear_regression.ml` (new)

#### Decision tree (~400 LOC, OCaml-native)

Captures non-linear interactions (e.g. "high RS only matters in Stage 2 with strong sector"). Greedy CART implementation, max-depth + min-leaf-size hyperparams.

Files to touch:
- `trading/trading/backtest/ml/lib/decision_tree.{ml,mli}` (new)
- `trading/trading/backtest/ml/test/test_decision_tree.ml` (new)

#### xgboost / lightgbm via FFI (~300 LOC binding, model is external)

OCaml C bindings to xgboost or lightgbm. Production-grade gradient boosting. Use only after baseline + tree show ML is the right approach.

Files to touch:
- `trading/trading/backtest/ml/lib/xgboost_bindings.{ml,mli}` (new) — `Ctypes`-based
- Build system: link xgboost as system dep; document in CLAUDE.md install steps

### Model serialization

- Linear regression: sexp `((feature_name "stage_2") (weight 0.421))`
- Decision tree: nested sexp of split points
- xgboost: native binary format + sexp metadata
- Loaded at backtest runtime by `Screener.score` (variant: `score_method = HandSet | LinearReg of model | DecisionTree of model | XGBoost of model`)

### Acceptance

- Linear regression beats hand-set weights on test-window Sharpe (2023–2025) by ≥5%
- Decision tree beats linear by ≥5% on test Sharpe
- xgboost beats decision tree by ≥3% (smaller incremental gain expected)
- All models pass walk-forward validation without leakage (asserted via test that randomizes labels and checks performance ≈ hand-set baseline)
- Inference cost: <100µs per (symbol, Friday) for production strategies

### No Python (still)

Per `.claude/rules/no-python.md`. Implementation in OCaml-native or via FFI to C libs. No `*.py` anywhere — `no_python_check.sh` is wired into `dune runtest`.

## M7.2 — Synthetic stress-test

### Goal

Run tuned configs on Synth-v3 universes. Reject configs that look great on real-history backtest but fail on synthetic stress (overfit to the observed regime).

### Protocol

For each candidate config (from M5.5 grid / Bayes / ML):
1. Generate 100 Synth-v3 universes (500 symbols × 80yr each, different seeds)
2. Run backtest on each
3. Compute distribution of Sharpe, MaxDD, CAGR, concavity_coef across 100 runs
4. Reject config if:
   - Median Sharpe < real-history Sharpe × 0.7 (significant degradation)
   - Worst-decile MaxDD > 50% (tail risk too high)
   - Median concavity_coef < 0 (strategy is concave / fragile)

### Output

`dev/stress-test/<config-name>/`:
- `synthetic_runs.csv` — one row per synth universe × all 35 metrics
- `distribution.md` — summary table + histograms (rendered text)
- `verdict.sexp` — pass/fail + reasons

### Acceptance

- Stress-test pipeline runs end-to-end on a known good config (current hand-set baseline)
- A deliberately overfit config (e.g. tuned to 2019-2023 sp500) fails stress
- Output interpretable; user can sanity-check why a config was rejected

## Files to touch (rollup)

| Phase | New module path |
|---|---|
| M7.0 Norgate | `analysis/data/sources/norgate/{lib,bin,test}` |
| M7.0 multi-market | (extend) `analysis/data/sources/eodhd/lib/exchange_resolver` |
| M7.0 Synth-v1 | `analysis/data/synthetic/{lib,bin,test}` (block bootstrap) |
| M7.0 Synth-v2 | (extend) `analysis/data/synthetic/lib/{hmm,garch}` |
| M7.0 Synth-v3 | (extend) `analysis/data/synthetic/lib/factor_model` |
| M7.1 ML | `trading/trading/backtest/ml/{lib,test}` (linear, tree, xgboost FFI) |
| M7.2 Stress | `trading/trading/backtest/stress/{lib,bin}` |

## Dependency graph

```
Norgate ──┬──→ Walk-forward ML training (M7.1)
          │
EODHD multi-market ──→ regime diversity for ML
          │
Synth-v1 ─→ Synth-v2 ─→ Synth-v3 ─→ Synthetic stress (M7.2)
                                            ↑
                                        M7.1 trained models
```

M7.0 Norgate + Synth-v1 land in parallel (independent surfaces). M7.1 starts after M7.0 Norgate (training data). M7.2 starts after M7.0 Synth-v3 (stress universe) AND M7.1 trained models (configs to stress).

## Risks / unknowns

- **Norgate licensing.** Restrictive on redistribution. Cache to `dev/data/norgate/` (gitignored). Document terms in `CLAUDE.md` install section.
- **Synth-v3 calibration is hard.** Cross-sectional factor model has many free parameters (per-symbol β distribution, idiosyncratic vol distribution, factor loadings). Allocate one full session to fitting.
- **OCaml ML library coverage thin.** `owl` is partial. Decision tree + xgboost FFI is realistic. Worst case: bespoke OCaml decision tree (~600 LOC).
- **Walk-forward leakage subtle.** `optimal-strategy` oracle uses post-hoc forward returns to identify "best picks" — labels are inherently future-aware. Training-time discipline: only use oracle labels from Fridays strictly before train-window cutoff.
- **xgboost FFI build cost.** System dep on xgboost C library. Document install for both maintainer + GHA runner.

## Acceptance for M7 as a whole

- M7.0 Norgate ingest: 30y survivorship-bias-aware US universe live; one full sp500-2000-2010 backtest run
- M7.0 Synth-v1: 80yr synthetic series passes statistical fidelity tests
- M7.0 Synth-v2 + v3 land in follow-up sessions
- M7.1 linear regression model trained, walk-forward validated, beats hand-set weights on test
- M7.1 decision tree improves on linear; xgboost optional
- M7.2 stress-test pipeline live; rejects overfit configs deterministically

## Out of scope

- 100-year NYSE data via CRSP (~$5k/yr) — defer until M7.1 proves scale matters
- Synth-v4 GARCH+jumps — defer until v3 fails
- GAN/VAE deep-learning synth — skip
- Reinforcement learning (PPO/A3C on strategy params) — different paradigm; defer indefinitely
- Real-time market microstructure modeling — we trade weekly; not needed
