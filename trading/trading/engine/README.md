# Trading Engine

**Status**: Phase 4 Complete - Limit Order Execution ✅

## Overview

Simulated broker that executes orders from OrderManager:
- Queries pending orders from OrderManager
- Executes based on market data (bid/ask/last prices)
- Returns execution_reports with generated trades
- Updates order status in OrderManager

**Data Flow**: `OrderManager → Engine.process_orders → execution_reports → Portfolio.apply_trades`

## API

```ocaml
(* Configuration *)
type engine_config = { commission : commission_config }
type commission_config = { per_share : float; minimum : float }

(* Market data *)
type price_quote = { symbol : symbol; bid : price option; ask : price option; last : price option }

(* Execution *)
type execution_report = { order_id : string; status : fill_status; trades : trade list }
type fill_status = Filled | PartiallyFilled | Unfilled

(* Functions *)
val create : engine_config -> t
val update_market : t -> price_quote list -> unit  (* Batch update prices *)
val process_orders : t -> order_manager -> execution_report list status_or
```

## Usage Example

```ocaml
let engine = Engine.create { commission = { per_share = 0.01; minimum = 1.0 } } in

(* Update market prices in batch *)
let quotes = [
  { symbol = "AAPL"; bid = Some 150.0; ask = Some 150.5; last = Some 150.25 };
  { symbol = "GOOGL"; bid = Some 2800.0; ask = Some 2805.0; last = Some 2802.5 };
] in
Engine.update_market engine quotes;

(* Process pending orders *)
match Engine.process_orders engine order_mgr with
| Ok reports ->
    let trades = List.concat_map reports ~f:(fun r -> r.trades) in
    Portfolio.apply_trades portfolio trades
| Error err -> (* handle error *)
```

## Implementation Status

### Phase 4 Complete ✅
- Limit order execution:
  - Buy limit: Execute when ask ≤ limit_price at ask price
  - Sell limit: Execute when bid ≥ limit_price at bid price
  - Orders remain pending when price conditions not met
- 16 engine tests + 12 type tests passing

### Phase 3 Complete ✅
- Market order execution at last price
- Commission calculation: `max(quantity * per_share, minimum)`
- Batch market data updates via `price_quote` list
- Order status updates to Filled

### Phase 5 Next
- Stop order execution (buy when last ≥ stop, sell when last ≤ stop)

## Test Coverage

**28 tests total** (all passing):
- 12 type tests (fill_status, execution_report, commission_config, price_quote)
- 16 engine tests:
  - Engine creation and configuration (2 tests)
  - Market data management (3 tests)
  - Market order execution (5 tests)
  - Limit order execution (6 tests)

## Module Structure

```
trading/engine/
├── lib/
│   ├── types.{ml,mli}   - Public types (price_quote, execution_report, config)
│   └── engine.{ml,mli}  - Engine implementation
└── test/
    ├── test_types.ml    - Type tests
    └── test_engine.ml   - Engine behavior tests
```

## Running Tests

```bash
# Engine tests only
dune runtest trading/engine/test/

# All tests
dune runtest

# Build
dune build
```
