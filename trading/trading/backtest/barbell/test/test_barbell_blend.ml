open Core
open OUnit2
open Matchers

(* Three common dates with hand-computable returns. floor returns +10%, +10%;
   engine returns -10%, +20%. *)
let d s = Date.of_string s

let floor_curve =
  [ (d "2020-01-01", 100.0); (d "2020-01-02", 110.0); (d "2020-01-03", 121.0) ]

let engine_curve =
  [ (d "2020-01-01", 100.0); (d "2020-01-02", 90.0); (d "2020-01-03", 108.0) ]

let cfg ~floor_weight ~rebalance_weeks : Barbell.Barbell_config.t =
  { enable = true; floor_weight; rebalance_weeks }

let nav_values (r : Barbell.Barbell_blend.t) = List.map r.nav_curve ~f:snd

let blend_daily ~floor_weight ~floor_curve ~engine_curve =
  Barbell.Barbell_blend.blend_with_stride_days ~floor_weight
    ~rebalance_stride_days:1 ~floor_curve ~engine_curve

(* Daily blend at w=0.5 over the fixture: blend.awk gives NAV path [1.0; 1.0;
   1.15] (r2 = 0.5*0.10 + 0.5*(-0.10) = 0; r3 = 0.5*0.10 + 0.5*0.20 = 0.15). The
   daily rebalance stride (1) is the limit that reproduces blend.awk exactly. *)
let test_reproduces_blend_awk_daily _ =
  let result = blend_daily ~floor_weight:0.5 ~floor_curve ~engine_curve in
  assert_that (nav_values result)
    (elements_are [ float_equal 1.0; float_equal 1.0; float_equal 1.15 ])

let test_blend_awk_total_return _ =
  let result = blend_daily ~floor_weight:0.5 ~floor_curve ~engine_curve in
  assert_that result.metrics.total_return_pct (float_equal 15.0)

(* Ground-truth proof against blend.awk: a 5-point, 4-trading-day fixture run
   through [awk -v w=0.4 -f blend.awk] (the validated barbell math) gives
   total_return 27.4%, sharpe 9.651, maxdd 6.4%, ulcer 3.37, n 5. The daily-
   stride overlay reproduces every metric. (The enormous calmar is blend.awk's
   own artifact of annualising a 4-day window; both produce it identically, so
   it is not pinned here.) *)
let blend_awk_floor =
  [
    (d "2020-01-01", 100.0);
    (d "2020-01-02", 110.0);
    (d "2020-01-03", 121.0);
    (d "2020-01-06", 115.0);
    (d "2020-01-07", 120.0);
  ]

let blend_awk_engine =
  [
    (d "2020-01-01", 100.0);
    (d "2020-01-02", 90.0);
    (d "2020-01-03", 108.0);
    (d "2020-01-06", 100.0);
    (d "2020-01-07", 130.0);
  ]

let test_matches_blend_awk_metrics _ =
  let result =
    blend_daily ~floor_weight:0.4 ~floor_curve:blend_awk_floor
      ~engine_curve:blend_awk_engine
  in
  assert_that result.metrics
    (all_of
       [
         field
           (fun m -> m.Barbell.Barbell_blend.total_return_pct)
           (float_equal ~epsilon:0.05 27.4);
         field
           (fun m -> m.Barbell.Barbell_blend.sharpe)
           (float_equal ~epsilon:0.001 9.651);
         field
           (fun m -> m.Barbell.Barbell_blend.max_drawdown_pct)
           (float_equal ~epsilon:0.05 6.4);
         field
           (fun m -> m.Barbell.Barbell_blend.ulcer_pct)
           (float_equal ~epsilon:0.005 3.37);
         field (fun m -> m.Barbell.Barbell_blend.n_points) (equal_to 5);
       ])

(* floor_weight = 1.0 => combined NAV is exactly the floor leg's own growth
   (normalised to 1.0 at the first date): 100 -> 110 -> 121 = [1.0; 1.1; 1.21]. *)
let test_pure_floor_is_floor_leg _ =
  let result =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:1.0 ~rebalance_weeks:1)
      ~floor_curve ~engine_curve
  in
  assert_that (nav_values result)
    (elements_are [ float_equal 1.0; float_equal 1.1; float_equal 1.21 ])

(* floor_weight = 0.0 => combined NAV is the engine leg's own growth normalised:
   100 -> 90 -> 108 = [1.0; 0.9; 1.08]. *)
let test_pure_engine_is_engine_leg _ =
  let result =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:0.0 ~rebalance_weeks:1)
      ~floor_curve ~engine_curve
  in
  assert_that (nav_values result)
    (elements_are [ float_equal 1.0; float_equal 0.9; float_equal 1.08 ])

(* The join is an inner join on common dates; a date present in only one leg is
   dropped (matching blend.awk's [if (d in f)]). *)
let test_inner_join_on_common_dates _ =
  let floor_only = floor_curve @ [ (d "2020-01-04", 130.0) ] in
  let result =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:0.5 ~rebalance_weeks:1)
      ~floor_curve:floor_only ~engine_curve
  in
  assert_that result.metrics.n_points (equal_to 3)

(* Build a longer synthetic pair of monotone-ish curves to compare daily vs
   weekly rebalance tracking. *)
let synthetic_curves n =
  let mk base step =
    List.init n ~f:(fun i ->
        ( Date.add_days (d "2020-01-01") i,
          base *. ((1.0 +. step) ** Float.of_int i) ))
  in
  (* floor: gentle +0.2%/day; engine: choppier +0.5%/day. *)
  (mk 100.0 0.002, mk 100.0 0.005)

let test_weekly_tracks_daily _ =
  let floor_c, engine_c = synthetic_curves 60 in
  let daily =
    Barbell.Barbell_blend.blend_with_stride_days ~floor_weight:0.4
      ~rebalance_stride_days:1 ~floor_curve:floor_c ~engine_curve:engine_c
  in
  let weekly =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:0.4 ~rebalance_weeks:1)
      ~floor_curve:floor_c ~engine_curve:engine_c
  in
  (* On smoothly trending legs the rebalance cadence barely matters; weekly
     (stride 7) tracks daily (stride 1) total return within a small tolerance. *)
  assert_that weekly.metrics.total_return_pct
    (float_equal ~epsilon:5.0 daily.metrics.total_return_pct)

(* maxdd is positive when the engine leg dips and pure engine is selected. *)
let test_drawdown_positive_on_engine_dip _ =
  let result =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:0.0 ~rebalance_weeks:1)
      ~floor_curve ~engine_curve
  in
  (* engine NAV 1.0 -> 0.9 -> 1.08: worst drawdown is the 10% dip. *)
  assert_that result.metrics.max_drawdown_pct (float_equal 10.0)

(* Fewer than two common dates => zeroed metrics, no crash. *)
let test_single_point_is_safe _ =
  let result =
    Barbell.Barbell_blend.blend
      ~config:(cfg ~floor_weight:0.5 ~rebalance_weeks:1)
      ~floor_curve:[ (d "2020-01-01", 100.0) ]
      ~engine_curve:[ (d "2020-01-01", 100.0) ]
  in
  assert_that result.metrics
    (all_of
       [
         field (fun m -> m.Barbell.Barbell_blend.n_points) (equal_to 1);
         field
           (fun m -> m.Barbell.Barbell_blend.total_return_pct)
           (float_equal 0.0);
       ])

let suite =
  "barbell_blend"
  >::: [
         "reproduces_blend_awk_daily" >:: test_reproduces_blend_awk_daily;
         "blend_awk_total_return" >:: test_blend_awk_total_return;
         "matches_blend_awk_metrics" >:: test_matches_blend_awk_metrics;
         "pure_floor_is_floor_leg" >:: test_pure_floor_is_floor_leg;
         "pure_engine_is_engine_leg" >:: test_pure_engine_is_engine_leg;
         "inner_join_on_common_dates" >:: test_inner_join_on_common_dates;
         "weekly_tracks_daily" >:: test_weekly_tracks_daily;
         "drawdown_positive_on_engine_dip"
         >:: test_drawdown_positive_on_engine_dip;
         "single_point_is_safe" >:: test_single_point_is_safe;
       ]

let () = run_test_tt_main suite
