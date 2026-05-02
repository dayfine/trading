(** Unit tests for {!Backtest.Fuzz_distribution} — per-metric distribution stats
    across N variant summaries. Hand-pinned values: median/p25/p75 follow Type-7
    linear interpolation (R [quantile(type=7)]). Sample standard deviation is
    Bessel-corrected (n-1 denominator). *)

open OUnit2
open Core
open Matchers
module Fuzz_distribution = Backtest.Fuzz_distribution
module Metric_types = Trading_simulation_types.Metric_types
module Summary = Backtest.Summary

let _date_2019 = Date.create_exn ~y:2019 ~m:Month.Jan ~d:2
let _date_2019_end = Date.create_exn ~y:2019 ~m:Month.Dec ~d:31

let _make_summary ?(metrics = Metric_types.empty) ?(final = 1_010_000.0) () :
    Summary.t =
  {
    start_date = _date_2019;
    end_date = _date_2019_end;
    universe_size = 100;
    n_steps = 252;
    initial_cash = 1_000_000.0;
    final_portfolio_value = final;
    n_round_trips = 5;
    metrics;
  }

let _summary_with_pnl pnl =
  _make_summary ~metrics:(Metric_types.of_alist_exn [ (TotalPnl, pnl) ]) ()

(* --- compute --- *)

let test_compute_handles_single_metric_across_variants _ =
  (* 5 variants with TotalPnl values [10; 20; 30; 40; 50]. *)
  let summaries =
    List.map [ 10.0; 20.0; 30.0; 40.0; 50.0 ] ~f:(fun pnl ->
        ("v" ^ Float.to_string pnl, _summary_with_pnl pnl))
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=30\xC2\xB120:5" summaries
  in
  let pnl_stats =
    List.find_exn result.metric_stats ~f:(fun s ->
        String.equal s.name "total_pnl")
  in
  (* For [10; 20; 30; 40; 50] sorted:
     - median (q=0.5, n=5): index 0.5*4 = 2 → sorted[2] = 30
     - p25 (q=0.25): index 1.0 → sorted[1] = 20
     - p75 (q=0.75): index 3.0 → sorted[3] = 40
     - min/max = 10/50
     - mean = 30; sum-of-squares = 4*100 + 0 + 0 + 0 + 4*100 = wrong, recompute
       deviations: -20, -10, 0, 10, 20; squared: 400, 100, 0, 100, 400 = 1000
       sample variance = 1000 / 4 = 250; std = sqrt(250) ≈ 15.8113883 *)
  assert_that pnl_stats
    (all_of
       [
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.median)
           (float_equal 30.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.p25)
           (float_equal 20.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.p75)
           (float_equal 40.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.min)
           (float_equal 10.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.max)
           (float_equal 50.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.std)
           (float_equal ~epsilon:1e-6 15.811388300841896);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.values)
           (elements_are
              [
                float_equal 10.0;
                float_equal 20.0;
                float_equal 30.0;
                float_equal 40.0;
                float_equal 50.0;
              ]);
       ])

let test_compute_percentile_linear_interpolation _ =
  (* For [1; 2; 3; 4] (n=4):
     - p25: index 0.25*3 = 0.75 → 1 + 0.75*(2-1) = 1.75
     - median: index 1.5 → 2 + 0.5*(3-2) = 2.5
     - p75: index 2.25 → 3 + 0.25*(4-3) = 3.25 *)
  let summaries =
    List.map [ 1.0; 2.0; 3.0; 4.0 ] ~f:(fun pnl ->
        ("v" ^ Float.to_string pnl, _summary_with_pnl pnl))
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=2.5\xC2\xB11.5:4" summaries
  in
  let pnl_stats =
    List.find_exn result.metric_stats ~f:(fun s ->
        String.equal s.name "total_pnl")
  in
  assert_that pnl_stats
    (all_of
       [
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.p25)
           (float_equal ~epsilon:1e-9 1.75);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.median)
           (float_equal ~epsilon:1e-9 2.5);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.p75)
           (float_equal ~epsilon:1e-9 3.25);
       ])

let test_compute_skips_metric_absent_from_all _ =
  let summaries =
    List.map [ 10.0; 20.0 ] ~f:(fun pnl ->
        ("v" ^ Float.to_string pnl, _summary_with_pnl pnl))
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=15\xC2\xB15:2" summaries
  in
  let has_sharpe =
    List.exists result.metric_stats ~f:(fun s ->
        String.equal s.name "sharpe_ratio")
  in
  assert_that has_sharpe (equal_to false)

let test_compute_handles_metric_present_in_some_variants _ =
  let s1 =
    _make_summary
      ~metrics:
        (Metric_types.of_alist_exn [ (TotalPnl, 100.0); (SharpeRatio, 1.0) ])
      ()
  in
  let s2 = _summary_with_pnl 200.0 in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=150\xC2\xB150:2"
      [ ("v1", s1); ("v2", s2) ]
  in
  let sharpe =
    List.find_exn result.metric_stats ~f:(fun s ->
        String.equal s.name "sharpe_ratio")
  in
  assert_that sharpe
    (all_of
       [
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.values)
           (elements_are [ float_equal 1.0 ]);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.std)
           (float_equal 0.0);
         field
           (fun (s : Fuzz_distribution.metric_stats) -> s.median)
           (float_equal 1.0);
       ])

let test_compute_preserves_variant_label_order _ =
  let summaries =
    [
      ("alpha", _summary_with_pnl 10.0);
      ("beta", _summary_with_pnl 20.0);
      ("gamma", _summary_with_pnl 30.0);
    ]
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=20\xC2\xB110:3" summaries
  in
  assert_that result.variant_labels
    (elements_are [ equal_to "alpha"; equal_to "beta"; equal_to "gamma" ])

(* --- to_sexp --- *)

let test_to_sexp_top_level_fields _ =
  let summaries =
    List.map [ 10.0; 20.0 ] ~f:(fun pnl ->
        ("v" ^ Float.to_string pnl, _summary_with_pnl pnl))
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=15\xC2\xB15:2" summaries
  in
  let dir = Core_unix.mkdtemp "/tmp/fuzz_dist_test_" in
  let path = Filename.concat dir "fuzz_distribution.sexp" in
  Fuzz_distribution.write_sexp ~output_path:path result;
  let loaded = Sexp.load_sexp path in
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
         equal_to "fuzz_spec_raw";
         equal_to "variant_labels";
         equal_to "metric_stats";
       ])

(* --- to_markdown --- *)

let test_to_markdown_includes_header_and_table _ =
  let summaries =
    List.map [ 10.0; 20.0; 30.0 ] ~f:(fun pnl ->
        ("v" ^ Float.to_string pnl, _summary_with_pnl pnl))
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"start_date=2019-05-01\xC2\xB15w:3"
      summaries
  in
  let md = Fuzz_distribution.to_markdown result in
  assert_that
    (String.is_substring md ~substring:"# Fuzz distribution")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"## Per-metric distribution")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"start_date=2019-05-01")
    (equal_to true);
  assert_that (String.is_substring md ~substring:"total_pnl") (equal_to true);
  assert_that
    (String.is_substring md ~substring:"| Metric | Median | p25 | p75 |")
    (equal_to true)

let test_write_markdown_creates_file _ =
  let summaries =
    [ ("v1", _summary_with_pnl 10.0); ("v2", _summary_with_pnl 20.0) ]
  in
  let result =
    Fuzz_distribution.compute ~fuzz_spec_raw:"x=15\xC2\xB15:2" summaries
  in
  let dir = Core_unix.mkdtemp "/tmp/fuzz_dist_md_test_" in
  let path = Filename.concat dir "fuzz_distribution.md" in
  Fuzz_distribution.write_markdown ~output_path:path result;
  let contents = In_channel.read_all path in
  assert_that
    (String.is_substring contents ~substring:"# Fuzz distribution")
    (equal_to true)

let suite =
  "Backtest.Fuzz_distribution"
  >::: [
         "compute: single metric across 5 variants"
         >:: test_compute_handles_single_metric_across_variants;
         "compute: linear-interpolation percentile"
         >:: test_compute_percentile_linear_interpolation;
         "compute: skips metric absent from all variants"
         >:: test_compute_skips_metric_absent_from_all;
         "compute: metric present in some variants only"
         >:: test_compute_handles_metric_present_in_some_variants;
         "compute: preserves variant label order"
         >:: test_compute_preserves_variant_label_order;
         "to_sexp: top-level fields stable" >:: test_to_sexp_top_level_fields;
         "to_markdown: includes header + table"
         >:: test_to_markdown_includes_header_and_table;
         "write_markdown: creates file" >:: test_write_markdown_creates_file;
       ]

let () = run_test_tt_main suite
