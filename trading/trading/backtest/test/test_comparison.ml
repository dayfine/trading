(** Unit tests for {!Backtest.Comparison} — per-metric delta computation and
    sexp/markdown rendering. The compute path is pure (Summary → Summary →
    Comparison.t); the render paths are pinned by string-equality on small
    fixtures. *)

open OUnit2
open Core
open Matchers
module Comparison = Backtest.Comparison
module Metric_types = Trading_simulation_types.Metric_types
module Summary = Backtest.Summary

let _date_2019 = Date.create_exn ~y:2019 ~m:Month.Jan ~d:2
let _date_2019_end = Date.create_exn ~y:2019 ~m:Month.Dec ~d:31

let _make_summary ?(metrics = Metric_types.empty) ?(final = 1_010_000.0)
    ?(n_round_trips = 5) () : Summary.t =
  {
    start_date = _date_2019;
    end_date = _date_2019_end;
    universe_size = 100;
    n_steps = 252;
    initial_cash = 1_000_000.0;
    final_portfolio_value = final;
    n_round_trips;
    metrics;
  }

let _metrics_of_alist alist = Metric_types.of_alist_exn alist

(* --- compute --- *)

let test_compute_delta_for_present_metric _ =
  let baseline =
    _make_summary
      ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0); (SharpeRatio, 0.50) ])
      ()
  in
  let variant =
    _make_summary
      ~metrics:(_metrics_of_alist [ (TotalPnl, 250.0); (SharpeRatio, 0.75) ])
      ~final:1_025_000.0 ()
  in
  let result = Comparison.compute ~baseline ~variant in
  let pnl_diff =
    List.find_exn result.metric_diffs ~f:(fun d ->
        String.equal d.name "total_pnl")
  in
  assert_that pnl_diff
    (all_of
       [
         field
           (fun (d : Comparison.metric_diff) -> d.baseline)
           (equal_to (Some 100.0));
         field
           (fun (d : Comparison.metric_diff) -> d.variant)
           (equal_to (Some 250.0));
         field
           (fun (d : Comparison.metric_diff) -> d.delta)
           (equal_to (Some 150.0));
       ])

let test_compute_metric_present_only_in_baseline _ =
  let baseline =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0) ]) ()
  in
  let variant = _make_summary ~metrics:Metric_types.empty () in
  let result = Comparison.compute ~baseline ~variant in
  let pnl_diff =
    List.find_exn result.metric_diffs ~f:(fun d ->
        String.equal d.name "total_pnl")
  in
  assert_that pnl_diff
    (all_of
       [
         field
           (fun (d : Comparison.metric_diff) -> d.baseline)
           (equal_to (Some 100.0));
         field (fun (d : Comparison.metric_diff) -> d.variant) (equal_to None);
         field (fun (d : Comparison.metric_diff) -> d.delta) (equal_to None);
       ])

let test_compute_metric_present_only_in_variant _ =
  let baseline = _make_summary ~metrics:Metric_types.empty () in
  let variant =
    _make_summary ~metrics:(_metrics_of_alist [ (SharpeRatio, 1.20) ]) ()
  in
  let result = Comparison.compute ~baseline ~variant in
  let sr_diff =
    List.find_exn result.metric_diffs ~f:(fun d ->
        String.equal d.name "sharpe_ratio")
  in
  assert_that sr_diff
    (all_of
       [
         field (fun (d : Comparison.metric_diff) -> d.baseline) (equal_to None);
         field
           (fun (d : Comparison.metric_diff) -> d.variant)
           (equal_to (Some 1.20));
         field (fun (d : Comparison.metric_diff) -> d.delta) (equal_to None);
       ])

let test_compute_skips_metric_absent_from_both _ =
  let baseline =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0) ]) ()
  in
  let variant =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 250.0) ]) ()
  in
  let result = Comparison.compute ~baseline ~variant in
  (* SharpeRatio is in neither summary; compute must skip it (no row of
     ((baseline -) (variant -) (delta -)) noise). *)
  let has_sharpe =
    List.exists result.metric_diffs ~f:(fun d ->
        String.equal d.name "sharpe_ratio")
  in
  assert_that has_sharpe (equal_to false)

let test_compute_scalar_diffs _ =
  let baseline = _make_summary ~final:1_000_000.0 ~n_round_trips:5 () in
  let variant = _make_summary ~final:1_120_000.0 ~n_round_trips:8 () in
  let result = Comparison.compute ~baseline ~variant in
  let final_delta =
    List.Assoc.find_exn result.scalar_diffs ~equal:String.equal
      "final_portfolio_value"
  in
  let n_round_trips_delta =
    List.Assoc.find_exn result.scalar_diffs ~equal:String.equal "n_round_trips"
  in
  assert_that final_delta (float_equal 120_000.0);
  assert_that n_round_trips_delta (float_equal 3.0)

(* --- to_sexp --- *)

let test_to_sexp_round_trips_via_save_load _ =
  let baseline =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0) ]) ()
  in
  let variant =
    _make_summary
      ~metrics:(_metrics_of_alist [ (TotalPnl, 250.0) ])
      ~final:1_025_000.0 ()
  in
  let result = Comparison.compute ~baseline ~variant in
  let dir = Core_unix.mkdtemp "/tmp/comparison_test_" in
  let path = Filename.concat dir "comparison.sexp" in
  Comparison.write_sexp ~output_path:path result;
  let loaded = Sexp.load_sexp path in
  (* Sexp must be a list with at least the four expected top-level fields.
     We don't assert structural equality of Summary sub-sexps to avoid
     coupling the test to summary's internal field set. *)
  let top_field_names =
    match loaded with
    | Sexp.List fields ->
        List.filter_map fields ~f:(function
          | Sexp.List [ Sexp.Atom n; _ ] -> Some n
          | _ -> None)
    | Sexp.Atom _ -> []
  in
  assert_that top_field_names
    (elements_are
       [
         equal_to "baseline_summary";
         equal_to "variant_summary";
         equal_to "metric_diffs";
         equal_to "scalar_diffs";
       ])

(* --- to_markdown --- *)

let test_to_markdown_includes_header_and_table _ =
  let baseline =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0) ]) ()
  in
  let variant =
    _make_summary
      ~metrics:(_metrics_of_alist [ (TotalPnl, 250.0) ])
      ~final:1_025_000.0 ()
  in
  let result = Comparison.compute ~baseline ~variant in
  let md = Comparison.to_markdown result in
  (* Spot-check structural elements. We don't pin the entire string because
     small label / decimal-format changes would break it across refactors. *)
  assert_that
    (String.is_substring md ~substring:"# Backtest comparison")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"## Metric diffs")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"## Scalar diffs")
    (equal_to true);
  assert_that (String.is_substring md ~substring:"total_pnl") (equal_to true);
  assert_that
    (String.is_substring md ~substring:"final_portfolio_value")
    (equal_to true)

let test_write_markdown_creates_file _ =
  let baseline =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 100.0) ]) ()
  in
  let variant =
    _make_summary ~metrics:(_metrics_of_alist [ (TotalPnl, 250.0) ]) ()
  in
  let result = Comparison.compute ~baseline ~variant in
  let dir = Core_unix.mkdtemp "/tmp/comparison_md_test_" in
  let path = Filename.concat dir "comparison.md" in
  Comparison.write_markdown ~output_path:path result;
  let contents = In_channel.read_all path in
  assert_that
    (String.is_substring contents ~substring:"# Backtest comparison")
    (equal_to true)

let suite =
  "Backtest.Comparison"
  >::: [
         "compute: delta for metric present in both"
         >:: test_compute_delta_for_present_metric;
         "compute: metric only in baseline yields delta = None"
         >:: test_compute_metric_present_only_in_baseline;
         "compute: metric only in variant yields delta = None"
         >:: test_compute_metric_present_only_in_variant;
         "compute: metric absent from both is skipped"
         >:: test_compute_skips_metric_absent_from_both;
         "compute: scalar diffs (final value, round trips)"
         >:: test_compute_scalar_diffs;
         "to_sexp: writes top-level fields in stable order"
         >:: test_to_sexp_round_trips_via_save_load;
         "to_markdown: includes header + tables"
         >:: test_to_markdown_includes_header_and_table;
         "write_markdown: creates file" >:: test_write_markdown_creates_file;
       ]

let () = run_test_tt_main suite
