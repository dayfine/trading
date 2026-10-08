(** Ex-dividend stop reduction — see [stops_dividend_runner.mli]. *)

open Core
open Trading_strategy

let with_stop_level (state : Weinstein_stops.stop_state) stop_level :
    Weinstein_stops.stop_state =
  match state with
  | Initial s -> Initial { s with stop_level }
  | Trailing s -> Trailing { s with stop_level }
  | Tightened s -> Tightened { s with stop_level }

(* The entry date of a [Holding] long; [None] for anything else. *)
let _held_long_entry_date (pos : Position.t) =
  match (pos.side, Position.get_state pos) with
  | Long, Holding { entry_date; _ } -> Some entry_date
  | _ -> None

(* The tick's window [(after, through]]: [None] unless the position is a
   [Holding] long and its symbol has two bars up to [as_of]. *)
let _window ~bar_reader ~as_of (pos : Position.t) =
  let%bind.Option entry_date = _held_long_entry_date pos in
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol:pos.symbol ~as_of in
  match List.rev bars with
  | curr :: prev :: _ ->
      Some (Date.max prev.Types.Daily_price.date entry_date, curr.date)
  | _ -> None

let _reduced_state ~eds ~bar_reader ~as_of ~stop_states (pos : Position.t) =
  let%bind.Option state = Map.find !stop_states pos.symbol in
  let%bind.Option after, through = _window ~bar_reader ~as_of pos in
  let level = Weinstein_stops.get_stop_level state in
  let reduced =
    Ex_dividend_stop.adjust eds ~symbol:pos.symbol ~after ~through level
  in
  Option.some_if Float.(reduced <> level) (with_stop_level state reduced)

let _adjust_one ~eds ~bar_reader ~as_of ~stop_states (pos : Position.t) =
  Option.iter (_reduced_state ~eds ~bar_reader ~as_of ~stop_states pos)
    ~f:(fun data -> stop_states := Map.set !stop_states ~key:pos.symbol ~data)

let adjust ~positions ~stop_states ~bar_reader ~as_of =
  match Bar_reader.ex_dividend_stops bar_reader with
  | None -> ()
  | Some eds ->
      Map.iter positions ~f:(_adjust_one ~eds ~bar_reader ~as_of ~stop_states)
