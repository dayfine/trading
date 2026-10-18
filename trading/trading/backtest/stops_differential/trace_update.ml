(** Section S4 (update state machine) of the stops surface trace. *)

open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Trace_common

(* ---- section 4: the update state machine ---- *)

let stages =
  [
    Stage1 { weeks_in_base = 6 };
    Stage2 { weeks_advancing = 4; late = false };
    Stage3 { weeks_topping = 3 };
    Stage4 { weeks_declining = 5 };
  ]

let ma_directions = [ Rising; Flat; Declining ]

(* 16 bars of a trend-with-corrections tape. Deterministic in [side]: a long
   tape advances with pullbacks, a short tape is its mirror, so both sides
   exercise correction cycles and tightening rather than exiting on bar 1. *)
let tape ~side =
  List.map (List.range 0 16) ~f:(fun i ->
      let t = Float.of_int i in
      let drift = t *. 1.4 in
      let wobble = (unit_float () -. 0.5) *. 12.0 in
      let c =
        match side with
        | Long -> 100.0 +. drift +. wobble
        | Short -> 100.0 -. drift -. wobble
      in
      let ma = match side with Long -> 96.0 +. t | Short -> 104.0 -. t in
      (flat_bar ~date:as_of ~l:(c -. 2.5) ~h:(c +. 2.5) ~c, ma))

let replay ~config ~side ~state0 ~stage ~ma_direction ~label =
  reseed 1013;
  let bars = tape ~side in
  ignore
    (List.fold bars ~init:state0 ~f:(fun state (b, ma_value) ->
         let state', event =
           update ~config ~side ~state ~current_bar:b ~ma_value ~ma_direction
             ~stage
         in
         line
           (Printf.sprintf "S4 %s %s %s -> %s %s" label
              (f b.Types.Daily_price.close_price)
              (f ma_value) (show_state state') (show_event event));
         state'))

let update_configs =
  [
    ("dflt", default_config);
    ( "wide",
      {
        default_config with
        trailing_stop_buffer_pct = 0.025;
        tightened_stop_buffer_pct = 0.012;
        tighten_on_flat_ma = false;
        ma_flat_threshold = 0.01;
      } );
  ]

let initial_states ~side =
  let structural =
    compute_initial_stop ~config:default_config ~side
      ~reference_level:(match side with Long -> 90.0 | Short -> 111.0)
  in
  let fallback =
    compute_initial_stop_with_floor ~config:default_config ~side
      ~entry_price:100.0 ~bars:[] ~as_of ~fallback_buffer:1.02
  in
  [ ("struct", structural); ("fallbk", fallback) ]

let update_cases =
  List.concat_map update_configs ~f:(fun (cname, config) ->
      List.concat_map sides ~f:(fun side ->
          List.concat_map (initial_states ~side) ~f:(fun (sname, state0) ->
              List.concat_map stages ~f:(fun stage ->
                  List.map ma_directions ~f:(fun ma_direction ->
                      (cname, config, side, sname, state0, stage, ma_direction))))))

let trace_update () =
  line "## S4 update cfg/side/state/stage/ma close|ma -> state event";
  List.iter update_cases
    ~f:(fun (cname, config, side, sname, state0, stage, ma_direction) ->
      let label =
        Printf.sprintf "%s/%s/%s/%s/%s" cname (show_side side) sname
          (show_stage stage)
          (show_ma_direction ma_direction)
      in
      replay ~config ~side ~state0 ~stage ~ma_direction ~label)
