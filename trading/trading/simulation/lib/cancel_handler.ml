(** Cancel/revert transition builder + applier — see [cancel_handler.mli]. *)

open Core
module Position = Trading_strategy.Position

(** True if [pos] is in the [Entering] state for the given [symbol]. *)
let _is_entering_for_symbol ~symbol (pos : Position.t) =
  match pos.state with
  | Entering _ -> String.equal pos.symbol symbol
  | _ -> false

(** Build a [CancelEntry] transition for [position_id] on [date]. The reason
    string is purely diagnostic — neither the position state machine nor the
    engine inspects it. *)
let _cancel_entry_transition ~date ~position_id ~symbol : Position.transition =
  {
    position_id;
    date;
    kind =
      CancelEntry
        { reason = Printf.sprintf "fill rejected by portfolio for %s" symbol };
  }

(** Find the [Entering] position for [symbol] in [positions] and emit a
    [CancelEntry] transition for it. Returns [None] when no matching [Entering]
    position exists. *)
let _cancel_transition_for_symbol ~date ~positions ~symbol =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if _is_entering_for_symbol ~symbol pos then
        Some (_cancel_entry_transition ~date ~position_id:id ~symbol)
      else None)

let transitions_for_rejected_trades ~date ~positions ~rejected_trades =
  List.filter_map rejected_trades ~f:(fun trade ->
      let symbol = trade.Trading_base.Types.symbol in
      _cancel_transition_for_symbol ~date ~positions ~symbol)

let apply_to_positions positions trans =
  let open Result.Let_syntax in
  match Map.find positions trans.Position.position_id with
  | None -> Ok positions
  | Some pos ->
      let%bind updated = Position.apply_transition pos trans in
      let key = trans.position_id in
      if Position.is_closed updated then Ok (Map.remove positions key)
      else Ok (Map.set positions ~key ~data:updated)

(** Reconstruct the [Holding] state from an [Exiting] position's carried fields
    (quantity, entry price/date, risk params), so the position resumes stop
    monitoring on its full pre-exit quantity. Returns [None] for any
    non-[Exiting] state.

    The core [Position] state machine has no [Exiting -> Holding] transition —
    an asymmetry vs the entry side, where [CancelEntry] exists. We reconstruct
    the [Holding] state here from the exposed [position_state] rather than add a
    core transition variant, keeping the fix at the simulation layer (A1). A
    future [CancelExit] core transition would let exit reversion route through
    [apply_to_positions] like [CancelEntry]; see the cancel_handler.mli note. *)
let _holding_from_exiting ~date (pos : Position.t) : Position.t option =
  match pos.state with
  | Exiting { quantity; entry_price; entry_date; risk_params; _ } ->
      let state =
        Position.Holding { quantity; entry_price; entry_date; risk_params }
      in
      Some { pos with state; last_updated = date }
  | _ -> None

(** True if [pos] is in the [Exiting] state for [symbol] with no partial fills
    yet — the stuck-exit signature. A partially-filled exit is deliberately NOT
    reverted: reverting would resurrect a [Holding] at the full pre-exit
    quantity while the portfolio already booked the partial cover, desyncing
    strategy and portfolio. Partial-fill recovery is out of scope; the common
    (zero-fill) cash-floor rejection is what this handler targets. *)
let _is_unfilled_exiting_for_symbol ~symbol (pos : Position.t) =
  match pos.state with
  | Exiting { filled_quantity; _ } ->
      String.equal pos.symbol symbol && Float.equal filled_quantity 0.0
  | _ -> false

(* Revert the first unfilled [Exiting] position matching [symbol] in [acc] back
   to [Holding], leaving [acc] unchanged when there is no such match. *)
let _revert_one ~date ~acc ~symbol =
  let target =
    Map.to_alist acc
    |> List.find ~f:(fun (_, pos) ->
        _is_unfilled_exiting_for_symbol ~symbol pos)
  in
  match
    Option.bind target ~f:(fun (id, pos) ->
        Option.map (_holding_from_exiting ~date pos) ~f:(fun r -> (id, r)))
  with
  | Some (id, reverted) -> Map.set acc ~key:id ~data:reverted
  | None -> acc

let revert_rejected_exits ~date ~positions ~rejected_trades =
  List.fold rejected_trades ~init:positions ~f:(fun acc trade ->
      _revert_one ~date ~acc ~symbol:trade.Trading_base.Types.symbol)

(* Apply one trade to the portfolio; tag it accepted (portfolio booked it) or
   rejected (carrying the rejection [err] for the WARN). *)
let _try_apply_trade portfolio trade =
  match Trading_portfolio.Portfolio.apply_single_trade portfolio trade with
  | Ok p -> (p, `Accepted trade)
  | Error err -> (portfolio, `Rejected (trade, err))

(* Loud, per-trade WARN on a portfolio-rejected fill. Silent drops here are how
   issue #1553's stuck-[Exiting] zombie escaped notice — every rejected fill now
   names symbol / side / qty / reason on stderr. *)
let _warn_rejected_trade (trade : Trading_base.Types.trade) err =
  eprintf
    "WARN: portfolio rejected fill for %s (side=%s qty=%.4f price=%.4f): %s. \
     Stranded position will be reverted for retry (see Cancel_handler).\n\
     %!"
    trade.symbol
    (Trading_base.Types.show_side trade.side)
    trade.quantity trade.price (Status.show err)

(* One fold step: apply [trade] (after the [hook]) and bucket it accepted /
   rejected, warning loudly on rejection. Extracted to keep the fold body flat
   (nesting linter). *)
let _bucket_trade ~hook (portfolio, accepted, rejected) trade =
  let trade = hook trade in
  match _try_apply_trade portfolio trade with
  | portfolio, `Accepted t -> (portfolio, t :: accepted, rejected)
  | portfolio, `Rejected (t, err) ->
      _warn_rejected_trade t err;
      (portfolio, accepted, t :: rejected)

let apply_trades_best_effort ?on_trade_fill portfolio trades =
  let hook = Option.value on_trade_fill ~default:Fn.id in
  let portfolio, accepted_rev, rejected_rev =
    List.fold trades ~init:(portfolio, [], []) ~f:(_bucket_trade ~hook)
  in
  (portfolio, List.rev accepted_rev, List.rev rejected_rev)
