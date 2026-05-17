(** Cancel-entry transition builder + applier — see [cancel_handler.mli]. *)

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
