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

(** Build a [CancelExit] transition for [position_id] on [date]. The exit-side
    mirror of [_cancel_entry_transition]: it reverts an unfilled [Exiting]
    position back to [Holding] via the core [Position] state machine. The reason
    string is purely diagnostic. *)
let _cancel_exit_transition ~date ~position_id ~symbol : Position.transition =
  let reason = Printf.sprintf "exit fill rejected by portfolio for %s" symbol in
  { position_id; date; kind = CancelExit { reason } }

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
   to [Holding] by routing a [CancelExit] transition through the core
   [Position.apply_transition] (via [apply_to_positions]) — the exit-side mirror
   of the [CancelEntry] path. Leaves [acc] unchanged when there is no matching
   unfilled-[Exiting] position. The match guard [_is_unfilled_exiting_for_symbol]
   ensures we only attempt the transition on an unfilled exit; the core
   [CancelExit] validator is a second backstop (it rejects a partially-filled
   [Exiting]). On the (unexpected) validator error we leave [acc] unchanged. *)
let _revert_one ~date ~acc ~symbol =
  let target =
    Map.to_alist acc
    |> List.find ~f:(fun (_, pos) ->
        _is_unfilled_exiting_for_symbol ~symbol pos)
  in
  match target with
  | None -> acc
  | Some (id, _) -> (
      let trans = _cancel_exit_transition ~date ~position_id:id ~symbol in
      match apply_to_positions acc trans with Ok acc' -> acc' | Error _ -> acc)

let revert_rejected_exits ~date ~positions ~rejected_trades =
  List.fold rejected_trades ~init:positions ~f:(fun acc trade ->
      _revert_one ~date ~acc ~symbol:trade.Trading_base.Types.symbol)

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
