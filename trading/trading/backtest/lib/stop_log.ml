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
  | Strategy_signal of { label : string; detail : string option }
  | End_of_period
[@@deriving show, eq, sexp]

type stop_info = {
  position_id : string;
  symbol : string;
  entry_date : Date.t option;
  entry_stop : float option;
  exit_stop : float option;
  exit_trigger : exit_trigger option;
}
[@@deriving show, eq, sexp]

type _pos_record = {
  mutable pos_symbol : string;
  mutable pos_entry_date : Date.t option;
  mutable pos_entry_stop : float option;
  mutable pos_current_stop : float option;
  mutable pos_exit_trigger : exit_trigger option;
}

type t = {
  positions : (string, _pos_record) Hashtbl.t;
  mutable current_date : Date.t option;
}

let create () =
  { positions = Hashtbl.create (module String); current_date = None }

let set_current_date t date = t.current_date <- Some date

let exit_trigger_of_reason (reason : Position.exit_reason) : exit_trigger =
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
  | StrategySignal { label; detail } -> Strategy_signal { label; detail }

type stop_trigger_kind = Gap_down | Intraday | End_of_period | Non_stop_exit
[@@deriving show, eq, sexp]

let gap_down_threshold_pct = 0.005

let _is_gap_down ~side ~stop_price ~actual_price ~gap_threshold_pct =
  let open Trading_base.Types in
  match side with
  | Long -> Float.( < ) actual_price (stop_price *. (1.0 -. gap_threshold_pct))
  | Short -> Float.( > ) actual_price (stop_price *. (1.0 +. gap_threshold_pct))

let classify_stop_trigger_kind ?(gap_threshold_pct = gap_down_threshold_pct)
    ~side (trigger : exit_trigger) : stop_trigger_kind =
  match trigger with
  | Stop_loss { stop_price; actual_price } ->
      if _is_gap_down ~side ~stop_price ~actual_price ~gap_threshold_pct then
        Gap_down
      else Intraday
  | End_of_period -> End_of_period
  | Take_profit _ | Signal_reversal _ | Time_expired _ | Underperforming _
  | Portfolio_rebalancing | Strategy_signal _ ->
      Non_stop_exit

let _fresh_record ~symbol =
  {
    pos_symbol = symbol;
    pos_entry_date = None;
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
      record.pos_entry_date <- t.current_date;
      record.pos_entry_stop <- risk_params.stop_loss_price;
      record.pos_current_stop <- risk_params.stop_loss_price
  | UpdateRiskParams { new_risk_params } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_current_stop <- new_risk_params.stop_loss_price
  | TriggerExit { exit_reason; _ } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_exit_trigger <- Some (exit_trigger_of_reason exit_reason)
  | ExitComplete ->
      (* Simulator's end-of-period auto-close path emits [ExitFill] +
         [ExitComplete] without a preceding [TriggerExit]. Tag the position
         with [End_of_period] only when no strategy-emitted trigger has
         already been recorded — an [ExitComplete] that follows a
         [TriggerExit] (the normal stop-out / take-profit path) leaves the
         strategy's trigger intact. *)
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      if Option.is_none record.pos_exit_trigger then
        record.pos_exit_trigger <- Some End_of_period
  | EntryFill _ | CancelEntry _ | ExitFill _ -> ()

let record_transitions t transitions =
  List.iter transitions ~f:(_process_transition t)

let _record_to_info ~position_id record : stop_info =
  {
    position_id;
    symbol = record.pos_symbol;
    entry_date = record.pos_entry_date;
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
