# Portfolio / Orders / Stops — Engineering Design

**Codebase:** `dayfine/trading` — ~18,600 lines OCaml, 34 test files. Core + Async throughout.

**Related docs:** [System Design](weinstein-trading-system-v2.md) · [Detailed Design](weinstein-detailed-design.md) · [Book Reference](weinstein-screener-design-doc-v2.md)

## Portfolio / Orders / Stops

## 3.1 Components

- **Portfolio** — existing `trading/portfolio/` — **no changes**
- **Orders** — existing `trading/orders/` — **no changes**
- **Engine** — existing `trading/engine/` — **no changes**
- **Position** — existing `trading/strategy/lib/position.ml` — **no changes**
- **Weinstein Stops** — new: `analysis/weinstein/stops/`
- **Portfolio Risk** — new: `analysis/weinstein/portfolio_risk/`
- **Order Generator** — new: `analysis/weinstein/order_gen/`
- **Trading State** — new: `analysis/weinstein/trading_state/`

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

### Order Generation

```ocaml
(* weinstein_order_gen.mli *)
type suggested_order = {
  ticker : string; side : Types.side;
  order_type : Types.order_type;  (* StopLimit for entries, Stop for stops *)
  shares : int; rationale : string;
  grade : Weinstein_types.grade option;
}

val from_candidates : candidates:Screener.scored_candidate list ->
  snapshot:Portfolio_risk.portfolio_snapshot -> config:Portfolio_risk.config ->
  suggested_order list

val from_stop_adjustments : adjustments:(string * Weinstein_stops.stop_event) list ->
  positions:Position.t String.Map.t -> suggested_order list

val from_exits : exits:(string * Weinstein_stops.stop_event) list ->
  positions:Position.t String.Map.t -> suggested_order list
```

---

## Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| Don't modify existing Position | Parallel Weinstein stop state | Extend risk_params | Keeps 6 test files passing, cleaner separation, no interface pollution |
| JSON for trading state | Simple file + atomic rename | SQLite or protobuf | Human-readable, tiny volume, easy debugging, schema evolution trivial |
| Redundant stop price | In both risk_params and stop_state | Single source of truth | Strategy is only writer — sync is simple. Clean module boundaries worth the duplication. |
