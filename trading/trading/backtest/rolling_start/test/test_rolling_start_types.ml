open Core
open OUnit2
open Matchers
module RT = Rolling_start.Rolling_start_types
module DS = Rolling_start.Dispersion_stats

let make_start ~y ~m ~d ~cagr ~underwater ~maxdd ?(benchmark = Float.nan)
    ?(realized_edge = Float.nan) ?(forward_index_max_dd = Float.nan)
    ?(sharpe = 1.0) ?(time_underwater = 0.0) ?(realized = 0.0)
    ?(factors = Rolling_start.Rolling_start_factors.empty) () : RT.per_start =
  {
    start_date = Date.create_exn ~y ~m ~d;
    cagr_pct = cagr;
    max_underwater_vs_initial_pct = underwater;
    max_drawdown_pct = maxdd;
    benchmark_cagr_pct = benchmark;
    edge_pct = cagr -. benchmark;
    realized_edge_pct = realized_edge;
    forward_index_max_dd_pct = forward_index_max_dd;
    sharpe;
    time_underwater_pct = time_underwater;
    realized_return_pct = realized;
    factors;
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
      ~maxdd:(-20.0) ~benchmark:20.0 ~realized_edge:5.0
      ~forward_index_max_dd:(-15.0) ();
    make_start ~y:2011 ~m:Month.Jul ~d:1 ~cagr:10.0 ~underwater:(-5.0)
      ~maxdd:(-40.0) ~benchmark:25.0 ~realized_edge:(-20.0)
      ~forward_index_max_dd:(-30.0) ();
    make_start ~y:2012 ~m:Month.Apr ~d:1 ~cagr:50.0 ~underwater:0.0
      ~maxdd:(-10.0) ~benchmark:20.0 ~realized_edge:25.0
      ~forward_index_max_dd:(-8.0) ();
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
         contains_substring "Realized edge %";
         contains_substring "Forward index max-DD %";
         contains_substring "Realized edge vs benchmark %";
         contains_substring "Median realized edge vs benchmark";
         contains_substring "Sharpe";
         contains_substring "TimeUnderwater %";
         contains_substring "Realized return %";
         contains_substring "MaxUnderwaterVsInitial %";
         (* Factor-decomposition lens 5b columns are a strict superset: the
            pre-existing outcome columns above still render, and the four factor
            headers are appended. *)
         contains_substring "SPY stage";
         contains_substring "Macro composite";
         contains_substring "Stage-2 count";
         contains_substring "Sector-RS dispersion";
         contains_substring "2011-01-01";
         contains_substring "2020-12-31";
       ])

(* A row whose factors are populated renders the decoded values: SPY stage 2 as
   the bare integer "2", the Stage-2 candidate count "42", and the macro
   composite / sector-RS dispersion as two-decimal floats. Pins that the
   per-start detail table carries the factor cells, not just the headers. *)
let test_to_markdown_renders_factor_values _ =
  let factors =
    {
      Rolling_start.Rolling_start_factors.spy_stage_at_start = Some 2;
      macro_composite_at_start = 0.75;
      stage2_candidate_count = Some 42;
      sector_rs_dispersion_at_start = 1.25;
    }
  in
  let md =
    RT.to_markdown
      (RT.build ~end_date
         [
           make_start ~y:2015 ~m:Month.Jun ~d:1 ~cagr:12.0 ~underwater:0.0
             ~maxdd:(-10.0) ~factors ();
         ])
  in
  assert_that md
    (all_of
       [
         contains_substring "| 2 | 0.75 | 42 | 1.25 |";
         contains_substring "2015-06-01";
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

(* Realized-edge summary across benchmarked starts: realized edges [5;-20;25] ->
   sorted [-20;5;25] -> median 5, min -20, max 25, n=3. Skips nan rows like
   [edge]. *)
let test_build_realized_edge_summary _ =
  let report = RT.build ~end_date benchmarked_starts in
  assert_that report.realized_edge
    (all_of
       [
         field (fun s -> s.DS.n) (equal_to 3);
         field (fun s -> s.DS.median) (float_equal 5.0);
         field (fun s -> s.DS.min) (float_equal (-20.0));
         field (fun s -> s.DS.max) (float_equal 25.0);
       ])

(* Forward-index max-DD summary: forward DDs [-15;-30;-8] -> sorted [-30;-15;-8]
   -> median -15, min -30, max -8, n=3. *)
let test_build_forward_index_max_dd_summary _ =
  let report = RT.build ~end_date benchmarked_starts in
  assert_that report.forward_index_max_dd
    (all_of
       [
         field (fun s -> s.DS.n) (equal_to 3);
         field (fun s -> s.DS.median) (float_equal (-15.0));
         field (fun s -> s.DS.min) (float_equal (-30.0));
         field (fun s -> s.DS.max) (float_equal (-8.0));
       ])

(* sample_starts have no benchmark -> realized_edge / forward DD are nan and the
   summaries skip them entirely (n=0), like the edge summary. *)
let test_realized_edge_and_forward_dd_skip_nan_starts _ =
  let report = RT.build ~end_date sample_starts in
  assert_that report
    (all_of
       [
         field (fun r -> r.RT.realized_edge.DS.n) (equal_to 0);
         field (fun r -> r.RT.forward_index_max_dd.DS.n) (equal_to 0);
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

(* --- A1: min-window guard --- *)

(* Three benchmarked starts plus one short-window start. With end_date
   2020-12-31, the short start 2020-12-01 spans 31 inclusive days; the other
   three span years. Its CAGR/edge are absurd (1000) so if it leaked into the
   summary the median/min would move. *)
let starts_with_short =
  benchmarked_starts
  @ [
      make_start ~y:2020 ~m:Month.Dec ~d:1 ~cagr:1000.0 ~underwater:0.0
        ~maxdd:(-1.0) ~benchmark:5.0 ();
    ]

(* Default (min_window_days = 0) counts every start — including the short one —
   so the summaries match the no-guard behaviour over all four starts. *)
let test_min_window_default_counts_all _ =
  let report = RT.build ~end_date starts_with_short in
  assert_that report
    (all_of
       [
         field (fun r -> r.RT.min_window_days) (equal_to 0);
         field (fun r -> r.RT.cagr.DS.n) (equal_to 4);
         field (fun r -> r.RT.edge.DS.n) (equal_to 4);
         (* short start's 1000 CAGR is the max when not excluded *)
         field (fun r -> r.RT.cagr.DS.max) (float_equal 1000.0);
       ])

(* With a 60-day guard the 31-day short start is excluded from every summary,
   leaving the three long benchmarked starts — identical to the un-guarded
   [benchmarked_starts] report (edges [-15;10;30], cagr max 50). The short row
   is still retained in [starts] for the detail table (4 rows). *)
let test_min_window_excludes_short_from_summary _ =
  let report = RT.build ~min_window_days:60 ~end_date starts_with_short in
  assert_that report
    (all_of
       [
         field (fun r -> r.RT.min_window_days) (equal_to 60);
         field (fun r -> List.length r.RT.starts) (equal_to 4);
         field (fun r -> r.RT.cagr.DS.n) (equal_to 3);
         field (fun r -> r.RT.cagr.DS.max) (float_equal 50.0);
         field (fun r -> r.RT.edge.DS.n) (equal_to 3);
         field (fun r -> r.RT.edge.DS.median) (float_equal 10.0);
         field (fun r -> r.RT.edge.DS.min) (float_equal (-15.0));
       ])

(* pct_beating_benchmark over the eligible subset: the short start beats its
   benchmark (1000 > 5) but is excluded, so the headline is computed over the
   three long starts only — 2 of 3 beat -> 66.67%, not 3 of 4 = 75%. *)
let test_min_window_pct_beating_excludes_short _ =
  let report = RT.build ~min_window_days:60 ~end_date starts_with_short in
  assert_that
    (RT.pct_beating_benchmark report)
    (is_between (module Float_ord) ~low:66.6 ~high:66.7)

(* Boundary: a start whose inclusive window is EXACTLY the threshold is included
   (the predicate is strictly-less-than). 2020-12-01 .. 2020-12-31 = 31 days, so
   min_window_days=31 keeps it (n=4) and min_window_days=32 drops it (n=3). *)
let test_min_window_boundary_inclusive _ =
  let at_31 = RT.build ~min_window_days:31 ~end_date starts_with_short in
  let at_32 = RT.build ~min_window_days:32 ~end_date starts_with_short in
  assert_that (at_31.RT.cagr.DS.n, at_32.RT.cagr.DS.n) (equal_to (4, 3))

(* is_short_window reproduces the exclusion predicate; <=0 threshold excludes
   nothing. *)
let test_is_short_window_predicate _ =
  let short =
    make_start ~y:2020 ~m:Month.Dec ~d:1 ~cagr:1000.0 ~underwater:0.0
      ~maxdd:(-1.0) ()
  in
  let long =
    make_start ~y:2011 ~m:Month.Jan ~d:1 ~cagr:10.0 ~underwater:0.0
      ~maxdd:(-1.0) ()
  in
  assert_that
    ( RT.is_short_window ~min_window_days:60 ~end_date short,
      RT.is_short_window ~min_window_days:60 ~end_date long,
      RT.is_short_window ~min_window_days:0 ~end_date short )
    (equal_to (true, false, false))

(* A negative threshold is rejected. *)
let test_min_window_negative_raises _ =
  assert_raises
    (Invalid_argument "build: min_window_days must be non-negative, got -1")
    (fun () -> RT.build ~min_window_days:(-1) ~end_date sample_starts)

(* The detail table flags the excluded short-window row but the summary table is
   computed over the eligible subset. *)
let test_min_window_markdown_flags_excluded _ =
  let md =
    RT.to_markdown (RT.build ~min_window_days:60 ~end_date starts_with_short)
  in
  assert_that md (contains_substring "short window, excluded")

(* Round-trip the report through sexp to pin the derived serializer. Uses the
   benchmarked starts so every float is finite — [@@deriving equal] compares
   floats with [Float.equal], under which [nan <> nan], so a report carrying nan
   edges (unbenchmarked starts) would never compare equal to itself. The
   serializer is still exercised on the full field set. *)
(* Fully-populated (no-nan) factors so the report's float fields are all
   defined — [equal_report] uses [Float.equal], and [Float.equal nan nan] is
   [false], which would spuriously break the roundtrip on the default
   nan-bearing {!Rolling_start_factors.empty}. *)
let populated_factors =
  {
    Rolling_start.Rolling_start_factors.spy_stage_at_start = Some 3;
    macro_composite_at_start = 0.5;
    stage2_candidate_count = Some 17;
    sector_rs_dispersion_at_start = 2.0;
  }

let test_sexp_roundtrip _ =
  let starts =
    List.map benchmarked_starts ~f:(fun s ->
        { s with RT.factors = populated_factors })
  in
  let report = RT.build ~end_date starts in
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
         "build_realized_edge_summary" >:: test_build_realized_edge_summary;
         "build_forward_index_max_dd_summary"
         >:: test_build_forward_index_max_dd_summary;
         "realized_edge_and_forward_dd_skip_nan_starts"
         >:: test_realized_edge_and_forward_dd_skip_nan_starts;
         "pct_beating_benchmark" >:: test_pct_beating_benchmark;
         "edge_skips_nan_starts" >:: test_edge_skips_nan_starts;
         "to_markdown_contains_sections" >:: test_to_markdown_contains_sections;
         "to_markdown_renders_factor_values"
         >:: test_to_markdown_renders_factor_values;
         "to_markdown_empty" >:: test_to_markdown_empty;
         "min_window_default_counts_all" >:: test_min_window_default_counts_all;
         "min_window_excludes_short_from_summary"
         >:: test_min_window_excludes_short_from_summary;
         "min_window_pct_beating_excludes_short"
         >:: test_min_window_pct_beating_excludes_short;
         "min_window_boundary_inclusive" >:: test_min_window_boundary_inclusive;
         "is_short_window_predicate" >:: test_is_short_window_predicate;
         "min_window_negative_raises" >:: test_min_window_negative_raises;
         "min_window_markdown_flags_excluded"
         >:: test_min_window_markdown_flags_excluded;
         "sexp_roundtrip" >:: test_sexp_roundtrip;
       ]

let () = run_test_tt_main suite
