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
  max_stop : float option;
  n_stop_raises : int;
}
[@@deriving show, eq, sexp]

type _pos_record = {
  mutable pos_symbol : string;
  mutable pos_side : Trading_base.Types.position_side;
  mutable pos_entry_date : Date.t option;
  mutable pos_entry_stop : float option;
  mutable pos_current_stop : float option;
  mutable pos_exit_trigger : exit_trigger option;
  mutable pos_exit_trigger_date : Date.t option;
      (* The transition date [pos_exit_trigger] was recorded on (#3147). *)
  mutable pos_max_stop : float option;
  mutable pos_n_stop_raises : int;
  mutable pos_seen_decision : bool;
      (* Whether {!record_stop_decision} has fired for this position yet: the
         first one is the fill-time seed of the stop machine. *)
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

let with_fill_price trigger ~fill_price =
  match trigger with
  | Stop_loss { stop_price; _ } ->
      Stop_loss { stop_price; actual_price = fill_price }
  | Take_profit { target_price; _ } ->
      Take_profit { target_price; actual_price = fill_price }
  | other -> other

type stop_trigger_kind =
  | Gap_through
  | Intraday
  | End_of_period
  | Non_stop_exit
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
        Gap_through
      else Intraday
  | End_of_period -> End_of_period
  | Take_profit _ | Signal_reversal _ | Time_expired _ | Underperforming _
  | Portfolio_rebalancing | Strategy_signal _ ->
      Non_stop_exit

let _fresh_record ~symbol =
  {
    pos_symbol = symbol;
    (* The record convention is long-only; a position whose [CreateEntering] we
       never observed — the stream starts at [EntryComplete] or
       [UpdateRiskParams] — is treated as long. *)
    pos_side = Trading_base.Types.Long;
    pos_entry_date = None;
    pos_entry_stop = None;
    pos_current_stop = None;
    pos_exit_trigger = None;
    pos_exit_trigger_date = None;
    pos_max_stop = None;
    pos_n_stop_raises = 0;
    pos_seen_decision = false;
  }

let _ensure_record t ~position_id ~symbol =
  Hashtbl.find_or_add t.positions position_id ~default:(fun () ->
      _fresh_record ~symbol)

(* "More protective" is directional: a long's stop protects by rising, a
   short's by falling. Strict comparison, so a re-install of the same level is
   not a raise — and a split rescale (which moves price and stop down together)
   is strictly less protective for a long, hence never counted. *)
let _is_more_protective ~(side : Trading_base.Types.position_side) ~previous
    ~next =
  match side with
  | Long -> Float.( > ) next previous
  | Short -> Float.( < ) next previous

(* Advance the high-water mark. An absent mark takes the new level as-is: that
   is the seed, not a raise. *)
let _more_protective_of ~side ~current ~next =
  match current with
  | None -> Some next
  | Some previous ->
      if _is_more_protective ~side ~previous ~next then Some next else current

(* One installed stop level. [is_raise_candidate] is false for the
   [EntryComplete] seed (which can never be a raise) and true for every
   [UpdateRiskParams]. *)
let _install_stop record ~level ~is_raise_candidate =
  let raised =
    is_raise_candidate
    &&
    match record.pos_current_stop with
    | None -> false (* first level on this position: an install, not a raise *)
    | Some previous ->
        _is_more_protective ~side:record.pos_side ~previous ~next:level
  in
  if raised then record.pos_n_stop_raises <- record.pos_n_stop_raises + 1;
  record.pos_max_stop <-
    _more_protective_of ~side:record.pos_side ~current:record.pos_max_stop
      ~next:level;
  record.pos_current_stop <- Some level

(* The position's initial stop: [entry_stop], the first [current] level and the
   high-water seed. Never a raise. *)
let _seed_entry_stop record ~level =
  record.pos_entry_stop <- Some level;
  _install_stop record ~level ~is_raise_candidate:false

(* The simulator's forced-exit labels ({!Trading_simulation.Margin_runner}). *)
let _margin_exit_labels =
  [ "margin_call"; "buyin_stress"; "maintenance_reduce" ]

let _is_margin_trigger = function
  | Strategy_signal { label; _ } ->
      List.mem _margin_exit_labels label ~equal:String.equal
  | _ -> false

(* #3147: a margin exit does not overwrite a trigger the strategy recorded for
   the same position on the same day. [Margin_runner] drops that strategy exit
   (stop-loss, force liquidation) in favour of its own, which fills the same
   way unless trigger-bar stop fills are armed; the label keeps the decision
   the audit and [force_liquidations.sexp] record. *)
let _record_exit_trigger record ~date trigger =
  let same_day =
    Option.equal Date.equal record.pos_exit_trigger_date (Some date)
  in
  let keep_strategy =
    same_day
    && Option.is_some record.pos_exit_trigger
    && _is_margin_trigger trigger
  in
  if not keep_strategy then (
    record.pos_exit_trigger <- Some trigger;
    record.pos_exit_trigger_date <- Some date)

let _process_transition t (trans : Position.transition) =
  match trans.kind with
  | CreateEntering { symbol; side; _ } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol in
      (* The record may already exist from {!record_installed_stop}, which the
         strategy's entry audit reaches before this transition is recorded. *)
      record.pos_symbol <- symbol;
      record.pos_side <- side
  | EntryComplete { risk_params } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      record.pos_entry_date <- t.current_date;
      (* The simulator's [EntryComplete] carries no stop for the Weinstein
         strategy (issue #2974); a [None] here must not erase the install
         {!record_installed_stop} already booked. *)
      Option.iter risk_params.stop_loss_price ~f:(fun level ->
          _seed_entry_stop record ~level)
  | UpdateRiskParams { new_risk_params } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      Option.iter new_risk_params.stop_loss_price ~f:(fun level ->
          _install_stop record ~level ~is_raise_candidate:true);
      record.pos_current_stop <- new_risk_params.stop_loss_price
  | TriggerExit { exit_reason; _ } | TriggerPartialExit { exit_reason; _ } ->
      let record = _ensure_record t ~position_id:trans.position_id ~symbol:"" in
      _record_exit_trigger record ~date:trans.date
        (exit_trigger_of_reason exit_reason)
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
  | EntryFill _ | CancelEntry _ | CancelExit _ | ExitFill _ -> ()

let record_transitions t transitions =
  List.iter transitions ~f:(_process_transition t)

let record_installed_stop t ~position_id ~symbol ~level =
  let record = _ensure_record t ~position_id ~symbol in
  record.pos_symbol <- symbol;
  _seed_entry_stop record ~level

let record_stop_move t ~position_id ~level =
  let record = _ensure_record t ~position_id ~symbol:"" in
  _install_stop record ~level ~is_raise_candidate:true

(* Issue #3075. The machine's level at the fill replaces the decision-time
   install: a ticket that rested across a split was rescaled in the machine but
   never reported here. Nothing before the fill can be a raise, so the seed,
   the current level and the high-water mark all restart from it. *)
let _reseed_at_fill record ~level =
  record.pos_entry_stop <- Some level;
  record.pos_current_stop <- Some level;
  record.pos_max_stop <- Some level

(* Bring the log back in line with a machine level no transition reported.
   Less protective can only be a split rescale (the machine never gives ground
   otherwise), so the high-water mark AND the initial stop are rescaled by the
   same factor: every stop column then sits on the current price basis, the one
   [trades.csv] restates [entry_price] onto (issue #3127, CTO 2021: entry_stop
   50.38 pre-split beside entry_price 19.48 post-split). More protective is a
   move whose transition has not arrived yet: install it, so the later
   transition is a no-op re-install. *)
let _rescale_to record ~current ~level =
  let factor = level /. current in
  let rescale = Option.map ~f:(fun m -> m *. factor) in
  record.pos_max_stop <- rescale record.pos_max_stop;
  record.pos_entry_stop <- rescale record.pos_entry_stop;
  record.pos_current_stop <- Some level

let _resync_to_machine record ~level =
  match record.pos_current_stop with
  | Some current when Float.( = ) current level -> ()
  | Some current
    when _is_more_protective ~side:record.pos_side ~previous:current ~next:level
    ->
      _install_stop record ~level ~is_raise_candidate:true
  | Some current when Float.( > ) current 0.0 ->
      _rescale_to record ~current ~level
  | Some _ | None -> ()

let record_stop_decision t ~position_id ~stop_before ~stop_after =
  let record = _ensure_record t ~position_id ~symbol:"" in
  if record.pos_seen_decision then _resync_to_machine record ~level:stop_before
  else _reseed_at_fill record ~level:stop_before;
  record.pos_seen_decision <- true;
  _install_stop record ~level:stop_after ~is_raise_candidate:true

let _record_to_info ~position_id record : stop_info =
  {
    position_id;
    symbol = record.pos_symbol;
    entry_date = record.pos_entry_date;
    entry_stop = record.pos_entry_stop;
    exit_stop = record.pos_current_stop;
    exit_trigger = record.pos_exit_trigger;
    max_stop = record.pos_max_stop;
    n_stop_raises = record.pos_n_stop_raises;
  }

let get_stop_infos t : stop_info list =
  Hashtbl.fold t.positions ~init:[] ~f:(fun ~key:position_id ~data:record acc ->
      _record_to_info ~position_id record :: acc)
  |> List.sort ~compare:(fun a b -> String.compare a.position_id b.position_id)
