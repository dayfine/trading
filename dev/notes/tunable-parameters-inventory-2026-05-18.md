# Tunable Parameter Inventory — Weinstein Trading System (2026-05-18)

Comprehensive list of all `type config` records that drive the Weinstein
strategy, with current defaults and tuning history. "Tuned?" = has the field
ever appeared in a scenario sexp `config_overrides` block or in a
`dev/experiments/*` sweep.

## Top-level (`Weinstein_strategy_config.config`)

Source: `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `universe` | `string list` | (caller-supplied) | N/A | Not a tunable — symbol list |
| `indices.primary` | `string` | (caller-supplied) | No | Benchmark symbol (GSPCX) |
| `indices.global` | `(string * string) list` | `[]` | No | Non-US indices for macro consensus |
| `sector_etfs` | `(string * string) list` | `[]` | No | Sector ETF mapping |
| `initial_stop_buffer` | `float` | `1.02` | Yes (scenarios) | Multiplier from suggested_stop to installed_stop |
| `lookback_bars` | `int` | `52` | No | Weekly bars per stock window |
| `bar_history_max_lookback_days` | `int option` | `None` | No | Daily-bar cap for adapters |
| `skip_ad_breadth` | `bool` | `false` | No | Skip A-D breadth load |
| `skip_sector_etf_load` | `bool` | `false` | No | Skip sector ETF load |
| `universe_cap` | `int option` | `None` | Yes (scenarios) | Cap N symbols loaded |
| `full_compute_tail_days` | `int option` | `None` | Yes (scenarios) | Force full compute on last N days |
| `enable_short_side` | `bool` | `true` | Yes (scenarios) | Master short-side switch |
| `stop_update_cadence` | `Daily \| Weekly` | `Daily` | No | G11 trail-advance cadence |
| `enable_stage3_force_exit` | `bool` | `false` | Yes (scenarios) | Master switch for Stage-3 force exit |
| `stage3_reentry_cooldown_weeks` | `int` | `0` | No | Cascade re-admission cooldown |
| `enable_laggard_rotation` | `bool` | `false` | Yes (scenarios) | Master switch for laggard rotation |
| `laggard_reentry_cooldown_weeks` | `int` | `0` | No | Cascade re-admission cooldown |
| `enable_continuation_buys` | `bool` | `false` | Yes (continuation-tuning-2026-05-14) | Master switch for Ch.3 continuation buys |
| `enable_pi_filter` | `bool` | `false` | Yes (p5-pi-filter-validation-2026-05-14) | Point-in-time universe membership filter |

## Stage analysis (`Stage.config`)

Source: `trading/analysis/weinstein/stage/lib/stage.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `ma_period` | `int` | `30` | No | MA period in weeks (Weinstein book canon) |
| `ma_type` | `Sma \| Wma \| Ema` | `Wma` | No | MA flavor |
| `slope_threshold` | `float` | `0.005` | No | Min `\|slope_pct\|` for Rising/Declining |
| `slope_lookback` | `int` | `4` | Yes (scenarios) | Weeks back to measure MA slope |
| `confirm_weeks` | `int` | `6` | No | Weeks used for above/below-MA count |
| `late_stage2_decel` | `float` | `0.5` | No | MA slope-decel threshold for late Stage2 |
| `stage_method` | `MaSlope \| Segmentation` | `MaSlope` | Yes (segmentation-ab-2026-05-10) | MA direction method |

## Screening + ranking (`Screener.config`)

Source: `trading/analysis/weinstein/screener/lib/screener.mli`

### `scoring_weights` (nested under `weights`)
Source: `trading/analysis/weinstein/screener/lib/screener_scoring.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `w_stage2_breakout` | `int` | `30` | Yes (m5-4-e4-scoring-weight-sweep) | Stage1->2 breakout |
| `w_strong_volume` | `int` | `20` | Yes (m5-4-e4, grid-screening-weights) | Strong volume confirmation |
| `w_adequate_volume` | `int` | `10` | Yes (grid-screening-weights-2026-05-12) | Adequate volume |
| `w_positive_rs` | `int` | `20` | Yes (m5-4-e4, grid-screening-weights) | Positive RS trend |
| `w_bullish_rs_crossover` | `int` | `10` | Yes (m5-4-e4) | RS crossover bonus |
| `w_clean_resistance` | `int` | `15` | Yes (m5-4-e4) | Virgin/Clean overhead |
| `w_sector_strong` | `int` | `10` | Yes (m5-4-e4) | Strong sector bonus |
| `w_late_stage2_penalty` | `int` | `-15` | Yes (m5-4-e4) | Late Stage2 penalty (negative) |

### `grade_thresholds`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `a_plus` | `int` | `85` | No | A+ floor |
| `a` | `int` | `70` | No | A floor |
| `b` | `int` | `55` | No | B floor |
| `c` | `int` | `40` | No | C floor (default `min_grade`) |
| `d` | `int` | `25` | No | D floor |

### `candidate_params`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `entry_buffer_pct` | `float` | `0.005` | No | Fraction above breakout for entry |
| `initial_stop_pct` | `float` | `0.08` | Yes (scenarios — advisory only) | Advisory long stop fraction (G15 severed from installed stop) |
| `short_stop_pct` | `float` | `0.08` | No | Short initial stop fraction |
| `base_low_proxy_pct` | `float` | `0.15` | No | Fraction below MA for base-low proxy |
| `breakout_fallback_pct` | `float` | `0.05` | No | Fallback fraction above MA |
| `installed_stop_min_pct` | `float` | `0.0` | Yes (m5-5-installed-stop-min-pct-2026-05-13 — axis-1 winner) | Floor on installed-stop distance |

### Top-level screener config

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `min_grade` | `grade` | `C` | No | Min grade (overridden by `min_score_override`) |
| `min_score_override` | `int option` | `None` | Yes (m5-5-axis-3-min-score-override) | Numeric score floor |
| `max_score_override` | `int option` | `None` | Yes (entry-caps-2026-05-12) | Numeric score ceiling (per-quintile fix) |
| `volume_ratio_exclude_range` | `volume_ratio_band option` | `None` | Yes (entry-caps-2026-05-12) | Half-open volume-ratio exclusion band |
| `max_buy_candidates` | `int` | `20` | Yes (scenarios) | Cap on returned buy candidates |
| `max_short_candidates` | `int` | `10` | Yes (scenarios) | Cap on returned short candidates |
| `cascade_post_stop_cooldown_weeks` | `int` | `0` | No | Per-symbol post-stop-out cooldown |

## Macro (`Macro.config`)

Source: `trading/analysis/weinstein/macro/lib/macro.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `stage_config` | `Stage.config` | `Stage.default_config` | (see Stage) | Index stage classifier |
| `bullish_threshold` | `float` | `0.65` | No | confidence > this -> Bullish |
| `bearish_threshold` | `float` | `0.35` | No | confidence < this -> Bearish |

### `indicator_weights`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `w_index_stage` | `float` | `3.0` | No | Index stage weight |
| `w_ad_line` | `float` | `2.0` | No | A-D line divergence weight |
| `w_momentum_index` | `float` | `2.0` | No | A-D momentum MA weight |
| `w_nh_nl` | `float` | `1.5` | No | NH-NL proxy weight |
| `w_global` | `float` | `1.5` | No | Global consensus weight |

### `indicator_thresholds`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `ad_line_lookback` | `int` | `26` | No | A-D divergence lookback (~6 mo) |
| `momentum_period` | `int` | `200` | No | A-D momentum MA period |
| `nh_nl_lookback` | `int` | `13` | No | NH-NL proxy lookback (~3 mo) |
| `nh_nl_up_threshold` | `float` | `1.02` | No | NH-NL bullish ratio |
| `nh_nl_down_threshold` | `float` | `0.98` | No | NH-NL bearish ratio |
| `ad_min_bars` | `int` | `4` | No | Min bars for A-D |
| `nh_nl_min_bars` | `int` | `10` | No | Min bars for NH-NL |
| `global_consensus_threshold` | `float` | `0.6` | No | Fraction of markets for consensus |

## Portfolio risk (`Portfolio_risk.config`)

Source: `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `risk_per_trade_pct` | `float` | `0.01` | No | Fixed-risk per trade fraction |
| `max_positions` | `int` | `20` | No | Total open-position cap |
| `max_long_exposure_pct` | `float` | `0.90` | Yes (scenarios) | Long exposure cap |
| `max_short_exposure_pct` | `float` | `0.30` | No | Short exposure cap |
| `max_short_notional_fraction` | `float` | `0.30` | No | G15 short-notional cap at entry |
| `min_cash_pct` | `float` | `0.10` | No | DEPRECATED — sexp compat only |
| `max_position_pct_long` | `float` | `0.30` | Yes (max-position-sweep-2026-05-10) | Per-position long cap |
| `max_position_pct_short` | `float` | `0.20` | No | Per-position short cap |
| `max_position_pct` | `float` | `0.20` | Yes (scenarios — legacy) | DEPRECATED — fixture compat |
| `max_sector_concentration` | `int` | `5` | No | Max positions per sector |
| `max_sector_exposure_pct` | `float option` | `None` | No | P1 2026-05-15 opt-in dollar cap |
| `max_unknown_sector_positions` | `int` | `2` | No | Unknown-sector position cap |
| `big_winner_multiplier` | `float` | `1.5` | No | Size multiplier for high-conviction |

### `force_liquidation`
Source: `trading/trading/weinstein/portfolio_risk/lib/force_liquidation.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `max_long_unrealized_loss_fraction` | `float` | `0.25` | No | Per-position long loss trigger |
| `max_short_unrealized_loss_fraction` | `float` | `0.15` | No | Per-position short loss trigger |
| `min_portfolio_value_fraction_of_peak` | `float` | `0.40` | No | Portfolio-floor trigger |

## Stops (`Weinstein_stops.config`)

Source: `trading/trading/weinstein/stops/lib/stop_types.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `round_number_nudge` | `float` | `0.125` | No | Distance from round number to nudge |
| `min_correction_pct` | `float` | `0.08` | Yes (m5-5-min-correction-pct-2026-05-14) | Min pullback to qualify as correction |
| `tighten_on_flat_ma` | `bool` | `true` | No | Tighten when MA flattens |
| `ma_flat_threshold` | `float` | `0.002` | No | MA slope threshold for flat |
| `trailing_stop_buffer_pct` | `float` | `0.01` | Yes (m5-4-e3-stop-buffer-sweep, stop-buffer/) | Buffer below correction low |
| `tightened_stop_buffer_pct` | `float` | `0.005` | Yes (stop-buffer/) | Buffer in Tightened state |
| `support_floor_lookback_bars` | `int` | `90` | No | Daily-bar lookback for support floor |
| `max_stop_distance_pct` | `float` | `0.15` | Yes (scenarios) | G15 stop-too-wide gate |

## Detectors

### `Continuation.config`
Source: `trading/analysis/weinstein/continuation/lib/continuation.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `ma_slope_min` | `float` | `0.01` | Yes (continuation-tuning-2026-05-14) | Min MA slope for §3.(a) |
| `pullback_band.low` | `float` | `0.95` | Yes (continuation-tuning-2026-05-14) | Lower close/MA ratio |
| `pullback_band.high` | `float` | `1.05` | Yes (continuation-tuning-2026-05-14) | Upper close/MA ratio |
| `pullback_lookback_weeks` | `int` | `8` | Yes (continuation-tuning-2026-05-14) | Pullback scan window |
| `consolidation_range_pct` | `float` | `0.10` | Yes (continuation-tuning, continuation-combined-2026-05-14 — REJECTED on 16y) | Consolidation tightness |
| `consolidation_weeks` | `int` | `4` | Yes (continuation-tuning, continuation-combined-2026-05-14 — REJECTED on 16y) | Consolidation window length |

### `Laggard_rotation.config`
Source: `trading/analysis/weinstein/laggard_rotation/lib/laggard_rotation.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `hysteresis_weeks` | `int` | `4` | Yes (laggard-h-sweep-15y-2026-05-07, capital-recycling-combined) | Consecutive-negative-RS threshold |
| `rs_window_weeks` | `int` | `13` | Yes (scenarios) | RS rolling window |

### `Stage3_force_exit.config`
Source: `trading/analysis/weinstein/stage3_force_exit/lib/stage3_force_exit.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `hysteresis_weeks` | `int` | `2` | Yes (stage3-force-exit-impact-2026-05-06) | Stage-3 streak before force exit |

## Per-stock analysis sub-configs

### `Volume.config`
Source: `trading/analysis/weinstein/volume/lib/volume.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `lookback_bars` | `int` | `4` | No | Avg volume window pre-event |
| `strong_threshold` | `float` | `2.0` | No | Volume ratio for Strong |
| `adequate_threshold` | `float` | `1.5` | No | Volume ratio for Adequate |
| `pullback_contraction` | `float` | `0.25` | No | Pullback volume vs breakout volume |

### `Rs.config`
Source: `trading/analysis/weinstein/rs/lib/rs.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `rs_ma_period` | `int` | `52` | No | Mansfield zero-line MA period |
| `trend_lookback` | `int` | `4` | No | Bars for RS trend direction |
| `flat_threshold` | `float` | `0.98` | No | RS flat-vs-declining threshold |

### `Resistance.config` (also `Support.config` — same record)
Source: `trading/analysis/weinstein/resistance/lib/resistance.mli`, `support/lib/support.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `chart_lookback_bars` | `int` | `130` | No | Bars analyzed for zone density (~2.5y) |
| `virgin_lookback_bars` | `int` | `520` | No | Virgin-territory lookback (~10y) |
| `congestion_band_pct` | `float` | `0.05` | No | Price-band width fraction |
| `heavy_resistance_bars` | `int` | `8` | No | Min bars for Heavy_resistance |
| `moderate_resistance_bars` | `int` | `3` | No | Min bars for Moderate_resistance |

### `Sector.config`
Source: `trading/analysis/weinstein/sector/lib/sector.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `stage_config` | `Stage.config` | `Stage.default_config` | (see Stage) | Sector index stage |
| `rs_config` | `Rs.config` | `Rs.default_config` | (see RS) | Sector RS vs market |
| `strong_confidence` | `float` | `0.6` | No | Min confidence for Strong rating |
| `weak_confidence` | `float` | `0.4` | No | Max confidence for Weak rating |
| `stage_weight` | `float` | `0.40` | No | Stage weight in composite |
| `rs_weight` | `float` | `0.35` | No | RS weight in composite |
| `constituent_weight` | `float` | `0.25` | No | Constituent-breadth weight |

### `Stock_analysis.config`
Source: `trading/analysis/weinstein/stock_analysis/lib/stock_analysis.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `stage` | `Stage.config` | `Stage.default_config` | (see Stage) | |
| `rs` | `Rs.config` | `Rs.default_config` | (see RS) | |
| `volume` | `Volume.config` | `Volume.default_config` | (see Volume) | |
| `resistance` | `Resistance.config` | `Resistance.default_config` | (see Resistance) | |
| `breakout_event_lookback` | `int` | `8` | No | Peak-volume scan window |
| `base_lookback_weeks` | `int` | `52` | No | Prior-base-high search window |
| `base_end_offset_weeks` | `int` | `8` | No | Recent bars excluded from base search |
| `continuation` | `Continuation.config option` | `None` | Yes (continuation-tuning) | Continuation detector (opt-in) |

## Adjacent

### `Margin_config.t`
Source: `trading/trading/portfolio/lib/margin_config.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `enabled` | `bool` | `false` | No | Master switch for margin accounting |
| `initial_margin_pct` | `float` | `0.50` | No | Reg-T initial margin (50% extra) |
| `maintenance_margin_pct` | `float` | `0.25` | No | Maintenance equity threshold |
| `short_borrow_fee_annual_pct` | `float` | `0.005` | No | Annualized borrow fee (50 bps) |

### `Stale_hold.config`
Source: `trading/trading/simulation/lib/stale_hold.mli`

| Field | Type | Default | Tuned? | Notes |
|---|---|---|---|---|
| `enabled` | `bool` | `true` | No | Detector master switch |
| `stale_after_days` | `int` | `5` | No | Calendar-day threshold for staleness |

### `Cost_model.t`
Source: `trading/trading/backtest/cost_model/lib/cost_model.mli`

Presets: `zero` (all 0), `retail_default` (5 bps spread), `institutional_default` ($0.005/sh, 2 bps, 1 bps/%ADV).

| Field | Type | Default (`zero`) | Tuned? | Notes |
|---|---|---|---|---|
| `per_trade_commission` | `float` | `0.0` | No | Flat $ per trade |
| `per_share_commission` | `float` | `0.0` | No | $ per share |
| `bid_ask_spread_bps` | `float` | `0.0` | Yes (m5-6-slippage-sweep-2026-05-14) | One-side spread bps |
| `market_impact_bps_per_pct_adv` | `float` | `0.0` | No | Impact bps per 1% ADV (not auto-wired) |

## Tuning history quick-reference

Active sweep experiments by axis (folders under `dev/experiments/`):

- **Stops** — m5-4-e3-stop-buffer-sweep, m5-5-installed-stop-min-pct-2026-05-13 (axis-1 winner `0.08`), m5-5-installed-stop-min-pct-validation-2026-05-14, m5-5-min-correction-pct-2026-05-14, stop-buffer/
- **Scoring** — m5-4-e4-scoring-weight-sweep, grid-screening-weights-2026-05-12, m5-5-axis-3-min-score-override-2026-05-14, entry-caps-2026-05-12 (max_score_override + volume_ratio_exclude_range)
- **Sizing** — max-position-sweep-2026-05-10
- **Detectors** — stage3-force-exit-impact-2026-05-06, laggard-h-sweep-15y-2026-05-07, capital-recycling-combined-2026-05-07, continuation-tuning-2026-05-14, continuation-combined-2026-05-14 (REJECTED on 16y), continuation-buys-impact-2026-05-14
- **Stage method** — segmentation-ab-2026-05-10, rolling-5y-segmentation-ab-2026-05-11
- **Cell-E baseline runs** — cell-e-15y-2026-05-07, cell-e-generalization-2026-05-08, cell-e-walk-forward-2026-05-08, rolling-5y-cell-e-0.14-exp0.70-2026-05-11
- **Cross-axis** — m5-5-axis-1x2-cross-sweep-2026-05-14, m5-5-axis-2-validation-2026-05-14, m5-5-e5-q5-soft-penalty-2026-05-14, bayesian-multi-param-2026-05-17
- **Costs / slippage** — m5-6-slippage-sweep-2026-05-14
- **Holding period** — holding-period-sweep-2026-05-12
- **PI filter** — p5-pi-filter-validation-2026-05-14, p5-pi-filter-16y-validation-2026-05-14
- **Per-Friday windows** — h1-h2-diagnostic-2026-05-12, golden-rerun-2026-05-12, state-pollution-2026-05-10

## Untouched parameters (No across all evidence)

These have never appeared in any scenario `config_overrides` block or
`dev/experiments/*` sweep — high-priority candidates for the next BO sweep
if their semantics suggest they should matter:

- **Stage** — `ma_period`, `ma_type`, `slope_threshold`, `confirm_weeks`, `late_stage2_decel`
- **Macro** — all `bullish/bearish_threshold`, all `indicator_weights`, all `indicator_thresholds`
- **Portfolio risk** — `risk_per_trade_pct`, `max_positions`, `max_short_exposure_pct`, `max_short_notional_fraction`, `max_position_pct_short`, `max_sector_concentration`, `max_sector_exposure_pct`, `max_unknown_sector_positions`, `big_winner_multiplier`
- **Force-liquidation** — all three thresholds
- **Stops** — `round_number_nudge`, `tighten_on_flat_ma`, `ma_flat_threshold`, `support_floor_lookback_bars`
- **Volume** — all four (lookback, strong/adequate thresholds, pullback_contraction)
- **RS** — all three (`rs_ma_period`, `trend_lookback`, `flat_threshold`)
- **Resistance/Support** — all five
- **Sector** — `strong/weak_confidence`, all three weights
- **Stock_analysis** — `breakout_event_lookback`, `base_lookback_weeks`, `base_end_offset_weeks`
- **Screener** — `entry_buffer_pct`, `short_stop_pct`, `base_low_proxy_pct`, `breakout_fallback_pct`, `cascade_post_stop_cooldown_weeks`, `grade_thresholds.*`
- **Macro/sector composites** — sector composite weights, macro confidence thresholds
- **Margin** — all four (Phase-2 opt-in, never enabled in goldens)
- **Stale-hold** — both
- **Cost model** — `per_trade_commission`, `per_share_commission`, `market_impact_bps_per_pct_adv`
