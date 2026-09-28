open Core
open Trading_strategy

type suggested_order = {
  ticker : string;
  side : Trading_base.Types.side;
  order_type : Trading_base.Types.order_type;
  shares : int;
  rationale : string;
}
[@@deriving show, eq]

(** Derive share count from a position's current quantity. *)
let _shares_of_position (pos : Position.t) =
  match pos.state with
  | Position.Holding { quantity; _ } -> Int.of_float quantity
  | Position.Entering { target_quantity; _ } -> Int.of_float target_quantity
  | Position.Exiting { quantity; _ } -> Int.of_float quantity
  | Position.Closed _ -> 0

(** Map position side to broker buy/sell for an entry order. Long entries are
    buys; short entries are sells. *)
let _entry_side_of_position_side (ps : Position.position_side) =
  match ps with
  | Position.Long -> Trading_base.Types.Buy
  | Position.Short -> Trading_base.Types.Sell

(** Map position side to broker buy/sell for an exit order. Long exits are
    sells; short exits are buys (cover). *)
let _exit_side_of_position_side (ps : Position.position_side) =
  match ps with
  | Position.Long -> Trading_base.Types.Sell
  | Position.Short -> Trading_base.Types.Buy

let _position_side_name (ps : Position.position_side) =
  match ps with Position.Long -> "long" | Position.Short -> "short"

(* The do-not-chase limit ceiling: the worst fill the order may accept, one
   [entry_extension_max_pct] past the breakout in the trade's own direction —
   above the trigger for a long, below it for a short (issue #2158). This is the
   same [E x (1 +/- pct/100)] the report's [Entry_reconciliation] classifies
   against; it is duplicated here rather than shared because [order_gen] sits in
   the [trading/] layer and must not depend on the [snapshot] report libraries.

   [entry_extension_max_pct <= 0.0] returns [entry_price] unchanged — the
   degenerate [StopLimit (E, E)] the generator emitted before this feature, so a
   default (disarmed) live run is byte-identical (experiment-flag-discipline
   R1). *)
let _entry_cap ~(side : Position.position_side) ~entry_price
    ~entry_extension_max_pct =
  if Float.( <= ) entry_extension_max_pct 0.0 then entry_price
  else
    let frac = entry_extension_max_pct /. 100.0 in
    match side with
    | Position.Long -> entry_price *. (1.0 +. frac)
    | Position.Short -> entry_price *. (1.0 -. frac)

let _entry_order symbol side target_quantity entry_price
    ~entry_extension_max_pct =
  let shares = Int.of_float target_quantity in
  let cap = _entry_cap ~side ~entry_price ~entry_extension_max_pct in
  Some
    {
      ticker = symbol;
      side = _entry_side_of_position_side side;
      order_type = Trading_base.Types.StopLimit (entry_price, cap);
      shares;
      rationale =
        Printf.sprintf
          "New %s entry: %d shares, StopLimit trigger $%.2f, limit $%.2f \
           (do-not-chase cap)"
          (_position_side_name side) shares entry_price cap;
    }

let _stop_order_for_pos pos stop_price =
  let shares = _shares_of_position pos in
  Some
    {
      ticker = pos.symbol;
      side = _exit_side_of_position_side pos.side;
      order_type = Trading_base.Types.Stop stop_price;
      shares;
      rationale =
        Printf.sprintf "Update stop to $%.2f (%d shares)" stop_price shares;
    }

let _market_exit_for_pos pos =
  let shares = _shares_of_position pos in
  Some
    {
      ticker = pos.symbol;
      side = _exit_side_of_position_side pos.side;
      order_type = Trading_base.Types.Market;
      shares;
      rationale = Printf.sprintf "Stop hit — exit %d shares at market" shares;
    }

(** Translate a single transition into a suggested_order option. Returns None
    for simulator-internal transitions or unhandled cases. *)
let _translate_transition ~entry_extension_max_pct
    ~(transition : Position.transition)
    ~(get_position : string -> Position.t option) : suggested_order option =
  match transition.kind with
  | Position.CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      _entry_order symbol side target_quantity entry_price
        ~entry_extension_max_pct
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = Some stop_price; _ } } ->
      Option.bind (get_position transition.position_id) ~f:(fun pos ->
          _stop_order_for_pos pos stop_price)
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = None; _ } } ->
      (* No stop price update — nothing to send to broker *)
      None
  (* TriggerExit is internal accounting for when the strategy detects a stop
     breach. In live trading the GTC Stop order sent via UpdateRiskParams is
     already working at the broker and will execute automatically — no
     additional order is needed here. *)
  | Position.TriggerExit _ | Position.TriggerPartialExit _
  (* Simulator-internal transitions: not relevant to the live broker *)
  | Position.EntryFill _ | Position.EntryComplete _ | Position.CancelEntry _
  | Position.CancelExit _ | Position.ExitFill _ | Position.ExitComplete ->
      None

(* --- Stop sync: broker stops sourced from the stop-level snapshots --- *)

type stop_sync = {
  positions : Position.t list;
  stop_level_before : string -> float option;
  stop_level_after : string -> float option;
}

(** Shares a broker stop must protect: the held quantity, or the filled part of
    an entry still in progress. [None] for positions with nothing at the broker
    to protect (unfilled entries, exits in progress, closed positions). *)
let _protected_shares (pos : Position.t) =
  match pos.state with
  | Position.Holding { quantity; _ } -> Some (Int.of_float quantity)
  | Position.Entering { filled_quantity; _ } when Float.(filled_quantity > 0.0)
    ->
      Some (Int.of_float filled_quantity)
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

let _is_entry_fill_for ~position_id (t : Position.transition) =
  String.equal t.position_id position_id
  &&
  match t.kind with
  | Position.EntryFill _ | Position.EntryComplete _ -> true
  | _ -> false

(** An [UpdateRiskParams] in this tick already emits a [Stop] at [level] for the
    position — the sync order would duplicate it. *)
let _already_updated_to ~position_id ~level (t : Position.transition) =
  String.equal t.position_id position_id
  &&
  match t.kind with
  | Position.UpdateRiskParams
      { new_risk_params = { stop_loss_price = Some p; _ } } ->
      Float.equal p level
  | _ -> false

(** Why [pos] needs a broker stop at [level] this tick, if it does: it just
    (partially) filled its entry, or its installed level moved. *)
let _sync_reason ~transitions ~stop_sync ~(pos : Position.t) ~level =
  let position_id = pos.id in
  let level_moved =
    not
      (Option.equal Float.equal
         (stop_sync.stop_level_before pos.symbol)
         (Some level))
  in
  if List.exists transitions ~f:(_already_updated_to ~position_id ~level) then
    None
  else if List.exists transitions ~f:(_is_entry_fill_for ~position_id) then
    Some "Initial stop on entry fill"
  else if level_moved then Some "Stop level moved"
  else None

let _sync_stop_order (pos : Position.t) ~level ~shares ~reason =
  {
    ticker = pos.symbol;
    side = _exit_side_of_position_side pos.side;
    order_type = Trading_base.Types.Stop level;
    shares;
    rationale =
      Printf.sprintf "%s: stop at $%.2f (%d shares)" reason level shares;
  }

let _sync_order_for_pos ~transitions ~stop_sync (pos : Position.t) =
  match (_protected_shares pos, stop_sync.stop_level_after pos.symbol) with
  | Some shares, Some level ->
      Option.map (_sync_reason ~transitions ~stop_sync ~pos ~level)
        ~f:(fun reason -> _sync_stop_order pos ~level ~shares ~reason)
  | _ -> None

let _stop_sync_orders ~transitions stop_sync =
  List.filter_map stop_sync.positions
    ~f:(_sync_order_for_pos ~transitions ~stop_sync)

let from_transitions ?(entry_extension_max_pct = 0.0) ?stop_sync ~transitions
    ~get_position () =
  let transition_orders =
    List.filter_map transitions ~f:(fun t ->
        _translate_transition ~entry_extension_max_pct ~transition:t
          ~get_position)
  in
  let sync_orders =
    Option.value_map stop_sync ~default:[] ~f:(_stop_sync_orders ~transitions)
  in
  transition_orders @ sync_orders
