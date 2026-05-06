(* @large-module: position state machine covers entry, partial fills, stop management, and exit transitions *)
(** Position lifecycle state machine *)

open Core

(** {1 Position States} *)

type entry_reasoning =
  | TechnicalSignal of { indicator : string; description : string }
  | PricePattern of string
  | Rebalancing
  | ManualDecision of { description : string }
[@@deriving show, eq]

type risk_params = {
  stop_loss_price : float option;
  take_profit_price : float option;
  max_hold_days : int option;
}
[@@deriving show, eq]

type exit_reason =
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
  | SignalReversal of { description : string }
  | TimeExpired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | PortfolioRebalancing
  | StrategySignal of { label : string; detail : string option }
[@@deriving show, eq]

type position_state =
  | Entering of {
      target_quantity : float;
      entry_price : float;
      filled_quantity : float;
      created_date : Date.t;
    }
  | Holding of {
      quantity : float;
      entry_price : float;
      entry_date : Date.t;
      risk_params : risk_params;
    }
  | Exiting of {
      quantity : float;
      entry_price : float;
      entry_date : Date.t;
      target_quantity : float;
      exit_price : float;
      filled_quantity : float;
      started_date : Date.t;
    }
  | Closed of {
      quantity : float;
      entry_price : float;
      exit_price : float;
      gross_pnl : float option;
      entry_date : Date.t;
      exit_date : Date.t;
      days_held : int;
    }
[@@deriving show, eq]

type position_side = Trading_base.Types.position_side = Long | Short
[@@deriving show, eq]

type t = {
  id : string;
  symbol : string;
  side : position_side;
  entry_reasoning : entry_reasoning;
  exit_reason : exit_reason option;
  state : position_state;
  last_updated : Date.t;
  portfolio_lot_ids : string list;
}
[@@deriving show, eq]

(** {1 Transitions} *)

type transition_trigger = Strategy | Simulator [@@deriving show, eq]

type transition_kind =
  | CreateEntering of {
      symbol : string;
      side : position_side;
      target_quantity : float;
      entry_price : float;
      reasoning : entry_reasoning;
    }
  | EntryFill of { filled_quantity : float; fill_price : float }
  | EntryComplete of { risk_params : risk_params }
  | CancelEntry of { reason : string }
  | TriggerExit of { exit_reason : exit_reason; exit_price : float }
  | UpdateRiskParams of { new_risk_params : risk_params }
  | ExitFill of { filled_quantity : float; fill_price : float }
  | ExitComplete
[@@deriving show, eq]

type transition = {
  position_id : string;
  date : Date.t;
  kind : transition_kind;
}
[@@deriving show, eq]

let trigger_of_kind = function
  | CreateEntering _ | TriggerExit _ | UpdateRiskParams _ -> Strategy
  | EntryFill _ | EntryComplete _ | ExitFill _ | ExitComplete | CancelEntry _ ->
      Simulator

(** {1 Helper Functions} *)

let _validate_position_id position_id transition_id =
  if String.equal position_id transition_id then Ok ()
  else
    let msg =
      Printf.sprintf "Position ID mismatch: expected %s, got %s" position_id
        transition_id
    in
    Error (Status.invalid_argument_error msg)

let _validate_positive name value =
  if Float.(value > 0.0) then Ok ()
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "%s must be positive: %.2f" name value))

let _validate_quantity_bounds filled target =
  if Float.(filled <= target) then Ok ()
  else
    let msg =
      Printf.sprintf "Filled quantity (%.2f) exceeds target (%.2f)" filled
        target
    in
    Error (Status.invalid_argument_error msg)

let _validate_has_fills filled =
  if Float.(filled > 0.0) then Ok ()
  else Error (Status.invalid_argument_error "Cannot complete with no fills")

let _validate_no_fills filled =
  if Float.(filled = 0.0) then Ok ()
  else
    Error
      (Status.invalid_argument_error "Cannot cancel entry after fills occurred")

let _validate_transition t transition =
  match (t.state, transition.kind) with
  | ( Entering { target_quantity; filled_quantity = curr_filled; _ },
      EntryFill { filled_quantity; fill_price } ) ->
      let new_filled = curr_filled +. filled_quantity in
      [
        _validate_positive "fill_price" fill_price;
        _validate_positive "filled_quantity" filled_quantity;
        _validate_quantity_bounds new_filled target_quantity;
      ]
  | Entering { filled_quantity; _ }, EntryComplete _ ->
      [ _validate_has_fills filled_quantity ]
  | Entering { filled_quantity; _ }, CancelEntry _ ->
      [ _validate_no_fills filled_quantity ]
  | Holding _, TriggerExit { exit_price; _ } ->
      [ _validate_positive "exit_price" exit_price ]
  | Holding _, UpdateRiskParams _ -> []
  | ( Exiting { target_quantity; filled_quantity = curr_filled; _ },
      ExitFill { filled_quantity; fill_price } ) ->
      let new_filled = curr_filled +. filled_quantity in
      [
        _validate_positive "fill_price" fill_price;
        _validate_positive "filled_quantity" filled_quantity;
        _validate_quantity_bounds new_filled target_quantity;
      ]
  | Exiting { filled_quantity; _ }, ExitComplete ->
      [ _validate_has_fills filled_quantity ]
  | Closed _, _ -> []
  | _ -> []

(** {1 Position Operations} *)

let create_entering ?(id = None) ?(date = None) transition =
  let open Result.Let_syntax in
  (* Check transition kind first and extract fields *)
  let%bind symbol, side, target_quantity, entry_price, reasoning =
    match transition.kind with
    | CreateEntering { symbol; side; target_quantity; entry_price; reasoning }
      ->
        Ok (symbol, side, target_quantity, entry_price, reasoning)
    | kind ->
        let kind_str = show_transition_kind kind in
        let msg =
          Printf.sprintf "Expected CreateEntering transition, got %s" kind_str
        in
        Error (Status.invalid_argument_error msg)
  in
  (* Validate extracted values *)
  let%bind () = _validate_positive "target_quantity" target_quantity in
  let%bind () = _validate_positive "entry_price" entry_price in
  (* Build position *)
  let position_id =
    match id with Some id -> id | None -> transition.position_id
  in
  let created_date = match date with Some d -> d | None -> transition.date in
  let state =
    Entering
      { target_quantity; entry_price; filled_quantity = 0.0; created_date }
  in
  Ok
    {
      id = position_id;
      symbol;
      side;
      entry_reasoning = reasoning;
      exit_reason = None;
      state;
      last_updated = created_date;
      portfolio_lot_ids = [];
    }

let get_state t = t.state
let is_closed t = match t.state with Closed _ -> true | _ -> false

(** {1 Transition Handlers} *)

let _invalid_transition kind =
  Error
    (Status.invalid_argument_error
       (Printf.sprintf "Invalid transition %s for current state"
          (show_transition_kind kind)))

let _entry_fill t ~date ~target_quantity ~entry_price ~curr ~created_date
    ~filled_quantity =
  let state =
    Entering
      {
        target_quantity;
        entry_price;
        filled_quantity = curr +. filled_quantity;
        created_date;
      }
  in
  Ok { t with state; last_updated = date }

let _entry_complete t ~date ~filled_quantity ~entry_price ~risk_params =
  let state =
    Holding
      {
        quantity = filled_quantity;
        entry_price;
        entry_date = date;
        risk_params;
      }
  in
  Ok { t with state; last_updated = date }

let _cancel_entry t ~date ~entry_price ~created_date =
  let state =
    Closed
      {
        quantity = 0.0;
        entry_price;
        exit_price = entry_price;
        gross_pnl = None;
        entry_date = created_date;
        exit_date = date;
        days_held = Date.diff date created_date;
      }
  in
  Ok
    {
      t with
      state;
      exit_reason = Some PortfolioRebalancing;
      last_updated = date;
    }

let _apply_entering_transition t transition =
  let date = transition.date in
  match (t.state, transition.kind) with
  | ( Entering
        { target_quantity; entry_price; filled_quantity = curr; created_date },
      EntryFill { filled_quantity; _ } ) ->
      _entry_fill t ~date ~target_quantity ~entry_price ~curr ~created_date
        ~filled_quantity
  | Entering { filled_quantity; entry_price; _ }, EntryComplete { risk_params }
    ->
      _entry_complete t ~date ~filled_quantity ~entry_price ~risk_params
  | Entering { entry_price; created_date; _ }, CancelEntry _ ->
      _cancel_entry t ~date ~entry_price ~created_date
  | _, kind -> _invalid_transition kind

let _trigger_exit t ~date ~quantity ~entry_price ~entry_date ~exit_reason
    ~exit_price =
  let state =
    Exiting
      {
        quantity;
        entry_price;
        entry_date;
        target_quantity = quantity;
        exit_price;
        filled_quantity = 0.0;
        started_date = date;
      }
  in
  Ok { t with state; exit_reason = Some exit_reason; last_updated = date }

let _update_risk_params t ~date ~quantity ~entry_price ~entry_date
    ~new_risk_params =
  Ok
    {
      t with
      state =
        Holding
          { quantity; entry_price; entry_date; risk_params = new_risk_params };
      last_updated = date;
    }

let _apply_holding_transition t transition =
  let date = transition.date in
  match (t.state, transition.kind) with
  | ( Holding { quantity; entry_price; entry_date; _ },
      TriggerExit { exit_reason; exit_price } ) ->
      _trigger_exit t ~date ~quantity ~entry_price ~entry_date ~exit_reason
        ~exit_price
  | ( Holding { quantity; entry_price; entry_date; _ },
      UpdateRiskParams { new_risk_params } ) ->
      _update_risk_params t ~date ~quantity ~entry_price ~entry_date
        ~new_risk_params
  | _, kind -> _invalid_transition kind

let _exit_fill t ~date ~quantity ~entry_price ~entry_date ~target_quantity
    ~exit_price ~curr ~started_date ~filled_quantity =
  let state =
    Exiting
      {
        quantity;
        entry_price;
        entry_date;
        target_quantity;
        exit_price;
        filled_quantity = curr +. filled_quantity;
        started_date;
      }
  in
  Ok { t with state; last_updated = date }

let _exit_complete t ~date ~filled_quantity ~entry_price ~exit_price ~entry_date
    =
  let state =
    Closed
      {
        quantity = filled_quantity;
        entry_price;
        exit_price;
        gross_pnl = None;
        entry_date;
        exit_date = date;
        days_held = Date.diff date entry_date;
      }
  in
  Ok { t with state; last_updated = date }

(* @nesting-ok: 7-field Exiting pattern forces multiline match; depth is structural *)
let _apply_exiting_transition t transition =
  let date = transition.date in
  match (t.state, transition.kind) with
  | ( Exiting
        {
          quantity;
          entry_price;
          entry_date;
          target_quantity;
          exit_price;
          filled_quantity = curr;
          started_date;
        },
      ExitFill { filled_quantity; _ } ) ->
      _exit_fill t ~date ~quantity ~entry_price ~entry_date ~target_quantity
        ~exit_price ~curr ~started_date ~filled_quantity
  | ( Exiting { filled_quantity; entry_price; exit_price; entry_date; _ },
      ExitComplete ) ->
      _exit_complete t ~date ~filled_quantity ~entry_price ~exit_price
        ~entry_date
  | _, kind -> _invalid_transition kind

(** {1 Transition Application} *)

let apply_transition t transition =
  let open Result.Let_syntax in
  let%bind () = _validate_position_id t.id transition.position_id in
  let%bind () =
    Status.combine_status_list (_validate_transition t transition)
  in
  match t.state with
  | Entering _ -> _apply_entering_transition t transition
  | Holding _ -> _apply_holding_transition t transition
  | Exiting _ -> _apply_exiting_transition t transition
  | Closed _ ->
      Error
        (Status.invalid_argument_error
           "Cannot apply transitions to closed position")
