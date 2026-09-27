(** Silent stop-move capture. See [stop_move_capture.mli]. *)

open Core
open Trading_strategy

let _level_of states ticker =
  Option.map (Map.find states ticker) ~f:Weinstein_stops.get_stop_level

(* The new level when [ticker]'s stop moved between the two maps; [None] when
   it did not move or either side has no state. *)
let _moved_level ~before ~after ticker =
  match (_level_of before ticker, _level_of after ticker) with
  | Some old_level, Some new_level when Float.( <> ) old_level new_level ->
      Some new_level
  | _ -> None

let _is_holding (pos : Position.t) =
  match Position.get_state pos with Position.Holding _ -> true | _ -> false

let _make_event ~current_date (pos : Position.t) stop_level :
    Audit_recorder.stop_move_event =
  {
    Audit_recorder.position_id = pos.id;
    symbol = pos.symbol;
    date = current_date;
    stop_level;
  }

let _event_of ~before ~after ~reported_ids ~current_date (pos : Position.t) =
  if (not (_is_holding pos)) || Set.mem reported_ids pos.id then None
  else
    Option.map
      (_moved_level ~before ~after pos.symbol)
      ~f:(_make_event ~current_date pos)

let silent_moves ~positions ~before ~after ~reported ~current_date =
  let reported_ids =
    String.Set.of_list
      (List.map reported ~f:(fun (t : Position.transition) -> t.position_id))
  in
  Map.data positions
  |> List.filter_map ~f:(_event_of ~before ~after ~reported_ids ~current_date)

let emit ~(audit_recorder : Audit_recorder.t) ~positions ~before ~after
    ~reported ~current_date =
  silent_moves ~positions ~before ~after ~reported ~current_date
  |> List.iter ~f:audit_recorder.record_stop_move
