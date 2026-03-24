# Simulation / Backtesting / Tuning — Engineering Design

**Codebase:** `dayfine/trading` — ~18,600 lines OCaml, 34 test files. Core + Async throughout.

**Related docs:** [System Design](weinstein-trading-system-v2.md) · [Detailed Design](weinstein-detailed-design.md) · [Book Reference](weinstein-screener-design-doc-v2.md)

## Simulation / Backtesting / Tuning

## 4.1 Components

- **Simulator** — extend existing `trading/simulation/lib/simulator.ml`
- **Weinstein Strategy** — new: `trading/strategy/lib/weinstein_strategy.ml`
- **Metrics** — extend existing `trading/simulation/lib/metrics.ml`
- **Tuner** — new: `analysis/weinstein/tuner/`

## 4.2 Requirements

**Functional:**
- Backtest Weinstein strategy over any date range with any config
- Weekly cadence: strategy runs Friday close, orders execute following week
- Standard metrics (Sharpe, drawdown, win rate, profit factor)
- Weinstein-specific metrics (grade accuracy, stop effectiveness)
- Config parameter search with sensitivity analysis
- Walk-forward validation for overfitting detection

**Non-functional:**
- Single backtest (10yr, 5K symbols): <10 minutes
- Tuner supports parallelization (each backtest is independent)
- Results reproducible: same config + data = same result, bit-for-bit

**Non-requirements:**
- Live paper trading (simulation = historical replay only)
- Tick-level simulation (OHLC-based fills, appropriate for weekly system)
- GPU acceleration

## 4.3 Design

### Weekly Simulation Mode

**Change:** Add `strategy_cadence` to simulator config.

```ocaml
type config = {
  start_date : Date.t; end_date : Date.t;
  initial_cash : float; commission : commission_config;
  strategy_cadence : Types.Cadence.t;  (* NEW *)
}
```

**Modified step logic:**
```ocaml
let should_call_strategy t =
  match t.config.strategy_cadence with
  | Daily -> true
  | Weekly -> Time_series.is_period_end ~cadence:Weekly t.current_date
  | Monthly -> Time_series.is_period_end ~cadence:Monthly t.current_date
```

Simulator still steps daily (for realistic order execution against intraday price paths). Strategy only called on Fridays. On non-Fridays, step only processes pending orders.

**Why daily steps + weekly strategy, not weekly steps?** Orders placed Friday should execute during the following week against realistic price paths. Weekly steps would skip the execution modeling. Daily steps + weekly calls gives realistic execution + correct Weinstein cadence.

### Weinstein Strategy Module

```ocaml
(* weinstein_strategy.mli *)
type config = {
  analysis : Stage.config;
  macro : Macro.config;
  screening : Screener.config;
  portfolio : Portfolio_risk.config;
  stops : Weinstein_stops.config;
}

val name : string
val make : config -> (module Strategy_interface.STRATEGY)
```

**`on_market_close` internally:**
```
1. Gather weekly bars for held positions + index
2. Stage-classify each held position
3. Update Weinstein stops for each held position
   → emit TriggerExit if stop hit
   → emit UpdateRiskParams if stop adjusted
4. Run macro analysis
5. If full-scan week:
   a. Analyze all tickers in universe
   b. Sector analysis
   c. Screen → candidates
   d. Emit CreateEntering for top candidates
6. Return all transitions
```

**Strategy state:** The STRATEGY interface is stateless (receives `positions` as input). Weinstein stops need to persist between calls. The `make` function creates a closure with private mutable refs for stop_states, prior_macro, prior_stages. In simulation, state lives in the closure. In live mode, state is loaded/saved via `trading_state.json`.

```ocaml
let make config =
  let stop_states = ref String.Map.empty in
  let prior_macro = ref None in
  (module struct
    let name = "Weinstein"
    let on_market_close ~get_price ~get_indicator ~positions =
      (* uses and updates !stop_states, !prior_macro *)
  end : STRATEGY)
```

**Why internal analysis instead of encoding as indicators?** The current `get_indicator` returns a single float. Stage classification, RS trends, and breakout signals are structured types, not floats. Encoding them as indicator values would be forced. The strategy owns its analysis pipeline.

### Tuner

```ocaml
(* tuner.mli *)
type param_range =
  | Int_range of { min : int; max : int; step : int }
  | Float_range of { min : float; max : float; step : float }
  | Choice of string list

type param_spec = { path : string; range : param_range }

type objective = Maximize of Metric_types.metric_type | Minimize of Metric_types.metric_type

type method_ =
  | Grid
  | Random of { n : int }
  | Bayesian of { n : int; init_random : int }

type run_record = {
  config_overrides : (string * string) list;
  metrics : Metric_types.metric_set;
}

type result = {
  best : run_record;
  all_runs : run_record list;
  sensitivity : (string * float) list;
  overfitting_warning : bool;
}

val run : config:tuner_config -> symbols:string list ->
  data_dir:Fpath.t -> result Status.status_or Deferred.t
```

**Walk-forward validation:** Split date range into K folds. For each fold: optimize on K-1 segments, test on held-out. If out-of-sample performance significantly worse → overfitting warning. Prevents configs that look great historically but fail forward.

**Complexity:** 5 params × 5 values each = 3,125 backtests. At 5 min each = ~10 days single-core. Mitigation: Random/Bayesian for exploration, Grid over narrow range. Parallelize — `Async.Deferred.List.map ~how:`Parallel` with throttle.

### Simulation Data Flow

```
  Tuner (N iterations)
    │
    ▼
  Simulator (weekly cadence)
    │ each Friday:
    ▼
  Weinstein Strategy
    on_market_close:
      Stage classify held → update stops → macro analysis → screen universe → emit transitions
    │
    ▼
  Existing infrastructure
    Order Generator → Engine → Portfolio → next step
    │
    ▼
  run_result (steps + metrics)
```

### Alternatives Considered

| Option | Rejected because |
|---|---|
| Separate backtester (not extending simulator) | Duplicates step loop, portfolio, execution. Divergence risk. |
| Daily strategy with weekly aggregation | 5× more calls, same result. Weekly flag is simpler. |
| Bayesian optimization from the start | Grid is simpler, interpretable. Bayesian adds implementation complexity. Upgrade later. |

---

## Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| Extend existing simulator | Add strategy_cadence flag | Build separate weekly backtester | Reuses step loop, engine, portfolio. Same code path live and sim. |
| Daily steps + weekly strategy | Combined in one simulator | Weekly steps only | Realistic intraday execution modeling for orders placed on Friday |
| Strategy state in closure | Mutable ref in factory | Thread through simulator types | Minimal changes to existing simulator interface |
| Grid search first | Exhaustive + simple | Bayesian from start | Simpler to implement and interpret. Upgrade path clear. |
| Walk-forward validation | K-fold train/test split | In-sample only | Detects overfitting before applying config to live trading |
