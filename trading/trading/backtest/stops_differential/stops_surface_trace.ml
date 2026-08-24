(** Deterministic whole-surface trace of the public stops API.

    Prints one line per call, with every float in [%.17g] so a one-ULP shift is
    visible. The companion golden ([stops_surface_trace.expected], diffed by the
    [runtest] rule in this directory's [dune]) is the regression pin: any change
    to default-path stop behaviour — including a refactor that only reassociates
    arithmetic — moves at least one line.

    {b Why this exists (issue #2503).} PR #2492 bundled a [Stop_geometry]
    extraction with its default-off flag. The extraction moved [bar_extreme],
    [nudge_round_number], the two buffered stop candidates, [is_better_stop],
    [is_correction] and [is_recovery] out of [weinstein_stops.ml], and repointed
    [floor_stop.ml]'s local nudge adapter at the new module. Reassociating a
    multiply / round / [Float.min] chain can shift a stop by one ULP, which is
    enough to flip a StopLimit fill and change which symbols a backtest enters.
    The proof that it did not is this trace, generated at the merge-base
    ([3782920a]) and byte-compared against HEAD; the golden is the merge-base
    output, so it also pins every future refactor.

    {b Coverage.} Every [val] in [weinstein_stops.mli] apart from the
    re-exported sub-modules ([Stop_split_adjust], [Stop_widen],
    [Vol_scaled_stop], [Catastrophic_stop], [Extension_stop]) — those were
    untouched by #2492 and are traced only where the functions below reach them
    (they do not). Only the public API is used: no field of [config] added after
    the merge-base may be named here, or the trace could not be generated on
    both sides. *)

open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops

(* ---- printing ---- *)

(* [%.17g] round-trips an IEEE double exactly, so two traces agree only if every
   float agrees bit-for-bit. *)
let f x = Printf.sprintf "%.17g" x
let line s = Printf.printf "%s\n" s
let show_side = function Long -> "L" | Short -> "S"

let show_state = function
  | Initial { stop_level; reference_level } ->
      Printf.sprintf "Initial(%s|%s)" (f stop_level) (f reference_level)
  | Trailing
      {
        stop_level;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
        correction_observed_since_reset;
      } ->
      Printf.sprintf "Trailing(%s|%s|%s|%s|%d|%b)" (f stop_level)
        (f last_correction_extreme)
        (f last_trend_extreme) (f ma_at_last_adjustment) correction_count
        correction_observed_since_reset
  | Tightened { stop_level; last_correction_extreme; reason } ->
      Printf.sprintf "Tightened(%s|%s|%S)" (f stop_level)
        (f last_correction_extreme)
        reason

let show_event = function
  | Stop_hit { trigger_price; stop_level } ->
      Printf.sprintf "Hit(%s|%s)" (f trigger_price) (f stop_level)
  | Stop_raised { old_level; new_level; reason } ->
      Printf.sprintf "Raised(%s|%s|%S)" (f old_level) (f new_level) reason
  | Entered_tightening { reason } -> Printf.sprintf "Tighten(%S)" reason
  | No_change -> "NoChange"

let show_basis = function
  | Flag_off -> "flag_off"
  | Adjusted -> "adjusted"
  | Raw_fallback -> "raw_fallback"
  | Empty_window -> "empty_window"

(* ---- deterministic pseudo-randomness ---- *)

(* A plain LCG on OCaml's 63-bit int, masked to 30 bits. No [Random] (its stream
   is not guaranteed stable across compiler versions) and no libm (whose last
   bit is not guaranteed stable across platforms), so the golden is portable. *)
let _lcg = ref 1

let _next () =
  _lcg := ((!_lcg * 1103515245) + 12345) land 0x3FFFFFFF;
  !_lcg

(* A value in [0, 1) with exactly 5 decimal digits — exact in binary terms only
   as a ratio of small integers, which is all we need for reproducibility. *)
let _unit () = Float.of_int (_next () mod 100_000) /. 100_000.
let _reseed n = _lcg := n

(* ---- fixtures ---- *)

let as_of = Date.of_string "2024-06-28"
let sides = [ Long; Short ]

let bar ~date ~o ~h ~l ~c ~adj =
  Types.Daily_price.
    {
      date;
      open_price = o;
      high_price = h;
      low_price = l;
      close_price = c;
      volume = 1_000_000;
      adjusted_close = adj;
      active_through = None;
    }

let flat_bar ~date ~l ~h ~c = bar ~date ~o:c ~h ~l ~c ~adj:c

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
      { stop_level = 100.25; last_correction_extreme = 101.0; reason = "probe" };
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

(* ---- section 3: the support-floor initial-stop path ---- *)

(* A 70-bar window with a deterministic pullback shape. [depth] scales the
   counter-move so some windows clear [min_correction_pct] (structural floor)
   and some do not (fixed-buffer fallback); [split] injects an adjusted-close
   factor so [split_safe_floors] has something to rescale. *)
let window ~depth ~split =
  List.map (List.range 0 70) ~f:(fun i ->
      let t = Float.of_int i in
      let wave = _unit () in
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
  _reseed 7;
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
      let wobble = (_unit () -. 0.5) *. 12.0 in
      let c =
        match side with
        | Long -> 100.0 +. drift +. wobble
        | Short -> 100.0 -. drift -. wobble
      in
      let ma = match side with Long -> 96.0 +. t | Short -> 104.0 -. t in
      (flat_bar ~date:as_of ~l:(c -. 2.5) ~h:(c +. 2.5) ~c, ma))

let replay ~config ~side ~state0 ~stage ~ma_direction ~label =
  _reseed 1013;
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

(* ---- main ---- *)

let () =
  line "# stops public-surface trace v1";
  trace_initial_stops ();
  trace_stop_hits ();
  trace_floor_path ();
  trace_update ()
