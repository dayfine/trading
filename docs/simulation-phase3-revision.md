# Simulation Phase 3 Revision: Engine-Centric Execution Model

## Status
**Planning** - Architecture revision before implementation

## Problem Statement

The current Phase 3 implementation has architectural issues:

1. **Execution logic in wrong place**: Simulator uses `Price_path.would_fill()` to determine order execution, but this should be the engine's responsibility
2. **Stop orders not properly modeled**: Stop orders should be conditional triggers (if stop met → execute market/limit), not direct execution
3. **Price path as simulator concern**: Price path handling should be internal to the engine, not exposed to the simulator
4. **Unnecessary abstraction**: Using bid/ask price quotes for backtesting when we just need sequential price points

## Proposed Architecture

### Core Principles

1. **Separation of Concerns**:
   - Price path generation (data transformation) ≠ Price path execution (business logic)
   - Simulator orchestrates, Engine executes

2. **Engine owns execution logic**:
   - Engine processes price data sequentially
   - Engine tracks stop order states
   - Engine decides when orders fill

3. **Mini-bars as execution unit**:
   - Daily OHLC → series of mini-bars (simple O/C points)
   - Engine processes mini-bars incrementally
   - Engine retains state across mini-bars

## Mini-Bar Model

### Type Definition

```ocaml
(** A mini-bar represents a point-to-point price movement within a trading day *)
type mini_bar = {
  time_fraction : float;  (** 0.0 = market open, 1.0 = market close *)
  open_price : float;     (** Price at start of this segment *)
  close_price : float;    (** Price at end of this segment *)
}
[@@deriving show, eq]

(** Intraday path as a sequence of mini-bars *)
type intraday_path = mini_bar list
```

### Generation from OHLC

Transform daily OHLC bar into sequence of mini-bars that touches all price points:

```
Daily OHLC: { O=100, H=105, L=95, C=102 }

Generated mini-bars (deterministic path):
1. { time=0.00, open=100, close=100 }  (* Market open *)
2. { time=0.25, open=100, close=105 }  (* Move to High *)
3. { time=0.50, open=105, close=95  }  (* Move to Low *)
4. { time=0.75, open=95,  close=102 }  (* Move to Close *)
5. { time=1.00, open=102, close=102 }  (* Market close *)
```

**Path selection logic**:
- If Close > Open: O → H → L → C (upward day)
- If Close < Open: O → L → H → C (downward day)
- If Close = Open: O → H → L → C (default)

### Why Mini-Bars?

- **Simplicity**: Just open/close prices, no bid/ask complexity
- **Sequential processing**: Engine can process incrementally
- **Realistic execution**: Orders execute as price moves through path
- **Stop order support**: Engine can detect stop triggers between bars

## Stop Order State Machine

### Order State Tracking

```ocaml
(** Stop order states tracked by engine *)
type stop_order_state = {
  order_id : string;
  stop_price : float;
  triggered : bool;
  triggered_at : float option;  (** time_fraction when triggered *)
}
```

### State Transitions

**Stop Buy Order**:
```
State: NotTriggered
Condition: price >= stop_price
Action: Convert to Market Buy order
```

**Stop Sell Order**:
```
State: NotTriggered
Condition: price <= stop_price
Action: Convert to Market Sell order
```

**Stop Limit Buy**:
```
State: NotTriggered
Condition: price >= stop_price
Action: Convert to Limit Buy order (at limit price)
```

**Stop Limit Sell**:
```
State: NotTriggered
Condition: price <= stop_price
Action: Convert to Limit Sell order (at limit price)
```

### Processing Logic

For each mini-bar:
1. Check if any stop orders trigger (stop condition met)
2. Convert triggered stop orders to market/limit orders
3. Execute market/limit orders if conditions met
4. Update order states
5. Generate trades for filled orders

## Component Responsibilities

### Price_path Module (`trading/simulation/lib/price_path.ml`)

**Responsibility**: Data transformation only

```ocaml
(** Generate intraday path from daily OHLC *)
val generate_mini_bars : Types.Daily_price.t -> mini_bar list

(** No more execution logic like would_fill *)
```

**What it does**:
- ✅ Convert daily OHLC to mini-bar sequence
- ✅ Ensure path touches all price points (O, H, L, C)
- ✅ Deterministic path generation

**What it doesn't do**:
- ❌ Determine if orders fill
- ❌ Calculate fill prices
- ❌ Track order states

### Engine Module (`trading/engine/lib/engine.ml`)

**Responsibility**: Order execution logic

```ocaml
(** Process a single mini-bar, updating order states and generating trades *)
val process_mini_bar :
  t ->
  order_manager ->
  mini_bar ->
  execution_report list status_or

(** Or batch version *)
val process_mini_bars :
  t ->
  order_manager ->
  mini_bar list ->
  execution_report list status_or
```

**What it does**:
- ✅ Process mini-bars sequentially
- ✅ Track stop order states
- ✅ Convert stop orders when triggered
- ✅ Execute market/limit orders
- ✅ Calculate fill prices and commissions
- ✅ Generate trades and execution reports
- ✅ Update order statuses in order manager

**Internal state**:
- Stop order trigger states
- Current mini-bar being processed
- Accumulated trades for the day

### Simulator Module (`trading/simulation/lib/simulator.ml`)

**Responsibility**: Orchestration

```ocaml
let step t =
  (* 1. Get daily OHLC data *)
  let daily_price = get_price_for_date t.deps t.current_date in

  (* 2. Generate mini-bars *)
  let mini_bars = Price_path.generate_mini_bars daily_price in

  (* 3. Process mini-bars through engine *)
  let execution_reports =
    Engine.process_mini_bars
      t.deps.engine
      t.deps.order_manager
      mini_bars
  in

  (* 4. Extract trades *)
  let trades =
    List.concat_map execution_reports ~f:(fun r -> r.trades)
  in

  (* 5. Apply trades to portfolio *)
  let updated_portfolio =
    Portfolio.apply_trades t.portfolio trades
  in

  Ok (Stepped ({ t with portfolio = updated_portfolio }, step_result))
```

**What it does**:
- ✅ Get historical price data
- ✅ Generate mini-bars from OHLC
- ✅ Feed mini-bars to engine
- ✅ Collect execution results
- ✅ Apply trades to portfolio

**What it doesn't do**:
- ❌ Determine order execution
- ❌ Track stop states
- ❌ Calculate fill prices

## Implementation Plan

### Phase 1: Mini-Bar Foundation

**Files to modify**:
- `trading/simulation/lib/price_path.mli`
- `trading/simulation/lib/price_path.ml`
- `trading/simulation/test/test_price_path.ml`

**Changes**:
1. Define `mini_bar` type
2. Implement `generate_mini_bars : Daily_price.t -> mini_bar list`
3. Remove `would_fill` function (move logic to engine)
4. Update tests to validate mini-bar generation

**Testing**:
- Generate mini-bars from various OHLC patterns
- Verify all price points (O, H, L, C) are touched
- Verify deterministic path selection

### Phase 2: Engine Mini-Bar Processing

**Files to modify**:
- `trading/engine/lib/engine.mli`
- `trading/engine/lib/engine.ml`
- `trading/engine/lib/types.mli` (add mini_bar)
- `trading/engine/test/test_engine.ml`

**Changes**:
1. Add mini-bar type to engine types
2. Implement stop order state tracking
3. Implement `process_mini_bar` or `process_mini_bars`
4. Update order execution logic:
   - Check stop triggers
   - Convert stop → market/limit
   - Execute market orders at close price
   - Execute limit orders if price crosses limit
5. Remove dependency on price_quote for backtesting

**Testing**:
- Stop buy triggers and converts to market
- Stop sell triggers and converts to market
- Stop limit triggers and converts to limit
- Market order execution at mini-bar close
- Limit order execution when price crosses
- Sequential processing across multiple mini-bars

### Phase 3: Simulator Integration

**Files to modify**:
- `trading/simulation/lib/simulator.ml`
- `trading/simulation/test/test_simulator.ml`

**Changes**:
1. Remove Price_path.would_fill usage
2. Update step logic:
   - Generate mini-bars
   - Call engine.process_mini_bars
   - Extract trades from execution reports
3. Update tests for new flow

**Testing**:
- Market orders execute correctly
- Limit orders execute when price met
- Stop orders trigger and execute
- Multi-day simulation works
- Portfolio updates correctly

### Phase 4: Documentation & Cleanup

**Files to modify**:
- `trading/simulation/README.md`
- `docs/architecture.md`

**Changes**:
1. Update README with new architecture
2. Document mini-bar model
3. Document stop order handling
4. Remove old Price_path.would_fill references

## API Design Decisions

### Question 1: Mini-Bar Granularity

**Option A: Fixed 5-point path** (current proposal)
```ocaml
(* O → H → L → C with intermediate points *)
[ {time=0.0; open=O; close=O};
  {time=0.25; open=O; close=H};
  {time=0.5; open=H; close=L};
  {time=0.75; open=L; close=C};
  {time=1.0; open=C; close=C} ]
```
- ✅ Simple and deterministic
- ✅ Sufficient for most order types
- ❌ Fixed granularity

**Option B: Parameterized granularity**
```ocaml
val generate_mini_bars :
  ?granularity:int ->
  Daily_price.t ->
  mini_bar list
```
- ✅ Flexible for future needs
- ❌ More complex
- ❌ YAGNI (not needed yet)

**Decision**: Start with Option A (fixed 5-point path), can extend later

### Question 2: Engine API - Incremental vs Batch

**Option A: Incremental processing**
```ocaml
val process_mini_bar :
  t ->
  order_manager ->
  mini_bar ->
  execution_report list status_or
```
- ✅ More control for caller
- ✅ Can inspect state between bars
- ❌ More boilerplate in simulator

**Option B: Batch processing**
```ocaml
val process_mini_bars :
  t ->
  order_manager ->
  mini_bar list ->
  execution_report list status_or
```
- ✅ Simpler caller code
- ✅ Engine handles sequencing
- ❌ Less visibility into intermediate state

**Decision**: Option B (batch) - simpler for simulator, engine controls sequencing

### Question 3: Stop State Persistence

**Option A: Engine internal state**
```ocaml
type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
  stop_states : (order_id, stop_order_state) Hashtbl.t;  (* New *)
}
```
- ✅ Engine owns execution logic
- ✅ Encapsulated state
- ❌ State tied to engine instance

**Option B: OrderManager extension**
```ocaml
(* Add stop_triggered field to order *)
type order = {
  ...existing fields...
  stop_triggered : bool;
  stop_triggered_at : Time_ns_unix.t option;
}
```
- ✅ Persisted with order
- ✅ Visible in order history
- ❌ Leaks execution details into data layer

**Decision**: Option A (engine internal) - execution state belongs in engine

## Migration Strategy

### Backward Compatibility

During transition:
1. Keep old `Price_path.would_fill` temporarily with deprecation notice
2. Add new mini-bar API alongside
3. Update tests incrementally
4. Remove old API once migration complete

### Testing Strategy

1. **Unit tests**: Each component in isolation
   - Price_path generates correct mini-bars
   - Engine processes mini-bars correctly
   - Stop orders trigger properly

2. **Integration tests**: End-to-end scenarios
   - Simulator → Price_path → Engine → Portfolio
   - Multi-day simulations
   - Various order types

3. **Regression tests**: Existing tests should still pass
   - Same fills as before (deterministic)
   - Same portfolio outcomes

## Benefits of New Architecture

1. **Proper separation of concerns**:
   - Price path = data transformation
   - Engine = execution logic
   - Simulator = orchestration

2. **Engine owns execution**:
   - Stop order logic in engine (where it belongs)
   - Consistent with live trading flow
   - Single source of truth

3. **Simpler model**:
   - No bid/ask complexity for backtesting
   - Mini-bars are intuitive (just price movement)
   - Sequential processing is easy to reason about

4. **Extensibility**:
   - Easy to add more order types
   - Can adjust granularity later
   - Can add execution algorithms

5. **Testing**:
   - Each component testable independently
   - Clear contracts between modules
   - Easier to validate correctness

## Open Questions

1. **Commission timing**: Apply on each mini-bar fill or once at end of day?
2. **Partial fills**: Support for future (currently not needed)?
3. **Slippage modeling**: Add random slippage to fills?
4. **Performance**: Process all mini-bars or short-circuit when no pending orders?

## Success Criteria

- [ ] Mini-bars correctly generated from OHLC
- [ ] Engine processes mini-bars sequentially
- [ ] Stop orders trigger and convert correctly
- [ ] Market orders execute at appropriate price
- [ ] Limit orders execute when price crosses
- [ ] All existing tests pass (regression)
- [ ] New tests cover stop order scenarios
- [ ] Documentation updated
- [ ] Code is cleaner and more maintainable

## Timeline

This is a significant refactoring. Estimated effort:
- Phase 1 (Mini-bar foundation): ~2-3 hours
- Phase 2 (Engine processing): ~4-6 hours
- Phase 3 (Simulator integration): ~2-3 hours
- Phase 4 (Documentation): ~1-2 hours

**Total**: ~10-15 hours of focused development

## References

- Current code: `trading/simulation/lib/price_path.ml`
- Architecture doc: `docs/architecture.md`
- Engine implementation: `trading/engine/lib/engine.ml`
