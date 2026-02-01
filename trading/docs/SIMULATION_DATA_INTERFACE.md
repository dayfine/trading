# Simulation Data Interface Requirements

## Overview

This document defines the **data interface** that the simulation module requires to operate. The simulation module is **NOT responsible** for implementing the data processing pipeline - it only defines what data format and access patterns it needs.

## Separation of Concerns

### What Simulation Module Does:
- ✅ Defines the interface for accessing market data and indicators
- ✅ Consumes data through this interface during backtesting
- ✅ Steps through dates one-by-one, querying data as needed

### What Simulation Module Does NOT Do:
- ❌ Implement data loading from storage
- ❌ Implement data preprocessing/transformation
- ❌ Compute indicators from raw price data
- ❌ Optimize data structures for fast lookup

### Responsibility of Data Processing Pipeline (To Be Built):
- Load historical price data from storage (CSV, database, API, etc.)
- Pre-compute indicators for the full date range
- Transform data into the format required by simulation interface
- Optimize data structures (indexing, caching) for performance
- Handle data quality issues (missing data, gaps, etc.)

## Required Data Interface

The simulation module requires an interface that provides:

### 1. Market Data Access

```ocaml
module type MARKET_DATA_VIEW = sig
  type t

  (** Current date in the simulation *)
  val current_date : t -> Date.t

  (** Get the latest price data for a symbol at current date *)
  val get_price : t -> symbol:string -> Daily_price.t option

  (** Get historical prices for a symbol (up to current date) *)
  val get_price_history :
    t ->
    symbol:string ->
    ?lookback_days:int ->  (* Default: all available history *)
    unit ->
    Daily_price.t list

  (** Advance to next date (returns new view for that date) *)
  val advance : t -> date:Date.t -> t
end
```

### 2. Indicator Access

```ocaml
module type INDICATOR_VIEW = sig
  type t

  (** Get EMA value for a symbol at current date *)
  val get_ema :
    t ->
    symbol:string ->
    period:int ->
    float option

  (** Get EMA series up to current date *)
  val get_ema_series :
    t ->
    symbol:string ->
    period:int ->
    ?lookback_days:int ->
    indicator_value list

  (** Future: Add more indicators as needed *)
  (* val get_sma : ... *)
  (* val get_rsi : ... *)
  (* val get_bollinger_bands : ... *)
end
```

### 3. Combined Interface

```ocaml
module type MARKET_DATA = sig
  include MARKET_DATA_VIEW
  include INDICATOR_VIEW with type t := t
end
```

## Performance Considerations

### Why Pre-computation is Needed

During simulation, strategies will query data frequently:
```ocaml
(* Every day, for every symbol *)
let ema_30 = get_ema market_data ~symbol:"AAPL" ~period:30 in
let ema_50 = get_ema market_data ~symbol:"AAPL" ~period:50 in
```

**Naive approach** (computing on-demand):
- Day 1: Calculate EMA(30) from days 1-30
- Day 2: Calculate EMA(30) from days 1-31 (recomputes everything!)
- Day 3: Calculate EMA(30) from days 1-32 (recomputes everything!)
- **Complexity**: O(n²) where n = number of simulation days

**Pre-computation approach**:
- Before simulation: Calculate all indicators for full date range (once)
- During simulation: O(1) lookup of pre-computed value for current date
- **Complexity**: O(n) preprocessing + O(1) per query

### Expected Implementation Strategy

The data processing pipeline should:

1. **Load all data upfront** for the simulation date range
2. **Pre-compute all indicators** using `analysis/technical/indicators`
3. **Build efficient lookup structures** (e.g., hash maps indexed by (symbol, date))
4. **Implement the MARKET_DATA interface** backed by these pre-computed structures

Example internal structure:
```ocaml
type preprocessed_data = {
  prices: (string * Date.t, Daily_price.t) Hashtbl.t;
  ema_cache: (string * int * Date.t, float) Hashtbl.t;
  (* indicator -> symbol -> period -> date -> value *)

  available_dates: Date.t list;
  date_range: Date.t * Date.t;
}
```

## Integration Points

### With analysis/data/storage
```ocaml
(* Data pipeline loads from storage *)
let storage = CsvStorage.create "AAPL" in
let prices = Storage.get storage ~start_date ~end_date () in
(* ... process into format required by MARKET_DATA interface ... *)
```

### With analysis/technical/indicators
```ocaml
(* Data pipeline uses indicator modules *)
let indicator_values =
  prices
  |> List.map ~f:(fun p -> { date = p.date; value = p.close_price })
in
let ema_30 = Ema.calculate_ema indicator_values 30 in
(* ... store in preprocessed_data.ema_cache ... *)
```

### With simulation module
```ocaml
(* Simulation receives an implementation of MARKET_DATA *)
module MyMarketData : MARKET_DATA = struct
  (* ... implementation using preprocessed_data ... *)
end

let market_data = MyMarketData.create ~preprocessed_data ~current_date in
let simulator = Simulator.create_with_strategy
  ~config
  ~market_data
  ~strategy
in
```

## Implementation Status

### Completed ✅

- [x] Define market data interface via `get_price_fn` and `get_indicator_fn` in `Strategy_interface`
- [x] Implement `Market_data_adapter` in `Trading_simulation_data` module
- [x] Implement `Price_cache` with lazy CSV loading
- [x] Implement `Indicator_manager` for cached indicator orchestration
- [x] Implement `Indicator_computer` for EMA computation
- [x] Implement `Time_series` wrapper for cadence abstraction (daily/weekly)
- [x] Handle edge cases (missing data, date gaps)
- [x] E2E tests with real CSV data

### Future Enhancements

- [ ] Performance benchmarking and optimization for large backtests
- [ ] Add more indicators (RSI, MACD, Bollinger Bands)
- [ ] Streaming data support for live trading

## Notes

- The `MARKET_DATA` interface is designed to be **implementation-agnostic**
- For **testing**, we can use a simple in-memory implementation
- For **production backtesting**, we need a performant implementation with pre-computation
- The interface can be **extended** to support additional indicators without breaking existing code
- **Caching** and **indexing** are implementation details, hidden behind the interface

## Summary

**Simulation module's role**: Define clean interface for data access
**Data pipeline's role**: Implement that interface efficiently

This separation allows:
- Simulation module to focus on trading logic
- Data pipeline to optimize for performance
- Easy testing with mock data
- Flexibility to swap implementations (in-memory, pre-computed, streaming, etc.)
