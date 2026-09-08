(** Cancels resting entry tickets at their delisting marker — see
    [delisted_ticket_cancel.mli]. *)

open Core
module Position = Trading_strategy.Position

(* Read from {!Delisted_exit_runner}, which owns the single definition of the
   literal, so one token covers both halves of a delisting in
   [trade_audit.sexp] and the two cannot drift apart. A stable identifier
   rather than a sentence, matching the sibling tokens in {!Cancel_handler} and
   {!Weinstein_strategy.Entry_ticket_ttl}. *)
let cancel_reason = Delisted_exit_runner.label

(* True when [pos] is a wholly-unfilled resting ticket. A partially-filled
   [Entering] is excluded here rather than left to fail downstream: the core
   [CancelEntry] validator rejects it ([_validate_no_fills]), and its shares are
   already booked with the portfolio. *)
let _is_resting_ticket (pos : Position.t) =
  match pos.state with
  | Entering { filled_quantity; _ } -> Float.equal filled_quantity 0.0
  | _ -> false

(* True when [symbol]'s marker is strictly in the past — the same boundary
   {!Delisted_exit_runner} and [Delisted_entry_gate] use, so the marker day
   itself stays tradeable on all three sides. *)
let _marker_has_passed ~active_through_for ~date symbol =
  match active_through_for symbol with
  | None -> false
  | Some d -> Date.( < ) d date

(* A resting ticket on a symbol whose series has already ended. *)
let _is_dead_ticket ~active_through_for ~date (pos : Position.t) =
  _is_resting_ticket pos
  && _marker_has_passed ~active_through_for ~date pos.symbol

let _cancel_transition ~date position_id : Position.transition =
  { position_id; date; kind = CancelEntry { reason = cancel_reason } }

let _cancel_transitions ~active_through_for ~date ~positions =
  Map.to_alist positions
  |> List.filter ~f:(fun (_, pos) ->
      _is_dead_ticket ~active_through_for ~date pos)
  |> List.map ~f:(fun (id, _) -> _cancel_transition ~date id)

(* Apply one [CancelEntry], dropping the now-[Closed] position from the map.
   Every transition built above names a wholly-unfilled [Entering], which the
   core validator always accepts, so the [Error] branch is unreachable; leaving
   [acc] unchanged there matches {!Cancel_handler}'s defensive convention rather
   than failing the step. *)
let _apply_one acc trans =
  match Cancel_handler.apply_to_positions acc trans with
  | Ok acc' -> acc'
  | Error _ -> acc

let tick ~order_manager ~active_through_for ~date ~positions () =
  let transitions = _cancel_transitions ~active_through_for ~date ~positions in
  if List.is_empty transitions then (positions, [])
  else begin
    (* Retire the resting orders BEFORE applying: [positions] still carries
       each cancelled ticket's symbol + side at this point, which is what
       {!Cancel_handler.cancel_resting_entry_orders} matches on. *)
    let (_ : Trading_orders.Types.order_id list) =
      Cancel_handler.cancel_resting_entry_orders ~order_manager ~positions
        ~transitions
    in
    (List.fold transitions ~init:positions ~f:_apply_one, transitions)
  end
