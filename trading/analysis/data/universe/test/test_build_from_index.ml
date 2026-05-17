open Core
open OUnit2
open Matchers
open Universe
open Universe.Snapshot
module SC = Shiller.Shiller_client
module KF = Kenneth_french.Kenneth_french_client

(* ---------------------------------------------------------------------- *)
(* Fixtures                                                                *)
(* ---------------------------------------------------------------------- *)

let _build_date = Date.create_exn ~y:1990 ~m:Month.May ~d:31

(* Shiller fixture: 12 monthly observations spanning 1990-06 .. 1991-05.
   The build date is 1990-05-31, so the in-window slice (Date.t-anchored at
   the first of each month) starts with 1990-06-01 and ends with 1991-05-01.
   p_start = 100, p_end = 110, dividends all None → composite return is
   exactly 10%. We deliberately omit 1990-05-01 (which would fall outside
   the [date..date+365] window) to keep the fixture's intent unambiguous. *)
let _shiller_fixture : SC.monthly_observation list =
  let months =
    [
      (1990, Month.Jun);
      (1990, Month.Jul);
      (1990, Month.Aug);
      (1990, Month.Sep);
      (1990, Month.Oct);
      (1990, Month.Nov);
      (1990, Month.Dec);
      (1991, Month.Jan);
      (1991, Month.Feb);
      (1991, Month.Mar);
      (1991, Month.Apr);
      (1991, Month.May);
    ]
  in
  let n = List.length months in
  List.mapi months ~f:(fun i (y, m) ->
      let frac = Float.of_int i /. Float.of_int (n - 1) in
      let price = 100.0 +. (10.0 *. frac) in
      {
        SC.period = Date.create_exn ~y ~m ~d:1;
        sp_price = price;
        dividend = None;
        earnings = None;
        cpi = None;
        long_rate = None;
      })

(* French fixture: 252 daily observations across the window 1990-05-31 ..
   1991-05-30 (linear date spacing, ignoring weekends — the builder filters
   purely on Date.t inclusion, so non-business-day-shaped dates are fine
   for unit-test purposes). Each industry gets a small constant daily return
   in percent. The cross-section spread doesn't matter for the calibration
   test — the builder's scalar correction anchors the aggregate regardless.
*)
let _french_industries = [ "Cnsmr"; "Manuf"; "HiTec"; "Hlth"; "Other" ]
let _french_pct_by_industry = [ 0.04; 0.05; 0.06; 0.03; 0.02 ]

let _french_industry_returns_for_day day_idx =
  ignore day_idx;
  List.zip_exn _french_industries _french_pct_by_industry
  |> List.map ~f:(fun (industry, pct) -> (industry, Some pct))

let _french_fixture : KF.daily_return list =
  let n_days = 252 in
  List.init n_days ~f:(fun i ->
      {
        KF.date = Date.add_days _build_date i;
        industry_returns = _french_industry_returns_for_day i;
      })

let _config_for ~size = Build_from_index.default_config ~size ~rng_seed:42

let _build_or_fail ~size =
  let config = _config_for ~size in
  match
    Build_from_index.build ~date:_build_date ~shiller_obs:_shiller_fixture
      ~french_obs:_french_fixture ~config
  with
  | Ok snapshot -> snapshot
  | Error err -> assert_failure ("build failed: " ^ Status.show err)

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

(* Calibration: cap-weighted aggregate must equal Shiller's 10% target
   within the default epsilon (0.5%). With closed-form rescale, the actual
   drift lands near machine epsilon — this test pins the contract. *)
let test_calibration_anchors_aggregate_to_shiller_target _ =
  let snapshot = _build_or_fail ~size:50 in
  assert_that snapshot
    (field
       (fun s -> s.aggregate_period_return)
       (float_equal ~epsilon:0.005 0.10))

let test_size_matches_config _ =
  let snapshot = _build_or_fail ~size:50 in
  assert_that snapshot
    (all_of
       [
         field (fun s -> s.size) (equal_to 50);
         field (fun s -> List.length s.entries) (equal_to 50);
       ])

let test_industry_distribution_is_equal_split _ =
  let snapshot = _build_or_fail ~size:50 in
  let count_in industry =
    List.count snapshot.entries ~f:(fun e -> String.equal e.sector industry)
  in
  assert_that
    (List.map _french_industries ~f:count_in)
    (elements_are
       [ equal_to 10; equal_to 10; equal_to 10; equal_to 10; equal_to 10 ])

let test_synthetic_symbol_naming_pinned_first_three _ =
  let snapshot = _build_or_fail ~size:50 in
  let first_three = List.take snapshot.entries 3 in
  assert_that first_three
    (elements_are
       [
         all_of
           [
             field (fun e -> e.symbol) (equal_to "SYNTH_Cnsmr_0001");
             field (fun e -> e.sector) (equal_to "Cnsmr");
             field (fun e -> e.synthetic) (equal_to true);
           ];
         all_of
           [
             field (fun e -> e.symbol) (equal_to "SYNTH_Cnsmr_0002");
             field (fun e -> e.sector) (equal_to "Cnsmr");
           ];
         all_of
           [
             field (fun e -> e.symbol) (equal_to "SYNTH_Cnsmr_0003");
             field (fun e -> e.sector) (equal_to "Cnsmr");
           ];
       ])

let test_total_weight_is_one _ =
  let snapshot = _build_or_fail ~size:50 in
  assert_that (Snapshot.total_weight snapshot) (float_equal 1.0)

let test_method_carries_anchor_and_skeleton _ =
  let snapshot = _build_or_fail ~size:50 in
  assert_that snapshot.method_
    (equal_to
       (Snapshot.Decomposition_from_index
          {
            anchor = `Shiller_sp_composite;
            factor_skeleton = `French_5_industry;
          }))

let test_determinism_same_seed_yields_same_snapshot _ =
  let snapshot_a = _build_or_fail ~size:50 in
  let snapshot_b = _build_or_fail ~size:50 in
  assert_that snapshot_a (equal_to snapshot_b)

let test_size_not_divisible_by_five_is_invalid_argument _ =
  let config = Build_from_index.default_config ~size:49 ~rng_seed:7 in
  assert_that
    (Build_from_index.build ~date:_build_date ~shiller_obs:_shiller_fixture
       ~french_obs:_french_fixture ~config)
    (is_error_with Status.Invalid_argument)

let test_empty_shiller_is_invalid_argument _ =
  let config = Build_from_index.default_config ~size:50 ~rng_seed:7 in
  assert_that
    (Build_from_index.build ~date:_build_date ~shiller_obs:[]
       ~french_obs:_french_fixture ~config)
    (is_error_with Status.Invalid_argument)

let suite =
  "Build_from_index"
  >::: [
         "test_calibration_anchors_aggregate_to_shiller_target"
         >:: test_calibration_anchors_aggregate_to_shiller_target;
         "test_size_matches_config" >:: test_size_matches_config;
         "test_industry_distribution_is_equal_split"
         >:: test_industry_distribution_is_equal_split;
         "test_synthetic_symbol_naming_pinned_first_three"
         >:: test_synthetic_symbol_naming_pinned_first_three;
         "test_total_weight_is_one" >:: test_total_weight_is_one;
         "test_method_carries_anchor_and_skeleton"
         >:: test_method_carries_anchor_and_skeleton;
         "test_determinism_same_seed_yields_same_snapshot"
         >:: test_determinism_same_seed_yields_same_snapshot;
         "test_size_not_divisible_by_five_is_invalid_argument"
         >:: test_size_not_divisible_by_five_is_invalid_argument;
         "test_empty_shiller_is_invalid_argument"
         >:: test_empty_shiller_is_invalid_argument;
       ]

let () = run_test_tt_main suite
