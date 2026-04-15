(** Per-trade stop logging for backtest diagnostics. *)

open Core
open Trading_strategy

type exit_trigger =
  | Stop_loss of { stop_price : float; actual_price : float }
  | Take_profit of { target_price : float; actual_price : float }
  | Signal_reversal of { description : string }
  | Time_expired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | Portfolio_rebalancing
[@@deriving show, eq, sexp]

type stop_info = {
  position_id : string;
  symbol : string;
  entry_stop : float option;
  exit_stop : float option;
  exit_trigger : exit_trigger option;
}
[@@deriving show, eq, sexp]

type _pos_record = {
  mutable pos_symbol : string;
  mutable pos_entry_stop : float option;
  mutable pos_current_stop : float option;
  mutable pos_exit_trigger : exit_trigger option;
}

type t = { positions : (string, _pos_record) Hashtbl.t }

let create () = { positions = Hashtbl.create (module String) }

let _exit_trigger_of_reason (reason : Position.exit_reason) : exit_trigger =
  match reason with
  | StopLoss { stop_price; actual_price; _ } ->
      Stop_loss { stop_price; actual_price }
  | TakeProfit { target_price; actual_price; _ } ->
      Take_profit { target_price; actual_price }
  | SignalReversal { description } -> Signal_reversal { description }
  | TimeExpired { days_held; max_days } -> Time_expired { days_held; max_days }
  | Underperforming { days_held; current_return } ->
      Underperforming { days_held; current_return }
  | PortfolioRebalancing -> Portfolio_rebalancing

let _fresh_record ~symbol =
  {
    pos_symbol = symbol;
    pos_entry_stop = None;
    pos_current_stop = None;
    pos_exit_trigger = None;
  }

let _ensure_record t ~position_id ~symbol =
  Hashtbl.find_or_add t.positions position_id ~default:(fun () ->
      _fresh_record ~symbol)

let _process_transition t (trans : Position.transition) =
  match trans.kind with
  | CreateEntering { symbol; _ } ->
      let _record = _ensure_record t ~position_id:trans.position_id ~symbol in
      ()
  | EntryComplete { risk_params } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_entry_stop <- risk_params.stop_loss_price;
      record.pos_current_stop <- risk_params.stop_loss_price
  | UpdateRiskParams { new_risk_params } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_current_stop <- new_risk_params.stop_loss_price
  | TriggerExit { exit_reason; _ } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_exit_trigger <- Some (_exit_trigger_of_reason exit_reason)
  | EntryFill _ | CancelEntry _ | ExitFill _ | ExitComplete -> ()

let record_transitions t transitions =
  List.iter transitions ~f:(_process_transition t)

let _record_to_info ~position_id record : stop_info =
  {
    position_id;
    symbol = record.pos_symbol;
    entry_stop = record.pos_entry_stop;
    exit_stop = record.pos_current_stop;
    exit_trigger = record.pos_exit_trigger;
  }

let _compare_by_position_id (a : stop_info) (b : stop_info) =
  String.compare a.position_id b.position_id

let get_stop_infos t : stop_info list =
  Hashtbl.fold t.positions ~init:[] ~f:(fun ~key:position_id ~data:record acc ->
      _record_to_info ~position_id record :: acc)
  |> List.sort ~compare:_compare_by_position_id
