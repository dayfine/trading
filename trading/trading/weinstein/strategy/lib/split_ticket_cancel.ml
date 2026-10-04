(** #3075 split-while-resting ticket cancel — see [split_ticket_cancel.mli]. *)

open Core
module Position = Trading_strategy.Position
module Portfolio_view = Trading_strategy.Portfolio_view

let cancel_reason = "entry_ticket_split_while_resting"

(* A wholly unfilled entry ticket. Partially filled entries are excluded: the
   core [CancelEntry] validator rejects them, and their shares are booked. *)
let _is_resting_ticket (pos : Position.t) =
  match Position.get_state pos with
  | Position.Entering { filled_quantity; _ } -> Float.equal filled_quantity 0.0
  | Position.Holding _ | Position.Exiting _ | Position.Closed _ -> false

let _cancel_of ~split_factor ~current_date (pos : Position.t) =
  if _is_resting_ticket pos && Option.is_some (split_factor ~symbol:pos.symbol)
  then
    Some
      ({
         position_id = pos.id;
         date = current_date;
         kind = Position.CancelEntry { reason = cancel_reason };
       }
        : Position.transition)
  else None

let cancellations ~positions ~split_factor ~current_date =
  Map.data positions
  |> List.filter_map ~f:(_cancel_of ~split_factor ~current_date)

(* Release each cancelled ticket's frozen [E] and drop its position from the
   view handed to the rest of the tick. *)
let _apply_cancels ~pending_entry_e ~(portfolio : Portfolio_view.t) transitions
    =
  List.fold transitions ~init:portfolio
    ~f:(fun (acc : Portfolio_view.t) (t : Position.transition) ->
      Option.iter (Map.find acc.positions t.position_id)
        ~f:(fun (pos : Position.t) ->
          Entry_freeze.release pending_entry_e ~symbol:pos.symbol);
      { acc with positions = Map.remove acc.positions t.position_id })

(* The armed path: detect today's splits, build the cancels, apply them. Hands
   back the very same portfolio when nothing is cancelled. *)
let _run_armed ~pending_entry_e ~bar_reader ~(portfolio : Portfolio_view.t)
    ~current_date =
  let split_factor ~symbol =
    Stops_split_runner.detect_split ~bar_reader ~symbol ~as_of:current_date
  in
  match
    cancellations ~positions:portfolio.positions ~split_factor ~current_date
  with
  | [] -> ([], portfolio)
  | transitions ->
      (transitions, _apply_cancels ~pending_entry_e ~portfolio transitions)

let run ~enabled ~pending_entry_e ~bar_reader ~portfolio ~current_date =
  if not enabled then ([], portfolio)
  else _run_armed ~pending_entry_e ~bar_reader ~portfolio ~current_date
