open OUnit2
open Core
open Matchers
module Weekly_prefix = Snapshot_pipeline.Weekly_prefix
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch

let _config = Resistance_supply.default_config
let _n_buckets = 20

(* A sketch with no overhead anywhere: every max-high below the breakout. *)
let _virgin_sketch =
  {
    Resistance_supply.max_high_130w = 90.0;
    max_high_260w = 95.0;
    max_high_520w = 99.0;
    bars_seen = 520.0;
    hist = Array.create ~len:_n_buckets 0.0;
    anchor_close = 100.0;
  }

let _with_hist ?(max_high = 150.0) counts =
  let hist = Array.create ~len:_n_buckets 0.0 in
  List.iter counts ~f:(fun (k, c) -> hist.(k) <- c);
  {
    _virgin_sketch with
    max_high_130w = max_high;
    max_high_260w = max_high;
    max_high_520w = max_high;
    hist;
  }

let test_virgin_scores_zero _ =
  let result =
    Resistance_supply.analyze ~config:_config ~sketch:_virgin_sketch
      ~breakout_price:100.0
  in
  assert_that result
    (equal_to
       ({
          score = 0.0;
          recent_weighted_bars = 0.0;
          quality = Weinstein_types.Virgin_territory;
        }
         : Resistance_supply.result))

(* 8 bars in the first bucket above the breakout = saturated heavy supply. *)
let test_heavy_recent_supply_saturates _ =
  let result =
    Resistance_supply.analyze ~config:_config
      ~sketch:(_with_hist [ (0, 8.0) ])
      ~breakout_price:100.0
  in
  assert_that result
    (all_of
       [
         field (fun (r : Resistance_supply.result) -> r.score) (float_equal 1.0);
         field
           (fun (r : Resistance_supply.result) -> r.quality)
           (equal_to Weinstein_types.Heavy_resistance);
       ])

(* 3 bars -> moderate grade, score 3/8. *)
let test_moderate_supply _ =
  let result =
    Resistance_supply.analyze ~config:_config
      ~sketch:(_with_hist [ (0, 3.0) ])
      ~breakout_price:100.0
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Resistance_supply.result) -> r.score)
           (float_equal 0.375);
         field
           (fun (r : Resistance_supply.result) -> r.quality)
           (equal_to Weinstein_types.Moderate_resistance);
       ])

(* The same bar mass farther above the breakout scores lower: 5 bars in
   bucket 4 weigh 5 * 0.7^4 = 1.2005 -> 0.15006 after saturation, vs 0.625
   for bucket 0. *)
let test_proximity_decay_discounts_distant_supply _ =
  let near =
    Resistance_supply.analyze ~config:_config
      ~sketch:(_with_hist [ (0, 5.0) ])
      ~breakout_price:100.0
  in
  let far =
    Resistance_supply.analyze ~config:_config
      ~sketch:(_with_hist [ (4, 5.0) ])
      ~breakout_price:100.0
  in
  assert_that (near.score, far.score)
    (all_of
       [
         field (fun (a, _) -> a) (float_equal 0.625);
         field (fun (_, b) -> b) (float_equal ~epsilon:1e-9 0.1500625);
       ])

(* A breakout above the anchor shifts the first relevant bucket up:
   supply in bucket 0 stops counting once the breakout clears its band. *)
let test_breakout_above_anchor_shifts_buckets _ =
  let sketch = _with_hist [ (0, 8.0) ] in
  (* bucket 0 spans [100, 100 * 2^(1/20)) ~ [100, 103.5); a breakout at 110
     sits above it, so the 8 bars no longer count as overhead mass — but
     max_high_130w = 150 still proves recent overhead -> recent_far_floor. *)
  let result =
    Resistance_supply.analyze ~config:_config ~sketch ~breakout_price:110.0
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Resistance_supply.result) -> r.recent_weighted_bars)
           (float_equal 0.0);
         field
           (fun (r : Resistance_supply.result) -> r.score)
           (float_equal _config.recent_far_floor);
       ])

(* Horizon floors: overhead only in the older windows. *)
let test_stale_horizon_floors _ =
  let mid =
    Resistance_supply.analyze ~config:_config
      ~sketch:
        { _virgin_sketch with max_high_260w = 120.0; max_high_520w = 120.0 }
      ~breakout_price:100.0
  in
  let old =
    Resistance_supply.analyze ~config:_config
      ~sketch:{ _virgin_sketch with max_high_520w = 120.0 }
      ~breakout_price:100.0
  in
  assert_that (mid, old)
    (all_of
       [
         field
           (fun ((m : Resistance_supply.result), _) -> m.score)
           (float_equal _config.stale_mid_floor);
         field
           (fun ((m : Resistance_supply.result), _) -> m.quality)
           (equal_to Weinstein_types.Clean);
         field
           (fun (_, (o : Resistance_supply.result)) -> o.score)
           (float_equal _config.stale_old_floor);
       ])

let test_insufficient_history _ =
  let config = { _config with min_history_bars = 240 } in
  let result =
    Resistance_supply.analyze ~config
      ~sketch:{ _virgin_sketch with bars_seen = 100.0 }
      ~breakout_price:100.0
  in
  assert_that result
    (equal_to
       ({
          score = config.insufficient_score;
          recent_weighted_bars = 0.0;
          quality = Weinstein_types.Insufficient_history;
        }
         : Resistance_supply.result))

let test_nan_sketch_degrades_to_insufficient _ =
  let result =
    Resistance_supply.analyze ~config:_config
      ~sketch:{ _virgin_sketch with max_high_520w = Float.nan }
      ~breakout_price:100.0
  in
  assert_that result.quality (equal_to Weinstein_types.Insufficient_history)

(* ------------------------------------------------------------------ *)
(* Parity vs the v1 mapper on the virgin verdict, through the real     *)
(* sketch builder: same weekly window, same raw-high basis.            *)
(* ------------------------------------------------------------------ *)

let _bar ~date ~high ~low ~close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* 60 Mon-Fri weeks: week 10 spikes to [spike_high]; all else flat 100. *)
let _daily_bars ~spike_high =
  let start = Date.of_string "2020-01-06" in
  List.init 60 ~f:(fun w ->
      List.init 5 ~f:(fun d ->
          let date = Date.add_days start ((7 * w) + d) in
          let high = if w = 10 then spike_high else 101.0 in
          _bar ~date ~high ~low:99.0 ~close:100.0))
  |> List.concat

let _v1_quality bars ~breakout_price =
  let bars_arr = Array.of_list bars in
  let weekly_prefix = Weekly_prefix.build bars_arr in
  let weekly =
    Weekly_prefix.window_for_day weekly_prefix
      ~day_idx:(Array.length bars_arr - 1)
      ~lookback:520
  in
  let result =
    Resistance.analyze ~config:Resistance.default_config ~bars:weekly
      ~breakout_price ~as_of_date:(List.last_exn weekly).Types.Daily_price.date
  in
  result.quality

let _v2_quality bars ~breakout_price =
  let bars_arr = Array.of_list bars in
  let weekly_prefix = Weekly_prefix.build bars_arr in
  let sketch = Resistance_sketch.compute ~weekly_prefix ~bars_arr in
  let i = Array.length bars_arr - 1 in
  let result =
    Resistance_supply.analyze ~config:_config
      ~sketch:
        {
          max_high_130w = sketch.max_high_130w.(i);
          max_high_260w = sketch.max_high_260w.(i);
          max_high_520w = sketch.max_high_520w.(i);
          bars_seen = sketch.bars_seen.(i);
          hist = Array.map sketch.hist ~f:(fun row -> row.(i));
          anchor_close = bars_arr.(i).Types.Daily_price.close_price;
        }
      ~breakout_price
  in
  result.quality

(* The virgin verdict is bit-equal between v1 (bar walk) and v2 (sketch):
   breakout above the 60-week spike is virgin in both, below it is not, and
   exactly AT the spike (the tie) both call it virgin (v1 requires a high
   STRICTLY above the breakout). *)
let test_virgin_parity_with_v1 _ =
  let bars = _daily_bars ~spike_high:130.0 in
  let breakouts = [ 135.0; 130.0; 120.0 ] in
  let agreements =
    List.count breakouts ~f:(fun breakout_price ->
        let v1 = _v1_quality bars ~breakout_price in
        let v2 = _v2_quality bars ~breakout_price in
        let virgin_v1 =
          match v1 with Weinstein_types.Virgin_territory -> true | _ -> false
        in
        let virgin_v2 =
          match v2 with Weinstein_types.Virgin_territory -> true | _ -> false
        in
        Bool.equal virgin_v1 virgin_v2)
  in
  assert_that agreements (equal_to (List.length breakouts))

let suite =
  "Resistance_supply tests"
  >::: [
         "virgin scores zero" >:: test_virgin_scores_zero;
         "heavy recent supply saturates" >:: test_heavy_recent_supply_saturates;
         "moderate supply" >:: test_moderate_supply;
         "proximity decay discounts distant supply"
         >:: test_proximity_decay_discounts_distant_supply;
         "breakout above anchor shifts buckets"
         >:: test_breakout_above_anchor_shifts_buckets;
         "stale horizon floors" >:: test_stale_horizon_floors;
         "insufficient history" >:: test_insufficient_history;
         "NaN sketch degrades to insufficient"
         >:: test_nan_sketch_degrades_to_insufficient;
         "virgin parity with v1" >:: test_virgin_parity_with_v1;
       ]

let () = run_test_tt_main suite
