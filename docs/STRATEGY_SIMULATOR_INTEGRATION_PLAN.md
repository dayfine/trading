# Strategy-Simulator Integration Plan (Revised)

## Goal
Integrate the strategy system into the simulator to enable end-to-end backtesting at scale with real strategies. Support:
- **Scale**: 100-1000 symbols over 10+ years
- **Flexibility**: Multiple time periods (daily, weekly, monthly)
- **Indicators**: EMA, RSI, volume-based indicators
- **Use cases**: Market-wide screening and focused portfolio simulation

## Architectural Principles

### 1. **Separation of Time-Windowing from Computation**
Indicators compute on any price series. Time period conversion (daily → weekly) is a preprocessing step, not indicator-specific logic.

### 2. **Layered Architecture**
```
Strategy Layer
    ↓
Market Data Adapter (Strategy Interface)
    ↓
Indicator Manager (Orchestration & Caching)
    ↓
Storage Backend ← → Indicator Computer
    ↓                      ↓
CSV Storage          Time Series Converter
(analysis/)          (Cadence handling)
```

### 3. **Direct CSV Integration**
Simulator no longer takes pre-loaded prices. Instead:
- Takes `symbols: string list` + `data_dir: Fpath.t option`
- Lazily loads from CSV storage (analysis/data/storage)
- Caches recent data per symbol (~100 days = ~6 KB/symbol)

### 4. **Weekly Cadence Support**
- **During week (Mon-Thu)**: Use current day's close as **provisional** weekly price
- **Week end (Friday)**: Friday's close becomes **finalized** weekly price
- **Indicator updates**: Compute provisionally during week, finalize on Friday

### 5. **Composable Components**
Each layer has single responsibility and is independently testable.

---

## Architecture Layers

### **Layer 1: Storage Backend**
Manages lazy loading from CSV storage with caching.

**Module**: `trading/trading/simulation/lib/storage_backend.{ml,mli}`

```ocaml
type t

val create : symbols:string list -> data_dir:Fpath.t option -> t Status.status_or
(** Initialize storage connections for symbol universe *)

val get_price : t -> symbol:string -> date:Date.t -> Types.Daily_price.t option
(** Get single day price - O(1) with caching *)

val get_price_range :
  t ->
  symbol:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  Types.Daily_price.t list Status.status_or
(** Get price range for indicator bootstrap *)

val advance_date : t -> Date.t -> unit
(** Advance simulation date, manage cache *)
```

**Implementation Details**:
- Hashtable of `(symbol, storage_state)` where storage_state contains:
  - `Csv_storage.t` connection
  - LRU cache of recent prices (default: 100 days)
- On `get_price`: check cache, then load from CSV if miss
- On `get_price_range`: load batch from CSV, populate cache
- Memory per symbol: ~6 KB (100 days × OHLCV data)
- Total for 1000 symbols: ~6 MB

---

### **Layer 2: Time Series Converter**
Converts daily prices to different time periods (weekly, monthly).

**Existing Infrastructure**: `trading/analysis/technical/indicators/time_period/lib/conversion.{ml,mli}`
- Already implements `daily_to_weekly` for complete weeks
- Needs enhancement for provisional values (incomplete weeks)

**New Module**: `trading/trading/simulation/lib/time_series.{ml,mli}`
- Defines `cadence` type for type safety
- Provides unified interface for all cadences
- Delegates to enhanced `Conversion` module

```ocaml
type cadence = Daily | Weekly | Monthly [@@deriving show, eq]

val convert_cadence :
  Types.Daily_price.t list ->
  cadence:cadence ->
  as_of_date:Date.t option ->
  Types.Daily_price.t list
(** Convert daily prices to specified cadence.

    For incomplete periods (e.g., Wed in a week):
    - If as_of_date is Some date: includes provisional value using latest day
    - If as_of_date is None: only includes complete periods

    Implementation delegates to Conversion module from analysis/
*)

val is_period_end : cadence:cadence -> Date.t -> bool
(** Check if date is period boundary (Friday for weekly, month-end for monthly) *)
```

**Implementation Strategy**:
- Enhance existing `Conversion.daily_to_weekly` to support provisional mode
- Create `time_series` module as thin wrapper providing cadence abstraction
- `Daily`: No-op, return prices as-is
- `Weekly`: Delegate to `Conversion.daily_to_weekly` with provisional support
- `Monthly`: Similar logic using month boundaries

**Example**:
```ocaml
(* Complete weeks only *)
let weekly = Time_series.convert_cadence daily_prices
  ~cadence:Weekly ~as_of_date:None

(* Include provisional value for Wednesday *)
let provisional = Time_series.convert_cadence daily_prices
  ~cadence:Weekly ~as_of_date:(Some wed_date)
(* Last element is Wed's close treated as week's close *)
```

---

### **Layer 3: Indicator Computer**
Generic indicator computation on any price series (time-agnostic).

**Module**: `trading/trading/simulation/lib/indicator_computer.{ml,mli}`

```ocaml
type indicator_spec = {
  name: string;        (* "EMA", "RSI", "Volume" *)
  period: int;         (* 20, 50, etc. *)
  cadence: Time_series.cadence;
}

val compute :
  indicator_spec ->
  Types.Daily_price.t list ->
  float option Status.status_or
(** Compute indicator value for last date in series *)

val compute_series :
  indicator_spec ->
  Types.Daily_price.t list ->
  (Date.t * float) list Status.status_or
(** Compute full historical series *)
```

**Implementation**:
- `EMA`: Convert prices to indicator_values, call `Ema.calculate_ema` (analysis/)
- `RSI`: Compute relative strength index (to be implemented)
- `Volume`: Moving average of volume field
- Extensible: add new indicators by pattern matching on `name`

**Key Point**: Indicator doesn't care if prices are daily, weekly, or monthly. It just computes on the provided series.

---

### **Layer 4: Indicator Manager**
Orchestrates storage, conversion, and computation with caching.

**Module**: `trading/trading/simulation/lib/indicator_manager.{ml,mli}`

```ocaml
type t

val create : storage_backend:Storage_backend.t -> t

val get_indicator :
  t ->
  symbol:string ->
  spec:Indicator_computer.indicator_spec ->
  date:Date.t ->
  float option Status.status_or
(** Get indicator value for symbol at date.

    Automatically:
    1. Loads daily prices from storage (with caching)
    2. Converts to specified cadence
    3. Computes indicator
    4. Caches result (marks as provisional or finalized)
*)

val finalize_period :
  t ->
  cadence:Time_series.cadence ->
  end_date:Date.t ->
  unit
(** Mark period as finalized (e.g., Friday for weekly).
    Invalidates provisional caches. *)
```

**Implementation Details**:

**Cache structure**:
```ocaml
type cache_key = {
  symbol: string;
  indicator_name: string;
  period: int;
  cadence: Time_series.cadence;
  date: Date.t;
}

type cache_entry = {
  value: float;
  is_provisional: bool;  (* True if computed mid-period *)
}
```

**Algorithm for `get_indicator`**:
1. Check cache for `(symbol, indicator, period, cadence, date)`
2. If cache hit: return cached value
3. If cache miss:
   a. Estimate lookback needed (e.g., 20w = 20 × 7 days + warmup)
   b. Load daily prices from storage_backend
   c. Convert to target cadence using Time_series.convert_cadence
      - Pass `as_of_date` if not at period boundary (provisional mode)
   d. Compute indicator using Indicator_computer
   e. Cache result with `is_provisional` flag
   f. Return value

**Lookback estimation**:
- Daily: `period + 10` (warmup buffer)
- Weekly: `period × 7 + 50`
- Monthly: `period × 30 + 100`

**Finalize period**:
- Iterate cache, remove entries where `is_provisional = true` and date is in completed period
- This ensures next day recomputes with finalized value

---

### **Layer 5: Market Data Adapter**
Provides strategy interface, delegates to backend services.

**Module**: `trading/trading/simulation/lib/market_data_adapter.{ml,mli}` (refactored)

```ocaml
type t = {
  watchlist: string list;
  storage_backend: Storage_backend.t;
  indicator_manager: Indicator_manager.t;
  current_date: Date.t;
}

val create :
  watchlist:string list ->
  current_date:Date.t ->
  data_dir:Fpath.t option ->
  t Status.status_or
(** Initialize adapter with storage backend *)

val get_price : t -> string -> Types.Daily_price.t option
(** Get price for symbol at current date *)

val get_indicator :
  t ->
  string ->
  string ->
  int ->
  Time_series.cadence ->
  float option
(** Get indicator value at current date

    @param symbol Trading symbol
    @param indicator_name "EMA", "RSI", etc.
    @param period 20, 50, etc.
    @param cadence Daily, Weekly, Monthly
*)

val advance_to_date : t -> Date.t -> t
(** Advance to next date, finalizing periods as needed *)

val update_watchlist : t -> symbols:string list -> t Status.status_or
(** Update active symbol watchlist (e.g., after screening) *)
```

**Key changes from original**:
- No longer stores prices in memory
- `get_indicator` takes `cadence` parameter
- Supports watchlist updates for periodic screening

---

## Enhanced Strategy Interface

Strategies can now request indicators with specific cadences:

```ocaml
module type STRATEGY = sig
  type output = {
    transitions: Position.transition list;
  }

  val on_market_close :
    get_price:(string -> Types.Daily_price.t option) ->
    get_indicator:(string -> string -> int -> Time_series.cadence -> float option) ->
    positions:Position.t String.Map.t ->
    output Status.status_or
end
```

**Example strategy using multiple timeframes**:

```ocaml
module Multi_timeframe_ema : STRATEGY = struct
  let on_market_close ~get_price ~get_indicator ~positions =
    let transitions = String.Map.fold positions ~init:[] ~f:(fun ~key:symbol ~data:pos acc ->
      (* Weekly EMA for long-term trend *)
      let ema_20w = get_indicator symbol "EMA" 20 Weekly in

      (* Daily EMA for short-term signals *)
      let ema_20d = get_indicator symbol "EMA" 20 Daily in

      (* Current price *)
      let price = get_price symbol in

      match ema_20w, ema_20d, price with
      | Some w_ema, Some d_ema, Some p ->
          (* Long-term uptrend AND short-term pullback *)
          if p.close_price > w_ema && p.close_price < d_ema then
            (* Buy signal *)
            ...
          else acc
      | _ -> acc
    ) in
    Ok { transitions }
end
```

---

## Revised Implementation Plan

### **Phase 0: Prerequisites** ✅
- CSV storage infrastructure (analysis/data/storage)
- Basic time period conversion (analysis/technical/indicators/time_period)
- EMA computation (analysis/technical/indicators/ema)

---

### **Phase 1: Time Series Infrastructure**

**Change 1.1: Enhance Time Period Conversion**
- **Goal**: Support provisional values for incomplete periods

**Files to modify**:
- `trading/analysis/technical/indicators/time_period/lib/conversion.{ml,mli}`

**Changes**:
- Add `convert_to_weekly_provisional` function
- Or enhance `daily_to_weekly` with optional `include_partial_week` flag
- Test incomplete weeks (Mon-Thu data)

**Tests**:
- Complete week (Mon-Fri) → 1 weekly price (Fri)
- Incomplete week (Mon-Wed) with provisional flag → 1 weekly price (Wed)
- Multiple incomplete weeks → correct handling

---

**Change 1.2: Create Time Series Module**
- **Goal**: Create thin wrapper with cadence types, delegates to enhanced Conversion module

**Files to create**:
- `trading/trading/simulation/lib/time_series.{ml,mli}`
- `trading/trading/simulation/test/test_time_series.ml`

**Dependencies**:
- Enhanced `Conversion` module from Change 1.1

**Implementation**:
```ocaml
type cadence = Daily | Weekly | Monthly [@@deriving show, eq]

let is_period_end ~cadence date =
  match cadence with
  | Daily -> true
  | Weekly -> Date.equal (Date.day_of_week date) Day_of_week.Fri
  | Monthly -> Date.is_last_day_of_month date

let convert_cadence prices ~cadence ~as_of_date =
  match cadence with
  | Daily -> prices
  | Weekly ->
      (* Delegate to enhanced Conversion.daily_to_weekly from analysis/ *)
      Conversion.daily_to_weekly ?include_partial_week:(Option.map as_of_date ~f:(fun _ -> true)) prices
  | Monthly -> ...
```

**Tests**:
- `is_period_end` for all cadences
- `convert_cadence` with and without `as_of_date`
- Edge cases: month boundaries, leap years

---

### **Phase 2: Storage Backend**

**Change 2: Create Storage Backend**
- **Goal**: Lazy loading from CSV storage with caching

**Files to create**:
- `trading/trading/simulation/lib/storage_backend.{ml,mli}`
- `trading/trading/simulation/test/test_storage_backend.ml`

**Dependencies**:
- `Csv_storage` from `analysis/data/storage/csv`
- `Fpath` for path handling

**Implementation highlights**:
- Hashtable: `(symbol, storage_state)`
- `storage_state`: CSV connection + LRU cache (100 recent prices)
- `get_price`: Cache → CSV fallback
- `get_price_range`: Batch load + cache population

**Tests** (6-8 tests):
- Create backend for multiple symbols
- `get_price` cache hit vs miss
- `get_price_range` loads correct date range
- Cache eviction (LRU behavior)
- Symbol not found → None
- Invalid date range → Error

**Verify**:
```bash
dune build
dune runtest trading/simulation/test/
```

---

### **Phase 3: Indicator Infrastructure**

**Change 3.1: Create Indicator Computer**
- **Goal**: Generic, time-agnostic indicator computation

**Files to create**:
- `trading/trading/simulation/lib/indicator_computer.{ml,mli}`
- `trading/trading/simulation/test/test_indicator_computer.ml`

**Implementation**:
```ocaml
type indicator_spec = {
  name: string;
  period: int;
  cadence: Time_series.cadence;
}

let compute spec prices =
  match spec.name with
  | "EMA" ->
      let values = List.map prices ~f:(fun p ->
        { Indicator_types.date = p.date; value = p.close_price }
      ) in
      let results = Ema.calculate_ema values spec.period in
      Ok (List.last results |> Option.map ~f:(fun iv -> iv.value))
  | "Volume" ->
      (* Moving average of volume *)
      ...
  | _ -> Error (Status.invalid_argument_error "Unknown indicator")
```

**Tests** (5-7 tests):
- EMA computation on daily prices
- EMA computation on weekly prices (same data, different cadence)
- Volume indicator
- Unknown indicator → Error
- Insufficient data → None
- Multiple periods

---

**Change 3.2: Add RSI Indicator** (Optional for MVP)
- **Goal**: Support Relative Strength Index

**Files to modify**:
- `trading/trading/simulation/lib/indicator_computer.ml`
- Add RSI implementation or link to existing

**Tests**:
- RSI computation accuracy
- RSI on different cadences

---

### **Phase 4: Indicator Management**

**Change 4: Create Indicator Manager**
- **Goal**: Orchestrate storage + conversion + computation with caching

**Files to create**:
- `trading/trading/simulation/lib/indicator_manager.{ml,mli}`
- `trading/trading/simulation/test/test_indicator_manager.ml`

**Implementation highlights**:
- Cache: `(cache_key, cache_entry)` Hashtable
- `get_indicator`:
  1. Check cache
  2. Load daily prices from storage_backend
  3. Convert to target cadence (provisional if mid-period)
  4. Compute indicator
  5. Cache with `is_provisional` flag
- `finalize_period`: Invalidate provisional caches

**Tests** (8-10 tests):
- First access → bootstrap (batch compute)
- Second access same date → cache hit
- Access next day (mid-week) → provisional value
- Access Friday → finalized value
- Finalize period → clears provisional caches
- Multiple symbols independently cached
- Multiple indicators for same symbol
- Different cadences cached separately

**Verify**:
```bash
dune build
dune runtest trading/simulation/test/
```

---

### **Phase 5: Market Data Adapter**

**Change 5: Refactor Market Data Adapter**
- **Goal**: Remove in-memory prices, integrate backend services

**Files to modify**:
- `trading/trading/simulation/lib/market_data_adapter.{ml,mli}`
- `trading/trading/simulation/test/test_market_data_adapter.ml`

**Changes**:
- Remove `price_data : (string, Daily_price.t list) Hashtbl.t`
- Add `storage_backend : Storage_backend.t`
- Add `indicator_manager : Indicator_manager.t`
- Add `watchlist : string list`
- Update `get_indicator` signature to include `cadence` parameter

**New interface**:
```ocaml
val create :
  watchlist:string list ->
  current_date:Date.t ->
  data_dir:Fpath.t option ->
  t Status.status_or

val get_price : t -> string -> Types.Daily_price.t option

val get_indicator : t -> string -> string -> int -> Time_series.cadence -> float option

val advance_to_date : t -> Date.t -> t

val update_watchlist : t -> symbols:string list -> t Status.status_or
```

**Tests** (10-12 tests):
- Create adapter with watchlist
- Get price for symbol in watchlist
- Get price for symbol not in watchlist → None
- Get indicator (daily cadence)
- Get indicator (weekly cadence)
- Get indicator mid-week → provisional
- Get indicator Friday → finalized
- Advance date → finalizes periods
- Update watchlist → new symbols accessible
- Multiple cadences for same symbol/indicator
- Lookahead prevention still works

**Verify**:
```bash
dune build
dune runtest trading/simulation/test/
```

---

### **Phase 6: Simulator Integration**

**Change 6: Update Simulator Dependencies**
- **Goal**: Change from pre-loaded prices to storage-backed approach

**Files to modify**:
- `trading/trading/simulation/lib/simulator.{ml,mli}`
- `trading/trading/simulation/test/test_simulator.ml`

**Changes to types**:
```ocaml
(* OLD *)
type symbol_prices = { symbol : string; prices : Types.Daily_price.t list }
type dependencies = { prices : symbol_prices list }

(* NEW *)
type dependencies = {
  symbols : string list;      (* Watchlist *)
  data_dir : Fpath.t option;  (* CSV storage location *)
}
```

**Changes to `create`**:
```ocaml
let create ~config ~deps =
  (* Initialize market data adapter with storage backend *)
  let%bind adapter = Market_data_adapter.create
    ~watchlist:deps.symbols
    ~current_date:config.start_date
    ~data_dir:deps.data_dir
  in

  (* ... existing initialization ... *)

  { config; deps; adapter; current_date = config.start_date; ... }
```

**Tests** (5-6 tests):
- Create simulator with symbol list (not pre-loaded prices)
- Simulator initializes storage backend
- Step loads prices on demand
- Multiple symbols in watchlist
- Symbol not in data_dir → handled gracefully
- Existing simulator tests still pass (regression check)

---

**Change 7: Add Strategy Invocation**
- **Goal**: Call strategy on each step with enhanced interface

**Files to modify**:
- `trading/trading/simulation/lib/simulator.ml`
- `trading/trading/simulation/test/test_simulator.ml`

**Changes to simulator type**:
```ocaml
type t = {
  (* existing fields *)
  adapter : Market_data_adapter.t;  (* NEW *)
  positions : Position.t String.Map.t;  (* NEW *)
  strategy : (module Strategy_interface.STRATEGY) option;  (* NEW *)
}
```

**Changes to `step`**:
```ocaml
let step t =
  (* 1. Update engine with today's bars ... existing code ... *)

  (* 2. Call strategy *)
  let%bind transitions =
    match t.strategy with
    | None -> Status.ok []
    | Some (module S) ->
        let get_price symbol = Market_data_adapter.get_price t.adapter symbol in
        let get_indicator symbol name period cadence =
          Market_data_adapter.get_indicator t.adapter symbol name period cadence
        in
        let%bind output = S.on_market_close
          ~get_price
          ~get_indicator
          ~positions:t.positions
        in
        Status.ok output.transitions
  in

  (* 3. Log transitions (not executing yet - next change) *)
  List.iter transitions ~f:(fun trans ->
    Logs.debug (fun m -> m "Transition: %a" Position.pp_transition trans)
  );

  (* 4. Execute existing orders ... *)

  (* 5. Advance date and adapter *)
  let next_date = Date.add_days t.current_date 1 in
  let adapter = Market_data_adapter.advance_to_date t.adapter next_date in

  { t with current_date = next_date; adapter }
```

**Tests** (6-8 tests):
- Strategy called on each step
- Strategy receives correct prices
- Strategy receives daily indicators
- Strategy receives weekly indicators (provisional during week)
- Friday step → finalized weekly indicators
- No strategy (None) → step works normally
- Multi-symbol strategy receives data for all symbols
- Transitions logged but not executed

---

**Change 8: Order Generation and Execution**
- **Goal**: Convert transitions to orders and execute

**Files to create**:
- `trading/trading/simulation/lib/order_generator.{ml,mli}`
- `trading/trading/simulation/test/test_order_generator.ml`

**Files to modify**:
- `trading/trading/simulation/lib/simulator.ml`

**Order Generator interface**:
```ocaml
val transitions_to_orders :
  Position.transition list ->
  Trading_orders.Types.order list Status.status_or
```

**Implementation**:
- `CreateEntering` → Market Buy order
- `TriggerExit` → Market Sell order
- Other transitions → No orders (state updates only)

**Tests for order generator** (6-7 tests):
- `CreateEntering` → Buy order
- `TriggerExit` → Sell order
- Empty list → empty orders
- Mixed transitions → correct filtering
- Extract symbol, quantity correctly
- Multiple transitions → multiple orders

**Changes to simulator**:
```ocaml
let step t =
  (* ... call strategy, get transitions ... *)

  (* NEW: Convert transitions to orders *)
  let%bind orders = Order_generator.transitions_to_orders transitions in

  (* NEW: Submit orders *)
  let statuses = Trading_orders.Manager.submit_orders t.order_manager orders in

  (* Execute orders via engine ... existing code ... *)

  (* NEW: Update positions from fills *)
  let t = _update_positions_from_fills t trades transitions in

  (* Advance date ... *)
```

**Position update logic**:
- Match trades to transitions by symbol
- `CreateEntering` + Buy trade → Create position in Entering state → Apply EntryFill → Apply EntryComplete → Store in positions map
- `TriggerExit` + Sell trade → Apply ExitFill → Apply ExitComplete → Update position to Closed

**Tests for full flow** (8-10 tests):
- Strategy transition → order created → executed → position updated
- CreateEntering → Buy → Position in Holding state
- TriggerExit → Sell → Position in Closed state
- Multiple positions tracked independently
- Position visible to strategy on next step
- Portfolio updated (cash, positions)
- No transition → no orders → no trades
- Partial fill handling

**Verify**:
```bash
dune build
dune runtest trading/simulation/test/
```

---

### **Phase 7: Integration Tests**

**Change 9: End-to-End Integration Test**
- **Goal**: Validate entire system with realistic scenario

**Files to create**:
- `trading/trading/simulation/test/test_strategy_integration.ml`

**Test scenarios**:

1. **Multi-timeframe EMA strategy** (20 days, 1 symbol):
   - Use 20w EMA (long-term) and 20d EMA (short-term)
   - Days 1-5: Below both EMAs → no position
   - Day 6: Above 20w, below 20d → entry signal
   - Days 7-15: Hold position
   - Day 16: Exit signal
   - Verify: Position lifecycle correct, portfolio updated

2. **Weekly cadence accuracy** (2 weeks):
   - Mon-Thu: Check provisional EMA values
   - Fri: Check finalized EMA value
   - Next Mon: Verify new provisional value
   - Verify: Provisional vs finalized values differ correctly

3. **Multi-symbol screening** (50 symbols, 5 days):
   - Simulate market-wide scan strategy
   - Each day: Scan all symbols for EMA crossover
   - Enter positions based on signals
   - Verify: Multiple positions created, portfolio allocation

4. **Performance test** (100 symbols, 1000 days):
   - Measure simulation speed
   - Check memory usage (should be ~10 MB)
   - Verify: Completes in reasonable time (< 60 seconds)

**Verify**:
```bash
dune build
dune runtest trading/simulation/test/
dune runtest  # All tests
```

---

### **Phase 8: Screening Tool** (Stretch Goal)

**Change 10: Create Screener Module**
- **Goal**: Periodic batch analysis of symbol universe

**Files to create**:
- `trading/trading/simulation/lib/screener.{ml,mli}`
- `trading/trading/simulation/test/test_screener.ml`

**Interface**:
```ocaml
type filter_criteria = {
  industries: string list option;
  sectors: string list option;
  min_ema_strength: float option;  (* price / EMA ratio *)
  min_volume: int option;
  (* Extensible *)
}

val screen :
  universe:string list ->
  criteria:filter_criteria ->
  as_of_date:Date.t ->
  data_dir:Fpath.t option ->
  string list Status.status_or
(** Returns filtered list of symbols passing all criteria *)
```

**Implementation**:
- Create temporary storage_backend and indicator_manager
- For each symbol in universe:
  - Load price at as_of_date
  - Compute required indicators
  - Apply filters
- Return passing symbols

**Tests** (6-8 tests):
- Screen by industry → correct subset
- Screen by EMA strength → correct filtering
- Screen by volume → correct filtering
- Combined filters → AND logic
- Empty universe → empty result
- No filters → returns universe
- Invalid date → Error

**Usage pattern**:
```ocaml
(* Run weekly screening *)
let%bind watchlist = Screener.screen
  ~universe:all_nyse_symbols  (* 1000s *)
  ~criteria:{
    industries = Some ["Technology"; "Healthcare"];
    min_ema_strength = Some 1.05;
    min_volume = Some 1_000_000;
  }
  ~as_of_date:(Date.of_string "2024-01-05")  (* Friday *)
  ~data_dir:(Some (Fpath.v "./data"))

(* Use watchlist in simulation *)
let deps = { symbols = watchlist; data_dir = ... } in
let sim = Simulator.create ~config ~deps in
...
```

---

## Memory & Performance Analysis

### **Memory Usage**

**Per symbol (with caching)**:
- Price cache: 100 days × 8 fields × 8 bytes ≈ 6 KB
- Indicator cache: 5 indicators × 3 cadences × 16 bytes ≈ 240 bytes
- CSV storage connection: negligible

**Total**:
- 100 symbols: ~600 KB
- 1000 symbols: ~6 MB

**Comparison to in-memory approach**:
- Old: All prices pre-loaded = 1000 symbols × 2500 days × 64 bytes = 160 MB
- New: Lazy + cache = ~6 MB (26× reduction)

### **Performance Per Simulation Day**

**Assumptions**: 100 symbols in watchlist, weekly cadence

**Operations**:
1. Get prices for 100 symbols: 100 × O(1) cache hit = fast
2. Get weekly EMA for 100 symbols:
   - First day: Bootstrap (load history, compute) = 100 × 50ms = 5s
   - Mon-Thu: Provisional (load current week, recompute) = 100 × 10ms = 1s
   - Friday: Finalized (incremental from last Friday) = 100 × 1ms = 100ms
3. Strategy computation: Depends on strategy (assume 100ms)
4. Order execution: Existing engine (assume 10ms)

**Total per day**:
- First day: ~5 seconds (one-time bootstrap)
- Mon-Thu: ~1 second (provisional)
- Friday: ~200ms (finalized + fast)

**For 1000 days (4 years)**:
- ~800 Fridays × 200ms = 160s
- ~200 bootstrap days × 5s = 1000s
- ~3000 other days × 1s = 3000s
- **Total**: ~4200s = 70 minutes

**Optimization opportunities**:
- Parallel indicator computation per symbol
- More aggressive caching
- Pre-warming indicators on simulation start

---

## Critical Files Summary

### **New Modules** (to create):
1. `trading/trading/simulation/lib/time_series.{ml,mli}` - Cadence types and conversion
2. `trading/trading/simulation/lib/storage_backend.{ml,mli}` - Lazy CSV loading
3. `trading/trading/simulation/lib/indicator_computer.{ml,mli}` - Generic computation
4. `trading/trading/simulation/lib/indicator_manager.{ml,mli}` - Orchestration + caching
5. `trading/trading/simulation/lib/order_generator.{ml,mli}` - Transition → order
6. `trading/trading/simulation/lib/screener.{ml,mli}` - Market scanning (stretch)

### **Modules to Refactor**:
1. `trading/trading/simulation/lib/market_data_adapter.{ml,mli}` - Remove in-memory, add cadence
2. `trading/trading/simulation/lib/simulator.{ml,mli}` - Use storage backend, add strategy

### **Modules to Enhance** (in analysis/):
1. `trading/analysis/technical/indicators/time_period/lib/conversion.{ml,mli}` - Provisional support
2. `trading/analysis/technical/indicators/ema/lib/ema.{ml,mli}` - Optional: incremental update

### **Dependencies**:
- Strategy system: `trading/trading/strategy/`
- Position state machine: `trading/trading/strategy/lib/position.ml`
- CSV storage: `trading/analysis/data/storage/csv/`
- Time conversion: `trading/analysis/technical/indicators/time_period/`
- EMA: `trading/analysis/technical/indicators/ema/`
- Order types: `trading/trading/orders/lib/types.ml`

---

## Development Workflow (Per Change)

1. **Design interface** (.mli) - types, function signatures, docs
2. **Write failing tests** - TDD approach, use matchers library
3. **Implement** (.ml) - make tests pass, keep functions small
4. **Build & test** - `dune build && dune runtest`
5. **Review** - check for duplication, naming, abstraction
6. **Format** - `dune fmt`
7. **Commit** - concise message summarizing change

---

## Success Criteria

After all changes:
- ✅ Simulator accepts symbol list + data_dir (not pre-loaded prices)
- ✅ Lazy loading from CSV storage with caching
- ✅ Strategies request indicators with specific cadences (Daily, Weekly, Monthly)
- ✅ Weekly indicators support provisional values (Mon-Thu) and finalized values (Fri)
- ✅ Multiple timeframe strategies work correctly
- ✅ Position states updated from trade execution
- ✅ 100 symbols × 1000 days simulation completes in reasonable time
- ✅ Memory usage scales linearly with watchlist size (~6 MB for 1000 symbols)
- ✅ All existing tests still pass (no regression)

---

## Progress Tracker

### Phase 1: Time Series Infrastructure
- [ ] Change 1.1: Enhance Time Period Conversion
- [ ] Change 1.2: Create Time Series Module

### Phase 2: Storage Backend
- [ ] Change 2: Create Storage Backend

### Phase 3: Indicator Infrastructure
- [ ] Change 3.1: Create Indicator Computer
- [ ] Change 3.2: Add RSI Indicator (Optional)

### Phase 4: Indicator Management
- [ ] Change 4: Create Indicator Manager

### Phase 5: Market Data Adapter
- [ ] Change 5: Refactor Market Data Adapter

### Phase 6: Simulator Integration
- [ ] Change 6: Update Simulator Dependencies
- [ ] Change 7: Add Strategy Invocation
- [ ] Change 8: Order Generation and Execution

### Phase 7: Integration Tests
- [ ] Change 9: End-to-End Integration Test

### Phase 8: Screening Tool (Stretch)
- [ ] Change 10: Create Screener Module

---

## Appendix: Design Rationale

### Why Layered Architecture?
- **Testability**: Each layer independently testable
- **Flexibility**: Easy to swap implementations (e.g., different storage backends)
- **Extensibility**: Add new indicators without modifying existing layers
- **Clarity**: Clear separation of concerns

### Why Time-Agnostic Indicators?
- **Reusability**: Same EMA code works for daily, weekly, monthly
- **Simplicity**: Indicator logic doesn't need to know about time periods
- **Composability**: Time conversion is a preprocessing step, not indicator-specific

### Why Lazy Loading?
- **Scalability**: Can't load 1000 symbols × 10 years into memory
- **Efficiency**: Only load data when needed
- **Caching**: Keep hot data in memory for fast access

### Why Provisional Values?
- **Realism**: Strategies need indicators every day, not just Fridays
- **Flexibility**: Support both intra-period decisions and period-boundary finalization
- **Correctness**: Clear distinction between provisional and finalized values

### Why Separate Screening?
- **Performance**: Screening 1000s symbols is batch operation, separate from daily simulation
- **Modularity**: Screener can be used standalone or integrated with simulator
- **Clarity**: Screening logic separate from simulation logic
