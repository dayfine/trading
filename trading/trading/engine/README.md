# Trading Engine Module

**Status**: Phase 3 Complete - Market Order Execution ✅
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

## Current Implementation (Phase 3)

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

**Implemented interface**:

```ocaml
type t  (* Opaque engine type *)

val create : engine_config -> t
(** Create engine with commission configuration *)

val update_market : t -> symbol -> bid:price option -> ask:price option -> last:price option -> unit
(** Update market data for a symbol - called by simulation to feed prices *)

val get_market_data : t -> symbol -> (price option * price option * price option) option
(** Query current market data for a symbol. Returns (bid, ask, last) tuple. *)

val process_orders : t -> order_manager -> execution_report list status_or
(** Process pending orders from OrderManager.
    Executes market orders at last price with commission. *)
```

### Engine Implementation (engine.ml)

**Current implementation**:
```ocaml
type market_data = {
  symbol : symbol;
  bid : price option;
  ask : price option;
  last : price option;
  timestamp : Time_ns_unix.t;
}

type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
}

let create config = { config; market_state = Hashtbl.create (module String) }

let update_market engine symbol ~bid ~ask ~last =
  let data = { symbol; bid; ask; last; timestamp = Time_ns_unix.now () } in
  Hashtbl.set engine.market_state ~key:symbol ~data

let get_market_data engine symbol =
  match Hashtbl.find engine.market_state symbol with
  | Some data -> Some (data.bid, data.ask, data.last)
  | None -> None

let process_orders engine order_mgr =
  (* 1. Get pending orders *)
  let pending = list_orders order_mgr ~filter:ActiveOnly in
  (* 2. Process each order *)
  let reports =
    List.filter_map pending ~f:(fun order ->
        match order.order_type with
        | Market -> (* Execute at last price with commission *)
            ...
        | _ -> None (* TODO: Phase 4-5 - Limit/Stop orders *))
  in
  Result.Ok reports
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

### Engine Tests (test_engine.ml) - 11 tests ✅

**All tests passing with real implementation**:
1. ✅ `test_create_engine` - Basic engine creation
2. ✅ `test_create_engine_with_custom_commission` - Custom commission config
3. ✅ `test_get_market_data_returns_none_when_no_data` - Returns None when no data
4. ✅ `test_get_market_data_returns_data_after_update` - Returns data after update_market
5. ✅ `test_update_market_with_partial_data` - Handles partial market data (only last price)
6. ✅ `test_update_market_overwrites_previous_data` - Updates overwrite previous data
7. ✅ `test_process_orders_empty_manager` - Empty order manager case
8. ✅ `test_process_orders_with_market_order` - Execute market order at last price
9. ✅ `test_process_orders_calculates_commission` - Commission = max(qty * per_share, minimum)
10. ✅ `test_process_orders_updates_order_status` - Order status updated to Filled
11. ✅ `test_process_orders_with_multiple_orders` - Process 3 orders correctly

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

### ✅ Phase 3: Market Order Execution
- Added internal `market_data` type with hashtable storage
- Implemented `update_market` to feed prices to engine
- Implemented `get_market_data` to query current prices
- Implemented `process_orders` for market order execution:
  - Executes at last price
  - Calculates commission: max(quantity * per_share, minimum)
  - Updates order status to Filled
  - Generates execution_report with trade
- Added 3 new tests for market data management
- Updated 4 existing tests with real assertions
- All 11 engine tests passing (total 23 with type tests)
- All 135 project tests passing

## Next Steps - Phase 4: Limit Order Execution

### Goal
Implement limit order execution based on bid/ask prices.

### What Needs to be Added

1. **Implement limit order logic in `_execute_limit_order`**:
   - Buy limit: execute when ask <= limit price
   - Sell limit: execute when bid >= limit price
   - Execute at limit price (not market price)
   - Return None if condition not met

2. **Update `process_orders`** to handle Limit orders:
```ocaml
| Limit limit_price -> (
    match _execute_limit_order engine order limit_price with
    | None -> None (* Price condition not met *)
    | Some trade -> (* Create execution_report *)
        ...)
```

### Success Criteria for Phase 4

- [ ] Buy limit orders execute when ask <= limit price
- [ ] Sell limit orders execute when bid >= limit price
- [ ] Execution price is the limit price
- [ ] Orders remain Pending when condition not met
- [ ] 5+ new tests for limit order execution
- [ ] All existing tests continue passing

## Future Phases (Post-Phase 4)

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
