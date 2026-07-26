open OUnit2
open Core
open Matchers
module Weekly_prefix = Snapshot_pipeline.Weekly_prefix
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch

let _config = Resistance_supply.default_config
let _n_buckets = 20
let _n_bands = Resistance_supply.n_age_bands

(* A single 20-bucket price histogram with [counts] placed. *)
let _band counts =
  let a = Array.create ~len:_n_buckets 0.0 in
  List.iter counts ~f:(fun (k, c) -> a.(k) <- c);
  a

(* A sketch with no overhead anywhere: every max-high below the breakout. *)
let _virgin_sketch =
  {
    Resistance_supply.max_high_130w = 90.0;
    max_high_260w = 95.0;
    max_high_520w = 99.0;
    bars_seen = 520.0;
    hist_bands = Resistance_supply.hist_bands_of_legacy (_band []);
    anchor_close = 100.0;
  }

(* Legacy age-blind histogram (all mass in the youngest band) at [max_high]. *)
let _with_hist ?(max_high = 150.0) counts =
  {
    _virgin_sketch with
    max_high_130w = max_high;
    max_high_260w = max_high;
    max_high_520w = max_high;
    hist_bands = Resistance_supply.hist_bands_of_legacy (_band counts);
  }

(* A sketch with an explicit 4-band histogram (each element a 20-bucket band). *)
let _with_bands ?(max_high = 150.0) bands =
  {
    _virgin_sketch with
    max_high_130w = max_high;
    max_high_260w = max_high;
    max_high_520w = max_high;
    hist_bands = bands;
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
  let n_buckets = Array.length sketch.hist / _n_bands in
  let result =
    Resistance_supply.analyze ~config:_config
      ~sketch:
        {
          max_high_130w = sketch.max_high_130w.(i);
          max_high_260w = sketch.max_high_260w.(i);
          max_high_520w = sketch.max_high_520w.(i);
          bars_seen = sketch.bars_seen.(i);
          hist_bands =
            Array.init _n_bands ~f:(fun b ->
                Array.init n_buckets ~f:(fun bucket ->
                    sketch.hist.((b * n_buckets) + bucket).(i)));
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

(* [is_virgin] is the standalone virgin predicate: at/above the 520-week max
   (99.0) is virgin (ties inclusive), below is not, and a non-finite sketch is
   never virgin (no fabrication). *)
let test_is_virgin_predicate _ =
  let nan_sketch = { _virgin_sketch with max_high_520w = Float.nan } in
  assert_that
    [
      Resistance_supply.is_virgin ~sketch:_virgin_sketch ~breakout_price:100.0;
      Resistance_supply.is_virgin ~sketch:_virgin_sketch ~breakout_price:99.0;
      Resistance_supply.is_virgin ~sketch:_virgin_sketch ~breakout_price:98.0;
      Resistance_supply.is_virgin ~sketch:nan_sketch ~breakout_price:100.0;
    ]
    (elements_are
       [
         equal_to true; (* tie *) equal_to true; equal_to false; equal_to false;
       ])

(* [is_virgin] agrees with [analyze]'s [quality = Virgin_territory] verdict on
   the same cells (single source of truth for the virgin test). *)
let test_is_virgin_agrees_with_analyze _ =
  let quality_virgin ~breakout_price =
    match
      (Resistance_supply.analyze ~config:_config ~sketch:_virgin_sketch
         ~breakout_price)
        .quality
    with
    | Weinstein_types.Virgin_territory -> true
    | _ -> false
  in
  let agree ~breakout_price =
    Bool.equal
      (Resistance_supply.is_virgin ~sketch:_virgin_sketch ~breakout_price)
      (quality_virgin ~breakout_price)
  in
  assert_that
    (List.count [ 100.0; 99.0; 98.0 ] ~f:(fun breakout_price ->
         agree ~breakout_price))
    (equal_to 3)

(* [is_clear_of_supply]: closing-basis new high ground. All-zero hist with
   [bars_seen > 0] is clear even when [max_high_520w] sits ABOVE the close (the
   AXTI own-week-high shape); a non-zero bin, [bars_seen = 0], or a non-finite
   sketch are all not clear (no fabrication). *)
let test_is_clear_of_supply _ =
  let axti_shape = { _virgin_sketch with max_high_520w = 105.0 } in
  let zero_bars = { _virgin_sketch with bars_seen = 0.0 } in
  let nan_sketch = { _virgin_sketch with anchor_close = Float.nan } in
  assert_that
    [
      Resistance_supply.is_clear_of_supply ~sketch:_virgin_sketch;
      Resistance_supply.is_clear_of_supply ~sketch:axti_shape;
      Resistance_supply.is_clear_of_supply ~sketch:(_with_hist [ (0, 8.0) ]);
      Resistance_supply.is_clear_of_supply ~sketch:zero_bars;
      Resistance_supply.is_clear_of_supply ~sketch:nan_sketch;
    ]
    (elements_are
       [
         equal_to true;
         equal_to true;
         equal_to false;
         equal_to false;
         equal_to false;
       ])

(* The own-week-high divergence: on a cell whose [max_high_520w] (105) sits above
   the breakout (100) — set by the current week's own high — yet has zero
   overhead in the histogram, [is_virgin] is FALSE but [is_clear_of_supply] is
   TRUE. The OR of the two in the re-admission predicate is what admits the
   genuine breakout (AXTI 2026-01-06: close 20.17, max 20.345, hist_sum 0). *)
let test_own_week_high_divergence _ =
  let axti_shape = { _virgin_sketch with max_high_520w = 105.0 } in
  assert_that
    ( Resistance_supply.is_virgin ~sketch:axti_shape ~breakout_price:100.0,
      Resistance_supply.is_clear_of_supply ~sketch:axti_shape )
    (equal_to (false, true))

(* ------------------------------------------------------------------ *)
(* Age-banded histogram (lever f): default bit-identical + the lever.  *)
(* ------------------------------------------------------------------ *)

(* Default parity: at default weights ([1;1;1;0]) the effective histogram is the
   SUM of the three 0-130w bands. 3 bars in bucket 0 split one-per-recent-band
   score identically to the same 3 bars packed into the youngest band (the v3
   layout) — both the moderate 3/8 score. This is the "v3-shaped sketch scores
   identically" parity: summing bands 0-2 = the pre-lever-f age-blind hist. *)
let test_default_collapse_sums_recent_bands _ =
  let split =
    [| _band [ (0, 1.0) ]; _band [ (0, 1.0) ]; _band [ (0, 1.0) ]; _band [] |]
  in
  let legacy = Resistance_supply.hist_bands_of_legacy (_band [ (0, 3.0) ]) in
  let r_split =
    Resistance_supply.analyze ~config:_config ~sketch:(_with_bands split)
      ~breakout_price:100.0
  in
  let r_legacy =
    Resistance_supply.analyze ~config:_config ~sketch:(_with_bands legacy)
      ~breakout_price:100.0
  in
  assert_that (r_split, r_legacy)
    (all_of
       [
         field
           (fun ((s : Resistance_supply.result), _) -> s.score)
           (float_equal 0.375);
         field
           (fun (_, (l : Resistance_supply.result)) -> l.score)
           (float_equal 0.375);
         field
           (fun ((s : Resistance_supply.result), _) -> s.quality)
           (equal_to Weinstein_types.Moderate_resistance);
       ])

(* Default inert 130-520w band: 8 bars living ONLY in the stale band contribute
   nothing to the effective histogram (weight 0), so the score falls to the
   horizon floor proven by the max-highs, not the saturated 1.0. *)
let test_stale_band_inert_at_default _ =
  let bands = [| _band []; _band []; _band []; _band [ (0, 8.0) ] |] in
  let result =
    Resistance_supply.analyze ~config:_config ~sketch:(_with_bands bands)
      ~breakout_price:100.0
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

(* The lever works: arming the 130-520w band weight makes its 8 bars saturate
   the score to 1.0 (Heavy), proving the age decay is a real score-time knob. *)
let test_stale_band_weight_activates _ =
  let bands = [| _band []; _band []; _band []; _band [ (0, 8.0) ] |] in
  let config = { _config with band_weight_130_520w = 1.0 } in
  let result =
    Resistance_supply.analyze ~config ~sketch:(_with_bands bands)
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

(* R1/R2 sexp back-compat: a config sexp written before lever f (lacking the
   four band-weight fields) still parses, the [@sexp.default]s filling in the
   no-op weights (1 / 1 / 1 / 0). *)
let test_config_parses_without_band_weights _ =
  let stripped =
    match Resistance_supply.sexp_of_config _config with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom k :: _) ->
                not (String.is_prefix k ~prefix:"band_weight")
            | _ -> true))
    | other -> other
  in
  let parsed = Resistance_supply.config_of_sexp stripped in
  assert_that
    (parsed.band_weight_0_26w, parsed.band_weight_130_520w)
    (all_of
       [
         field (fun (a, _) -> a) (float_equal 1.0);
         field (fun (_, b) -> b) (float_equal 0.0);
       ])

(* [is_clear_of_supply] ignores the 130-520w band: mass there alone is still
   "clear" (recent overhead empty), keeping the virgin-readmission lever's 130w
   semantics unchanged. *)
let test_is_clear_ignores_stale_band _ =
  let bands = [| _band []; _band []; _band []; _band [ (0, 8.0) ] |] in
  assert_that
    (Resistance_supply.is_clear_of_supply ~sketch:(_with_bands bands))
    (equal_to true)

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
         "is_virgin predicate" >:: test_is_virgin_predicate;
         "is_virgin agrees with analyze" >:: test_is_virgin_agrees_with_analyze;
         "is_clear_of_supply" >:: test_is_clear_of_supply;
         "own-week-high divergence" >:: test_own_week_high_divergence;
         "default collapse sums recent bands"
         >:: test_default_collapse_sums_recent_bands;
         "stale band inert at default" >:: test_stale_band_inert_at_default;
         "stale band weight activates" >:: test_stale_band_weight_activates;
         "config parses without band weights"
         >:: test_config_parses_without_band_weights;
         "is_clear ignores stale band" >:: test_is_clear_ignores_stale_band;
       ]

let () = run_test_tt_main suite
