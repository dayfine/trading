(** Per-position trailing-stop helpers for the sector-rotation Weinstein
    strategy — see [sector_rotation_stops.mli]. *)

open Core
open Trading_strategy

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

(* The [(entry_price, entry_date)] anchor of a [Holding] position — what the
   initial stop's support floor is computed against. [None] for any other
   state. *)
let _holding_entry (pos : Position.t) : (float * Date.t) option =
  match pos.state with
  | Position.Holding h -> Some (h.entry_price, h.entry_date)
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

(* Map a stop state-machine event to an optional exit transition. *)
let _exit_of_stop_event ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(event : Weinstein_stops.stop_event) : Position.transition option =
  match event with
  | Weinstein_stops.Stop_hit { stop_level; _ } ->
      Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level)
  | Weinstein_stops.Stop_raised _ | Weinstein_stops.Entered_tightening _
  | Weinstein_stops.No_change ->
      None

(* Weekly-close stop advance against the stage read [r]. *)
let _advance_stop ~stops_config ~(r : Stage.result)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  let new_state, event =
    Weinstein_stops.update ~config:stops_config ~side:Position.Long ~state
      ~current_bar:bar ~ma_value:r.ma_value ~ma_direction:r.ma_direction
      ~stage:r.stage
  in
  (new_state, _exit_of_stop_event ~pos ~bar ~event)

let seed_initial ~stops_config ~bar_reader ~fallback_buffer ~(symbol : string)
    ~(entry_price : float) ~(as_of : Date.t) : Weinstein_stops.stop_state =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  Weinstein_stops.compute_initial_stop_with_floor ~config:stops_config
    ~side:Position.Long ~entry_price ~bars ~as_of ~fallback_buffer

let seed_or_keep ~stops_config ~bar_reader ~fallback_buffer ~(symbol : string)
    ~(existing : Weinstein_stops.stop_state option) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Weinstein_stops.stop_state =
  match existing with
  | Some s -> s
  | None ->
      let entry_price, entry_date =
        Option.value (_holding_entry pos) ~default:(bar.close_price, bar.date)
      in
      seed_initial ~stops_config ~bar_reader ~fallback_buffer ~symbol
        ~entry_price ~as_of:entry_date

let step ~stops_config ~(stage_result : Stage.result option)
    ~(state : Weinstein_stops.stop_state) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) :
    Weinstein_stops.stop_state * Position.transition option =
  if Weinstein_stops.check_stop_hit ~state ~side:Position.Long ~bar () then
    let stop_level = Weinstein_stops.get_stop_level state in
    (state, Some (Spy_only_transitions.build_stop_exit ~pos ~bar ~stop_level))
  else if not (_is_weekly_close ~date:bar.date) then (state, None)
  else
    match stage_result with
    | None -> (state, None)
    | Some r -> _advance_stop ~stops_config ~r ~state ~pos ~bar
