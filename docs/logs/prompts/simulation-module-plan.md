# Simulation Module Implementation Plan

## Overview

Build a daily-granularity backtesting framework:
`Historical OHLC → Strategy (after market) → Orders → Intraday Execution → Portfolio`

**Key Design Decisions:**
- **Daily granularity**: Strategy runs once per day, after market close
- **OHLC-based execution**: Generate synthetic intraday price paths from OHLC for realistic order execution
- **Leverage existing data**: Use `analysis/data` module for historical prices
- **Inter-day strategy**: Strategy decides positions after seeing the day's close, orders execute next day

---

## Phase 1: Core Types & Build Setup

**Goal**: Define foundational types and get the module building.

### Types to define (`lib/types.mli`):
```ocaml
(* Reuse existing type from analysis/data/types *)
module Daily_price = Analysis_data_types.Daily_price

type symbol_prices = {
  symbol : string;
  prices : Daily_price.t list;  (* sorted by date *)
}

type simulation_config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  symbols : string list;
  commission : Trading_engine.Types.commission_config;
}

type simulation_state = {
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  order_manager : Trading_orders.Manager.order_manager;
  engine : Trading_engine.Engine.t;
  price_history : symbol_prices list;  (* for strategy lookback *)
}
```

### Deliverables:
- [ ] `lib/types.ml` and `lib/types.mli` with core types
- [ ] `lib/dune` build configuration
- [ ] `test/dune` test configuration
- [ ] Basic type tests

### Tests:
- Type construction and equality
- Deriving show/eq working

---

## Phase 2: OHLC Price Path Simulator

**Goal**: Generate realistic intraday price paths from daily OHLC for order execution.

### Concept:
Given a daily bar (O, H, L, C), simulate the intraday price path to determine
when/if limit and stop orders would execute.

### Interface (`lib/price_path.mli`):
```ocaml
type path_point = {
  fraction_of_day : float;  (* 0.0 = open, 1.0 = close *)
  price : float;
}

type intraday_path = path_point list

val generate_path : Daily_price.t -> intraday_path
(** Generate synthetic intraday path from OHLC.
    Ensures path touches O, H, L, C in realistic order. *)

val would_fill_at : intraday_path -> Trading_base.Types.order_type -> Trading_base.Types.side -> float option
(** Check if order would fill during this path, return fill price if so.
    - Market orders: fill at open
    - Limit buy: fill if path goes <= limit_price
    - Stop sell: fill if path goes <= stop_price
    etc. *)
```

### Path Generation Strategy:
Simple approach: O → H → L → C or O → L → H → C based on close vs open.
More sophisticated: randomized paths that respect OHLC constraints.

### Deliverables:
- [ ] `lib/price_path.ml` and `lib/price_path.mli`
- [ ] Deterministic path generation (for reproducible backtests)
- [ ] Optional randomized path generation

### Tests:
- Generated path respects OHLC bounds
- Market orders fill at open
- Limit orders fill at correct prices
- Stop orders trigger correctly
- Path visits all OHLC points

---

## Phase 3: Daily Simulation Loop

**Goal**: Simulate day-by-day, executing orders based on OHLC paths.

### Interface (`lib/simulator.mli`):
```ocaml
type t

val create : simulation_config -> symbol_prices list -> t
(** Initialize simulation with config and historical prices per symbol *)

val state : t -> simulation_state
(** Get current simulation state *)

val step_day : t -> bool
(** Process one trading day:
    1. Generate intraday paths from today's OHLC
    2. Execute pending orders against paths
    3. Update portfolio with trades
    4. Advance to next day
    Returns false when no more days *)

val run : t -> simulation_state
(** Run to completion, return final state *)
```

### Day Processing:
1. Get today's OHLC bars for all symbols
2. Generate intraday price paths
3. For each pending order:
   - Check if it would fill against the path
   - If yes, execute at fill price
4. Apply all trades to portfolio
5. Update price history
6. Advance date

### Deliverables:
- [ ] `lib/simulator.ml` and `lib/simulator.mli`
- [ ] Daily simulation loop
- [ ] Integration with Engine, Portfolio, OrderManager
- [ ] Integration with price path simulator

### Tests:
- Empty simulation (no orders)
- Single day processing
- Market order fills at open
- Limit order fills when price reached
- Multi-day simulation

---

## Phase 4: Strategy Interface

**Goal**: Define strategy interface that runs after market close.

### Interface (`lib/strategy.mli`):
```ocaml
(** Order intent wraps an order with strategy reasoning.
    Orders MUST have prices (Limit, Stop, or StopLimit) - no market orders.
    This ensures deterministic backtesting and realistic execution. *)
type order_intent = {
  order : Trading_orders.Types.order_params;
  reason : string;  (* strategy's reasoning for this order *)
}

(** Validate that order_intent has a priced order type *)
val validate_order_intent : order_intent -> order_intent status_or

module type STRATEGY = sig
  type state

  val name : string
  (** Strategy identifier *)

  val init : simulation_config -> state
  (** Initialize strategy state *)

  val on_market_close : state -> simulation_state -> (state * order_intent list)
  (** Called after market close each day.
      Receives current state including today's prices.
      Returns updated state and orders for next day.

      Orders must be priced (Limit/Stop/StopLimit, NOT Market). *)
end

type t

val create : (module STRATEGY) -> simulation_config -> t
val on_market_close : t -> simulation_state -> order_intent list
```

### Key Points:
- Strategy runs **once per day after close**
- Has access to full price history for lookback calculations
- Returns order intents to execute on **next trading day**
- Does NOT run intraday
- **Orders must be priced** (Limit, Stop, StopLimit) - no market orders
- Order intents include reasoning for debugging/analysis

### Deliverables:
- [ ] `lib/strategy.mli` and `lib/strategy.ml`
- [ ] Strategy module signature
- [ ] Strategy wrapper type

### Tests:
- Strategy initialization
- on_market_close called with correct state
- Order intents returned correctly

---

## Phase 5: Built-in Strategies

**Goal**: Implement simple strategies for testing.

### Strategies to implement:
```ocaml
module BuyAndHold : STRATEGY
(** Buy fixed quantity on first day, hold forever.
    Places limit order at previous close on day 1. *)

module SimpleMovingAverage : STRATEGY
(** Compare close to N-day SMA.
    Go long when close > SMA, flat when close < SMA.
    Uses limit orders at close price. *)

module MeanReversion : STRATEGY
(** Buy when price drops X% below N-day average.
    Sell when price returns to average.
    Uses limit orders at target prices. *)
```

### Deliverables:
- [ ] `lib/strategies/buy_and_hold.ml`
- [ ] `lib/strategies/simple_ma.ml`
- [ ] `lib/strategies/mean_reversion.ml`
- [ ] Strategy parameter configuration

### Tests:
- BuyAndHold generates limit buy order on day 1
- SMA generates correct signals on crossovers with limit orders
- MeanReversion places limit orders at correct prices
- All strategies produce priced orders (no market orders)

---

## Phase 6: Simulation with Strategy

**Goal**: Integrate strategy into simulation loop.

### Extended Simulator:
```ocaml
val create_with_strategy :
  simulation_config -> symbol_prices list -> (module STRATEGY) -> t
(** Create simulation with automated strategy *)
```

### Daily Loop with Strategy:
1. **Market open**: Execute pending orders against today's OHLC path
2. **Market close**:
   - Update portfolio valuations at close prices
   - Call strategy.on_market_close
   - Convert order intents to orders for tomorrow
3. **Advance to next day**

### Deliverables:
- [ ] Strategy integration in simulator
- [ ] Order intent to order conversion
- [ ] Full automated backtest capability

### Tests:
- BuyAndHold full backtest
- SMA strategy backtest
- Verify trades match strategy signals
- Multi-symbol backtest

---

## Phase 7: Performance Metrics

**Goal**: Calculate portfolio performance metrics.

### Interface (`lib/metrics.mli`):
```ocaml
type performance_summary = {
  total_return : float;
  annualized_return : float;
  volatility : float;
  sharpe_ratio : float;
  max_drawdown : float;
  win_rate : float;
  profit_factor : float;
  total_trades : int;
  days_simulated : int;
}

val calculate : simulation_state -> symbol_prices list -> performance_summary
(** Calculate metrics from final state and price history *)

val calculate_equity_curve : simulation_state -> (Date.t * float) list
(** Portfolio value at each day's close *)
```

### Deliverables:
- [ ] `lib/metrics.ml` and `lib/metrics.mli`
- [ ] Return calculations
- [ ] Risk metrics (volatility, Sharpe, max drawdown)
- [ ] Trade statistics (win rate, profit factor)

### Tests:
- Known return scenarios
- Drawdown calculation
- Sharpe ratio calculation

---

## Phase 8: Simulation Results & Reporting

**Goal**: Comprehensive simulation output.

### Interface:
```ocaml
type simulation_result = {
  config : simulation_config;
  final_state : simulation_state;
  metrics : performance_summary;
  equity_curve : (Date.t * float) list;
  trades : Trading_base.Types.trade list;
  duration : Time_ns.Span.t;
}

val run_backtest :
  simulation_config -> symbol_prices list -> (module STRATEGY) -> simulation_result
(** Complete backtest with full results *)
```

### Deliverables:
- [ ] Result aggregation
- [ ] Timing/performance tracking
- [ ] Result pretty-printing

### Tests:
- Full backtest returns complete results
- All metrics populated correctly

---

## Phase 9: CLI Tool & Data Integration

**Goal**: Command-line interface and integration with existing data modules.

### Data Integration:
```ocaml
val load_from_analysis_data : string list -> Date.t -> Date.t -> symbol_prices list
(** Load historical data from analysis/data/storage for given symbols and date range.
    Reuses existing Daily_price.t from analysis/data/types. *)
```

### CLI Usage:
```bash
# Run backtest with stored data
./simulate --symbols AAPL,GOOGL --strategy sma --start 2023-01-01 --end 2023-12-31

# Output results
./simulate --symbols AAPL --strategy buy_and_hold --output results.json
```

### Deliverables:
- [ ] Integration with `analysis/data/storage`
- [ ] `bin/simulate.ml` CLI entry point
- [ ] Argument parsing
- [ ] Output formatting (text, JSON)

### Tests:
- Data loading from storage
- CLI argument parsing
- End-to-end backtest via CLI

---

## Summary

| Phase | Focus | Key Deliverable |
|-------|-------|-----------------|
| 1 | Core Types | `types.ml`, build setup |
| 2 | OHLC Path Simulator | Intraday path from OHLC |
| 3 | Daily Simulation Loop | Day-by-day execution |
| 4 | Strategy Interface | STRATEGY module type (after-close) |
| 5 | Built-in Strategies | BuyAndHold, SMA, MeanReversion |
| 6 | Strategy Integration | Automated backtests |
| 7 | Performance Metrics | Sharpe, drawdown, etc. |
| 8 | Results & Reporting | Complete output |
| 9 | CLI & Data Integration | Command-line tool |

## Dependencies Between Phases

```
Phase 1 (Types)
    ↓
Phase 2 (OHLC Path Simulator)
    ↓
Phase 3 (Daily Simulation Loop) ← depends on Engine, Portfolio, Orders
    ↓
Phase 4 (Strategy Interface)
    ↓
Phase 5 (Built-in Strategies)
    ↓
Phase 6 (Strategy Integration)
    ↓
Phase 7 (Metrics)
    ↓
Phase 8 (Results)
    ↓
Phase 9 (CLI & Data) ← depends on analysis/data
```

## Estimated Effort

- Phases 1-3: Foundation (~2-3 sessions)
- Phases 4-6: Strategy system (~2-3 sessions)
- Phases 7-9: Polish & tooling (~2 sessions)

Total: ~6-8 sessions for complete module
