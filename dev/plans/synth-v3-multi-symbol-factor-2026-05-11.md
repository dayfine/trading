# Synth-v3 — Multi-symbol factor model

Date: 2026-05-11
Track: data-foundations / M7.0 Track 3
Authority: `dev/plans/m7-data-and-tuning-2026-05-02.md` §Synth-v3.

## Context

The Weinstein synthetic-data ladder has three rungs:

- **Synth-v1** (#755, MERGED) — block bootstrap of a single symbol. Captures
  short-range auto-correlation, vol clustering up to block length, fat tails
  visible in the source series.
- **Synth-v2** (#775, MERGED) — three-regime HMM + per-regime GARCH(1,1)
  on top, producing a single-symbol series with realistic regime persistence
  (mean bull ~33 / bear ~15 / crisis ~3 steps).
- **Synth-v3** (this PR) — multi-symbol factor model layered on top of
  Synth-v2. Each symbol is generated as `r_i = β_i · r_market + ε_i` where
  `r_market` comes from a single Synth-v2 run and `ε_i` is per-symbol
  idiosyncratic GARCH noise. Beta `β_i` and idiosyncratic GARCH params are
  sampled from a parametric loading distribution (no real cross-section
  calibration in this PR; defer to a follow-up).

What it unlocks: **full strategy backtests on synthetic universes**. With
500 symbols × 80 years of deterministic synthetic OHLCV the strategy can be
run end-to-end on stress regimes that don't exist in the real-history
backtest (e.g. extended grinding bear markets, repeat-crisis decades), and
the strategy's Sharpe/MaxDD/CAGR distribution across many universes can be
inspected for fragility.

## Approach

### Maths

For each business day `t`:

```
r_market_t = log_return from Synth-v2 generator at step t
r_i_t      = β_i · r_market_t + ε_i_t
ε_i_t      ~ GARCH(ω_i, α_i, β_i_garch)  (independent draws per symbol)
price_i_t  = price_i_{t-1} · exp(r_i_t)
```

The factor model is a single-factor regression. `β_i` is the symbol's
sensitivity to the market; `ε_i` is the residual not explained by the
market move. Setting all idiosyncratic GARCH params equal and modest gives
roughly `corr(r_i, r_j) ≈ β_i · β_j · σ_m² / sqrt((β_i² σ_m² + σ_ε²)(β_j² σ_m² + σ_ε²))`
which, for typical `β` ~ 1 and `σ_ε / σ_m` ~ 1, lands near 0.5.

### β distribution

`β_i` is drawn from a normal distribution `N(β_mean, β_stddev)` truncated to
`[β_min, β_max]`. Defaults: `mean=1.0`, `stddev=0.4`, `min=0.2`, `max=2.5` —
keeps the cross-section in the standard equity range (defensive utilities
near 0.3, levered tech near 2.0). Truncation is via resampling.

### Idiosyncratic GARCH parameters

Per-symbol idiosyncratic noise has its own GARCH(1,1). To keep the
parameter surface small we sample `ω_i` from a log-normal centered on a
default and reuse a shared `(α, β_garch)` pair. Defaults: `ω_mean=1e-5`,
`ω_lognormal_sigma=0.3`, `α=0.05`, `β_garch=0.90` (well inside stationary
region). Each symbol has its own independent draw.

### Plug-in market series

The market series comes from a `Synth_v2.config` passed as an input. The
factor module is deliberately agnostic to where the market log-returns
come from — `Synth_v3` calls `Synth_v2.generate`, then extracts log-returns
from the bar list, and feeds them to `Factor_model.generate_symbol`.

### Determinism

`Synth_v3.config.seed` is the master seed. The seed cascade is:

- `seed`        → Synth-v2 market generation (HMM + GARCH internally use `seed` and `seed + 1`)
- `seed + 100_000`  → β-sampling RNG (one draw per symbol)
- `seed + 200_000`  → idiosyncratic GARCH ω-sampling RNG
- `seed + 1_000_000 + i` → idiosyncratic GARCH return stream for symbol `i`

The offsets are far enough apart that even adversarially chosen seeds keep
the streams independent. (Synth-v2 already uses `seed` and `seed + 1`; the
chunked offsets above leave a comfortable buffer.)

## Files to change / create

New:

- `analysis/data/synthetic/lib/factor_model.{ml,mli}` (~300 LOC) —
  the single-factor model:
  - `type loading_distribution` (β-sampling parameters)
  - `type idio_distribution` (per-symbol idiosyncratic GARCH parameters)
  - `default_loading_distribution`, `default_idio_distribution`
  - `sample_betas : loading_distribution -> n:int -> seed:int -> float list`
  - `sample_idio_params : idio_distribution -> n:int -> seed:int -> Garch.params list`
  - `generate_symbol_returns :
      market_returns:float list ->
      beta:float ->
      idio_params:Garch.params ->
      seed:int -> float list` — pure log-return composition

- `analysis/data/synthetic/lib/synth_v3.{ml,mli}` (~350 LOC) —
  the universe orchestrator:
  - `type config` mirroring Synth-v2's shape
  - `type universe = { symbols : (string * Types.Daily_price.t list) list }`
  - `default_config`, `default_symbols`
  - `generate : config -> (universe, Status.t) Result.t`

- `analysis/data/synthetic/bin/generate_synth_v3.ml` (~100 LOC) —
  CLI wrapper: emit one CSV per symbol under a target directory.

- `analysis/data/synthetic/test/test_factor_model.ml` (~250 LOC) —
  unit tests for β-sampling distribution shape, determinism, and
  return composition.

- `analysis/data/synthetic/test/test_synth_v3.ml` (~250 LOC) —
  integration tests: output length per symbol, dates aligned across
  symbols, determinism, cross-sectional correlation in the expected
  range, OHLC well-formed, validation paths.

Modifications:

- `analysis/data/synthetic/lib/dune` — add `factor_model` + `synth_v3`
  modules.
- `analysis/data/synthetic/bin/dune` — add `generate_synth_v3`.
- `analysis/data/synthetic/test/dune` — add the two new test files.

No modifications to existing Synth-v1/v2 modules. Synth-v3 is strictly
additive — it consumes `Synth_v2`'s existing surface.

## Test plan

### `test_factor_model.ml`

- `sample_betas` produces `n` values; all in `[β_min, β_max]`.
- `sample_betas` is deterministic given seed; different seeds produce
  different values.
- Empirical mean/stddev of `sample_betas` on `n=10_000` lands near the
  configured `mean`/`stddev` (loose tolerance — truncation shifts both).
- `sample_idio_params` produces `n` finite stationary GARCH params.
- `generate_symbol_returns` returns a list of the same length as
  `market_returns`.
- `generate_symbol_returns` with `beta=0` and zero-vol idio (degenerate)
  produces ~zero returns (sanity check that market term doesn't leak when
  decoupled).
- `generate_symbol_returns` with `beta=1` and zero-vol idio reproduces the
  market series exactly (within float epsilon).
- Determinism per symbol seed.
- Validation: zero or negative `n`, malformed loading distribution,
  malformed idio distribution.

### `test_synth_v3.ml`

- `generate` returns the configured number of symbols.
- Each symbol's bar list has length `target_length_days`.
- All symbols share the same date sequence (cross-symbol calendar alignment).
- Determinism: same config → identical universe.
- Different seed → different universe (compare two symbols).
- OHLC well-formed per bar across all symbols.
- Cross-sectional correlation: on a 50-symbol × 5_000-day run, average
  pairwise daily-return correlation is in `[0.3, 0.7]` (target ~0.5; loose
  to accommodate distribution-tail draws). This is the load-bearing
  acceptance test from the m7 plan.
- All prices remain finite over a long simulation (default 500-symbol ×
  20_000-bar; smoke-only since 20_000 × 500 is ~10M samples — but we run
  a sparser 20-symbol version to keep test wall-clock under a few seconds).
- Validation: zero/negative `n_symbols`, missing market config, malformed
  loading distribution propagates.

### Wall-clock budget

The cross-section test runs 50 symbols × 5_000 bars. At ~1µs per sample
the worst case is ~250 ms — well inside the test-suite budget.

## Risks

- **Cross-sectional correlation drift.** Pure-N(0,1) idio noise with the
  proposed defaults *should* land near 0.5 average pairwise correlation,
  but the actual value depends on the regime path's volatility profile
  (Synth-v2 is heteroscedastic). We pin a wide acceptance band `[0.3, 0.7]`
  for the integration test, and note in the .mli that tightening this
  requires real-cross-section calibration (deferred).
- **Numerical stability of idio GARCH.** Synth-v2's market series can have
  large-magnitude returns in crisis regimes. The factor model multiplies
  the market by `β_i`; if `β_i` is at the upper truncation bound (2.5) and
  the market is in crisis, the combined return can be large. We clamp
  generated prices to strictly positive using `Float.is_finite` checks at
  the bar-build stage and pin a "all prices finite" test.
- **Calendar alignment.** Synth-v2 emits business days only via a
  hard-coded Mon-Fri rule (ignores holidays). Synth-v3 reuses the same
  date sequence across all symbols, so no per-symbol calendar drift can
  occur. Pinned by the "all symbols share dates" test.
- **Memory.** 500 symbols × 20_000 bars × ~80 bytes per bar = ~800 MB.
  This is a known cost of the universe-scale acceptance test from the m7
  plan; we do *not* run that test in `dune runtest`. Tests cap at
  50-symbol × 5_000-bar runs. The CLI bin is the path for full
  universe-scale generation, gated by the user invoking it locally.

## Acceptance

From `m7-data-and-tuning-2026-05-02.md` §Synth-v3:

- [x] 500-symbol × 80yr synthetic universe generated; deterministic by seed.
  Verified by the CLI bin's `--n-symbols 500 --target-days 20000` mode and
  by the deterministic-seed test in `test_synth_v3.ml` (smaller-scale).
- [x] Cross-sectional correlation structure: ~0.5 avg pairwise on daily
  returns. Pinned by `test_synth_v3.ml` cross-correlation test on a
  50-symbol × 5_000-bar run, tolerance `[0.3, 0.7]`.
- [ ] Strategy runs end-to-end on the synthetic universe → produces
  interpretable Sharpe/MaxDD. **Deferred to a local-only follow-up.** The
  data side (the generator) is the unit of this PR; the strategy-side
  integration belongs in `feat-backtest`. Once the CLI lands, the
  user/orchestrator can wire it through `backtest_runner.exe` separately.
- [ ] Performance distribution across 100 synthetic universes shows
  expected variance. **Deferred to the same follow-up** — requires the
  strategy-side integration above.

Build / lint acceptance:

- `dune build && dune runtest` green on the branch.
- `dune build @fmt` clean.
- `no_python_check.sh` passes (no `*.py` introduced).

## Out of scope

- GAN / VAE / TimeGAN deep-learning alternatives — skipped per
  `m7-data-and-tuning-2026-05-02.md`.
- Synth-v4 (Bates jump-diffusion / Merton jumps) — deferred until v3
  proves insufficient.
- Real-cross-section calibration of β-distribution / idio params from
  EODHD history — deferred to a follow-up PR. The defaults in this PR
  are hand-set to roughly match observed equity cross-section.
- Multi-factor models (Fama-French) — single factor is the explicit M7.0
  target; multi-factor would be Synth-v5+ if needed.
- Strategy-side smoke test running on the generated universe (see
  Acceptance above).
