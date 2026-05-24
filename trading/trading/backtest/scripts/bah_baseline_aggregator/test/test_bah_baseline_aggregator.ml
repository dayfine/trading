(** Unit tests for {!Bah_baseline_aggregator_lib}. Pure-math checks on synthetic
    constant-growth price series — no CSV I/O, no walk-forward executor. *)

open OUnit2
open Core
open Matchers
module Window_spec = Walk_forward.Window_spec
module Wf_types = Walk_forward.Walk_forward_types
module Lib = Bah_baseline_aggregator_lib

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(** Build a synthetic price series for [[start_date .. end_date]] (inclusive)
    where [adjusted_close = base * growth^i]. OHL columns are unused by the
    aggregator; we still populate them with the same value so the record is
    well-formed. *)
let _synthetic_prices ~start_date ~end_date ~base ~growth :
    Types.Daily_price.t list =
  let n_days = Date.diff end_date start_date + 1 in
  List.init n_days ~f:(fun i ->
      let date = Date.add_days start_date i in
      let p = base *. (growth ** Float.of_int i) in
      Types.Daily_price.make ~date ~open_price:p ~high_price:p ~low_price:p
        ~close_price:p ~volume:0 ~adjusted_close:p ())

(* ---------- compute_fold_actual ---------- *)

let test_compute_fold_actual_constant_growth _ =
  let start_date = _date 2020 1 1 in
  let end_date = _date 2020 6 29 in
  let growth = 1.001 in
  let prices = _synthetic_prices ~start_date ~end_date ~base:100.0 ~growth in
  let fold : Window_spec.fold =
    {
      index = 0;
      name = "fold-000";
      train_period = None;
      test_period = { start_date; end_date };
    }
  in
  let actual = Lib.compute_fold_actual ~prices ~variant_label:"cell-E" ~fold in
  let n_days = Date.diff end_date start_date + 1 in
  let expected_total_return =
    ((growth ** Float.of_int (n_days - 1)) -. 1.0) *. 100.0
  in
  assert_that actual
    (all_of
       [
         field
           (fun (a : Wf_types.fold_actual) -> a.fold_name)
           (equal_to "fold-000");
         field
           (fun (a : Wf_types.fold_actual) -> a.variant_label)
           (equal_to "cell-E");
         field
           (fun (a : Wf_types.fold_actual) -> a.total_return_pct)
           (float_equal ~epsilon:1e-6 expected_total_return);
         (* Monotonic growth ⇒ zero drawdown. *)
         field
           (fun (a : Wf_types.fold_actual) -> a.max_drawdown_pct)
           (float_equal ~epsilon:1e-9 0.0);
         (* BAH holds the full fold ⇒ avg_holding_days = fold length. *)
         field
           (fun (a : Wf_types.fold_actual) -> a.avg_holding_days)
           (float_equal (Float.of_int n_days));
       ])

(* ---------- compute_bah_aggregate (2-fold) ---------- *)

let _stability_variant_label_is (s : Wf_types.variant_stability) =
  s.variant_label

let _stability_return_mean (s : Wf_types.variant_stability) =
  s.total_return_pct.mean

let _stability_dd_mean (s : Wf_types.variant_stability) =
  s.max_drawdown_pct.mean

let _stability_holding_mean (s : Wf_types.variant_stability) =
  s.avg_holding_days.mean

let _expected_stability_matcher ~per_fold_total_return =
  all_of
    [
      field _stability_variant_label_is (equal_to "cell-E");
      field _stability_return_mean
        (float_equal ~epsilon:1e-6 per_fold_total_return);
      field _stability_dd_mean (float_equal ~epsilon:1e-9 0.0);
      field _stability_holding_mean (float_equal 180.0);
    ]

let test_compute_bah_aggregate_2fold _ =
  (* Two non-overlapping 180-day folds covering 2020-01-01..2020-06-28 and
     2020-06-29..2020-12-25. The growth series spans both folds; per-fold
     total_returns are identical because growth is constant per day. *)
  let start_date = _date 2020 1 1 in
  let end_date = _date 2020 12 26 in
  let growth = 1.001 in
  let prices = _synthetic_prices ~start_date ~end_date ~base:100.0 ~growth in
  let spec : Window_spec.t =
    Rolling
      { start_date; end_date; train_days = 0; test_days = 180; step_days = 180 }
  in
  let agg = Lib.compute_bah_aggregate ~prices ~spec ~label:"cell-E" in
  let per_fold_total_return =
    ((growth ** Float.of_int (180 - 1)) -. 1.0) *. 100.0
  in
  assert_that agg
    (all_of
       [
         field (fun (a : Wf_types.aggregate) -> a.fold_count) (equal_to 2);
         field
           (fun (a : Wf_types.aggregate) -> a.baseline_label)
           (equal_to "cell-E");
         field
           (fun (a : Wf_types.aggregate) -> a.metric_label)
           (equal_to "Sharpe");
         (* Single variant — sensitivity + verdicts exclude the baseline. *)
         field (fun (a : Wf_types.aggregate) -> a.sensitivity) (size_is 0);
         field (fun (a : Wf_types.aggregate) -> a.verdicts) (size_is 0);
         field
           (fun (a : Wf_types.aggregate) -> a.stability)
           (elements_are [ _expected_stability_matcher ~per_fold_total_return ]);
       ])

(* ---------- sexp round-trip ---------- *)

(** Belt-and-suspenders that the aggregate the lib produces is a fixed point of
    [sexp_of_aggregate |> aggregate_of_sexp]. The bayesian_runner consumes the
    aggregate from disk via [aggregate_of_sexp], so a non-round-trippable shape
    would silently block the v7 sweep. *)
let test_aggregate_roundtrips_through_sexp _ =
  let start_date = _date 2020 1 1 in
  let end_date = _date 2020 6 28 in
  let prices =
    _synthetic_prices ~start_date ~end_date ~base:100.0 ~growth:1.001
  in
  let spec : Window_spec.t =
    Rolling
      { start_date; end_date; train_days = 0; test_days = 90; step_days = 90 }
  in
  let agg = Lib.compute_bah_aggregate ~prices ~spec ~label:"cell-E" in
  let sexp = Wf_types.sexp_of_aggregate agg in
  let agg' = Wf_types.aggregate_of_sexp sexp in
  assert_that agg' (equal_to agg)

let suite =
  "test_bah_baseline_aggregator"
  >::: [
         "test_compute_fold_actual_constant_growth"
         >:: test_compute_fold_actual_constant_growth;
         "test_compute_bah_aggregate_2fold" >:: test_compute_bah_aggregate_2fold;
         "test_aggregate_roundtrips_through_sexp"
         >:: test_aggregate_roundtrips_through_sexp;
       ]

let () = run_test_tt_main suite
