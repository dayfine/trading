# Position Lifecycle State Machine Design

## Overview

This document defines a state machine model for tracking the complete lifecycle of a trading position from entry signal to position closure. This replaces the previous intent-based model with explicit states and transitions.

## Motivation

**Problems with Intent-Based Model**:
- Entry and exit are separate intents with no relationship
- No "holding" phase - positions exist in portfolio but aren't tracked by intents
- Exit intents don't know entry price or entry date (needed for P&L, stop loss, time-based exits)
- Complex state space - hard to reason about all possible combinations
- Lifecycle is implicit rather than explicit

**State Machine Benefits**:
- Single position object tracks entire lifecycle
- Explicit states make valid/invalid transitions clear
- Each state contains only relevant data
- Transitions are explicit and testable
- Easy to audit and debug position lifecycle

## State Diagram

```
                    ┌─────────────┐
                    │   SIGNAL    │
                    │  DETECTED   │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
              ┌────▶│  ENTERING   │◀────┐
              │     └──────┬──────┘     │
              │            │            │
    Cancel    │            │ Entry      │ Partial
              │            │ Complete   │ Fill
              │            ▼            │
              │     ┌─────────────┐     │
              │     │   HOLDING   │─────┘
              │     └──────┬──────┘
              │            │
              │            │ Exit
              │            │ Triggered
              │            ▼
              │     ┌─────────────┐
              └────▶│   EXITING   │◀────┐
                    └──────┬──────┘     │
                           │            │
                  Exit     │            │ Partial
                  Complete │            │ Fill
                           ▼            │
                    ┌─────────────┐     │
                    │   CLOSED    │─────┘
                    └─────────────┘
```

## States

### 1. Entering

**Purpose**: Attempting to open a position.

**Data**:
```ocaml
type entering_state = {
  id : string;                        (* Unique position identifier *)
  symbol : string;
  target_quantity : float;            (* Desired position size *)
  entry_plan : entry_plan;            (* How to enter *)
  orders_placed : order_id list;      (* Orders currently working *)
  filled_quantity : float;            (* Amount filled so far *)
  created_date : Date.t;
  reasoning : entry_reasoning;        (* Why entering *)
}

and entry_plan =
  | LimitEntry of float                      (* Single limit order *)
  | ScaledEntry of entry_level list          (* Multiple limit orders *)
  | StopEntry of { trigger : float; limit : float option }

and entry_level = {
  price : float;
  quantity : float;                   (* Absolute quantity at this level *)
}

and entry_reasoning =
  | TechnicalSignal of {
      indicator : string;             (* "EMA", "RSI", etc. *)
      description : string;
    }
  | PricePattern of string
  | Rebalancing
```

**Valid Transitions**:
- → `Holding` (when target quantity filled)
- → `Closed` (if cancelled before any fills)
- → `Entering` (partial fill, update filled_quantity)

### 2. Holding

**Purpose**: Position is open, monitoring for exit conditions.

**Data**:
```ocaml
type holding_state = {
  id : string;
  symbol : string;
  quantity : float;                   (* Current position size *)
  entry_price : float;                (* Average entry price *)
  entry_date : Date.t;
  entry_reasoning : entry_reasoning;  (* Why we entered *)
  risk_params : risk_params;          (* Exit conditions *)
}

and risk_params = {
  stop_loss_price : float option;     (* Exit if price falls below *)
  take_profit_price : float option;   (* Exit if price rises above *)
  trailing_stop_percent : float option;
  max_hold_days : int option;         (* Time-based exit *)
}
```

**Valid Transitions**:
- → `Exiting` (when exit condition triggered)

### 3. Exiting

**Purpose**: Attempting to close position.

**Data**:
```ocaml
type exiting_state = {
  id : string;
  symbol : string;
  holding_state : holding_state;      (* Original position info *)
  exit_reason : exit_reason;
  target_quantity : float;            (* Amount to exit *)
  exit_plan : exit_plan;              (* How to exit *)
  orders_placed : order_id list;
  filled_quantity : float;            (* Amount exited so far *)
  started_date : Date.t;
}

and exit_reason =
  | TakeProfit of {
      target_price : float;
      actual_price : float;
      profit_percent : float;
    }
  | StopLoss of {
      stop_price : float;
      actual_price : float;
      loss_percent : float;
    }
  | TrailingStop of {
      high_water_mark : float;
      stop_price : float;
    }
  | SignalReversal of {
      original_signal : entry_reasoning;
      reversal_description : string;
    }
  | TimeExpired of {
      days_held : int;
      max_days : int;
    }
  | Underperforming of {
      days_held : int;
      current_return : float;
      benchmark_return : float option;
    }
  | PortfolioRebalancing

and exit_plan =
  | LimitExit of float
  | MarketExit                        (* Only allowed for exits *)
  | ScaledExit of exit_level list

and exit_level = {
  price : float;
  quantity : float;
}
```

**Valid Transitions**:
- → `Closed` (when all quantity exited)
- → `Exiting` (partial fill, update filled_quantity)

### 4. Closed

**Purpose**: Position fully closed, final state.

**Data**:
```ocaml
type closed_state = {
  id : string;
  symbol : string;
  quantity : float;                   (* Total quantity traded *)
  entry_price : float;
  exit_price : float;                 (* Average exit price *)
  gross_pnl : float;                  (* Before commissions *)
  net_pnl : float;                    (* After commissions *)
  return_percent : float;             (* (exit - entry) / entry *)
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_reasoning : entry_reasoning;
  close_reason : exit_reason;
  commissions_paid : float;
}
```

**Valid Transitions**: None (terminal state)

## State Machine Type

```ocaml
type position_state =
  | Entering of entering_state
  | Holding of holding_state
  | Exiting of exiting_state
  | Closed of closed_state
[@@deriving show, eq]

type position = {
  state : position_state;
  last_updated : Date.t;
}
```

## Transitions

### Transition Type

```ocaml
type transition =
  (* Entry phase *)
  | PlaceEntryOrder of {
      position_id : string;
      order : Trading_orders.Types.order;
    }
  | EntryPartialFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
    }
  | EntryComplete of {
      position_id : string;
      total_filled : float;
      average_price : float;
      risk_params : risk_params;
    }
  | CancelEntry of {
      position_id : string;
      reason : string;
    }

  (* Holding phase *)
  | TriggerExit of {
      position_id : string;
      exit_reason : exit_reason;
      exit_plan : exit_plan;
    }
  | UpdateRiskParams of {
      position_id : string;
      new_risk_params : risk_params;
    }

  (* Exit phase *)
  | PlaceExitOrder of {
      position_id : string;
      order : Trading_orders.Types.order;
    }
  | ExitPartialFill of {
      position_id : string;
      filled_quantity : float;
      fill_price : float;
    }
  | ExitComplete of {
      position_id : string;
      total_filled : float;
      average_exit_price : float;
    }
[@@deriving show, eq]
```

### Transition Triggers

**What triggers each transition?**

| Transition | Triggered By | When |
|------------|-------------|------|
| PlaceEntryOrder | Strategy | Signal detected, ready to enter |
| EntryPartialFill | Engine | Order partially filled |
| EntryComplete | Engine | All entry orders filled |
| CancelEntry | Strategy | Signal invalidated, or manual cancel |
| TriggerExit | Strategy | Exit condition met (stop loss, take profit, etc.) |
| UpdateRiskParams | Strategy | Adjust stops (e.g., trailing stop) |
| PlaceExitOrder | Strategy | Exit triggered, place order |
| ExitPartialFill | Engine | Exit order partially filled |
| ExitComplete | Engine | All exit orders filled |

### Transition Validation

```ocaml
val apply_transition :
  position ->
  transition ->
  position Status.status_or
  (** Apply a transition to a position.

      Returns Error if:
      - Transition is invalid for current state
      - Position ID doesn't match
      - Data is inconsistent (e.g., filled > target)
      - Business rules violated
  *)
```

**Validation Rules**:

1. **State-Transition Compatibility**:
   - `PlaceEntryOrder`, `EntryPartialFill`, `EntryComplete`, `CancelEntry` → only valid in `Entering`
   - `TriggerExit`, `UpdateRiskParams` → only valid in `Holding`
   - `PlaceExitOrder`, `ExitPartialFill`, `ExitComplete` → only valid in `Exiting`

2. **Data Consistency**:
   - `filled_quantity` must be ≤ `target_quantity`
   - `average_price` must be > 0
   - `risk_params.stop_loss_price` must be < entry_price (for long positions)
   - `risk_params.take_profit_price` must be > entry_price (for long positions)

3. **Business Rules**:
   - Cannot cancel entry after partial fill (must complete or force exit)
   - Cannot trigger exit before entry completes
   - Position ID must match
   - Dates must advance monotonically

### Transition Examples

**Example 1: Successful Entry → Hold → Exit**

```ocaml
(* Day 1: Create entering state *)
let entering = {
  id = "pos-001";
  symbol = "AAPL";
  target_quantity = 100.0;
  entry_plan = LimitEntry 150.0;
  orders_placed = [];
  filled_quantity = 0.0;
  created_date = Date.of_string "2024-01-01";
  reasoning = TechnicalSignal { indicator = "EMA"; description = "Price crossed above EMA(30)" };
} in
let position = { state = Entering entering; last_updated = day1 } in

(* Day 1: Place order *)
let position = apply_transition position
  (PlaceEntryOrder { position_id = "pos-001"; order = ... }) in

(* Day 2: Order fills completely *)
let position = apply_transition position
  (EntryComplete {
    position_id = "pos-001";
    total_filled = 100.0;
    average_price = 150.0;
    risk_params = {
      stop_loss_price = Some 142.5;  (* -5% *)
      take_profit_price = Some 165.0;  (* +10% *)
      trailing_stop_percent = None;
      max_hold_days = Some 30;
    };
  }) in
(* position.state = Holding { entry_price = 150.0; quantity = 100.0; ... } *)

(* Day 7: Price hits take profit *)
let position = apply_transition position
  (TriggerExit {
    position_id = "pos-001";
    exit_reason = TakeProfit {
      target_price = 165.0;
      actual_price = 165.5;
      profit_percent = 10.3;
    };
    exit_plan = LimitExit 165.0;
  }) in
(* position.state = Exiting { exit_reason = TakeProfit; ... } *)

(* Day 7: Exit order fills *)
let position = apply_transition position
  (ExitComplete {
    position_id = "pos-001";
    total_filled = 100.0;
    average_exit_price = 165.5;
  }) in
(* position.state = Closed { net_pnl = 1550.0; return_percent = 10.3; ... } *)
```

**Example 2: Partial Fill → Cancel**

```ocaml
(* Entering with partial fill *)
let entering = { ...; filled_quantity = 50.0; target_quantity = 100.0; ... } in
let position = { state = Entering entering; ... } in

(* Try to cancel - should fail! *)
match apply_transition position (CancelEntry { position_id = "pos-001"; reason = "Changed mind" }) with
| Error status ->
    (* "Cannot cancel entry after partial fill. Must complete entry or force exit." *)
| Ok _ -> (* Won't happen *)
```

## Strategy Integration

### Strategy State

Strategy maintains a map of active positions:

```ocaml
type strategy_state = {
  active_positions : (string, position) Hashtbl.t;  (* position_id -> position *)
  closed_positions : closed_state list;              (* For performance tracking *)
  config : strategy_config;
}
```

### Strategy on_market_close

```ocaml
val on_market_close :
  market_data:market_data ->
  portfolio:Portfolio.t ->
  state:strategy_state ->
  (strategy_output * strategy_state) Status.status_or

and strategy_output = {
  transitions : transition list;     (* State transitions to apply *)
  orders : order list;               (* Orders to submit to engine *)
}
```

**Strategy responsibilities**:

1. **Monitor entering positions**: Check for fills, trigger completion
2. **Monitor holding positions**: Check exit conditions (stop loss, take profit, signal reversal)
3. **Monitor exiting positions**: Check for fills, trigger completion
4. **Generate new signals**: Create new entering positions
5. **Apply transitions**: Update position states based on market data

### Example Strategy Logic

```ocaml
let on_market_close ~market_data ~portfolio ~state =
  let transitions = [] in
  let orders = [] in

  (* 1. Check all holding positions for exit conditions *)
  Hashtbl.iter state.active_positions ~f:(fun ~key:id ~data:pos ->
    match pos.state with
    | Holding holding ->
        let current_price = MarketData.get_price market_data holding.symbol in
        (* Check stop loss *)
        (match holding.risk_params.stop_loss_price with
        | Some stop when current_price <= stop ->
            let transition = TriggerExit {
              position_id = id;
              exit_reason = StopLoss { stop_price = stop; actual_price = current_price; ... };
              exit_plan = MarketExit;  (* Exit immediately *)
            } in
            transitions := transition :: !transitions
        | _ -> ());
        (* Check take profit *)
        (match holding.risk_params.take_profit_price with
        | Some target when current_price >= target ->
            let transition = TriggerExit {
              position_id = id;
              exit_reason = TakeProfit { target_price = target; actual_price = current_price; ... };
              exit_plan = LimitExit target;
            } in
            transitions := transition :: !transitions
        | _ -> ())
    | _ -> ()
  );

  (* 2. Check for new entry signals *)
  let ema = MarketData.get_ema market_data "AAPL" 30 in
  let price = MarketData.get_price market_data "AAPL" in
  if price > ema then
    (* Signal: enter position *)
    let entering = {
      id = generate_id ();
      symbol = "AAPL";
      target_quantity = 100.0;
      entry_plan = LimitEntry price;
      ...
    } in
    let new_position = { state = Entering entering; last_updated = today } in
    Hashtbl.set state.active_positions ~key:entering.id ~data:new_position;

  Ok ({ transitions; orders }, state)
```

## Testing Strategy

### Unit Tests for Transitions

Test each transition independently:

```ocaml
let test_entry_complete _ =
  let entering = make_entering ~filled:100.0 ~target:100.0 in
  let position = { state = Entering entering; ... } in
  let transition = EntryComplete {
    position_id = entering.id;
    total_filled = 100.0;
    average_price = 150.0;
    risk_params = default_risk_params;
  } in
  match apply_transition position transition with
  | Ok { state = Holding holding; ... } ->
      assert_equal 100.0 holding.quantity;
      assert_equal 150.0 holding.entry_price
  | _ -> assert_failure "Expected Holding state"

let test_invalid_transition _ =
  let holding = make_holding () in
  let position = { state = Holding holding; ... } in
  let transition = EntryComplete { ... } in  (* Invalid for Holding *)
  match apply_transition position transition with
  | Error status ->
      assert_bool "Should reject invalid transition"
        (String.is_substring (Status.show status) ~substring:"Invalid transition")
  | Ok _ -> assert_failure "Should have rejected transition"
```

### Property-Based Tests

```ocaml
(* Property: filled_quantity never exceeds target_quantity *)
let prop_filled_never_exceeds_target position transition =
  match apply_transition position transition with
  | Ok { state = Entering { filled_quantity; target_quantity; ... }; ... } ->
      filled_quantity <= target_quantity
  | _ -> true

(* Property: Holding state always has positive entry_price and quantity *)
let prop_holding_valid position transition =
  match apply_transition position transition with
  | Ok { state = Holding { entry_price; quantity; ... }; ... } ->
      entry_price > 0.0 && quantity > 0.0
  | _ -> true
```

## Implementation Plan

**Status: All phases completed ✅**

### Phase 1: Core Types and Transitions ✅
- [x] Define state types (entering_state, holding_state, exiting_state, closed_state)
- [x] Define transition type
- [x] Implement apply_transition with validation
- [x] Unit tests for each transition
- [x] Property-based tests for invariants

### Phase 2: Strategy Integration ✅
- [x] Update strategy_state to use position map
- [x] Update strategy_output to use transitions
- [x] Example strategy using state machine (EMA strategy, Buy and Hold)

### Phase 3: Simulator Integration ✅
- [x] Simulator applies transitions from strategy
- [x] Simulator triggers transitions based on engine results (fills)
- [x] Integration tests (see `test_e2e_integration.ml`)

## Open Questions

1. **Partial fills during entry**: Should we auto-transition to Holding after first fill, or wait for all orders?
   - **Proposal**: Wait for EntryComplete transition. Strategy decides when to transition.

2. **Forced exit of entering position**: What if we need to exit a position that's still entering?
   - **Proposal**: Add ForceExit transition that works from any state

3. **Position sizing**: Should target_quantity be in shares or dollars?
   - **Proposal**: Shares for now. Add PositionSizing helper to convert % to shares.

4. **Multiple exit reasons**: Can a position trigger multiple exit conditions simultaneously?
   - **Proposal**: Take first triggered condition. Priority: StopLoss > TakeProfit > Other

## Summary

**Key Improvements**:
- ✅ Explicit lifecycle: Entering → Holding → Exiting → Closed
- ✅ Each state has only relevant data
- ✅ Transitions are explicit and validated
- ✅ Exit knows entry price and date
- ✅ Single position object tracks full lifecycle
- ✅ Easy to test and audit

**Business-Critical Aspects**:
- Transition triggers are well-defined (strategy vs engine)
- Transition validation prevents invalid states
- State invariants are testable
- Lifecycle is auditable (log every transition)
