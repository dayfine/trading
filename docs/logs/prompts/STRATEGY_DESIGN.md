# Strategy Interface Design

## Overview

This document describes the design for Phase 4: Strategy Interface. The strategy system enables pluggable trading algorithms that generate order intents based on market data, technical indicators, and portfolio state.

## Requirements

### Functional Requirements

**FR1: Strategy State Management**
- Strategies MUST maintain state across simulation days
- State includes:
  - Active trading intents (entry/exit plans)
  - Position entry prices and dates (for P&L calculation)
  - Calculated indicators (can be cached for performance)
  - Risk management parameters per position
- State is passed to strategy each day and updated state is returned

**FR2: Position Lifecycle Management**
- Strategies MUST be able to open new positions based on signals
- Strategies MUST be able to close existing positions based on:
  - **Take Profit**: Exit when profit target reached
  - **Stop Loss**: Exit when loss threshold exceeded
  - **Signal Reversal**: Exit when entry signal invalidates
  - **Time-based**: Exit after holding period expires
  - **Portfolio Rebalancing**: Exit to free capital for better opportunities
- Strategies MUST track positions from entry to exit

**FR3: Risk Management**
- Strategies MUST enforce position sizing rules:
  - Maximum position size (% of portfolio)
  - Maximum risk per trade
  - Maximum total portfolio risk exposure
- Strategies MUST support stop-loss orders for downside protection
- Strategies MUST support take-profit orders for profit-taking
- Strategies MUST be able to close underperforming positions

**FR4: Order Intent System**
- Strategies generate **intents** (not direct orders)
- Intents represent trading goals that may span multiple days
- Each intent includes:
  - Position goal (what to achieve)
  - Execution plan (how to achieve it)
  - Reasoning (why this decision)
  - Lifecycle status (active/filled/cancelled)
- Intents can generate multiple orders over time

**FR5: Market Data Access**
- Strategies MUST have access to:
  - Historical price data (OHLC) for all symbols
  - Current portfolio state (positions, cash, P&L)
  - Technical indicators (EMA, SMA, RSI, etc.)
  - Current date in simulation
- Data access abstraction supports adding new indicators

**FR6: Signal Generation**
- Strategies analyze market data to generate trading signals
- Signals include:
  - Technical indicators (e.g., EMA crossover)
  - Price patterns (e.g., breakout, support/resistance)
  - Risk triggers (e.g., stop loss hit)
  - Portfolio rebalancing needs
- Each signal includes confidence level and reasoning

**FR7: Priced Orders Only**
- Strategies MUST NOT use Market orders
- All orders MUST be priced:
  - Limit orders (buy at or below, sell at or above)
  - Stop orders (trigger at price)
  - Stop-Limit orders (trigger + limit)
- This enables realistic backtesting with OHLC execution modeling

### Non-Functional Requirements

**NFR1: Modularity**
- Strategies implement a common `STRATEGY` module signature
- New strategies can be added without modifying simulator
- Strategies are self-contained and independently testable

**NFR2: Testability**
- Strategy logic is pure function: `(inputs, state) → (outputs, new_state)`
- No side effects (I/O, randomness) in strategy logic
- Deterministic behavior for given inputs
- Easy to write unit tests with mock data

**NFR3: Composability**
- Strategy state is explicit (not hidden global state)
- Multiple strategies can be composed (future)
- Strategies can be parameterized via config

**NFR4: Performance**
- Indicator calculations should be efficient
- Caching strategies supported (future optimization)
- Strategy execution should not bottleneck simulation

**NFR5: Debuggability**
- Each intent includes structured reasoning
- Intent lifecycle is trackable
- Strategy decisions are explainable
- Support for logging/tracing (future)

### Constraints

**C1: Daily Cadence**
- Strategies run once per day after market close
- No intraday strategy decisions
- Orders execute next day against OHLC price paths

**C2: No Lookahead Bias**
- Strategies only see data up to current simulation date
- Future prices are not available
- Ensures realistic backtesting

**C3: Integration with Existing Components**
- Must use existing Portfolio, Engine, OrderManager
- Must integrate with analysis/ components (indicators, price data)
- Should not duplicate existing functionality

### Key Use Cases

**UC1: Simple Buy and Hold**
- Strategy buys on day 1, holds until end
- No active management
- Single intent, never closed

**UC2: Moving Average Crossover**
- Strategy monitors EMA vs price
- Buys when price crosses above EMA
- Sells when price crosses below EMA
- Manages multiple positions across symbols

**UC3: Stop Loss / Take Profit**
- Strategy enters position with signal
- Sets stop loss (e.g., -5% from entry)
- Sets take profit (e.g., +10% from entry)
- Automatically exits when either triggered

**UC4: Underperforming Asset Exit**
- Strategy holds multiple positions
- Tracks days held and P&L for each position
- Exits positions that underperform for N days
- Frees capital for new opportunities

**UC5: Portfolio Rebalancing**
- Strategy maintains target allocations (e.g., 5% per symbol)
- Rebalances when positions drift from targets
- Sells overweight positions, buys underweight

### Success Criteria

- ✅ Strategies can maintain state across days
- ✅ Strategies can open and close positions
- ✅ Strategies can implement stop loss and take profit
- ✅ Strategies can track position entry prices
- ✅ Strategies can access historical prices and indicators
- ✅ Intents provide clear reasoning for decisions
- ✅ All orders are priced (no market orders)
- ✅ Strategy interface is pluggable and testable
- ✅ Integration with analysis/ components works seamlessly

## Architecture

### High-Level Data Flow

```
Simulator
   ↓
   ├─→ MarketData (provides price history + indicators)
   │      ↓
   ├─→ Strategy.on_market_close(market_data, portfolio, active_intents, state)
   │      ↓
   │   Strategy Decision:
   │      - Create new intents
   │      - Update existing intents
   │      - Cancel intents
   │      - Generate orders ready to execute
   │      ↓
   ├─→ Intent → Order conversion
   │      ↓
   └─→ Engine.process_orders (next day)
```

## Components

### 1. MarketData - Data Access Layer

**Purpose**: Provides strategies with access to historical prices and technical indicators.

**Responsibilities**:
- Fetch price history for symbols
- Compute technical indicators (EMA, etc.)
- Cache computed indicators (future optimization)

**Interface**:
```ocaml
module type MARKET_DATA = sig
  type t

  val current_date : t -> Date.t

  val get_latest_price :
    t ->
    symbol:string ->
    Daily_price.t option

  val get_price_history :
    t ->
    symbol:string ->
    ?start_date:Date.t ->
    ?end_date:Date.t ->
    unit ->
    Daily_price.t list

  val get_ema :
    t ->
    symbol:string ->
    period:int ->
    indicator_value list  (* From analysis/technical/indicators *)
end
```

**Connection to analysis/**:
- Uses `Daily_price.t` from `analysis/data/types`
- Delegates to `Ema.calculate_ema` from `analysis/technical/indicators/ema`
- Could integrate with `HistoricalDailyPriceStorage` for data persistence

**Implementation Notes**:
- Initially: Simple wrapper around price data, calls indicator functions directly
- Future: Cache indicator results to avoid recomputation

### 2. Intent System - Stateful Order Management

**Purpose**: Represent trading intentions that span multiple days and may generate multiple orders.

#### 2.1 Position Intent - What to Achieve

```ocaml
type position_goal =
  | AbsoluteShares of float
      (** Buy/sell exactly N shares (e.g., "buy 100 shares") *)
  | TargetPosition of float
      (** Reach a target position size (e.g., "hold 200 shares total")
          - If currently at 150, buy 50
          - If currently at 250, sell 50 *)
  | PercentOfPortfolio of float
      (** Position worth X% of portfolio value
          Dynamically calculated based on current portfolio *)
```

#### 2.2 Execution Strategy - How to Achieve It

```ocaml
type execution_plan =
  | SingleOrder of {
      price: float;
      order_type: Trading_base.Types.order_type;  (* Limit/Stop/StopLimit *)
    }
  | StagedEntry of staged_order list
      (** Multiple orders at different price levels
          Example: "Buy 50 shares at $100, 50 more at $95" *)

and staged_order = {
  fraction: float;           (* Fraction of total intent (0.0 to 1.0) *)
  price: float;              (* Target price *)
  order_type: order_type;    (* Limit/Stop/StopLimit *)
}
```

**Examples**:
- **Simple limit buy**: `AbsoluteShares 100`, `SingleOrder { price=150.0; order_type=Limit 150.0 }`
- **Staged entry**: `AbsoluteShares 200`, `StagedEntry [{ fraction=0.5; price=150.0; ... }; { fraction=0.5; price=145.0; ... }]`
- **Target position**: `TargetPosition 300`, `SingleOrder { ... }` (if currently at 250, will buy 50)

#### 2.3 Reasoning - Why This Intent

```ocaml
type signal_type =
  | TechnicalIndicator of {
      indicator: string;      (* "EMA", "RSI", etc. *)
      value: float;           (* Current value *)
      threshold: float;       (* Threshold crossed *)
      condition: string;      (* "crossed above", "below", etc. *)
    }
  | PriceAction of {
      pattern: string;        (* "breakout", "support", "resistance" *)
      description: string;
    }
  | RiskManagement of risk_reason
  | PortfolioRebalancing of {
      current_allocation: float;
      target_allocation: float;
    }

and risk_reason =
  | StopLoss of {
      entry_price: float;
      current_price: float;
      loss_percent: float;
    }
  | TakeProfit of {
      entry_price: float;
      current_price: float;
      profit_percent: float;
    }
  | UnderperformingAsset of {
      days_held: int;
      total_return: float;
      benchmark_return: float option;
    }

type reasoning = {
  signal: signal_type;
  confidence: float;          (* 0.0 to 1.0 *)
  description: string;        (* Human-readable explanation *)
}
```

#### 2.4 Intent Lifecycle

```ocaml
type intent_status =
  | Active
      (** Intent is being worked on, orders may be pending *)
  | PartiallyFilled of {
      filled_quantity: float;
      remaining_quantity: float;
    }
      (** Some orders have executed, more to go *)
  | Completed
      (** All orders executed or goal achieved *)
  | Cancelled of string
      (** Intent cancelled (reason provided) *)

type order_intent = {
  id: string;                       (* Unique identifier *)
  created_date: Date.t;            (* When intent was created *)
  symbol: string;
  side: Trading_base.Types.side;   (* Buy or Sell *)
  goal: position_goal;             (* What to achieve *)
  execution: execution_plan;       (* How to achieve it *)
  reasoning: reasoning;            (* Why *)
  status: intent_status;           (* Current state *)
  expires_date: Date.t option;     (* Optional expiration *)
}
```

#### 2.5 Intent Actions

```ocaml
type intent_action =
  | CreateIntent of order_intent
  | UpdateIntent of {
      id: string;
      new_status: intent_status;
    }
  | CancelIntent of {
      id: string;
      reason: string;
    }
```

**Examples**:
- Create: New signal detected, create intent to enter position
- Update: Partial fill occurred, update intent status
- Cancel: Market conditions changed, cancel pending intent

### 3. Strategy Interface

**Purpose**: Module signature that all trading strategies must implement.

```ocaml
module type STRATEGY = sig
  type config
      (** Strategy-specific configuration (e.g., EMA periods, thresholds) *)

  type state
      (** Strategy-specific state (e.g., active intents, calculated indicators) *)

  val name : string
      (** Strategy name for logging/identification *)

  val init : config:config -> state
      (** Initialize strategy state from configuration *)

  val on_market_close :
    market_data:market_data ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (strategy_output * state) Status.status_or
      (** Called once per day after market close.

          Strategy evaluates:
          - Current market conditions (via market_data)
          - Current portfolio state (positions, cash, P&L)
          - Active intents (from strategy state)

          Returns:
          - Intent actions (create/update/cancel)
          - Orders ready to execute (from intents that are ready)
          - Updated strategy state (with active intents)
       *)
end

and strategy_output = {
  intent_actions: intent_action list;
      (** Changes to intent state *)

  orders_to_submit: Trading_orders.Types.order list;
      (** Orders ready to be submitted to engine
          (converted from intents that are ready to execute) *)
}
```

**Key Design Decisions**:
1. **Strategy manages its own intents** - Intents live in strategy state, not simulator state
2. **Daily cadence** - Strategy runs once per day after market close
3. **No market orders** - All orders must be priced (Limit/Stop/StopLimit)
4. **Stateful** - Strategy maintains state across days
5. **Pure function** - Given inputs, returns outputs (no side effects)

### 4. Strategy State Management

**Responsibility**: Strategy tracks its own active intents and updates them.

**Example Flow**:

**Day 1 - Create Intent**:
```
Strategy state: { active_intents = [] }
Signal detected: EMA crossed above price
Output:
  - intent_actions = [CreateIntent { ... }]
  - orders_to_submit = [Order { symbol="AAPL"; side=Buy; limit=150.0; ... }]
New state: { active_intents = [intent1] }
```

**Day 2 - Update Intent** (partial fill):
```
Strategy state: { active_intents = [intent1] }
Check execution status: Intent1 partially filled (50/100 shares)
Output:
  - intent_actions = [UpdateIntent { id=intent1.id; new_status=PartiallyFilled {...} }]
  - orders_to_submit = [Order { ... remaining 50 shares ... }]
New state: { active_intents = [intent1_updated] }
```

**Day 3 - Cancel Intent** (conditions changed):
```
Strategy state: { active_intents = [intent1_updated] }
Market conditions changed: Signal invalidated
Output:
  - intent_actions = [CancelIntent { id=intent1.id; reason="Signal reversed" }]
  - orders_to_submit = [] (no new orders)
New state: { active_intents = [] }
```

## Integration with Existing Components

### Simulator Integration

The simulator orchestrates the daily loop:

```ocaml
let step t =
  if is_complete t then ...
  else
    (* 1. Update market data with today's prices *)
    let market_data = MarketData.update t.market_data today_prices in

    (* 2. Process yesterday's orders (existing logic) *)
    let execution_reports = Engine.process_orders t.engine t.order_manager in
    let trades = extract_trades execution_reports in
    let updated_portfolio = Portfolio.apply_trades t.portfolio trades in

    (* 3. Call strategy after market close *)
    let strategy_output, new_strategy_state =
      Strategy.on_market_close
        ~market_data
        ~portfolio:updated_portfolio
        ~state:t.strategy_state
    in

    (* 4. Submit new orders from strategy *)
    let _ = submit_orders t strategy_output.orders_to_submit in

    (* 5. Advance to next day *)
    { t with
      current_date = next_date;
      portfolio = updated_portfolio;
      strategy_state = new_strategy_state;
      market_data;
    }
```

### Connection to analysis/

**Price Data**:
- `MarketData` uses `Daily_price.t` from `analysis/data/types`
- Can integrate with `HistoricalDailyPriceStorage` from `analysis/data/storage` for persistence

**Technical Indicators**:
- `MarketData.get_ema` delegates to `Ema.calculate_ema` from `analysis/technical/indicators/ema`
- Takes `Daily_price.t list`, converts to `indicator_value list`, calls `Ema.calculate_ema`
- Returns cached result if available (future optimization)

**Time Period Conversion**:
- Can use `Conversion.daily_to_weekly` from `analysis/technical/indicators/time_period`
- For strategies that operate on weekly/monthly data

## Implementation Phases

### Phase 4a: Core Infrastructure
1. Define intent types (`order_intent`, `position_goal`, `execution_plan`, `reasoning`)
2. Define `STRATEGY` module signature
3. Define `MARKET_DATA` module signature
4. Implement basic `MarketData` (no caching, direct delegation to `Ema.calculate_ema`)
5. Update simulator to support strategy integration
6. Tests for intent lifecycle and strategy interface

### Phase 4b: Example Strategy
1. Implement `BuyAndHold` strategy (simplest case)
   - Single intent on day 1
   - No updates needed
   - Target position or percent of portfolio
2. Tests for BuyAndHold

### Phase 4c: Technical Strategy
1. Implement `MovingAverageCrossover` strategy
   - Uses EMA from `analysis/technical/indicators`
   - Creates intents when EMA crosses price
   - Manages active intents across days
2. Tests for MovingAverageCrossover

### Phase 4d: Advanced Features
1. Staged entry/exit (multiple orders per intent)
2. Risk management signals (stop loss, take profit)
3. Portfolio rebalancing
4. Intent expiration

## Open Questions

1. **Order lifecycle tracking**: How does strategy know which orders from an intent have filled?
   - Option A: Strategy queries portfolio for position changes
   - Option B: Simulator passes execution results to strategy
   - **Proposed**: Option A (simpler, strategy is stateless observer)

2. **Intent-to-Order conversion**: Who converts intents to orders?
   - Option A: Strategy does conversion in `on_market_close`
   - Option B: Simulator has converter function
   - **Proposed**: Option A (strategy controls timing and parameters)

3. **Multiple strategies**: Should simulator support multiple concurrent strategies?
   - Not in Phase 4
   - Future: Strategy composition/ensemble

4. **Performance**: When to add indicator caching in `MarketData`?
   - Start without caching (call `Ema.calculate_ema` each time)
   - Profile and optimize if needed
   - Caching can be added later without interface changes

## Summary

**Core Concepts**:
- **Intents**: Stateful, span multiple days, may generate multiple orders
- **Strategy**: Manages intents, generates orders, maintains state
- **MarketData**: Provides price history + indicators via analysis/ modules
- **Daily Cadence**: Strategy runs once per day after market close

**Integration**:
- Reuses `Daily_price.t`, `Ema.calculate_ema`, indicator types from analysis/
- Extends simulator to call strategy and manage strategy state
- Intent system provides rich expressiveness for complex strategies

**Phasing**:
- 4a: Core types and interfaces
- 4b: Simple BuyAndHold strategy
- 4c: Technical MovingAverage strategy
- 4d: Advanced features (staged orders, risk management)
