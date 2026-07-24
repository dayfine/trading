# leverage-dawn — regime-conditional long margin (default-off)

Date: 2026-07-24. Owner: feat-backtest. Branch: `feat/leverage-dawn`.
Authority: `dev/notes/regime-dependency-evaluation-2026-07-24.md` §1/§3 +
`dev/notes/margin-m4-validation-2026-07-23.md` §Addendum (user green-lit
2026-07-24). Rules: `experiment-flag-discipline.md` R1/R2,
`weinstein-faithful-core.md` (deployment-intensity dial),
`promotion-confirmation.md` (post-merge, not this PR).

## One sentence

Run the long book levered (`initial_long_margin_req < 1.0`) ONLY while the
primary index's weekly MA has recently flipped up (young post-bear uptrend, a
lagging real-time signal); cash-account otherwise. Default-off; the surface
run happens post-merge.

## Why this is Weinstein-faithful (W1/W2)

Spine untouched: stage classification, Stage-2-only buys, breakout+volume
entry, stops, macro/sector gate all unchanged. This is a **deployment-intensity
dial** — how much buying power the long engine deploys — conditioned on a
trailing (never forward-looking) regime label. Weinstein deploys aggressively in
confirmed young uptrends and defensively otherwise; the "dawn" label is exactly
that classification off the weekly MA (the book's central instrument). Not
reversal timing: the signal is lagging (MA-flip age), so it errs late by
construction.

## Mechanism

1. **Dawn signal** (`Leverage_dawn`, pure): from the primary index's weekly MA
   values (offset 0 = current week, larger = older), dawn is TRUE iff the MA is
   currently *rising* (stage-classifier Rising: slope over `slope_lookback`
   weeks ≥ `slope_threshold`) AND the most recent negative→positive slope flip
   happened ≤ `dawn_max_ma_flip_age_weeks` weeks ago. Lookahead-free: consults
   only offsets ≥ 0. Reuses the Stage MA kernel via
   `Panel_callbacks.stage_callbacks_of_weekly_view` (no MA re-implementation).
2. **Effect**: when dawn TRUE, the effective `initial_long_margin_req` for that
   Friday's entry walk = `dawn_initial_long_margin_req`; else the base
   `initial_long_margin_req`. Threaded by swapping the field in the config
   passed to `Entry_walk.entries_from_candidates` — the ONLY functional reader
   of `initial_long_margin_req` (`Screening_notional.make_entry_walk_state`). All
   other margin mechanics (M1 rate, M2 maintenance/force-reduce, debit interest)
   unchanged; the mechanism only modulates the initial requirement by regime.

## Config fields (experiment-flag-discipline R1/R2)

- `dawn_leverage_enabled : bool [@sexp.default false]` — default-off; merging
  changes no backtest result (the wiring short-circuits to the unchanged config
  before any fetch when disabled).
- `dawn_initial_long_margin_req : float [@sexp.default 1.0]` — no-op default.
- `dawn_max_ma_flip_age_weeks : int [@sexp.default 78]` (~1.5y) — inert while
  disabled.

All three are real config fields → `Overlay_validator.apply_overrides` resolves
them (generic sexp deep-merge) → `Variant_matrix` axes. Validation
(`Leverage_dawn.validate`, called in `Weinstein_strategy.make`): when
`dawn_leverage_enabled = true`, require `margin_config.enabled` (dawn leverage
runs margin-armed by convention — memo §2 item 3) AND
`dawn_initial_long_margin_req ∈ (0, 1]`.

## Seam

`Weinstein_strategy_screening.screen_universe` (has `config`, `bar_reader`,
`current_date`, primary index symbol via `config.indices.primary`) computes the
dawn-effective config just before `Entry_walk.entries_from_candidates`. Deep
index history is fetched via `Bar_reader.weekly_view_for` (depth =
`ma_period + max_flip_age + slope_lookback + margin`) so the flip search sees
past the default 52-week `lookback_bars`. Fetch happens ONLY when enabled.

## Tests (`test_leverage_dawn.ml`)

- Flip-age on synthetic MA tapes: young flip → dawn; old flip → not; current
  slope negative → not; boundary at `max_flip_age_weeks`; data-boundary (can't
  confirm recency) → not.
- Default-off no-op: config with fields absent ≡ explicitly disabled (sexp
  round-trip) and `dawn_effective_config` returns the config unchanged.
- Effect: `effective_initial_long_margin_req` returns the dawn req when
  dawn+enabled, base otherwise.
- Overlay resolves all three fields (R2 axis expressibility).
- Validation raises on enabled + margin disarmed / req out of (0,1].

## WF spec (deliverable, NOT run in this PR)

`trading/test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp` mirrors
`margin-m4-leverage-BROAD-2000-2026.sexp` (same base scenario, rolling 13×730d,
gate `(Sharpe, m 7, n 13, worst_delta 0.0)`, same priced margin dials) with
`dawn_initial_long_margin_req ∈ {0.90, 0.85, 0.75}` ×
`dawn_max_ma_flip_age_weeks ∈ {52, 78}`, `dawn_leverage_enabled true`, shorts
off. fold-012 (2024-25) is the named falsifier (melt-up-lag dawn false-positive);
milder rungs {0.90,0.85} because 1.33×'s DD price exceeds any promotable bar.
