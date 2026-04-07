# Portfolio / Orders / Stops — Engineering Design

**Codebase:** `dayfine/trading` — ~18,600 lines OCaml, 34 test files. Core + Async throughout.

**Related docs:** [System Design](weinstein-trading-system-v2.md) · [Book Reference](weinstein-book-reference.md)

## Portfolio / Orders / Stops

## 3.1 Components

- **Portfolio** — existing `trading/portfolio/` — **no changes**
- **Orders** — existing `trading/orders/` — **no changes**
- **Engine** — existing `trading/engine/` — **no changes**
- **Position** — existing `trading/strategy/lib/position.ml` — **no changes**
- **Weinstein Stops** — new: `trading/weinstein/stops/`
- **Portfolio Risk** — new: `analysis/weinstein/portfolio_risk/`
- **Weinstein Strategy** — new: `trading/weinstein/strategy/` — implements `STRATEGY` interface; IS the portfolio manager for both live and simulation
- **Trading State** — new: `trading/weinstein/trading_state/` — persistence for live runs
- **Order Generator** — new: `trading/weinstein/order_gen/` — formats `Position.transition list` → broker orders for the live runner

## 3.2 Requirements

**Functional:**
- Track open positions with Weinstein-specific stop state (initial, trailing, tightened)
- Implement the full trailing stop state machine (Weinstein Ch. 6)
- Compute position sizes using fixed-risk sizing
- Track portfolio exposure (long/short/cash %) and enforce limits
- Detect sector concentration
- Generate orders from screener candidates and stop events
- Persist portfolio state between runs
- Support both live (manual trade logging) and simulated (auto-fill) modes

**Non-functional:**
- Stop computations: deterministic (same bars + state = same result)
- State serialization: atomic (no partial writes on crash)
- Position sizing: never exceeds available cash

**Non-requirements:**
- Margin calculations, options, multi-currency, tax-lot optimization

## 3.3 Design

### Key Decision: Don't Modify Existing Modules

Existing Portfolio, Orders, Engine, Position are well-tested. We build alongside, not inside.

Weinstein stop state lives in a separate module. The strategy manages a parallel map of `(ticker → stop_state)` alongside the position map. When adjusting a stop, the strategy emits `UpdateRiskParams` (existing Position transition) with the new stop_loss_price.

**Why not extend Position.risk_params?** `risk_params` is generic (all strategies). Weinstein stops need more state (correction lows, rally peaks, MA at adjustment). Adding these pollutes the interface. Keeping separate means 6 existing Position test files pass with zero changes.

**Trade-off:** Slight redundancy — stop price exists in both `risk_params.stop_loss_price` and `stop_state.stop_level`. Strategy keeps them in sync. Acceptable — strategy is the only writer.

### Weinstein Stops

```ocaml
(* weinstein_stops.mli *)

type stop_state =
  | Initial of { stop_level : float; support_floor : float; entry_price : float }
  | Trailing of {
      stop_level : float; last_correction_low : float;
      last_rally_peak : float; ma_at_last_adjustment : float;
      correction_count : int;
    }
  | Tightened of { stop_level : float; last_correction_low : float; reason : string }
[@@deriving show, eq]

type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening of { reason : string }
  | No_change
[@@deriving show, eq]

type config = {
  round_number_nudge : float;    (* default: 0.125 *)
  min_correction_pct : float;    (* default: 0.08 *)
  max_initial_risk_pct : float;  (* default: 0.15 *)
  tighten_on_flat_ma : bool;     (* default: true *)
}

val compute_initial_stop : config:config -> entry_price:float -> support_floor:float -> stop_state
val update : config:config -> state:stop_state -> current_bar:Types.Daily_price.t ->
  ma_value:float -> ma_slope:Weinstein_types.ma_slope ->
  stage:Weinstein_types.stage -> stop_state * stop_event
val check_stop_hit : state:stop_state -> low_price:float -> bool
```

**State transitions:**
```
Initial ──→ Trailing (after first 8–10% correction + recovery)
Trailing ──→ Trailing (stop ratcheted after each correction cycle)
Trailing ──→ Tightened (MA flattens / Stage 3 detected)
Tightened ──→ Tightened (stop ratcheted more aggressively)
Any ──→ [stop hit] → exit signal
```

**Round number logic:** If stop lands near N.0 or N.5, nudge below (e.g. 18.125 → 17.875). Buy orders accumulate at round numbers creating support — if that level breaks, real trouble.

### Portfolio Risk

```ocaml
(* portfolio_risk.mli *)
type portfolio_snapshot = {
  total_value : float; cash : float; cash_pct : float;
  long_exposure : float; long_exposure_pct : float;
  short_exposure : float; short_exposure_pct : float;
  position_count : int; sector_counts : (string * int) list;
}

type sizing_result = { shares : int; position_value : float; position_pct : float; risk_amount : float }

type limit_violation =
  | Max_positions_exceeded of int
  | Long_exposure_exceeded of float | Short_exposure_exceeded of float
  | Cash_below_minimum of float
  | Sector_concentration of string * int
  | Risk_too_high of float
[@@deriving show]

type config = {
  risk_per_trade_pct : float; max_positions : int;
  max_long_exposure_pct : float; max_short_exposure_pct : float;
  min_cash_pct : float; max_sector_concentration : int;
  big_winner_multiplier : float;
}

val snapshot : portfolio:Portfolio.t -> market_prices:(string * float) list -> portfolio_snapshot
val compute_position_size : config:config -> portfolio_value:float ->
  entry_price:float -> stop_price:float -> ?big_winner:bool -> unit -> sizing_result
val check_limits : config:config -> snapshot:portfolio_snapshot ->
  proposed_side:[ `Long | `Short ] -> proposed_value:float ->
  proposed_sector:string -> (unit, limit_violation list) Result.t
```

### Trading State Persistence

```ocaml
(* trading_state.mli *)
type t = {
  portfolio : Portfolio.t;
  positions : Position.t String.Map.t;
  stop_states : (string * Weinstein_stops.stop_state) list;
  prior_stages : (string * Weinstein_types.stage) list;
  prior_macro : Macro.result option;
  trade_log : trade_log_entry list;
  last_scan_date : Date.t option;
}

type trade_log_entry = {
  date : Date.t; ticker : string;
  action : [ `Buy | `Sell | `Short | `Cover ];
  price : float; shares : int;
  grade : Weinstein_types.grade option; reason : string;
}

val empty : initial_cash:float -> t
val save : t -> path:Fpath.t -> unit Status.status_or
val load : path:Fpath.t -> t Status.status_or
```

**Format:** JSON. Small (<100KB). Human-readable. Atomic write via temp file + rename.

**Why JSON, not SQLite?** Human-inspectable (`cat state.json`). Easy to debug. Schema evolution is trivial. Performance irrelevant — read/write once per scan. If trade log grows to thousands of entries, could move history to SQLite while keeping active state in JSON.

### Live Runner vs Simulator

The `STRATEGY` interface is the generic seam between decision logic and execution —
the same strategy runs in both contexts. There is no separate "portfolio manager"
component.

```
Simulation (backtesting):
  Simulator drives a time loop
    → calls strategy.on_market_close at each step (strategy is the callback)
    → auto-executes Position.transition list (fills, position tracking)
    → accumulates equity curve + metrics
  Simulator IS the stateful portfolio manager for backtesting.

Live (weekly scan):
  Live runner triggered by cron or manually
    → loads trading_state from disk
    → constructs strategy with initial_stop_states = trading_state.stop_states
    → calls strategy.on_market_close (same call as simulation)
    → passes Position.transition list to order_gen → broker order suggestions
    → saves updated trading_state
  trading_state is the live runner's equivalent of the simulator's in-memory state.
```

Both paths call the same `strategy.on_market_close`. The difference is what happens
to the output: the simulator auto-executes; the live runner formats it for human review.

The strategy already supports live initialization:
```ocaml
(* weinstein_strategy already accepts saved stop state *)
val make : ?initial_stop_states:Weinstein_stops.stop_state String.Map.t
        -> config -> (module Strategy_interface.STRATEGY)
```

### Order Generation

`order_gen` translates `Position.transition list` from the strategy into concrete
broker order specifications for the live runner. It is not used by the simulator.

**Input:** `Position.transition list` from `strategy.on_market_close` + a position
quantity lookup (to determine share count for stop and exit orders).

**Output:** Suggested broker orders the human reviews before placing.

```
CreateEntering { symbol; side=Long; target_quantity=100; entry_price=150 }
  → StopLimit buy 100 shares at $150 (triggers + fills at the breakout level)

UpdateRiskParams { stop_loss_price=140 }
  → Cancel old stop / place Stop sell 100 shares at $140

TriggerExit { exit_price }
  → Market sell 100 shares (stop was hit, exit at market open)
```

This translation is strategy-agnostic: any strategy using `Position.transition` gets
broker order formatting. No Weinstein-specific logic needed.

```ocaml
(* weinstein_order_gen.mli — trading/weinstein/order_gen/ *)

type suggested_order = {
  ticker     : string;
  side       : Trading_base.Types.side;
  order_type : Trading_base.Types.order_type;
  shares     : int;
  rationale  : string;
}
[@@deriving show, eq]

val from_transitions :
  transitions:Trading_strategy.Position.transition list ->
  get_position:(string -> Trading_strategy.Position.t option) ->
  suggested_order list
(** Translate strategy output into broker orders.
    CreateEntering  → StopLimit entry order.
    UpdateRiskParams { stop_loss_price } → Stop order at new level.
    TriggerExit     → Market exit order.
    Other transitions → ignored. *)
```

**Location:** `trading/weinstein/order_gen/` — depends on `Trading_strategy.Position`
so it belongs in `trading/`, not `analysis/`.

---

## Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| Don't modify existing Position | Parallel Weinstein stop state | Extend risk_params | Keeps 6 existing test files passing; Weinstein stop fields (correction lows, peaks, MA history) don't belong in a generic interface |
| STRATEGY as the portfolio manager | Single interface for live + simulation | Separate portfolio_manager component | Avoids phantom abstraction; strategy already accepts `initial_stop_states` for live initialization; same code runs both paths |
| order_gen takes Position.transition | Strategy-agnostic formatter | order_gen takes screener output + does sizing | Sizing decisions already made by strategy; formatting is the only live-specific concern; any strategy gets order formatting for free |
| JSON for trading state | Simple file + atomic rename | SQLite or protobuf | Human-readable, tiny volume, easy debugging, schema evolution trivial |
| Redundant stop price | In both risk_params and stop_state | Single source of truth | Strategy is only writer — sync is simple; clean module boundaries worth the duplication |
