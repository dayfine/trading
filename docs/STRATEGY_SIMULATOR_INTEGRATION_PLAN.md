# Strategy-Simulator Integration Plan

## Goal
Integrate the strategy system into the simulator to enable end-to-end backtesting with real strategies (EMA crossover, buy-and-hold).

## User Preferences
- ✅ Include EMA indicators from the start
- ✅ Create a proper order_generator module
- ✅ Track position state directly in simulator

## Overview
Break the integration into 8 small, incremental changes. Each change is independently compilable and testable.

---

## Change 1: Create Market Data Adapter (Price Only) ✅

**Status**: COMPLETED

**Goal**: Build adapter to convert simulator's price data into strategy-compatible format.

**Files created**:
- `trading/trading/simulation/lib/market_data_adapter.mli`
- `trading/trading/simulation/lib/market_data_adapter.ml`
- `trading/trading/simulation/test/test_market_data_adapter.ml`

**Tests**: 7 tests passing

---

## Change 2: Add EMA Indicator Computation

**Goal**: Enable `get_indicator` to compute and cache EMA values.

**Why second**: Strategies need EMA. Builds on Change 1 by enhancing the adapter.

### Files to modify:
- `trading/trading/simulation/lib/market_data_adapter.ml` (enhance)
- `trading/trading/simulation/test/test_market_data_adapter.ml` (add tests)

### Dependencies to add:
- Link to `Ema` module from `analysis/technical/indicators/ema`

### Implementation:
- Add `ema_cache : (string * int, (Date.t * float) list) Hashtbl.Poly.t` to record
- Implement `get_indicator`:
  - Parse indicator name: "EMA" (case-insensitive)
  - Check cache for (symbol, period)
  - If not cached: compute using `Ema.calculate_ema`, store in cache
  - Return value for current_date
- Helper: `_compute_ema : t -> symbol -> period -> (Date.t * float) list`
- Helper: `_get_price_history : t -> symbol -> end_date -> Daily_price.t list`

### Key insight from Mock_market_data:
```ocaml
(* Convert prices to indicator_values *)
let prices_to_indicator_values prices =
  List.map prices ~f:(fun p ->
    { Indicator_types.date = p.date; value = p.close_price })

(* Use real Ema module *)
let ema_results = Ema.calculate_ema indicator_values period
```

### Tests to add (4-5 tests):
- `get_indicator` with "EMA" returns correct value
- `get_indicator` caches computation (verify cache hit)
- `get_indicator` returns None for invalid indicator name
- `get_indicator` returns None for insufficient history
- `get_indicator` works for multiple symbols independently

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 3: Create Order Generator Module

**Goal**: Convert Position.transition to Trading_orders.Types.order.

**Why third**: Second foundation piece. Independent of simulator changes.

### Files to create:
- `trading/trading/simulation/lib/order_generator.mli`
- `trading/trading/simulation/lib/order_generator.ml`
- `trading/trading/simulation/test/test_order_generator.ml`

### Key insight:
Strategies produce transitions like `CreateEntering` and `TriggerExit`. The order generator converts these to actual orders.

### Interface:
```ocaml
val transitions_to_orders :
  Position.transition list ->
  Trading_orders.Types.order list Status.status_or
```

### Implementation:
- Map `CreateEntering` → Buy Market order
  - Extract: symbol, target_quantity from transition
  - Create order with status=Pending
- Map `TriggerExit` → Sell Market order
  - Need to find position to get quantity
  - Extract: symbol, quantity from position state
- Other transitions don't create orders (they update position state)
- Helper: `_create_market_order : symbol -> side -> quantity -> order`

### Tests (5-6 tests):
- `CreateEntering` → Buy order with correct symbol/quantity
- `TriggerExit` → Sell order with correct symbol/quantity
- Empty transitions list → empty orders list
- Mixed transitions → only CreateEntering/TriggerExit produce orders
- Invalid transition data → Error

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 4: Add Position Tracking to Simulator

**Goal**: Extend simulator state to track positions without changing behavior.

**Why fourth**: Data structure change before behavior change. Safe and testable.

### Files to modify:
- `trading/trading/simulation/lib/simulator.ml`
- `trading/trading/simulation/test/test_simulator.ml`

### Changes:
```ocaml
type t = {
  (* existing fields *)
  positions : Position.t String.Map.t;  (* NEW *)
}
```

- Initialize to `String.Map.empty` in `create`
- Add getters (no setters yet - we'll update in later changes):
  - `get_position : t -> string -> Position.t option`
  - `get_all_positions : t -> Position.t String.Map.t`

### Tests (3-4 tests):
- `create` initializes empty positions map
- `get_position` returns None for non-existent symbol
- `get_all_positions` returns empty map initially
- Existing simulator tests still pass (no regression)

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 5: Add Strategy Field and Invocation (Read-Only)

**Goal**: Call strategy on each step but don't execute orders yet. Log transitions.

**Why fifth**: Adds strategy invocation without changing execution. Can verify strategy is called correctly.

### Files to modify:
- `trading/trading/simulation/lib/simulator.ml`
- `trading/trading/simulation/test/test_simulator.ml`

### Changes to simulator:
```ocaml
type t = {
  (* existing fields *)
  positions : Position.t String.Map.t;
  strategy : (module Strategy_interface.STRATEGY) option;  (* NEW *)
}
```

- Add `strategy` parameter to `create` (optional)
- In `step`, after updating engine with bars, before processing orders:

```ocaml
let _call_strategy t =
  match t.strategy with
  | None -> Status.ok []
  | Some (module S) ->
      (* Create market data accessor functions *)
      let adapter = Market_data_adapter.create
        ~prices:t.deps.prices
        ~current_date:t.current_date
      in
      let get_price sym = Market_data_adapter.get_price adapter sym in
      let get_indicator sym name period =
        Market_data_adapter.get_indicator adapter sym name period
      in

      (* Call strategy *)
      let%bind output = S.on_market_close
        ~get_price
        ~get_indicator
        ~positions:t.positions
      in

      (* Log transitions but don't execute *)
      List.iter output.transitions ~f:(fun trans ->
        Logs.debug (fun m -> m "Strategy transition: %a"
          Position.pp_transition trans)
      );

      Status.ok output.transitions
```

### Tests (4-5 tests):
- Step calls strategy when provided
- Step works without strategy (None)
- Strategy receives correct prices via get_price
- Strategy receives correct indicators via get_indicator
- Transitions are logged but portfolio unchanged

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 6: Generate and Submit Orders from Transitions

**Goal**: Convert strategy transitions to orders and submit to order_manager.

**Why sixth**: Connect strategy output to order execution. Builds on Changes 3 and 5.

### Files to modify:
- `trading/trading/simulation/lib/simulator.ml`
- `trading/trading/simulation/test/test_simulator.ml`

### Changes to step:
```ocaml
let step t =
  (* ... existing: get bars, update engine ... *)

  (* Call strategy and get transitions *)
  let%bind transitions = _call_strategy t in

  (* NEW: Convert transitions to orders *)
  let%bind orders = Order_generator.transitions_to_orders transitions in

  (* NEW: Submit orders to order_manager *)
  let t = List.fold orders ~init:t ~f:(fun t order ->
    { t with order_manager =
        Trading_orders.Manager.submit_orders t.order_manager [order] }
  ) in

  (* ... existing: process orders, apply trades ... *)
```

### Tests (5-6 tests):
- Strategy transitions → orders created
- Orders submitted to order_manager
- Multiple transitions → multiple orders
- No transitions → no orders
- Orders have correct symbol/side/quantity
- Portfolio reflects executed trades

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 7: Update Position States from Execution

**Goal**: Close the loop by updating position states based on fills.

**Why seventh**: Final piece. Ensures strategies see current position states.

### Files to modify:
- `trading/trading/simulation/lib/simulator.ml`
- `trading/trading/simulation/test/test_simulator.ml`

### Implementation:
After trades are extracted from execution_reports, update positions:

```ocaml
let _update_positions_from_fills t trades transitions =
  (* For each CreateEntering transition that resulted in a fill *)
  List.fold transitions ~init:t ~f:(fun t trans ->
    match trans.kind with
    | Position.CreateEntering { symbol; target_quantity; entry_price; reasoning } ->
        (* Check if trade executed for this symbol *)
        (match List.find trades ~f:(fun tr -> String.equal tr.symbol symbol) with
        | Some trade when phys_equal trade.side Buy ->
            (* Create position in Entering state *)
            let pos_result = Position.create_entering trans in
            (match pos_result with
            | Ok pos ->
                (* Apply EntryFill *)
                let fill_trans = {
                  position_id = pos.id;
                  date = t.current_date;
                  kind = EntryFill {
                    filled_quantity = trade.quantity;
                    fill_price = trade.price
                  }
                } in
                let pos = Position.apply_transition pos fill_trans |> Status.ok_exn in

                (* Apply EntryComplete to move to Holding *)
                let complete_trans = {
                  position_id = pos.id;
                  date = t.current_date;
                  kind = EntryComplete {
                    risk_params = {
                      stop_loss_price = None;
                      take_profit_price = None;
                      max_hold_days = None
                    }
                  }
                } in
                let pos = Position.apply_transition pos complete_trans |> Status.ok_exn in

                (* Store position *)
                { t with positions = String.Map.set t.positions ~key:symbol ~data:pos }
            | Error _ -> t)
        | _ -> t)

    | Position.TriggerExit { exit_reason; exit_price } ->
        (* Similar logic for exits *)
        (* ... *)

    | _ -> t
  )
```

### Tests (6-8 tests):
- CreateEntering + fill → position in Holding state
- TriggerExit + fill → position in Closed state
- Positions persist across steps
- Multiple positions tracked independently
- Position state visible to strategy on next step
- End-to-end: strategy creates position, sees it next day

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
```

---

## Change 8: Integration Test with Real Strategy

**Goal**: End-to-end test with EMA strategy over multiple days.

**Why last**: Validates entire integration with realistic scenario.

### File to create:
- `trading/trading/simulation/test/test_strategy_integration.ml`

### Test scenarios:
1. **EMA crossover test** (20 days):
   - Days 1-10: Price below EMA → no position
   - Day 11: Price crosses above EMA → enter
   - Days 12-20: Position held
   - Verify: Position created, portfolio value changed

2. **Buy and hold test** (15 days):
   - Day 1: Enter position
   - Days 2-15: Hold
   - Verify: Single position, held throughout

3. **Multi-symbol test**:
   - AAPL and GOOGL with different price patterns
   - Verify: Independent positions

### Test structure:
```ocaml
let%test_unit "ema_crossover_integration" =
  (* Create price data with crossover pattern *)
  let prices = Test_helpers.Price_generators.make_price_sequence
    ~symbol:"TEST" ~start_date ~days:20
    ~base_price:100.0 ~trend:(Uptrend 1.0) ~volatility:0.01
  in

  (* Create simulator with EMA strategy *)
  let sim = Simulator.create
    ~config
    ~deps:{ prices = [{ symbol = "TEST"; prices }] }
    ~strategy:(Some (module Ema_strategy))
  in

  (* Run for 20 days *)
  let final_sim = run_for_days sim 20 in

  (* Verify position created and portfolio changed *)
  assert_that (Simulator.get_position final_sim "TEST") is_some;
  assert_that final_sim.portfolio.current_cash (is_less_than 100000.0)
```

### Verify:
```bash
dune build
dune runtest trading/simulation/test/
dune runtest  # Run all tests
```

---

## Critical Files

### To create:
1. `trading/trading/simulation/lib/market_data_adapter.{ml,mli}` ✅ - Bridge simulator data to strategy interface
2. `trading/trading/simulation/lib/order_generator.{ml,mli}` - Convert transitions to orders
3. Test files for each module

### To modify:
1. `trading/trading/simulation/lib/simulator.ml` - Add strategy invocation and position tracking
2. `trading/trading/simulation/lib/dune` - Add dependencies (ema, trading_strategy)

### Dependencies:
- Strategy system: `trading/trading/strategy/`
- Position state machine: `trading/trading/strategy/lib/position.ml`
- EMA indicators: `trading/analysis/technical/indicators/ema/`
- Order types: `trading/trading/orders/lib/types.ml`

---

## Development Workflow (Per Change)

1. **Design interface** (.mli) - types, function signatures, docs
2. **Write failing tests** - TDD approach, use matchers library
3. **Implement** (.ml) - make tests pass, keep functions small
4. **Build & test** - `dune build && dune runtest`
5. **Review** - check for duplication, naming, abstraction
6. **Format** - `dune fmt`

---

## Success Criteria

After all changes:
- ✅ Simulator accepts strategy as parameter
- ✅ Strategy called on each step with correct market data
- ✅ EMA indicators computed and cached
- ✅ Transitions converted to orders
- ✅ Orders executed by engine
- ✅ Position states updated after fills
- ✅ Full integration tests pass
- ✅ All existing tests still pass (no regression)

---

## Progress Tracker

- [x] Change 1: Create Market Data Adapter (Price Only)
- [ ] Change 2: Add EMA Indicator Computation
- [ ] Change 3: Create Order Generator Module
- [ ] Change 4: Add Position Tracking to Simulator
- [ ] Change 5: Add Strategy Field and Invocation (Read-Only)
- [ ] Change 6: Generate and Submit Orders from Transitions
- [ ] Change 7: Update Position States from Execution
- [ ] Change 8: Integration Test with Real Strategy
