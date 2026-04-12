open Core

(* Two dates are in the same ISO week iff they share (year, week_number). *)
let _is_same_week (d1 : Date.t) (d2 : Date.t) : bool =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

let _ordering_error_msg =
  "Data must be sorted chronologically by date with no duplicates"

let _validate_ordering (prev : Date.t) (curr : Date.t) : unit =
  if Date.compare prev curr >= 0 then
    raise (Invalid_argument _ordering_error_msg)

type 'a _state = {
  acc : 'a list;
  curr_week_rev : 'a list;
  prev_date : Date.t option;
}
(** Fold state: completed buckets (reverse chronological), the current week's
    items (also reverse chronological), and the last seen date (for ordering
    checks). *)

let _empty_state = { acc = []; curr_week_rev = []; prev_date = None }

let _flush_week ~aggregate state =
  match state.curr_week_rev with
  | [] -> state
  | week_rev ->
      { state with acc = aggregate week_rev :: state.acc; curr_week_rev = [] }

let _step ~get_date ~aggregate state item =
  let date = get_date item in
  Option.iter state.prev_date ~f:(fun prev -> _validate_ordering prev date);
  let state =
    match state.curr_week_rev with
    | last :: _ when not (_is_same_week (get_date last) date) ->
        _flush_week ~aggregate state
    | _ -> state
  in
  {
    acc = state.acc;
    curr_week_rev = item :: state.curr_week_rev;
    prev_date = Some date;
  }

let bucket_weekly ~get_date ~aggregate items =
  let final =
    List.fold items ~init:_empty_state ~f:(_step ~get_date ~aggregate)
    |> _flush_week ~aggregate
  in
  List.rev final.acc
