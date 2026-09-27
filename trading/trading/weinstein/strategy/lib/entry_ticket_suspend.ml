(** See [entry_ticket_suspend.mli]. *)

open Core
module Position = Trading_strategy.Position
module Portfolio_view = Trading_strategy.Portfolio_view

let cancel_reason = "entry_ticket_macro_suspended"
let _days_per_week = 7

(* Everything needed to re-emit the withdrawn order unchanged. [origin_date] is
   the FIRST placement date, carried across every suspend / re-issue cycle so
   the TTL clock keeps counting. *)
type ticket = {
  symbol : string;
  side : Position.position_side;
  target_quantity : float;
  entry_price : float;
  reasoning : Position.entry_reasoning;
  origin_date : Date.t;
  stop_state : Weinstein_stops.stop_state option;
}

type t = {
  stashed : ticket Hashtbl.M(String).t;  (** by symbol *)
  origins : Date.t Hashtbl.M(String).t;  (** re-issued position id -> origin *)
}

let create () =
  {
    stashed = Hashtbl.create (module String);
    origins = Hashtbl.create (module String);
  }

let suspends ~(config : Weinstein_strategy_config.config)
    ~(macro_result : Macro.result) =
  match config.entry_ticket_macro_suspend with
  | Entry_ticket_suspend_mode.Off -> false
  | Entry_ticket_suspend_mode.On_bearish_macro ->
      not (Long_entry_macro_gate.admits ~config ~macro_result)
  | Entry_ticket_suspend_mode.On_index_stage4 ->
      not
        (Screener.longs_admitted_by_index_stage
           ~index_stage_veto_blocks_longs:true
           (Some macro_result.Macro.index_stage.Stage.stage))

(* A re-issued [Entering] seen with its original placement date. *)
let _with_origin t (pos : Position.t) =
  match (Hashtbl.find t.origins pos.id, pos.state) with
  | Some origin, Position.Entering e ->
      {
        pos with
        Position.state = Position.Entering { e with created_date = origin };
      }
  | _ -> pos

let aged_portfolio t (portfolio : Portfolio_view.t) =
  if Hashtbl.is_empty t.origins then portfolio
  else
    {
      portfolio with
      Portfolio_view.positions =
        Map.map portfolio.Portfolio_view.positions ~f:(_with_origin t);
    }

(* [Some ticket] for a wholly unfilled LONG [Entering] — the only shape a
   suspension withdraws. A partial fill has booked shares and is left alone,
   the same discipline {!Entry_ticket_ttl} applies. *)
let _resting_long t ~stop_states (pos : Position.t) =
  match (pos.side, pos.state) with
  | Trading_base.Types.Long, Position.Entering e
    when Float.equal e.filled_quantity 0.0 ->
      Some
        {
          symbol = pos.symbol;
          side = pos.side;
          target_quantity = e.target_quantity;
          entry_price = e.entry_price;
          reasoning = pos.entry_reasoning;
          origin_date =
            Option.value (Hashtbl.find t.origins pos.id) ~default:e.created_date;
          stop_state = Map.find !stop_states pos.symbol;
        }
  | _ -> None

let _cancel ~current_date (pos : Position.t) : Position.transition =
  {
    position_id = pos.id;
    date = current_date;
    kind = Position.CancelEntry { reason = cancel_reason };
  }

let _stash_and_cancel t ~current_date (pos : Position.t) (tk : ticket) =
  Hashtbl.set t.stashed ~key:tk.symbol ~data:tk;
  _cancel ~current_date pos

let _suspend_one t ~stop_states ~current_date (pos : Position.t) =
  _resting_long t ~stop_states pos
  |> Option.map ~f:(_stash_and_cancel t ~current_date pos)

(* Same whole-weeks arithmetic as {!Entry_ticket_ttl}: [max_rest_weeks <= 0] is
   unbounded, otherwise a ticket older than the clock is expired. *)
let _expired ~max_rest_weeks ~current_date (tk : ticket) =
  max_rest_weeks > 0
  && Date.diff current_date tk.origin_date / _days_per_week > max_rest_weeks

(* Forget a stashed ticket for good, releasing its no-chase pin so a later
   re-qualification earns a fresh [E] (as an F2 cancel does). *)
let _drop t ?pending_entry_e symbol =
  Hashtbl.remove t.stashed symbol;
  Option.iter pending_entry_e ~f:(fun pins -> Entry_freeze.release pins ~symbol)

let _sorted_stash t =
  Hashtbl.data t.stashed
  |> List.sort ~compare:(fun (a : ticket) (b : ticket) ->
      String.compare a.symbol b.symbol)

let _prune_expired t ?pending_entry_e ~max_rest_weeks ~current_date () =
  _sorted_stash t
  |> List.filter ~f:(_expired ~max_rest_weeks ~current_date)
  |> List.iter ~f:(fun (tk : ticket) -> _drop t ?pending_entry_e tk.symbol)

let _held_elsewhere positions symbol =
  Map.exists positions ~f:(fun (p : Position.t) ->
      String.equal p.symbol symbol && not (Position.is_closed p))

(* Re-emit the withdrawn order with identical parameters and re-install its
   stop plan; the fresh id inherits the ticket's origin date for the clock. *)
let _reissue_one t ~stop_states ~current_date (tk : ticket) :
    Position.transition =
  let position_id = Entry_audit_capture.gen_position_id tk.symbol in
  Hashtbl.set t.origins ~key:position_id ~data:tk.origin_date;
  Option.iter tk.stop_state ~f:(fun st ->
      stop_states := Map.set !stop_states ~key:tk.symbol ~data:st);
  Hashtbl.remove t.stashed tk.symbol;
  {
    position_id;
    date = current_date;
    kind =
      Position.CreateEntering
        {
          symbol = tk.symbol;
          side = tk.side;
          target_quantity = tk.target_quantity;
          entry_price = tk.entry_price;
          reasoning = tk.reasoning;
        };
  }

let _reissue t ?pending_entry_e ~stop_states ~positions ~current_date () =
  let conflicted, free =
    List.partition_tf (_sorted_stash t) ~f:(fun (tk : ticket) ->
        _held_elsewhere positions tk.symbol)
  in
  List.iter conflicted ~f:(fun (tk : ticket) ->
      _drop t ?pending_entry_e tk.symbol);
  List.map free ~f:(_reissue_one t ~stop_states ~current_date)

let _positions_minus ~cancels positions =
  let cancelled =
    List.map cancels ~f:(fun (tr : Position.transition) -> tr.position_id)
    |> String.Set.of_list
  in
  Map.filter_keys positions ~f:(fun id -> not (Set.mem cancelled id))

(* The armed path: F2 cancels on the aged view, drop expired stash entries,
   then either suspend what is still resting or re-issue what is stashed. *)
let _step t ?pending_entry_e ~config ~macro_result ~stop_states
    ~(portfolio : Portfolio_view.t) ~current_date ~cancel_expired () =
  let positions = portfolio.Portfolio_view.positions in
  Hashtbl.filter_keys_inplace t.origins ~f:(Map.mem positions);
  let cancels = cancel_expired (aged_portfolio t portfolio) in
  let remaining = _positions_minus ~cancels positions in
  _prune_expired t ?pending_entry_e
    ~max_rest_weeks:config.Weinstein_strategy_config.entry_order_max_rest_weeks
    ~current_date ();
  let suspending = suspends ~config ~macro_result in
  let suspended =
    if suspending then
      List.filter_map (Map.data remaining)
        ~f:(_suspend_one t ~stop_states ~current_date)
    else []
  in
  (* Read after suspending and before re-issuing: this week's stash plus the
     tickets about to be re-issued, none of which the cascade may re-admit. *)
  let held = Hashtbl.keys t.stashed in
  let reissued =
    if suspending then []
    else
      _reissue t ?pending_entry_e ~stop_states ~positions:remaining
        ~current_date ()
  in
  (cancels @ suspended @ reissued, held)

let run ?store ?pending_entry_e ~(config : Weinstein_strategy_config.config)
    ~macro_result ~stop_states ~portfolio ~current_date ~cancel_expired () =
  match (store, config.entry_ticket_macro_suspend) with
  | None, _ | Some _, Entry_ticket_suspend_mode.Off ->
      (cancel_expired portfolio, [])
  | ( Some t,
      ( Entry_ticket_suspend_mode.On_bearish_macro
      | Entry_ticket_suspend_mode.On_index_stage4 ) ) ->
      _step t ?pending_entry_e ~config ~macro_result ~stop_states ~portfolio
        ~current_date ~cancel_expired ()
