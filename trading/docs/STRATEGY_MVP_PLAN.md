# Strategy System MVP Plan

## Goal

Build and test the position state machine and EMA-based strategies in isolation, without full simulator integration. Validate that the state machine correctly handles position lifecycle and that strategies make correct decisions.

## Scope

### In Scope
- ✅ Position state machine implementation
- ✅ Basic EMA crossover strategy
- ✅ Variant EMA strategy (different time scales)
- ✅ Simple market data mock for testing
- ✅ Manual step-by-step testing
- ✅ Test scenarios: take profit, stop loss, signal reversal, rebalancing

### Out of Scope
- ❌ Full simulator integration (Phase 4a focus is state machine + strategy)
- ❌ Data processing pipeline (use mocks)
- ❌ Performance optimization
- ❌ Multiple concurrent positions (initially test single position)
- ❌ Complex execution plans (staged entry/exit - add later)

## Architecture

```
Test → Strategy → Position State Machine → Transitions
  ↓         ↓
  └─→ MockMarketData (prices + EMA)
```

**Testing approach**: Manually advance through dates, call strategy.on_market_close each day, verify transitions and orders.

## Implementation Phases

### Phase 1: Position State Machine Core

**Goal**: Implement state machine with transitions and validation.

**Tasks**:
- [ ] Define state types (`position.mli`):
  - `entering_state`, `holding_state`, `exiting_state`, `closed_state`
  - `position_state` variant
  - Keep simple: single order per phase (no staged entry/exit for MVP)
- [ ] Define transition types (`position.mli`):
  - Entry: `PlaceEntryOrder`, `EntryFill`, `EntryComplete`
  - Holding: `TriggerExit`, `UpdateRiskParams`
  - Exit: `PlaceExitOrder`, `ExitFill`, `ExitComplete`
  - Simplified from design doc (combine PartialFill into Fill with quantity)
- [ ] Implement `apply_transition` (`position.ml`):
  - State-transition validation
  - Data consistency checks
  - Return new position or error
- [ ] Unit tests (`test_position.ml`):
  - Each transition from each valid state
  - Invalid transitions rejected
  - Data validation (filled ≤ target, prices > 0)

**Files**:
- `trading/simulation/lib/position.mli`
- `trading/simulation/lib/position.ml`
- `trading/simulation/test/test_position.ml`

**Success Criteria**:
- All state transitions work correctly
- Invalid transitions are rejected
- Data consistency enforced
- ~15-20 unit tests passing

---

### Phase 2: Mock Market Data

**Goal**: Simple in-memory MARKET_DATA implementation for testing.

**Tasks**:
- [ ] Implement `MockMarketData` module (`test/mock_market_data.ml`):
  - Create from list of `(symbol, Daily_price.t list)`
  - Pre-compute EMA for given periods
  - Implement MARKET_DATA interface
  - Support `advance` to move through dates
- [ ] Helper to create test price data:
  - `make_price_sequence` - generate OHLCV for date range
  - `with_trend` - uptrend, downtrend, sideways
  - `with_spike` - price spike at specific date

**Example usage**:
```ocaml
let prices = make_price_sequence
  ~symbol:"AAPL"
  ~start_date:(Date.of_string "2024-01-01")
  ~days:30
  ~base_price:150.0
  ~trend:Uptrend 0.5  (* +0.5% per day *)
  ~volatility:0.02
in
let market_data = MockMarketData.create
  ~data:[("AAPL", prices)]
  ~ema_periods:[30; 50]
  ~current_date:(Date.of_string "2024-01-01")
in
let ema_30 = MockMarketData.get_ema market_data "AAPL" 30
```

**Files**:
- `trading/simulation/test/mock_market_data.ml`
- `trading/simulation/test/price_generators.ml`

**Success Criteria**:
- Can create price sequences with trends
- EMA computed correctly
- Can advance through dates
- Returns None for future dates (no lookahead)

---

### Phase 3: EMA Crossover Strategy

**Goal**: Implement basic EMA crossover strategy using state machine.

**Strategy Logic**:
- **Entry signal**: Price crosses above EMA(period)
- **Exit signals**:
  - Take profit: +X% from entry
  - Stop loss: -Y% from entry
  - Signal reversal: Price crosses below EMA
- **Risk management**: Configure stop loss and take profit percentages

**Tasks**:
- [ ] Define strategy config (`ema_strategy.ml`):
  ```ocaml
  type config = {
    symbol : string;
    ema_period : int;
    stop_loss_percent : float;     (* e.g., 0.05 = -5% *)
    take_profit_percent : float;   (* e.g., 0.10 = +10% *)
    position_size : float;          (* shares to trade *)
  }
  ```
- [ ] Define strategy state:
  ```ocaml
  type state = {
    config : config;
    active_position : Position.position option;
  }
  ```
- [ ] Implement STRATEGY interface:
  - `init`: Create initial state
  - `on_market_close`:
    - Check for entry signal (no position + price > EMA)
    - Check for exit signals (has position + stop/take/reversal)
    - Generate transitions and orders

**Files**:
- `trading/simulation/lib/ema_strategy.ml`
- `trading/simulation/lib/ema_strategy.mli`

**Success Criteria**:
- Strategy implements STRATEGY interface
- Generates correct entry signals
- Generates correct exit signals
- Uses position state machine

---

### Phase 4: Manual Step Testing

**Goal**: Test strategy behavior through step-by-step scenarios.

**Test Scenarios**:

#### Scenario 1: Take Profit
```
Day 1-29: Price below EMA (no signal)
Day 30: Price crosses above EMA → Enter at $150
Day 31-35: Price rises
Day 36: Price hits $165 (+10%) → Take profit, exit
Result: Position closed with profit
```

#### Scenario 2: Stop Loss
```
Day 30: Price crosses above EMA → Enter at $150
Day 31-33: Price falls
Day 34: Price hits $142.50 (-5%) → Stop loss, exit
Result: Position closed with loss
```

#### Scenario 3: Signal Reversal
```
Day 30: Price crosses above EMA → Enter at $150
Day 35: Price crosses below EMA → Signal reversal, exit at $148
Result: Position closed with small loss
```

#### Scenario 4: Rebalancing (Multiple Positions)
```
Portfolio has 3 positions: AAPL, MSFT, GOOGL
One position (AAPL) underperforming for 10 days
Strategy decides to exit underperforming position
Free up capital for better opportunity
```

#### Scenario 5: Entry Cancellation
```
Day 30: Signal detected, place entry order at $150
Day 31: Price gaps up to $155 (missed entry)
Day 32: Signal reverses (price < EMA) → Cancel entry
Result: No position taken
```

**Test Structure**:
```ocaml
let test_take_profit _ =
  (* Setup: Create price data with uptrend after crossover *)
  let prices = make_price_sequence (* ... with specific pattern ... *) in
  let market_data = MockMarketData.create ~data:[("AAPL", prices)] in

  let config = {
    symbol = "AAPL";
    ema_period = 30;
    stop_loss_percent = 0.05;
    take_profit_percent = 0.10;
    position_size = 100.0;
  } in
  let strategy_state = EmaStrategy.init ~config in

  (* Day 1-29: No signal *)
  let market_data = MockMarketData.advance market_data (Date.of_string "2024-01-29") in
  let result = EmaStrategy.on_market_close
    ~market_data:(module MockMarketData)
    ~market_data_instance:market_data
    ~portfolio:(create_empty_portfolio ())
    ~state:strategy_state
  in
  assert_that result (is_ok_and_holds (fun (output, _) ->
    assert_that output.orders (is_empty)  (* No entry yet *)
  ));

  (* Day 30: Entry signal *)
  let market_data = MockMarketData.advance market_data (Date.of_string "2024-01-30") in
  let result = EmaStrategy.on_market_close ~market_data ~portfolio ~state:strategy_state in
  (* ... assert entry order placed ... *)

  (* Day 36: Take profit triggered *)
  let market_data = MockMarketData.advance market_data (Date.of_string "2024-02-05") in
  (* ... simulate entry filled ... *)
  let result = EmaStrategy.on_market_close ~market_data ~portfolio ~state:strategy_state in
  (* ... assert exit order placed with TakeProfit reason ... *)
```

**Files**:
- `trading/simulation/test/test_ema_strategy.ml`
- `trading/simulation/test/test_scenarios.ml`

**Success Criteria**:
- All 5 scenarios pass
- Transitions are correct for each scenario
- Orders generated match expectations
- Position lifecycle is complete

---

### Phase 5: Variant EMA Strategy

**Goal**: Second strategy with different time scale to prove modularity.

**Variant**: EMA(50) instead of EMA(30)
- Different config: `ema_period = 50`
- Same logic, different signals
- Test that both strategies can coexist

**Tasks**:
- [ ] Create `EmaStrategy50` module (or parameterized factory)
- [ ] Test both strategies in parallel:
  - Same price data
  - Different entry/exit points due to different EMA
  - Verify they don't interfere

**Files**:
- `trading/simulation/test/test_multiple_strategies.ml`

**Success Criteria**:
- Two strategies with different configs work independently
- Same STRATEGY interface
- Different trading decisions on same data

---

## Iteration Plan

### Week 1: State Machine Foundation
- Phase 1: Position state machine core
- Get basic transitions working and tested

### Week 2: Strategy Implementation
- Phase 2: Mock market data
- Phase 3: EMA strategy implementation

### Week 3: Testing & Validation
- Phase 4: Manual step testing (all scenarios)
- Phase 5: Variant strategy
- Bug fixes and refinements

## Success Metrics

**Code Quality**:
- [ ] All types compile
- [ ] All tests pass (target: 30-40 tests)
- [ ] No incomplete pattern matches
- [ ] Clean separation: state machine ↔ strategy ↔ market data

**Functional Correctness**:
- [ ] Position lifecycle works: Entering → Holding → Exiting → Closed
- [ ] Take profit scenario passes
- [ ] Stop loss scenario passes
- [ ] Signal reversal scenario passes
- [ ] Rebalancing scenario passes
- [ ] Entry cancellation scenario passes

**Design Validation**:
- [ ] State machine is easy to reason about
- [ ] Transitions are explicit and debuggable
- [ ] Strategy logic is clear and testable
- [ ] Multiple strategies can coexist

## Next Steps After MVP

Once MVP is validated:
1. Integrate with full simulator (Phase 4b in original plan)
2. Implement data processing pipeline for real backtests
3. Add more strategies (Mean Reversion, Momentum, etc.)
4. Add staged entry/exit execution plans
5. Performance optimization

## Open Questions for MVP

1. **Portfolio integration**: How does strategy query current positions?
   - **Proposal**: Portfolio.get_position returns position or None
   - Strategy checks portfolio to know if position exists

2. **Order conversion**: Who converts position transitions to orders?
   - **Proposal**: Strategy does it in on_market_close
   - Returns both transitions (for state updates) and orders (for execution)

3. **Fill simulation**: In tests, how do we simulate order fills?
   - **Proposal**: Manual in tests - apply EntryFill transition with test data
   - Later: integrate with engine's execution logic

4. **Multiple positions**: MVP focuses on single position - when to add multi-position?
   - **Proposal**: After MVP validated, add in Phase 4b
   - Rebalancing scenario can test exit logic even with single position

## Implementation Status & Architecture

### ✅ Completed Phases

All MVP phases have been completed with some architectural improvements:

**Phase 1: Position State Machine** ✅
- Implemented in `trading/strategy/lib/position.ml`
- Simplified transitions (removed PlaceEntryOrder/PlaceExitOrder)
- Strategies directly create EntryFill/ExitFill transitions (simulating instant fills)
- All states and transitions working with validation

**Phase 2: Mock Market Data** ✅
- Implemented in `trading/strategy/test/mock_market_data.ml`
- Price generators with trend support
- Pre-computed EMA indicators
- Date advancement support

**Phase 3 & 4: EMA Strategy with Tests** ✅
- Implemented in `trading/strategy/lib/ema_strategy.ml`
- Also: `buy_and_hold_strategy.ml` (baseline strategy)
- Multi-symbol support (not just single symbol)
- Immutable Map-based state (not Hashtbl)
- All test scenarios passing

**Phase 5: Multiple Strategies** ✅
- Test suite validates multiple strategies with different configs
- Strategy polymorphic dispatch via `Strategy.t` GADT

**Additional Work Completed:**
- **Order Generator** (`trading/strategy/lib/order_generator.ml`)
  - Separates strategy decisions from order execution
  - Converts transitions to orders
- **Separation of concerns**: Strategies return only transitions (not orders)

### Two Types of Positions: Strategy vs Portfolio

The system maintains **two separate position types** serving different purposes:

#### 1. Strategy Position (`Trading_strategy.Position.t`)

**Purpose:** Tracks the *decision-making lifecycle* of a trade

**Located:** `trading/strategy/lib/position.ml`

**Key Responsibilities:**
- **Lifecycle State Machine:** Entering → Holding → Exiting → Closed
- **Entry Reasoning:** Why we entered (TechnicalSignal, PricePattern, etc.)
- **Exit Conditions:** When to exit (stop_loss, take_profit, max_hold_days)
- **Exit Reasoning:** Why we exited (TakeProfit, StopLoss, SignalReversal)
- **Performance Tracking:** gross_pnl, days_held
- **Unique ID:** Each strategy decision gets unique position ID

**State Structure:**
```ocaml
type holding_state = {
  id : string;                      (* "AAPL-pos-1" *)
  symbol : string;
  quantity : float;
  entry_price : float;              (* Average entry: $150.00 *)
  entry_date : Date.t;
  entry_reasoning : entry_reasoning;
  risk_params : risk_params;        (* Exit conditions *)
}

type risk_params = {
  stop_loss_price : float option;     (* $142.50 = -5% *)
  take_profit_price : float option;   (* $165.00 = +10% *)
  max_hold_days : int option;
}
```

**Example:** *"I bought AAPL at $150 based on EMA crossover, will exit at $165 (take profit) or $142 (stop loss)"*

#### 2. Portfolio Position (`Trading_portfolio.Types.portfolio_position`)

**Purpose:** Tracks the *accounting* of holdings

**Located:** `trading/portfolio/lib/types.mli`

**Key Responsibilities:**
- **Holdings Tracking:** What we own (consolidated across all strategies)
- **Cost Basis:** Per-lot cost basis including commissions
- **Accounting Method:** FIFO vs AverageCost for tax reporting
- **Lot Management:** Multiple lots with different acquisition dates
- **Aggregation by Symbol:** One position per symbol, regardless of source

**Structure:**
```ocaml
type portfolio_position = {
  symbol : string;
  lots : position_lot list;          (* Multiple lots *)
  accounting_method : accounting_method;
}

type position_lot = {
  lot_id : string;                   (* "AAPL-lot-1" *)
  quantity : float;                  (* 60.0 shares *)
  cost_basis : float;                (* $9,015 total cost *)
  acquisition_date : Date.t;
}
```

**Example:** *"I own 100 AAPL shares in 2 lots: 60 shares acquired 2024-01-15 at $9,015 cost, 40 shares acquired 2024-01-18 at $6,020 cost"*

#### Key Difference: One-to-Many Relationship

**Multiple strategy positions can map to a single portfolio position:**

```
Strategy A: Position "AAPL-1" (50 shares, entry $150)  ┐
                                                        ├──▶ Portfolio: AAPL
Strategy B: Position "AAPL-2" (50 shares, entry $152)  ┘    (100 shares, 2 lots)
```

- Strategy positions: Independent per signal/strategy
- Portfolio position: Aggregated holdings per symbol

### Execution Flow: How Positions Are Updated

#### Current Flow (Test Mode)

Strategies currently simulate instant fills for testing:

```ocaml
(* In ema_strategy.ml:_process_symbol *)

(* 1. Strategy detects entry signal *)
let position = Position.create_entering
  ~id:"AAPL-pos-1"
  ~symbol:"AAPL"
  ~target_quantity:100.0
  ~entry_price:150.0
  ~reasoning:(TechnicalSignal { indicator = "EMA"; ... })

(* 2. Strategy simulates fill *)
let fill_transition = Position.EntryFill {
  position_id = "AAPL-pos-1";
  filled_quantity = 100.0;
  fill_price = 150.0;
  fill_date = today;
}
let position_filled = Position.apply_transition position fill_transition

(* 3. Strategy completes entry *)
let complete_transition = Position.EntryComplete {
  position_id = "AAPL-pos-1";
  risk_params = { stop_loss = Some 142.50; take_profit = Some 165.00; ... };
}
let position_holding = Position.apply_transition position_filled complete_transition

(* 4. Strategy returns transitions *)
return (
  { transitions = [fill_transition; complete_transition] },
  { config; positions = Map.set positions ~key:"AAPL" ~data:position_holding }
)
```

**What's Updated:**
- ✅ Strategy Position: Entering → Holding (state machine advanced)
- ❌ Portfolio Position: NOT updated (strategies don't modify portfolio)

**Gap:** Portfolio integration missing - `~portfolio:_` parameter is ignored.

#### Proposed Flow (With Simulator Integration)

When integrated with simulator:

**Step 1: Strategy Generates Decisions**
```ocaml
let output, new_strategy_state =
  Strategy.execute strategy ~market_data ~portfolio ~state
in
(* output.transitions = [EntryFill, EntryComplete] *)
(* Strategy Position: Entering → Holding *)
```

**Step 2: Convert Transitions to Orders**
```ocaml
let orders = Order_generator.from_transitions
  ~positions:new_strategy_state.positions
  ~transitions:output.transitions
in
(* orders = [{ symbol="AAPL"; side=Buy; quantity=100.0; price=Limit 150.0 }] *)
```

**Step 3: Submit Orders to Simulator**
```ocaml
Simulator.submit_orders simulator orders
```

**Step 4: Simulator Advances One Day**
```ocaml
(* simulator.ml:step *)
let step simulator =
  let today_bars = _get_today_bars simulator in
  Engine.update_market simulator.engine today_bars;

  (* Engine fills orders based on price paths *)
  let execution_reports =
    Engine.process_orders simulator.engine simulator.order_manager
  in

  (* Extract trades from filled orders *)
  let trades = _extract_trades execution_reports in
  (* trades = [{ symbol="AAPL"; side=Buy; quantity=100.0; price=150.25; ... }] *)

  (* Apply trades to portfolio *)
  let updated_portfolio =
    Portfolio.apply_trades simulator.portfolio trades
  in

  return (Stepped (updated_simulator, step_result))
```

**Step 5: Portfolio Gets Updated**
```ocaml
(* Inside Portfolio.apply_trades *)
(* Cash: $100,000 → $84,974 *)
(* Position: New AAPL lot (100 shares, cost $15,026 including commission) *)
```

### Complete Timeline Example

**Day 1 (2024-01-15):**

1. **Market Close:** `Strategy.on_market_close` called
   - Detects: Price $150.25 > EMA $145.00
   - Decision: Enter position
   - Updates strategy position: `None` → `Holding "AAPL-pos-1"`
   - Returns: `[EntryFill, EntryComplete]`

2. **After Close:** Order_generator converts to orders
   - Order: Buy 100 AAPL @ Limit $150.25

3. **After Close:** Order submitted to simulator

4. **Next Morning:** Engine processes order
   - Generates price path from OHLC
   - Fills order at $150.25
   - Creates trade

5. **Portfolio Updated:**
   - Cash: $100,000 → $84,974
   - Position: AAPL lot (100 shares, cost $15,026)

**Day 7 (2024-01-22):**

1. **Market Close:** Strategy detects take profit
   - Price $165.50 ≥ Target $165.00
   - Updates strategy position: `Holding` → `Closed`
   - Returns: `[TriggerExit, ExitFill, ExitComplete]`

2. **After Close:** Order generated
   - Order: Sell 100 AAPL @ Limit $165.00

3. **Next Morning:** Engine fills
   - Fill: $165.50

4. **Portfolio Updated:**
   - Cash: $84,974 → $101,523
   - Position: AAPL lot closed
   - Trade history: Realized P&L = $1,497

### Module Boundaries

**Trading_strategy Module** (Decision making)
- Position state machine
- Strategy logic
- Transition generation
- Order_generator (transitions → orders)

**Trading_portfolio Module** (Accounting)
- Holdings tracking with lots
- Cost basis and P&L calculation
- Cash management
- Trade history

**Trading_simulation Module** (Orchestration)
- Daily simulation loop
- Order execution via Engine
- Trade application to Portfolio
- Strategy integration (calls `Strategy.on_market_close` each day)

### Completed Integration ✅

The following items have been fully implemented:

1. **Simulator ↔ Strategy Integration** ✅
   - Simulator calls `Strategy.on_market_close` each simulation day
   - Strategies receive `get_price` and `get_indicator` functions
   - Strategies return transitions which are applied to positions

2. **Full Execution Loop** ✅
   - Complete flow: Strategy → Transitions → Orders → Engine → Trades → Portfolio
   - Verified by E2E tests (`test_e2e_integration.ml`)
   - EMA strategy runs on real CSV data with actual trades

### Design Rationale

**Why Two Position Types?**

- **Separation of Concerns:** Trading logic (WHY/WHEN) vs Accounting (WHAT/HOW MUCH)
- **Different Lifecycles:** Strategy positions per signal, Portfolio positions aggregated
- **Different Consumers:** Strategy logic vs reporting/tax calculations

**Why Transitions Instead of Direct Orders?**

- **Audit Trail:** Every position change is explicit event
- **Flexibility:** Strategy decides WHAT, Order_generator decides HOW
- **Testability:** Test strategy logic independently from execution
- **Separation:** Decisions vs execution details vs market reality

## Summary

**MVP delivers**:
- ✅ Working position state machine
- ✅ EMA strategy that makes real trading decisions
- ✅ Comprehensive test scenarios
- ✅ Proof that design works before full integration
- ✅ Order generation separation (transitions → orders)
- ✅ Multi-symbol support with immutable state
- ✅ Clear understanding of Strategy vs Portfolio positions
- ✅ Full simulator ↔ strategy integration
- ✅ E2E tests with real CSV data

**Approach**: Build bottom-up, test thoroughly at each level, validate design with real scenarios.

**Status**: MVP complete. Full end-to-end execution loop is working.

## Next Steps

With the MVP complete, potential next steps include:

1. **Add more strategies** - Mean Reversion, Momentum, etc.
2. **Staged entry/exit** - Scale in/out of positions over multiple orders
3. **More indicators** - RSI, MACD, Bollinger Bands
4. **Performance optimization** - Profiling and optimization for large backtests
5. **Enhanced metrics** - Win rate by strategy, risk-adjusted returns, etc.
