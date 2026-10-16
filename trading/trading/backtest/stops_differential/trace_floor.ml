(** Section S3 (support-floor initial-stop path) of the stops surface trace. *)

open Core
open Weinstein_stops
open Trace_common

(* ---- section 3: the support-floor initial-stop path ---- *)

(* A 70-bar window with a deterministic pullback shape. [depth] scales the
   counter-move so some windows clear [min_correction_pct] (structural floor)
   and some do not (fixed-buffer fallback); [split] injects an adjusted-close
   factor so [split_safe_floors] has something to rescale. *)
let window ~depth ~split =
  List.map (List.range 0 70) ~f:(fun i ->
      let t = Float.of_int i in
      let wave = unit_float () in
      let c = 100.0 +. (t *. 0.3) -. (depth *. wave *. 20.0) in
      let date = Date.add_days as_of (i - 70) in
      bar ~date ~o:c ~h:(c +. 1.5) ~l:(c -. 1.5) ~c ~adj:(c *. split))

let floor_configs =
  List.concat_map [ Support_floor.Wick; Support_floor.Close ] ~f:(fun mode ->
      List.concat_map [ Support_floor.Window_extreme; Support_floor.Nearest ]
        ~f:(fun scope ->
          List.map [ false; true ] ~f:(fun ss ->
              {
                default_config with
                support_floor_anchor_mode = mode;
                support_floor_anchor_scope = scope;
                split_safe_floors = ss;
              })))

let trace_floor_case ~config ~side ~bars ~entry_price ~fallback_buffer =
  let cbs = callbacks_from_bars ~config ~bars ~as_of in
  let by_bars =
    compute_initial_stop_with_floor ~config ~side ~entry_price ~bars ~as_of
      ~fallback_buffer
  in
  let by_cbs =
    compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
      ~callbacks:cbs ~fallback_buffer
  in
  line
    (Printf.sprintf "S3 %s %s %s -> %s | %s | %b %b | %s %s" (show_side side)
       (f entry_price) (f fallback_buffer) (show_state by_bars)
       (show_state by_cbs)
       (floor_is_structural ~config ~side ~bars ~as_of)
       (floor_is_structural_with_callbacks ~config ~side ~callbacks:cbs)
       (show_basis (split_safe_basis_of_bars ~config ~bars ~as_of))
       (show_basis (split_safe_basis_of_callbacks ~config ~callbacks:cbs)))

(* The fixed-buffer fallback flavour on its own: an empty window has no
   qualifying counter-move, so [_fallback_reference] decides the reference —
   [entry *. buffer] for a long, [entry /. buffer] for a short. The division is
   a distinct rounding site from every other path here, so it gets its own
   entry-price / buffer grid. Also covers the two [split_safe_basis] branches a
   well-formed window cannot reach: [Empty_window], and [Raw_fallback] via a
   window with one unusable adjusted close. *)
let trace_fallback_flavour ~corrupt =
  let ss = { default_config with split_safe_floors = true } in
  let cases =
    List.concat_map [ default_config; ss ] ~f:(fun config ->
        List.concat_map
          [ ([], "empty"); (corrupt, "corrupt") ]
          ~f:(fun (bars, _tag) ->
            List.concat_map [ 100.0; 37.13; 4.07 ] ~f:(fun entry_price ->
                List.concat_map [ 1.0; 1.02; 1.05 ] ~f:(fun fallback_buffer ->
                    List.map sides ~f:(fun side ->
                        (config, bars, side, entry_price, fallback_buffer))))))
  in
  List.iter cases ~f:(fun (config, bars, side, entry_price, fallback_buffer) ->
      trace_floor_case ~config ~side ~bars ~entry_price ~fallback_buffer)

let trace_floor_path () =
  line "## S3 floor path side|entry|buffer -> bars | cbs | structural | basis";
  reseed 7;
  let windows =
    List.concat_map [ 0.0; 0.2; 0.6; 1.2 ] ~f:(fun depth ->
        List.map [ 1.0; 0.25 ] ~f:(fun split -> window ~depth ~split))
  in
  let cases =
    List.concat_map floor_configs ~f:(fun config ->
        List.concat_map windows ~f:(fun bars ->
            List.map sides ~f:(fun side -> (config, bars, side))))
  in
  List.iter cases ~f:(fun (config, bars, side) ->
      line
        (Printf.sprintf "S3cfg %s %s %b"
           (Support_floor.show_anchor_mode config.support_floor_anchor_mode)
           (Support_floor.show_anchor_scope config.support_floor_anchor_scope)
           config.split_safe_floors);
      trace_floor_case ~config ~side ~bars ~entry_price:100.0
        ~fallback_buffer:1.02);
  let corrupt =
    match window ~depth:0.6 ~split:1.0 with
    | b :: rest -> { b with Types.Daily_price.adjusted_close = 0.0 } :: rest
    | [] -> []
  in
  trace_fallback_flavour ~corrupt
