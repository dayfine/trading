(** Sections S1 (compute_initial_stop) and S2 (check_stop_hit) of the stops
    surface trace. *)

open Core
open Trading_base.Types
open Weinstein_stops
open Trace_common

(* ---- section 1: compute_initial_stop ---- *)

(* Offsets around a round-number reference, in units of the default 0.125 nudge
   distance: dead on the boundary, one representable step either side, and well
   inside / outside. The nudge predicate is [|price - nearest_half| <= nudge],
   so these are exactly the inputs where a reassociated multiply flips it. *)
let boundary_offsets =
  [
    -0.13;
    -0.126;
    -0.125;
    -0.124;
    -0.0625;
    0.0;
    0.0625;
    0.124;
    0.125;
    0.126;
    0.13;
  ]

(* Reference levels whose raw stop [ref *. (1 -. delta)] lands on or beside a
   half-dollar boundary. Inverting the multiply reintroduces rounding, which is
   the point: the input is a realistic near-boundary reference, not a contrived
   exact one. *)
let boundary_references ~side ~delta =
  let targets =
    List.concat_map (List.range 1 11) ~f:(fun k ->
        List.map boundary_offsets ~f:(fun e -> (Float.of_int k *. 0.5) +. e))
  in
  List.map targets ~f:(fun t ->
      match side with
      | Long -> t /. (1.0 -. delta)
      | Short -> t /. (1.0 +. delta))

let initial_stop_cases =
  List.concat_map [ 0.05; 0.125; 0.25 ] ~f:(fun nudge ->
      List.concat_map [ 0.08; 0.10 ] ~f:(fun mcp ->
          List.concat_map sides ~f:(fun side ->
              let cfg =
                {
                  default_config with
                  round_number_nudge = nudge;
                  min_correction_pct = mcp;
                }
              in
              List.map
                (boundary_references ~side ~delta:(mcp /. 2.0))
                ~f:(fun r -> (cfg, side, r)))))

let trace_initial_stops () =
  line "## S1 compute_initial_stop nudge|mcp|side|reference -> state";
  List.iter initial_stop_cases ~f:(fun (cfg, side, reference_level) ->
      let st = compute_initial_stop ~config:cfg ~side ~reference_level in
      line
        (Printf.sprintf "S1 %s %s %s %s %s" (f cfg.round_number_nudge)
           (f cfg.min_correction_pct) (show_side side) (f reference_level)
           (show_state st)));
  (* A plain arithmetic sweep at the shipped defaults, catching anything the
     boundary grid's inversion happens to step over. *)
  List.iter (List.range 0 176) ~f:(fun i ->
      let reference_level = 1.0 +. (Float.of_int i *. 1.7) in
      List.iter sides ~f:(fun side ->
          let st =
            compute_initial_stop ~config:default_config ~side ~reference_level
          in
          line
            (Printf.sprintf "S1sweep %s %s %s" (show_side side)
               (f reference_level) (show_state st))))

(* ---- section 2: check_stop_hit / get_stop_level ---- *)

let probe_states =
  [
    Initial { stop_level = 97.92; reference_level = 102.0 };
    Trailing
      {
        stop_level = 99.5;
        last_correction_extreme = 98.0;
        last_trend_extreme = 110.0;
        ma_at_last_adjustment = 100.0;
        correction_count = 2;
        correction_observed_since_reset = true;
      };
    Tightened
      {
        stop_level = 100.25;
        last_correction_extreme = 101.0;
        reason = "probe";
        swing_peak = None;
      };
  ]

(* Bars whose low / high / close straddle each probe stop level exactly, one
   representable step below, and one step above. *)
let probe_bars =
  List.concat_map [ 97.92; 99.5; 100.25 ] ~f:(fun s ->
      List.map [ -0.01; -1e-12; 0.0; 1e-12; 0.01 ] ~f:(fun e ->
          flat_bar ~date:as_of ~l:(s +. e) ~h:(s -. e) ~c:(s +. e)))

let trace_stop_hits () =
  line "## S2 check_stop_hit side|on_close|state|low|high|close -> hit, level";
  let cases =
    List.concat_map probe_states ~f:(fun state ->
        List.concat_map sides ~f:(fun side ->
            List.concat_map [ false; true ] ~f:(fun on_close ->
                List.map probe_bars ~f:(fun b -> (state, side, on_close, b)))))
  in
  List.iter cases ~f:(fun (state, side, on_close, b) ->
      let hit = check_stop_hit ~on_close ~state ~side ~bar:b () in
      line
        (Printf.sprintf "S2 %s %b %s %s %s %s -> %b %s" (show_side side)
           on_close (show_state state)
           (f b.Types.Daily_price.low_price)
           (f b.Types.Daily_price.high_price)
           (f b.Types.Daily_price.close_price)
           hit
           (f (get_stop_level state))))
