(** Direct unit tests for {!Weinstein_snapshot_gen.Live_resistance_sketch} — the
    live bar-list resistance-v2 sketch bridge.

    Builds deterministic synthetic daily bars (4 Mon-Fri weeks with a single
    high spike) so the extracted sketch cells can be pinned against independent
    oracles: the rolling max-high family peaks at the spike, the histogram
    anchor is the last bar's raw close, the spike sits in bucket 0, and
    [bars_seen] is honestly shallow (a handful of weeks, never a fabricated
    520). *)

open Core
open OUnit2
open Matchers
module Live_sketch = Weinstein_snapshot_gen.Live_resistance_sketch

(* First Monday of 2022 (a clean ISO-week boundary). *)
let _monday = Date.of_string "2022-01-03"

(* [weeks] consecutive Mon-Fri weeks starting on [_monday]; per-bar high / low /
   close chosen by index (0 = oldest). Adjusted close = raw close (no splits),
   so the histogram anchor reads the raw close directly. *)
let _make_bars ~weeks ~high_at ~low_at ~close_at : Types.Daily_price.t list =
  List.concat_map (List.range 0 weeks) ~f:(fun w ->
      List.map (List.range 0 5) ~f:(fun d ->
          let i = (w * 5) + d in
          let date = Date.add_days _monday ((7 * w) + d) in
          Types.Daily_price.make ~date ~open_price:(low_at i)
            ~high_price:(high_at i) ~low_price:(low_at i)
            ~close_price:(close_at i) ~volume:1_000_000
            ~adjusted_close:(close_at i) ()))

(* 4 weeks (20 bars): a lone high spike to 150 on week-1 Wednesday (index 7);
   every other high 110; low 90 throughout; last bar (index 19) closes at 120,
   every other bar at 105. The spike week aggregates to weekly high 150, low 90,
   mid 120 = the anchor, so it lands in histogram bucket 0; no other week's
   weekly high (110) clears the 120 anchor. *)
let _spike_idx = 7
let _last_idx = 19

let _bars_4w =
  _make_bars ~weeks:4
    ~high_at:(fun i -> if i = _spike_idx then 150.0 else 110.0)
    ~low_at:(fun _ -> 90.0)
    ~close_at:(fun i -> if i = _last_idx then 120.0 else 105.0)

(* Happy path: the sketch at the analysis Friday pins the max-high family to the
   window peak (150), the anchor to the last raw close (120), the histogram mass
   to the single spike week in bucket 0, and a shallow-but-plausible bars_seen
   (4 distinct weeks). *)
let test_sketch_pins_known_cells _ =
  assert_that
    (Live_sketch.of_daily_bars _bars_4w)
    (is_some_and
       (all_of
          [
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_520w)
              (float_equal 150.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_260w)
              (float_equal 150.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.max_high_130w)
              (float_equal 150.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.anchor_close)
              (float_equal 120.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.hist_bands.(0).(0))
              (float_equal 1.0);
            field
              (fun (s : Resistance_supply.sketch) ->
                Array.fold s.hist_bands ~init:0.0 ~f:(fun acc band ->
                    acc +. Array.fold band ~init:0.0 ~f:( +. )))
              (float_equal 1.0);
            field
              (fun (s : Resistance_supply.sketch) -> s.bars_seen)
              (is_between (module Float_ord) ~low:3.0 ~high:5.0);
          ]))

(* Shallow-history honesty: a single week of bars yields a bars_seen of ~1 — the
   fetched window is short, so the sketch reports the true (tiny) depth rather
   than fabricating a full 520-week history. *)
let test_shallow_history_is_honest _ =
  let one_week =
    _make_bars ~weeks:1
      ~high_at:(fun _ -> 110.0)
      ~low_at:(fun _ -> 90.0)
      ~close_at:(fun _ -> 105.0)
  in
  assert_that
    (Live_sketch.of_daily_bars one_week)
    (is_some_and
       (field
          (fun (s : Resistance_supply.sketch) -> s.bars_seen)
          (is_between (module Float_ord) ~low:1.0 ~high:2.0)))

(* Empty history has no bar to anchor the sketch on → [None]. *)
let test_empty_bars_is_none _ =
  assert_that (Live_sketch.of_daily_bars []) is_none

let suite =
  "live_resistance_sketch"
  >::: [
         "sketch pins known cells" >:: test_sketch_pins_known_cells;
         "shallow history is honest" >:: test_shallow_history_is_honest;
         "empty bars is none" >:: test_empty_bars_is_none;
       ]

let () = run_test_tt_main suite
