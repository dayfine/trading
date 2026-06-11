open Core
open OUnit2
open Matchers
module RT = Rolling_start.Rolling_start_types
module DS = Rolling_start.Dispersion_stats

let make_start ~y ~m ~d ~cagr ~underwater ~maxdd ?(benchmark = Float.nan)
    ?(sharpe = 1.0) ?(time_underwater = 0.0) ?(realized = 0.0) () : RT.per_start
    =
  {
    start_date = Date.create_exn ~y ~m ~d;
    cagr_pct = cagr;
    max_underwater_vs_initial_pct = underwater;
    max_drawdown_pct = maxdd;
    benchmark_cagr_pct = benchmark;
    edge_pct = cagr -. benchmark;
    sharpe;
    time_underwater_pct = time_underwater;
    realized_return_pct = realized;
  }

let sample_starts =
  [
    (* Deliberately out of date order to pin the sort in [build]. *)
    make_start ~y:2012 ~m:Month.Apr ~d:1 ~cagr:30.0 ~underwater:0.0
      ~maxdd:(-20.0) ();
    make_start ~y:2011 ~m:Month.Jan ~d:1 ~cagr:10.0 ~underwater:(-5.0)
      ~maxdd:(-40.0) ();
    make_start ~y:2011 ~m:Month.Jul ~d:1 ~cagr:50.0 ~underwater:0.0
      ~maxdd:(-10.0) ();
  ]

(* Three starts with benchmarks: edges = 30-20=+10, 10-25=-15, 50-20=+30.
   Sorted edges [-15;10;30] -> median 10, min -15. Two of three beat the
   benchmark -> 66.67% beating. *)
let benchmarked_starts =
  [
    make_start ~y:2011 ~m:Month.Jan ~d:1 ~cagr:30.0 ~underwater:0.0
      ~maxdd:(-20.0) ~benchmark:20.0 ();
    make_start ~y:2011 ~m:Month.Jul ~d:1 ~cagr:10.0 ~underwater:(-5.0)
      ~maxdd:(-40.0) ~benchmark:25.0 ();
    make_start ~y:2012 ~m:Month.Apr ~d:1 ~cagr:50.0 ~underwater:0.0
      ~maxdd:(-10.0) ~benchmark:20.0 ();
  ]

let end_date = Date.create_exn ~y:2020 ~m:Month.Dec ~d:31

(* CAGR values across starts: [30;10;50] -> sorted [10;30;50], median=30, min=10,
   max=50. The report must compute these via Dispersion_stats. *)
let test_build_cagr_summary _ =
  let report = RT.build ~end_date sample_starts in
  assert_that report.cagr
    (all_of
       [
         field (fun s -> s.DS.n) (equal_to 3);
         field (fun s -> s.DS.median) (float_equal 30.0);
         field (fun s -> s.DS.min) (float_equal 10.0);
         field (fun s -> s.DS.max) (float_equal 50.0);
       ])

(* Underwater values [0;-5;0] -> sorted [-5;0;0], median=0, min=-5. *)
let test_build_underwater_summary _ =
  let report = RT.build ~end_date sample_starts in
  assert_that report.max_underwater_vs_initial
    (all_of
       [
         field (fun s -> s.DS.median) (float_equal 0.0);
         field (fun s -> s.DS.min) (float_equal (-5.0));
       ])

(* [build] sorts the per-start rows ascending by start_date. *)
let test_build_sorts_starts _ =
  let report = RT.build ~end_date sample_starts in
  assert_that report.starts
    (elements_are
       [
         field
           (fun s -> s.RT.start_date)
           (equal_to (Date.create_exn ~y:2011 ~m:Month.Jan ~d:1));
         field
           (fun s -> s.RT.start_date)
           (equal_to (Date.create_exn ~y:2011 ~m:Month.Jul ~d:1));
         field
           (fun s -> s.RT.start_date)
           (equal_to (Date.create_exn ~y:2012 ~m:Month.Apr ~d:1));
       ])

let test_build_preserves_end_date _ =
  let report = RT.build ~end_date sample_starts in
  assert_that report.end_date (equal_to end_date)

let test_build_empty _ =
  let report = RT.build ~end_date [] in
  assert_that report.cagr (field (fun s -> s.DS.n) (equal_to 0))

(* The markdown renderer surfaces the header, the dispersion table, and a
   per-start detail row. *)
let test_to_markdown_contains_sections _ =
  let md = RT.to_markdown (RT.build ~end_date benchmarked_starts) in
  assert_that md
    (all_of
       [
         contains_substring "Rolling-start dispersion";
         contains_substring "Edge-vs-benchmark robustness";
         contains_substring "Starts beating benchmark";
         contains_substring "Dispersion across starts";
         contains_substring "Per-start detail";
         contains_substring "CAGR %";
         contains_substring "Benchmark CAGR %";
         contains_substring "Edge %";
         contains_substring "Sharpe";
         contains_substring "TimeUnderwater %";
         contains_substring "Realized return %";
         contains_substring "MaxUnderwaterVsInitial %";
         contains_substring "2011-01-01";
         contains_substring "2020-12-31";
       ])

let test_to_markdown_empty _ =
  let md = RT.to_markdown (RT.build ~end_date []) in
  assert_that md
    (all_of
       [
         contains_substring "Rolling-start dispersion";
         contains_substring "No starts";
       ])

(* Edge summary across benchmarked starts: edges [-15;10;30] -> median 10,
   min -15, n=3. *)
let test_build_edge_summary _ =
  let report = RT.build ~end_date benchmarked_starts in
  assert_that report.edge
    (all_of
       [
         field (fun s -> s.DS.n) (equal_to 3);
         field (fun s -> s.DS.median) (float_equal 10.0);
         field (fun s -> s.DS.min) (float_equal (-15.0));
         field (fun s -> s.DS.max) (float_equal 30.0);
       ])

(* Two of three benchmarked starts have positive edge -> 66.67%. *)
let test_pct_beating_benchmark _ =
  let report = RT.build ~end_date benchmarked_starts in
  assert_that
    (RT.pct_beating_benchmark report)
    (is_between (module Float_ord) ~low:66.6 ~high:66.7)

(* Starts without a benchmark (edge = nan) are skipped from the edge summary and
   the beating-percentage denominator, not counted as failures. *)
let test_edge_skips_nan_starts _ =
  (* sample_starts have no benchmark -> all edges nan. *)
  let report = RT.build ~end_date sample_starts in
  assert_that report
    (all_of
       [
         field (fun r -> r.RT.edge.DS.n) (equal_to 0);
         field
           (fun r -> Float.is_nan (RT.pct_beating_benchmark r))
           (equal_to true);
       ])

(* Round-trip the report through sexp to pin the derived serializer. Uses the
   benchmarked starts so every float is finite — [@@deriving equal] compares
   floats with [Float.equal], under which [nan <> nan], so a report carrying nan
   edges (unbenchmarked starts) would never compare equal to itself. The
   serializer is still exercised on the full field set. *)
let test_sexp_roundtrip _ =
  let report = RT.build ~end_date benchmarked_starts in
  let back = RT.report_of_sexp (RT.sexp_of_report report) in
  assert_that back (equal_to ~cmp:RT.equal_report report)

let suite =
  "rolling_start_types"
  >::: [
         "build_cagr_summary" >:: test_build_cagr_summary;
         "build_underwater_summary" >:: test_build_underwater_summary;
         "build_sorts_starts" >:: test_build_sorts_starts;
         "build_preserves_end_date" >:: test_build_preserves_end_date;
         "build_empty" >:: test_build_empty;
         "build_edge_summary" >:: test_build_edge_summary;
         "pct_beating_benchmark" >:: test_pct_beating_benchmark;
         "edge_skips_nan_starts" >:: test_edge_skips_nan_starts;
         "to_markdown_contains_sections" >:: test_to_markdown_contains_sections;
         "to_markdown_empty" >:: test_to_markdown_empty;
         "sexp_roundtrip" >:: test_sexp_roundtrip;
       ]

let () = run_test_tt_main suite
