(** Cancel/revert transition builder + applier — see [cancel_handler.mli]. *)

open Core
module Position = Trading_strategy.Position

(** True if [pos] is in the [Entering] state for the given [symbol]. *)
let _is_entering_for_symbol ~symbol (pos : Position.t) =
  match pos.state with
  | Entering _ -> String.equal pos.symbol symbol
  | _ -> false

(** The reason token stamped on a portfolio-rejection [CancelEntry]. A stable
    identifier rather than a sentence, matching the two
    {!Weinstein_strategy.Entry_ticket_ttl} tokens ([entry_ticket_ttl_expired] /
    [entry_ticket_requalification_failed]), so that a [trade_audit.sexp] reader
    can group ticket deaths by cause instead of parsing prose. The symbol is not
    interpolated: the audit row it lands on already names it, and a per-symbol
    string would defeat grouping. *)
let portfolio_rejection_reason = "entry_fill_rejected_by_portfolio"

(** Build a [CancelEntry] transition for [position_id] on [date]. The reason
    string is purely diagnostic — neither the position state machine nor the
    engine inspects it; {!Backtest.Trade_audit} persists it verbatim. *)
let _cancel_entry_transition ~date ~position_id : Position.transition =
  {
    position_id;
    date;
    kind = CancelEntry { reason = portfolio_rejection_reason };
  }

(** Find the [Entering] position for [symbol] in [positions] and emit a
    [CancelEntry] transition for it. Returns [None] when no matching [Entering]
    position exists. *)
let _cancel_transition_for_symbol ~date ~positions ~symbol =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if _is_entering_for_symbol ~symbol pos then
        Some (_cancel_entry_transition ~date ~position_id:id)
      else None)

let transitions_for_rejected_trades ~date ~positions ~rejected_trades =
  List.filter_map rejected_trades ~f:(fun trade ->
      let symbol = trade.Trading_base.Types.symbol in
      _cancel_transition_for_symbol ~date ~positions ~symbol)

(* Routing key for "an order that would open THIS position": symbol plus the
   order side that opens it (long entries rest as Buy, short entries as Sell —
   the mirror of [Order_generator]'s entry-side mapping). Same (symbol, side)
   heuristic {!Fill_router} already uses to route fills back to positions, since
   the per-step [order_links] table is cleared on every generation pass and so
   cannot identify an order placed on an earlier step. *)
let _order_route_key ~symbol ~(side : Trading_base.Types.side) =
  symbol ^ "|" ^ Trading_base.Types.show_side side

let _entry_route_key ~symbol ~(side : Trading_base.Types.position_side) =
  _order_route_key ~symbol ~side:(Fill_router.entry_trade_side side)

(* The position a [CancelEntry] names, if it is still present. Other transition
   kinds resolve to [None]. *)
let _position_of_cancel_entry ~positions (t : Position.transition) =
  match t.kind with
  | Position.CancelEntry _ -> Map.find positions t.position_id
  | _ -> None

(* Route key of a position that is still a resting [Entering] — i.e. one whose
   order must go. Anything else (already filled, already closed) resolves to
   [None] and its orders are left alone. *)
let _route_key_of_resting_entry (pos : Position.t) =
  if _is_entering_for_symbol ~symbol:pos.symbol pos then
    Some (_entry_route_key ~symbol:pos.symbol ~side:pos.side)
  else None

let _cancelled_entry_keys ~positions (transitions : Position.transition list) =
  List.filter_map transitions ~f:(fun t ->
      _position_of_cancel_entry ~positions t
      |> Option.bind ~f:_route_key_of_resting_entry)
  |> String.Set.of_list

let cancel_resting_entry_orders ~order_manager ~positions ~transitions =
  let wanted = _cancelled_entry_keys ~positions transitions in
  if Set.is_empty wanted then []
  else
    let is_wanted (o : Trading_orders.Types.order) =
      Float.equal o.filled_quantity 0.0
      && Set.mem wanted (_order_route_key ~symbol:o.symbol ~side:o.side)
    in
    let ids =
      Trading_orders.Manager.list_orders ~filter:ActiveOnly order_manager
      |> List.filter ~f:is_wanted
      |> List.map ~f:(fun (o : Trading_orders.Types.order) -> o.id)
    in
    let (_ : Status.status list) =
      Trading_orders.Manager.cancel_orders order_manager ids
    in
    ids

let apply_to_positions positions trans =
  let open Result.Let_syntax in
  match Map.find positions trans.Position.position_id with
  | None -> Ok positions
  | Some pos ->
      let%bind updated = Position.apply_transition pos trans in
      let key = trans.position_id in
      if Position.is_closed updated then Ok (Map.remove positions key)
      else Ok (Map.set positions ~key ~data:updated)

(* Apply a [TriggerExit] / [TriggerPartialExit] to its named position, dropping
   it from the map when the transition closes it. A transition naming a
   position that is no longer present is a no-op (defensive). *)
let _apply_trigger_exit acc trans =
  let open Result.Let_syntax in
  match Map.find acc trans.Position.position_id with
  | None -> Ok acc
  | Some pos ->
      let%bind updated = Position.apply_transition pos trans in
      Ok
        (Fill_router.set_or_drop_if_closed acc ~key:trans.position_id
           ~data:updated)

let apply_transitions ~positions ~transitions =
  let open Result.Let_syntax in
  List.fold_result transitions ~init:positions ~f:(fun acc trans ->
      match trans.Position.kind with
      | CreateEntering _ ->
          let%bind pos = Position.create_entering trans in
          Ok (Map.set acc ~key:pos.id ~data:pos)
      | TriggerExit _ | TriggerPartialExit _ -> _apply_trigger_exit acc trans
      | CancelEntry _ -> apply_to_positions acc trans
      | _ -> Ok acc)

(** Build a [CancelExit] transition for [position_id] on [date]. The exit-side
    mirror of [_cancel_entry_transition]: it reverts an unfilled [Exiting]
    position back to [Holding] via the core [Position] state machine. The reason
    string is purely diagnostic. *)
let _cancel_exit_transition ~date ~position_id ~symbol : Position.transition =
  let reason = Printf.sprintf "exit fill rejected by portfolio for %s" symbol in
  { position_id; date; kind = CancelExit { reason } }

(** True if [pos] is the position [trade] was the exit fill of: same symbol,
    [Exiting] with no partial fills yet — the stuck-exit signature — and a trade
    side that {e closes} a position of [pos]'s side.

    A partially-filled exit is deliberately NOT reverted: reverting would
    resurrect a [Holding] at the full pre-exit quantity while the portfolio
    already booked the partial cover, desyncing strategy and portfolio.
    Partial-fill recovery is out of scope; the common (zero-fill) cash-floor
    rejection is what this handler targets.

    The side check (#2466) is the same one {!Fill_router} applies when routing
    accepted fills, for the same reason its header gives: when an entry and an
    exit coexist on one symbol — sibling positions, e.g. a scale-in add
    [Entering] while the original [Exiting] — matching on symbol and state alone
    lets a rejected {e entry} Buy revert the unrelated exit back to [Holding],
    silently cancelling a stop-out the portfolio never refused. Today the
    Weinstein strategy blocks that pairing upstream ([Entry_walk.held_symbols]
    counts [Exiting] as held, so no entry ticket is written for a symbol that is
    exiting), which is why this is a no-op on every current run rather than a
    bug fix with a golden behind it. It belongs here regardless: this module is
    strategy-agnostic and must not depend on a caller's invariant. *)
let _is_unfilled_exiting_for_trade ~(trade : Trading_base.Types.trade)
    (pos : Position.t) =
  match pos.state with
  | Exiting { filled_quantity; _ } ->
      String.equal pos.symbol trade.symbol
      && Float.equal filled_quantity 0.0
      && Trading_base.Types.equal_side trade.side
           (Fill_router.exit_trade_side pos.side)
  | _ -> false

(* Revert the first unfilled [Exiting] position [trade] could be the exit fill
   of back to [Holding], by routing a [CancelExit] transition through the core
   [Position.apply_transition] (via [apply_to_positions]) — the exit-side mirror
   of the [CancelEntry] path. Leaves [acc] unchanged when there is no matching
   unfilled-[Exiting] position. The match guard [_is_unfilled_exiting_for_trade]
   ensures we only attempt the transition on an unfilled exit whose side the
   trade closes; the core [CancelExit] validator is a second backstop (it
   rejects a partially-filled [Exiting]). On the (unexpected) validator error we
   leave [acc] unchanged. *)
let _revert_one ~date ~acc ~(trade : Trading_base.Types.trade) =
  let target =
    Map.to_alist acc
    |> List.find ~f:(fun (_, pos) -> _is_unfilled_exiting_for_trade ~trade pos)
  in
  match target with
  | None -> acc
  | Some (id, _) -> (
      let trans =
        _cancel_exit_transition ~date ~position_id:id ~symbol:trade.symbol
      in
      match apply_to_positions acc trans with Ok acc' -> acc' | Error _ -> acc)

let revert_rejected_exits ~date ~positions ~rejected_trades =
  List.fold rejected_trades ~init:positions ~f:(fun acc trade ->
      _revert_one ~date ~acc ~trade)

(* Apply one trade to the portfolio; tag it accepted (portfolio booked it) or
   rejected (carrying the rejection [err] for the WARN). Routed through the
   long-margin-aware apply so a levered long BUY funds its cash shortfall into
   [long_margin_debit] instead of being floor-rejected. At the default cash
   account ([initial_long_margin_req >= 1.0]) this is bit-equal to
   [Portfolio.apply_single_trade] (margin M1b-2). *)
let _try_apply_trade ~initial_long_margin_req portfolio trade =
  match
    Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin
      ~initial_long_margin_req portfolio trade
  with
  | Ok p -> (p, `Accepted trade)
  | Error err -> (portfolio, `Rejected (trade, err))

(* Loud, per-trade WARN on a portfolio-rejected fill. Silent drops here are how
   issue #1553's stuck-[Exiting] zombie escaped notice — every rejected fill now
   names symbol / side / qty / reason on stderr.

   The trailing sentence used to read "Stranded position will be reverted for
   retry", which is true only on the EXIT side ([revert_rejected_exits]). An
   entry is CANCELLED, not retried, and its resting order is already marked
   [Filled] by the engine before the portfolio ever sees the trade — so one
   cash-tight instant destroys a ticket that may have rested for months. That
   wording sent the 2026-08-15 session looking for a retry that does not exist;
   see dev/notes/ticket-death-on-cash-2026-08-16.md §G2. *)
let _warn_rejected_trade (trade : Trading_base.Types.trade) err =
  eprintf
    "WARN: portfolio rejected fill for %s (side=%s qty=%.4f price=%.4f): %s. \
     An entry is cancelled outright; an exit is reverted to Holding for retry \
     (see Cancel_handler).\n\
     %!"
    trade.symbol
    (Trading_base.Types.show_side trade.side)
    trade.quantity trade.price (Status.show err)

(* One fold step: apply [trade] (after the [hook]) and bucket it accepted /
   rejected, warning loudly on rejection. Extracted to keep the fold body flat
   (nesting linter). *)
let _bucket_trade ~hook ~initial_long_margin_req (portfolio, accepted, rejected)
    trade =
  let trade = hook trade in
  match _try_apply_trade ~initial_long_margin_req portfolio trade with
  | portfolio, `Accepted t -> (portfolio, t :: accepted, rejected)
  | portfolio, `Rejected (t, err) ->
      _warn_rejected_trade t err;
      (portfolio, accepted, t :: rejected)

let apply_trades_best_effort ?on_trade_fill ?(initial_long_margin_req = 1.0)
    portfolio trades =
  let hook = Option.value on_trade_fill ~default:Fn.id in
  let portfolio, accepted_rev, rejected_rev =
    List.fold trades ~init:(portfolio, [], [])
      ~f:(_bucket_trade ~hook ~initial_long_margin_req)
  in
  (portfolio, List.rev accepted_rev, List.rev rejected_rev)
