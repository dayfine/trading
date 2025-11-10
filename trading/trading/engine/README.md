# Trading Engine Module

**Status**: Phase 1 Complete - Stub implementation with tests ✅
**Branch**: `feature/engine-with-order-manager`

## Overview

The Trading Engine acts as a **simulated broker** that executes orders from the OrderManager. It is designed to work as part of a larger trading simulation system where:

- **OrderManager** manages order lifecycle (submit, cancel, query, update)
- **Engine** executes orders based on market conditions
- **Portfolio** tracks positions and P&L from executed trades

## Key Architectural Decisions

### 1. Engine Works WITH OrderManager (Not Replacing It)

The engine does NOT manage its own orders. Instead:
- It queries pending orders from OrderManager
- Executes them based on internal market state
- Updates order status back in OrderManager via `update_order`
- Returns `execution_report` list containing trades

**Real-world analogy**:
- OrderManager = Your order book / order tracking system
- Engine = The broker you send orders to
- Portfolio = Your position tracking / accounting system

### 2. Market Data is Internal (Currently Deferred)

**Original Design**: Engine maintains internal `market_state` (hashtable of symbol → market_data)
- Simulation feeds prices via `update_market()`
- Engine uses prices for execution decisions

**Current State**: Market data management **removed** in Phase 1 refactor to keep things minimal
- `get_market_data` returns `None` for now
- Will be added back when implementing market order execution (Phase 3)

### 3. Execution Reports Bridge to Portfolio

```
OrderManager (order lifecycle)
    ↓ pending orders
Engine.process_orders (execution)
    ↓ execution_reports
        ↓ contains trades
Portfolio.apply_trades (position tracking)
```

Example usage:
```ocaml
let reports = Engine.process_orders engine order_mgr in
let trades = List.concat_map reports ~f:(fun r -> r.trades) in
let portfolio' = Portfolio.apply_trades portfolio trades
```

## Current Implementation (Phase 1)

### Module Structure

```
trading/engine/
├── lib/
│   ├── dune              - Build configuration
│   ├── types.mli         - Public type definitions
│   ├── types.ml          - Type implementations
│   ├── engine.mli        - Engine public API (stub)
│   └── engine.ml         - Engine implementation (stub)
└── test/
    ├── dune              - Test configuration
    ├── test_types.ml     - Type tests (12 passing)
    └── test_engine.ml    - Engine tests (8 passing, with TODOs)
```

### Types (types.mli)

**Simplified in Phase 1 refactor**:

```ocaml
type fill_status = Filled | PartiallyFilled | Unfilled

type execution_report = {
  order_id : string;
  status : fill_status;
  trades : trade list;  (* All details derivable from trades *)
}
[@@deriving show, eq]

type commission_config = {
  per_share : float;
  minimum : float;
}
[@@deriving show, eq]

type engine_config = {
  commission : commission_config;
}
[@@deriving show, eq]
```

**Why simplified?** Removed redundant fields from `execution_report`:
- ~~`filled_quantity`~~ - derivable from summing `trade.quantity`
- ~~`average_price`~~ - derivable from weighted average of `trade.price`
- ~~`remaining_quantity`~~ - derivable from `order.quantity - filled_quantity`
- ~~`timestamp`~~ - each trade has its own timestamp

**Removed types** (deferred to Phase 3+):
- `market_data` record type
- `market_state` type

### Engine API (engine.mli)

**Current stub interface**:

```ocaml
type t  (* Opaque engine type *)

val create : engine_config -> t
(** Create engine with commission configuration *)

val get_market_data : t -> symbol -> (price option * price option * price option) option
(** Returns None until Phase 6+ - market data management deferred *)

val process_orders : t -> order_manager -> execution_report list status_or
(** Process pending orders from OrderManager.
    Currently returns [] with TODOs for Phase 3-5 implementation. *)
```

### Engine Implementation (engine.ml)

**Current stub**:
```ocaml
type t = { config : engine_config }

let create config = { config }

let get_market_data _engine _symbol = None

let process_orders _engine _order_mgr =
  (* TODO: Phase 3 - Implement market order execution
     TODO: Phase 4 - Implement limit order execution
     TODO: Phase 5 - Implement stop order execution

     Algorithm:
     1. Get pending orders from order_mgr using list_orders ~filter:ActiveOnly
     2. For each order, match on order.order_type:
        - Market: execute immediately at last price
        - Limit: check if price condition met, execute at limit price
        - Stop: check if triggered, execute as market order
        - StopLimit: not implemented yet
     3. For executed orders:
        - Generate trade with commission
        - Update order status in order_mgr
        - Create execution_report
     4. Return list of execution_reports *)
  Result.Ok []
```

## Test Coverage

### Type Tests (test_types.ml) - 12 tests ✅

All passing:
- `fill_status` variants and show/eq derivers
- `execution_report` construction with trades
- `execution_report` equality
- `execution_report` with multiple trades
- `commission_config` construction and equality
- `engine_config` construction and equality

### Engine Tests (test_engine.ml) - 8 tests ✅

**Currently passing with stub implementation**:
1. ✅ `test_create_engine` - Basic engine creation
2. ✅ `test_create_engine_with_custom_commission` - Custom commission config
3. ✅ `test_get_market_data_returns_none` - Verifies stub returns None
4. ✅ `test_process_orders_empty_manager` - Empty order manager case

**With TODO comments for Phase 3 implementation**:
5. ✅ `test_process_orders_with_market_order` - Execute market order at price
   - TODO: Verify execution_report returned
   - TODO: Verify trade generated with correct price/commission
   - TODO: Verify order updated to Filled in OrderManager

6. ✅ `test_process_orders_calculates_commission` - Commission = max(qty * per_share, minimum)
   - TODO: For 50 shares at $0.01/share: commission should be max(0.50, 1.0) = 1.0

7. ✅ `test_process_orders_updates_order_status` - Order status changes
   - TODO: Verify order.status updated to Filled
   - TODO: Verify list_orders ~filter:ActiveOnly no longer returns filled order

8. ✅ `test_process_orders_with_multiple_orders` - Process 3 orders
   - TODO: Verify 3 execution_reports returned

Each test includes detailed TODO comments describing expected behavior.

## Dependencies

### Current
- `trading.base` - Core types (symbol, price, quantity, side, order_type, trade)
- `trading.orders` - OrderManager, order types, create_order
- `status` - Result type helpers

### Will Need (Phase 3+)
- `core` - For Hashtbl and standard library utilities
- `core_unix.time_ns_unix` - For timestamps in market_data

## Completed Work

### ✅ Phase 1: Engine Types Module
- Simplified `execution_report` (removed redundant fields)
- Removed `market_data` types from public API
- 12 type tests passing
- Committed: `d8eabed`

### ✅ Phase 1 (continued): Stub Engine Implementation
- Minimal `engine.ml` with clear TODOs
- Clean `engine.mli` public API
- 8 stub tests with detailed expectations
- Committed: `83df1d8`, `898a155`

### ✅ Phase 2: OrderManager.update_order (completed separately)
- Added `update_order` function to OrderManager
- 4 new tests in orders module (17 total)
- Engine will use this to update order status after execution
- Committed: Already merged to main (#56)

### ✅ Branch Rebased
- Successfully rebased onto main (5f061c5)
- All tests passing (67 total across project)

## Next Steps - Phase 3: Market Order Execution

### Goal
Implement market order execution with internal market state management.

### What Needs to be Added

1. **Add back internal market_data type** (in `engine.ml`, not public):
```ocaml
type market_data = {
  symbol : symbol;
  bid : price option;
  ask : price option;
  last : price option;
  timestamp : Time_ns_unix.t;
}
```

2. **Update engine type** to include market_state:
```ocaml
type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
}
```

3. **Implement update_market** (add to `engine.mli`):
```ocaml
val update_market :
  t ->
  symbol ->
  bid:price option ->
  ask:price option ->
  last:price option ->
  unit
(** Update market data for a symbol. Called by simulation to feed prices. *)
```

4. **Implement process_orders** for Market orders:
```ocaml
let process_orders engine order_mgr =
  (* 1. Get pending orders *)
  let pending = OrderManager.list_orders order_mgr ~filter:ActiveOnly in

  (* 2. Process each order *)
  let reports = List.filter_map pending ~f:(fun order ->
    match order.order_type with
    | Market ->
        (* Get market data for symbol *)
        (* Execute at last price *)
        (* Calculate commission = max(qty * per_share, minimum) *)
        (* Generate trade *)
        (* Update order status to Filled in order_mgr *)
        (* Return execution_report with trade *)
    | _ -> None  (* Limit/Stop not implemented yet *)
  ) in
  Result.Ok reports
```

### Tests to Update

Update the 5 TODO tests in `test_engine.ml` to verify:
- Market orders execute at last price
- Commission calculated correctly
- Order status updated to Filled
- Trades generated with correct fields
- Multiple orders process correctly

### Success Criteria for Phase 3

- [ ] `update_market` feeds prices to engine
- [ ] `get_market_data` returns actual data
- [ ] Market orders execute at last price
- [ ] Commission: `max(quantity * per_share, minimum)`
- [ ] Order status updated to Filled in OrderManager
- [ ] Trade generated with: id, order_id, symbol, side, quantity, price, commission, timestamp
- [ ] execution_report contains trade
- [ ] Multiple market orders process correctly
- [ ] All 8 engine tests pass with real implementation (no TODOs)
- [ ] 20+ total engine tests

## Future Phases (Post-Phase 3)

### Phase 4: Limit Order Execution
- Check bid/ask prices against limit price
- Execute only when price condition is met
- Return Unfilled status when condition not met

### Phase 5: Stop Order Execution
- Monitor last price for stop trigger
- Convert to market order when triggered
- Execute at last price after trigger

### Phase 6: Stop-Limit Orders
- Combine stop trigger with limit execution

### Phase 7: Portfolio Integration Tests
- End-to-end workflow tests
- Order → Engine → Trades → Portfolio

See `/workspaces/trading-1/docs/logs/prompts/20251110.md` for detailed implementation guidance.

## Development Workflow

### Running Tests
```bash
# Just engine tests
dune runtest trading/engine/test/

# All tests
dune runtest

# Build
dune build

# Format
dune fmt
```

### Git Workflow
```bash
# Current branch
git checkout feature/engine-with-order-manager

# Check status
git status

# Run tests before committing
dune build && dune runtest

# Commit
git add .
git commit -m "Implement market order execution"
```

## Design Notes & Decisions

### Why Separate OrderManager from Engine?

They have distinct responsibilities:
- **OrderManager**: Lifecycle management (CRUD operations on orders)
- **Engine**: Execution logic (turning orders into trades based on market conditions)

This separation allows:
- Testing execution logic independently
- Swapping execution strategies
- Reusing OrderManager in live trading (not just simulation)

### Why Simplified execution_report?

Original had redundant fields derivable from trades list:
- `filled_quantity` = `List.sum (List.map trades ~f:(fun t -> t.quantity))`
- `average_price` = weighted average of `trade.price` by `trade.quantity`
- `remaining_quantity` = `order.quantity - filled_quantity`

Benefits of keeping only trades:
- More flexible for partial fills (future enhancement)
- Supports multiple fills at different prices
- Tracks commission per trade
- Single source of truth

### Why Make Market Data Internal?

Originally `market_data` was in public `types.mli`, but:
- It's an implementation detail of how engine executes
- Clients don't create or manipulate market data
- Simulation only needs `update_market(symbol, prices)`
- Keeping it internal allows flexibility in storage/caching

### Error Handling for Missing Market Data

Options for market orders when market data unavailable:
1. Skip silently (current plan via filter_map)
2. Return Unfilled execution_report
3. Return error in Result

**Current approach**: Skip silently
- Market orders stay Pending if no data
- Will be picked up in next process_orders call
- Simple and consistent

Could revisit if needed.

## Known Issues / Open Questions

1. **Trade ID Generation**
   Current: Simple `"trade_" ^ order.id`
   Issue: Won't work for partial fills (multiple trades per order)
   Solution: Consider UUID generator or counter

2. **Timestamps in Tests**
   Using `Time_ns_unix.now()` makes tests non-deterministic
   Solution: Add optional `~now_time` parameter for testing

3. **Commission Rounding**
   Using Float, no rounding yet
   Question: Should we round to 2 decimal places?

4. **Execution Price for Market Orders**
   Using last price
   Question: Should we use bid (for sells) / ask (for buys) for more realism?

5. **Failed Executions**
   Currently skipped via filter_map
   Question: Should we track failed execution attempts?

## References

- **Main Development Plan**: `/workspaces/trading-1/docs/logs/prompts/20251110.md`
- **Orders Module**: `/workspaces/trading-1/trading/trading/orders/`
- **Portfolio Module**: `/workspaces/trading-1/trading/trading/portfolio/`
- **Base Types**: `/workspaces/trading-1/trading/trading/base/`
- **Project Guidelines**: `/workspaces/trading-1/CLAUDE.md`

## Recent Commits

```
898a155 Add stub tests for Engine module
83df1d8 Refactor Phase 1: Simplify engine types and add minimal stub
d8eabed Implement engine types module with core data structures
5f061c5 trading engine - part 1 (#56) [main]
```

Last updated: 2025-11-10
