# Weinstein Trading System — Detailed Design

This document covers the detailed roadmap and component designs for building the Weinstein trading system on top of the existing `dayfine/trading` codebase.

**Existing codebase provides:** orders, portfolio, engine, simulation loop, strategy interface, position state machine, EODHD client, CSV storage, EMA, daily→weekly conversion, trend regression.

**We build:** Weinstein-specific analysis, screening, strategy, stop rules, weekly simulation, config, reporting, and tuning.

---

# Part 1: Roadmap

## Phase overview

```
P1  Indicators        ░░░░    New MA types, breadth indicators
P2  Stage classifier  ░░░░░░  The heart — stage state machine
P3  Stock analysis    ░░░░    RS, volume, resistance, breakout detection
P4  Macro + sector    ░░░░░░  Market regime, sector health
P5  Screener          ░░░░    Cascade filter + scoring
P6  Weinstein stops   ░░░░    Trailing stop state machine
P7  Strategy module   ░░░░░░  Plugs into existing STRATEGY interface
P8  Weekly sim mode   ░░░░    Extend simulator for weekly cadence
P9  Config + CLI      ░░░░    Unified config, command-line tools
P10 Reporter          ░░░░    Weekly report generation, alerts
P11 Tuner             ░░░░░░  Parameter search over backtests
```

## Milestones

Milestones mark the points where you gain new capability — not just "code compiles" but "I can do something I couldn't before."

### Milestone 1: Single-Stock Analyst (after P1 + P2 + P3)

**You can:** Run `weinstein analyze AAPL.US` and get back a complete analysis of any individual stock — its current stage, whether it's near a breakout, volume confirmation quality, relative strength vs the market, overhead resistance grade, and suggested stop level.

**What this enables:**
- Validate the system's analysis against your own chart reading
- Spot-check any ticker on demand
- Start building intuition for how the classifier behaves
- Compare the system's stage calls against the book's examples

**What it doesn't do yet:** No macro context, no sector filtering, no screening the full universe.

---

### Milestone 2: Market Context (after P4)

**You can:** Run `weinstein macro` to see the current market regime (bullish/bearish/neutral with indicator breakdown) and `weinstein sector` to see which sectors are strong, weak, or transitioning.

**What this enables:**
- Know whether to be aggressive (buying) or defensive (raising cash, looking for shorts)
- Identify which sectors to focus on before looking at individual stocks
- Get the "forest" view that gates everything else

**Combined with M1:** You can now manually apply the full Weinstein three-layer filter — check macro, check sector, then analyze individual stocks from favorable sectors. It's manual, but the analysis is automated.

---

### Milestone 3: Automated Screening (after P5)

**You can:** Run `weinstein scan` and get a ranked list of buy and short candidates across the entire US equity universe, graded A+ through F, with suggested entries, stops, and risk percentages.

**What this enables:**
- Your Saturday morning workflow begins. Run the scan, review candidates, decide which to act on.
- Stop manually scanning hundreds of charts — the system surfaces the best setups
- Each candidate comes with a rationale explaining why it scored the way it did

**What it doesn't do yet:** No position tracking, no trailing stop management, no portfolio awareness. You're using it as a screener, not as a portfolio manager.

---

### Milestone 4: Position Management (after P6 + partial P9 for CLI)

**You can:** Log your trades with `weinstein enter AAPL --price 152 --shares 200 --stop 137`, and the system tracks your positions, computes trailing stops, monitors for stop hits, and alerts you when something needs attention.

**What this enables:**
- The full weekly cycle: scan → enter positions → system manages stops → alerts on exits
- Position sizing: the system tells you how many shares to buy given your risk budget
- Portfolio awareness: exposure tracking, sector concentration warnings
- No more manually tracking where your stops should be — the system implements Weinstein's trailing stop state machine mechanically

**Combined with M3:** The screener now knows what you hold and won't suggest buying something you already own. It factors your exposure limits into candidate rankings.

---

### Milestone 5: Historical Backtesting (after P7 + P8)

**You can:** Run `weinstein backtest --from 2015-01-01 --to 2025-12-31` and get a full performance report — equity curve, Sharpe ratio, max drawdown, win rate, trade log.

**What this enables:**
- Validate the system before risking real money (or validate it alongside real trading)
- Test the strategy across different market regimes (bull, bear, sideways)
- Compare different time periods to understand when Weinstein's approach works best
- Build confidence (or identify weaknesses) in the approach

**Combined with M4:** You can now run the system in parallel — live trading with real positions while backtesting parameter variations on the side.

---

### Milestone 6: Full Automated Cycle (after P9 + P10)

**You can:** Set up a cron job and the system runs automatically: weekly scan on Friday close, daily stop monitoring, alerts sent to you, weekly report generated and waiting for you Saturday morning.

**What this enables:**
- Zero effort during the week unless an alert fires
- The Saturday review session is structured: open the report, check alerts, review candidates, decide, place orders
- Trade history accumulates, giving you a record to review and learn from

**This is the system described in the design doc §3 — the target operating state.**

---

### Milestone 7: Parameter Optimization (after P11)

**You can:** Run `weinstein tune --param analysis.ma_period:20-40 --param screening.volume_breakout_ratio:1.5-3.0 --objective sharpe` and the system searches the config space, running hundreds of backtests, and reports the best configuration with sensitivity analysis.

**What this enables:**
- Empirically optimize scoring weights, MA periods, stop thresholds
- Understand which parameters matter most (sensitivity) and which don't
- Detect overfitting risk before applying new parameters to live trading
- Experiment with strategy variations (e.g. "what if I use 20-week MA instead of 30?")

---

### Milestone summary

```
M1  Single-Stock Analyst    P1+P2+P3    Analyze any ticker on demand
M2  Market Context          +P4         Macro regime + sector health
M3  Automated Screening     +P5         Weekly scan → ranked candidates
M4  Position Management     +P6+CLI     Full portfolio tracking + stops
M5  Historical Backtesting  +P7+P8      Backtest over any date range
M6  Full Automated Cycle    +P9+P10     Cron → report → review → trade
M7  Parameter Optimization  +P11        Tune config against history
```

Each milestone is independently valuable. You could stop at M3 and have a useful screener. You could stop at M4 and have a complete manual trading system. M5+ adds simulation and optimization on top.

---

## Phase details

### P1: Indicators (foundation, no dependencies on other new code)

**New modules:**
```
analysis/technical/indicators/sma/lib/sma.{ml,mli}          # Simple moving average
analysis/technical/indicators/weighted_ma/lib/wma.{ml,mli}   # Weighted (Mansfield-style)
analysis/technical/indicators/breadth/lib/breadth.{ml,mli}   # A-D line, momentum index, NH-NL
```

**Interface pattern (matching existing EMA):**
```ocaml
(* sma.mli *)
val calculate_sma : Indicator_types.indicator_value list -> int -> Indicator_types.indicator_value list

(* wma.mli *)
val calculate_wma : Indicator_types.indicator_value list -> int -> Indicator_types.indicator_value list
```

**Tests:** Verify against known values. SMA of [1,2,3,4,5] period 3 = [2,3,4]. WMA should weight recent values higher.

**Done when:** `dune build && dune runtest` passes, indicators produce correct values for test vectors.

### P2: Stage Classifier (core domain logic)

**New modules:**
```
analysis/weinstein/stage/lib/stage.{ml,mli}
analysis/weinstein/stage/test/test_stage.ml
```

**Depends on:** P1 (MA indicators), existing trend module.

**Done when:** Given historical bars for any ticker, correctly classifies into Stage 1–4 and detects transitions.

### P3: Individual Stock Analysis

**New modules:**
```
analysis/weinstein/rs/lib/rs.{ml,mli}                        # Relative strength
analysis/weinstein/volume/lib/volume.{ml,mli}                 # Volume confirmation
analysis/weinstein/resistance/lib/resistance.{ml,mli}         # Overhead resistance mapping
analysis/weinstein/breakout/lib/breakout.{ml,mli}             # Breakout/breakdown detection
analysis/weinstein/stock_analysis/lib/stock_analysis.{ml,mli} # Combines all into stock_analysis type
```

**Depends on:** P1, P2.

**Done when:** Can analyze any single ticker and produce a complete `stock_analysis` with stage, RS, breakout signal, overhead grade, volume confirmation.

### P4: Macro + Sector Analysis

**New modules:**
```
analysis/weinstein/macro/lib/macro.{ml,mli}     # Market regime from DJI stage, A-D, MI, etc.
analysis/weinstein/sector/lib/sector.{ml,mli}   # Sector stage, RS, constituent analysis
```

**Depends on:** P1, P2, P3 (uses stage classifier and RS on indices/sectors).

**Extends:** EODHD client — add index data fetching, fundamentals for sector metadata.

**Done when:** Can determine market regime (bullish/bearish/neutral) and rate sectors.

### P5: Screener

**New modules:**
```
analysis/weinstein/screener/lib/screener.{ml,mli}
analysis/weinstein/screener/lib/scoring.{ml,mli}
```

**Depends on:** P2, P3, P4, config.

**Done when:** Given macro_state + sectors + stock analyses → produces ranked buy/short candidates with grades.

### P6: Weinstein Trailing Stops

**New modules:**
```
analysis/weinstein/stops/lib/weinstein_stops.{ml,mli}
```

**Depends on:** P2 (stage), P1 (MA).

**Integrates with:** Existing `Position.risk_params` and `UpdateRiskParams` transition.

**Done when:** Given a position + weekly bar history, correctly implements the full trailing stop state machine (initial → trailing below MA → tightened in Stage 3 → exit).

### P7: Weinstein Strategy Module

**New modules:**
```
trading/trading/strategy/lib/weinstein_strategy.{ml,mli}
```

**Implements:** Existing `STRATEGY` module type.

**Depends on:** P2–P6 (all analysis), existing strategy interface.

**Done when:** Can be plugged into the existing simulator and produce correct transitions.

### P8: Weekly Simulation Mode

**Extends:** `trading/trading/simulation/lib/simulator.{ml,mli}`

**Changes:** Add ability to step weekly instead of daily. Strategy runs on Friday close. Orders execute the following week.

**Done when:** Can backtest Weinstein strategy over multi-year historical data at weekly cadence.

### P9: Config + CLI

**New modules:**
```
analysis/weinstein/config/lib/config.{ml,mli}
analysis/weinstein/cli/bin/*.ml
```

**Done when:** All parameters configurable from a single file. CLI tools for scan, analyze, query.

### P10: Reporter

**New modules:**
```
analysis/weinstein/reporter/lib/reporter.{ml,mli}
```

**Done when:** Produces the weekly report (JSON + human-readable) answering all questions from §2.3 of the system design.

### P11: Tuner

**New modules:**
```
analysis/weinstein/tuner/lib/tuner.{ml,mli}
```

**Done when:** Can search config space, run N backtests, produce best config + sensitivity report.

---

# Part 2: Screener / Analysis Component Design

## Overview

The screener/analysis subsystem is the Weinstein-specific intelligence layer. It takes market data and produces actionable analysis: market regime, sector health, individual stock scores, and ranked candidates.

## Component structure

```
analysis/weinstein/
├── config/          # Shared config type
├── types/           # Shared domain types (stage, grade, etc.)
├── stage/           # Stage classifier
├── rs/              # Relative strength
├── volume/          # Volume confirmation
├── resistance/      # Overhead resistance
├── breakout/        # Breakout/breakdown detection
├── stock_analysis/  # Per-stock composite analysis
├── macro/           # Market regime
├── sector/          # Sector health
├── screener/        # Cascade filter + scoring
└── stops/           # Weinstein trailing stop rules
```

## Shared types

```ocaml
(* analysis/weinstein/types/lib/weinstein_types.mli *)

(** Moving average slope classification *)
type ma_slope = Rising | Flat | Declining [@@deriving show, eq]

(** Stage with metadata *)
type stage =
  | Stage1 of { weeks_in_base : int }
  | Stage2 of { weeks_advancing : int; late : bool }
  | Stage3 of { weeks_topping : int }
  | Stage4 of { weeks_declining : int }
[@@deriving show, eq]

(** Overhead resistance quality *)
type overhead_quality =
  | Virgin_territory    (** No historical trading above this level *)
  | Clean               (** Minimal resistance on chart *)
  | Moderate_resistance (** Some supply overhead *)
  | Heavy_resistance    (** Dense trading zone above *)
[@@deriving show, eq]

(** Volume confirmation on breakout *)
type volume_confirmation =
  | Strong of float     (** Ratio ≥ 3× avg *)
  | Adequate of float   (** Ratio ≥ 2× avg but < 3× *)
  | Weak of float       (** Ratio < 2× avg *)
[@@deriving show, eq]

(** Relative strength trend *)
type rs_trend =
  | Bullish_crossover     (** Crossing zero line upward *)
  | Positive_rising
  | Positive_flat
  | Negative_improving
  | Negative_declining
  | Bearish_crossover     (** Crossing zero line downward *)
[@@deriving show, eq]

(** Market trend *)
type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq]

(** Candidate grade *)
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, compare]
```

## Stage classifier

**Input:** Weekly bar series (52+ weeks), config.

**Output:** `stage` with transition detection.

**Algorithm outline:**
```
1. Compute 30-week MA (SMA or weighted, per config)
2. Compute MA slope over config.ma_slope_lookback weeks
3. Classify slope as Rising/Flat/Declining using config.ma_slope_threshold
4. Count recent weeks where close > MA vs close < MA
5. Determine stage:
   - MA declining + price consistently below → Stage4
   - MA rising + price consistently above → Stage2
   - MA flat + oscillating: use prior stage context
     - After Stage4/Stage1 → Stage1
     - After Stage2/Stage3 → Stage3
6. Detect late Stage 2: MA rising but angle decelerating, stock extended
```

**Interface:**
```ocaml
(* stage.mli *)
type stage_input = {
  bars : Types.Daily_price.t list;   (** Weekly bars, chronological *)
  prior_stage : Weinstein_types.stage option;
}

type stage_result = {
  current_stage : Weinstein_types.stage;
  ma_value : float;
  ma_slope : Weinstein_types.ma_slope;
  ma_slope_pct : float;
  transition : (Weinstein_types.stage * Weinstein_types.stage) option;
    (** (from, to) if stage changed *)
}

val classify :
  config:Config.analysis_config ->
  stage_input ->
  stage_result
```

**Key design decision:** The classifier is a pure function. It doesn't maintain state between calls. The caller provides `prior_stage` if available (from the previous week's run or from persistent state). This makes it testable and usable in both live and simulation modes.

## Stock analysis

**Composes** stage, RS, volume, resistance, and breakout into a single per-ticker result.

```ocaml
(* stock_analysis.mli *)
type t = {
  ticker : string;
  stage : Stage.stage_result;
  rs : Relative_strength.t;
  breakout : Breakout.signal option;
  overhead : Weinstein_types.overhead_quality;
  support_level : float;
  pre_breakout_advance_pct : float option;
  is_big_winner_candidate : bool;
}

val analyze :
  config:Config.analysis_config ->
  bars:Types.Daily_price.t list ->
  index_bars:Types.Daily_price.t list ->
  prior_stage:Weinstein_types.stage option ->
  t
```

## Macro analyzer

```ocaml
(* macro.mli *)
type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  detail : string;
}

type t = {
  index_stage : Stage.stage_result;
  indicators : indicator_reading list;
  trend : Weinstein_types.market_trend;
  confidence : float;   (** 0.0–1.0, fraction of indicators agreeing *)
  shift : bool;         (** Did regime change since last run? *)
  rationale : string list;
}

val analyze :
  config:Config.macro_config ->
  index_bars:Types.Daily_price.t list ->      (** DJI or SPX weekly *)
  ad_data:(Core.Date.t * int * int) list ->   (** date, advances, declines *)
  global_indices:(string * Types.Daily_price.t list) list ->
  prior:t option ->
  t
```

## Sector analyzer

```ocaml
(* sector.mli *)
type t = {
  name : string;
  stage : Stage.stage_result;
  rs : Relative_strength.t;
  rating : [ `Strong | `Neutral | `Weak ];
  bullish_pct : float;
  bearish_pct : float;
}

val analyze_sector :
  config:Config.analysis_config ->
  sector_name:string ->
  constituent_bars:(string * Types.Daily_price.t list) list ->
  index_bars:Types.Daily_price.t list ->
  t
```

## Screener

The screener is where macro, sector, and stock analysis converge. It implements the cascade filter.

```ocaml
(* screener.mli *)
type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : Sector.t;
  grade : Weinstein_types.grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}

type t = {
  buy_candidates : scored_candidate list;
  short_candidates : scored_candidate list;
  watchlist : (string * string) list;  (** ticker, reason *)
}

val screen :
  config:Config.t ->
  macro:Macro.t ->
  sectors:Sector.t list ->
  stocks:Stock_analysis.t list ->
  portfolio:Portfolio_state.t ->  (** to know current holdings *)
  t
```

**Cascade logic:**
1. If `macro.trend = Bearish` → suppress buy candidates, only emit shorts
2. For each stock: look up its sector. If sector is `Weak` → exclude from buys
3. Score surviving candidates using config weights
4. Filter to `min_grade` threshold
5. Sort by grade descending
6. For buys: exclude tickers already held long
7. For shorts: exclude tickers already held short

---

# Part 3: Portfolio / Orders Component Design

## Overview

The portfolio/orders subsystem is **largely built**. Our job is to extend it with Weinstein-specific position management, risk sizing, and portfolio-level awareness.

## What exists (no changes needed)

- `trading/orders/` — Order creation, validation, lifecycle. Complete.
- `trading/portfolio/` — Position tracking, cash, P&L, trade application. Complete.
- `trading/engine/` — Simulated broker, price paths, order execution. Complete.
- `trading/strategy/lib/position.ml` — Position state machine. Complete.

## What we extend

### Position risk params → Weinstein stop metadata

The existing `risk_params` has `stop_loss_price`, `take_profit_price`, `max_hold_days`. For Weinstein we need richer stop state:

```ocaml
(* Option A: Extend risk_params *)
type risk_params = {
  stop_loss_price : float option;
  take_profit_price : float option;
  max_hold_days : int option;
  (* NEW: Weinstein-specific *)
  stop_state : Weinstein_stops.stop_state option;
  last_correction_low : float option;
  last_rally_peak : float option;
}

(* Option B: Separate Weinstein state alongside position — preferred *)
(* Keep Position.t unchanged; manage Weinstein state in strategy *)
```

**Recommendation: Option B.** Don't modify the existing Position module. The Weinstein strategy maintains its own stop state per position, stored alongside the position map in the strategy's closure or as additional state passed through the simulation. This keeps the existing modules untouched.

### Weinstein stop state

```ocaml
(* weinstein_stops.mli *)
type stop_state =
  | Initial of { stop_level : float; support_floor : float }
  | Trailing of {
      stop_level : float;
      last_correction_low : float;
      last_rally_peak : float;
      ma_at_last_adjustment : float;
    }
  | Tightened of {
      stop_level : float;
      last_correction_low : float;
    }
[@@deriving show, eq]

type stop_event =
  | Stop_hit of float       (** Price that triggered the stop *)
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening      (** MA flattened, entering Stage 3 risk zone *)
[@@deriving show, eq]

val compute_initial_stop :
  entry_price:float ->
  support_floor:float ->
  config:Config.stops_config ->
  stop_state

val update_stop :
  state:stop_state ->
  current_bar:Types.Daily_price.t ->
  ma_value:float ->
  ma_slope:Weinstein_types.ma_slope ->
  stage:Weinstein_types.stage ->
  config:Config.stops_config ->
  stop_state * stop_event list
```

### Portfolio-level risk management (NEW)

```ocaml
(* portfolio_risk.mli *)
type portfolio_state = {
  total_value : float;
  cash : float;
  cash_pct : float;
  long_exposure : float;
  long_exposure_pct : float;
  short_exposure : float;
  short_exposure_pct : float;
  position_count : int;
  sector_concentrations : (string * int) list;  (** sector, count *)
}

type sizing_result = {
  shares : int;
  position_value : float;
  position_pct : float;
  risk_amount : float;
}

val compute_state :
  portfolio:Trading_portfolio.Portfolio.t ->
  market_prices:(string * float) list ->
  portfolio_state

val compute_position_size :
  portfolio_value:float ->
  risk_per_trade_pct:float ->
  entry_price:float ->
  stop_price:float ->
  sizing_result

val check_limits :
  state:portfolio_state ->
  proposed:sizing_result ->
  sector:string ->
  config:Config.portfolio_config ->
  (unit, string list) Result.t
  (** Returns Ok if within limits, Error with list of violated constraints *)
```

### Order generation from screener candidates

The existing `order_generator.ml` converts `Position.transition` → orders. We extend this pattern:

```ocaml
(* weinstein_order_generator.mli *)
type suggested_order = {
  ticker : string;
  side : Trading_base.Types.side;
  order_type : Trading_base.Types.order_type;
  quantity : int;
  rationale : string;
  candidate_grade : Weinstein_types.grade;
}

val generate_entry_orders :
  candidates:Screener.scored_candidate list ->
  portfolio_state:Portfolio_risk.portfolio_state ->
  config:Config.portfolio_config ->
  suggested_order list

val generate_stop_orders :
  positions:(string * Weinstein_stops.stop_state) list ->
  suggested_order list

val generate_exit_orders :
  stop_events:(string * Weinstein_stops.stop_event) list ->
  suggested_order list
```

---

# Part 4: Simulation / Tuning Component Design

## Overview

The simulation infrastructure is **largely built**. We extend it for weekly cadence and add a tuning layer on top.

## What exists (core simulation loop)

The simulator already:
1. Steps through dates day by day
2. Updates market data in the engine
3. Processes pending orders → fills → trades
4. Applies trades to portfolio
5. Calls strategy `on_market_close`
6. Applies strategy transitions → new orders
7. Collects step results and metrics

## Extension 1: Weekly simulation cadence

The existing simulator steps daily. Weinstein's system operates weekly. Two approaches:

**Approach A: Weekly step.** The simulator advances one week per step. Strategy sees Friday's close. Orders execute the following Monday-Friday against daily price paths.

**Approach B: Daily step, weekly strategy call.** The simulator still steps daily (for accurate order execution against intraday paths), but the strategy is only called on Fridays. Orders submitted Friday night execute during the following week.

**Recommendation: Approach B.** It preserves the existing daily execution model (which gives realistic fills) while gating the strategy to weekly decision-making. Minimal changes to the simulator.

**Implementation:** Add a `cadence` field to the simulator config. When `cadence = Weekly`, the simulator checks `Time_series.is_period_end ~cadence:Weekly date` before calling the strategy. On non-Friday days, the step only processes pending orders — no new strategy signals.

```ocaml
(* Changes to simulator config *)
type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : commission_config;
  strategy_cadence : Types.Cadence.t;  (* NEW: Daily | Weekly | Monthly *)
}

(* In simulator.step: *)
let should_call_strategy t =
  match t.config.strategy_cadence with
  | Daily -> true
  | Weekly -> Time_series.is_period_end ~cadence:Weekly t.current_date
  | Monthly -> Time_series.is_period_end ~cadence:Monthly t.current_date
```

## Extension 2: Weinstein strategy in simulation

The Weinstein strategy module (P7) implements `STRATEGY`. When plugged into the simulator:

- `on_market_close` is called on Fridays (weekly cadence)
- It receives market data via `get_price` and `get_indicator`
- It looks at current `positions` map
- It returns transitions:
  - `CreateEntering` for new buy/short candidates that passed the screener
  - `TriggerExit` for positions where stops were hit
  - `UpdateRiskParams` for positions where stops were adjusted

The strategy needs access to the full analysis pipeline (macro, sector, stock, screener). These are pure functions that run inside `on_market_close`, using the market data accessors.

**Key interface question:** The current `get_indicator` returns a single float for a given (symbol, indicator_name, period, cadence). Our analysis needs richer data — stage classification, RS trend, breakout signals. Two approaches:

**Approach A: Encode everything as indicators.** Register custom indicator names like "WEINSTEIN_STAGE", "RS_TREND", etc. Awkward — stages aren't floats.

**Approach B: The strategy does its own analysis internally.** The strategy calls `get_price` to fetch bars, then runs the Weinstein analysis pipeline directly. The `get_indicator` accessor is used for standard indicators (MA values). Weinstein-specific analysis lives inside the strategy.

**Recommendation: Approach B.** The Weinstein analysis pipeline is complex enough that shoehorning it into the indicator framework would be forced. The strategy module owns its analysis — it calls `get_price` for each symbol, runs stage classification, macro analysis, screening internally, and emits transitions.

## Tuner

The tuner wraps the simulator in a search loop.

```ocaml
(* tuner.mli *)
type param_range =
  | Int_range of { min : int; max : int; step : int }
  | Float_range of { min : float; max : float; step : float }
  | Enum of string list

type param_spec = {
  path : string;           (** e.g. "analysis.ma_period" *)
  range : param_range;
}

type objective =
  | Maximize of Metric_types.metric_type  (** e.g. SharpeRatio *)
  | Minimize of Metric_types.metric_type  (** e.g. MaxDrawdown *)

type tuning_config = {
  base_config : Config.t;
  params : param_spec list;
  objective : objective;
  sim_config : Simulator_types.config;
  method_ : [ `Grid | `Random of int | `Bayesian ];
}

type run_record = {
  config : Config.t;
  metrics : Metric_types.metric_set;
}

type result = {
  best : run_record;
  all_runs : run_record list;
  param_sensitivity : (string * float) list;  (** param path, correlation with objective *)
}

val tune :
  tuning_config:tuning_config ->
  symbols:string list ->
  data_dir:Fpath.t ->
  result Status.status_or
```

**Implementation approach:** Start with grid search (simplest). Each candidate config is generated by varying one or more parameters within their ranges. For each config, run a full simulation via `Simulator.run`. Collect metrics. Sort by objective. Report best + sensitivity.

**Walk-forward validation** (future enhancement): Split the date range into train/test folds. Optimize on train, validate on test. Helps detect overfitting.

---

# Part 5: Trading Feedback Loop Design

## Overview

The trading feedback loop is what makes this a **system** rather than a screener. It's the bidirectional flow between the automated analysis and your manual decisions.

## The loop

```
┌──────────────────────────────────────────────────┐
│                                                  │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│   │ Analyze  │───→│ Screen   │───→│ Suggest  │  │
│   │          │    │          │    │ orders   │  │
│   └──────────┘    └──────────┘    └──────────┘  │
│        ▲                               │         │
│        │                               ▼         │
│   ┌──────────┐                   ┌──────────┐   │
│   │ Monitor  │←──────────────────│ Report   │   │
│   │ positions│                   │ to user  │   │
│   └──────────┘                   └──────────┘   │
│        ▲                               │         │
│        │                               ▼         │
│   ┌──────────┐                   ┌──────────┐   │
│   │ Update   │←──────────────────│ User     │   │
│   │ state    │   (logs trades)   │ decides  │   │
│   └──────────┘                   └──────────┘   │
│                                                  │
└──────────────────────────────────────────────────┘
```

## The state that persists between runs

```ocaml
(* trading_state.mli *)

(** The persistent state of the trading system between runs.
    Serialized to JSON on disk. Loaded at the start of each run. *)
type t = {
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Position.t Core.String.Map.t;
  weinstein_stops : (string * Weinstein_stops.stop_state) list;
  prior_macro : Macro.t option;
  prior_stages : (string * Weinstein_types.stage) list;  (** Per-ticker *)
  prior_sector_stages : (string * Weinstein_types.stage) list;
  trade_log : trade_log_entry list;
  last_scan_date : Core.Date.t option;
}

type trade_log_entry = {
  date : Core.Date.t;
  ticker : string;
  action : [ `Buy | `Sell | `Short | `Cover ];
  price : float;
  shares : int;
  reason : string;
}

val load : Fpath.t -> t Status.status_or
val save : t -> Fpath.t -> unit Status.status_or
val empty : initial_cash:float -> t
```

## Events that trigger state updates

| Event | Who triggers | What updates |
|-------|-------------|-------------|
| Weekly scan completes | Automated (cron) | prior_macro, prior_stages, prior_sector_stages, last_scan_date |
| You log a trade entry | Manual CLI | portfolio (apply_trade), positions (add), weinstein_stops (compute_initial), trade_log |
| You log a trade exit | Manual CLI | portfolio (apply_trade), positions (transition to Closed), weinstein_stops (remove), trade_log |
| Stop is hit (detected by monitor) | Automated alert | Alert sent to user. State NOT updated until user confirms and logs exit. |
| Stop is adjusted (weekly scan) | Automated | weinstein_stops (updated levels) |
| Mid-week re-scan | Manual CLI | Same as weekly scan, but updates prior_stages etc. |

## CLI commands for the feedback loop

```
# Weekly workflow
weinstein scan                    # Full pipeline → report
weinstein report                  # Display latest report
weinstein alerts                  # Show any pending alerts

# Portfolio management
weinstein portfolio               # Show current holdings, exposure, P&L
weinstein enter AAPL --price 152.50 --shares 200 --stop 137.00
weinstein exit AAPL --price 145.00 --reason "stop hit"
weinstein adjust-stop AAPL --new-stop 148.00

# Analysis
weinstein analyze AAPL            # Single stock analysis
weinstein macro                   # Market regime
weinstein sector Technology       # Sector health

# Simulation
weinstein backtest --from 2018-01-01 --to 2025-12-31
weinstein tune --param analysis.ma_period:20-40 --objective sharpe

# Mid-week
weinstein rescan                  # Re-run full pipeline now
weinstein monitor                 # Check stops against today's close
```

## How the loop differs in simulation vs live

| Aspect | Live | Simulation |
|--------|------|------------|
| Data source | EODHD API (current) | Historical cache (replayed) |
| Strategy call | Weekly (Friday close) | Weekly (simulated Friday) |
| Order execution | Manual (you place GTC limits) | Automatic (engine fills next week) |
| Trade logging | Manual CLI (`weinstein enter/exit`) | Automatic (from engine fills) |
| Stop monitoring | Daily automated check | Per-step in simulator |
| State persistence | JSON on disk | In-memory during sim run |
| Portfolio | Real money | Simulated cash |

The key insight: the analysis and screening logic is identical. The **feedback loop is the only thing that differs** — in live mode, you're in the loop. In simulation, the simulator closes the loop automatically.

---

# Part 6: Next Steps

This document establishes the detailed designs for all four subsystems. To start building:

1. **P1 (Indicators)** is the obvious first step — small, self-contained, no dependencies on other new code. SMA is ~50 lines. Weighted MA is ~80 lines. Breadth indicators are ~150 lines. All follow the existing EMA pattern. Tests are straightforward.

2. **P2 (Stage Classifier)** is the first substantial piece. Before coding, it may be worth writing a few test cases by hand — take a known stock that went through Stage 1→2→3→4, extract the weekly bars, and specify what the classifier should output at each point. This becomes the acceptance test.

3. **P3–P4** can proceed in parallel once P2 is solid.

4. **P7 (Strategy Module)** is the integration point where everything comes together. Its design depends on P2–P6 being stable, but the interface is already defined by the existing `STRATEGY` module type.

For sub-component design: each module above has its interface sketched. The next level of detail is implementation — writing the `.mli` files, then tests, then code, following the TDD workflow established in the repo's CLAUDE.md.
