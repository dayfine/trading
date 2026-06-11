open Core
open OUnit2
open Matchers
module Runner = Rolling_start.Rolling_start_runner
module RT = Rolling_start.Rolling_start_types
module Metric_types = Trading_simulation_types.Metric_types

let date ~y ~m ~d = Date.create_exn ~y ~m ~d

module Date_ord = struct
  type t = Date.t

  let compare = Date.compare
  let show = Date.to_string
end

(* ----- enumerate_starts ----- *)

(* A 1-year span at quarterly stride from Jan 1: starts at Jan 1, Apr 1, Jul 1,
   Oct 1 — every start strictly before the Dec 31 end. Day deltas from Jan 1 are
   0/91/182/273; +364 = Dec 31 would be the end itself (excluded since a start
   == end is a zero-length window). *)
let test_enumerate_quarterly _ =
  let starts =
    Runner.enumerate_starts
      ~scenario_start:(date ~y:2011 ~m:Month.Jan ~d:1)
      ~end_date:(date ~y:2011 ~m:Month.Dec ~d:31)
      ~stride_days:91
  in
  assert_that starts
    (elements_are
       [
         equal_to (date ~y:2011 ~m:Month.Jan ~d:1);
         equal_to (date ~y:2011 ~m:Month.Apr ~d:2);
         equal_to (date ~y:2011 ~m:Month.Jul ~d:2);
         equal_to (date ~y:2011 ~m:Month.Oct ~d:1);
       ])

(* The first start always equals scenario_start when scenario_start < end_date,
   and the last enumerated start is strictly before end_date. *)
let test_enumerate_first_and_last _ =
  let scenario_start = date ~y:2015 ~m:Month.Mar ~d:10 in
  let end_date = date ~y:2018 ~m:Month.Mar ~d:10 in
  let starts =
    Runner.enumerate_starts ~scenario_start ~end_date ~stride_days:91
  in
  assert_that starts
    (all_of
       [
         field List.hd_exn (equal_to scenario_start);
         field List.last_exn (lt (module Date_ord) end_date);
       ])

(* scenario_start == end_date yields an empty list (zero-length window). *)
let test_enumerate_empty_when_start_eq_end _ =
  let d = date ~y:2020 ~m:Month.Jan ~d:1 in
  assert_that
    (Runner.enumerate_starts ~scenario_start:d ~end_date:d ~stride_days:91)
    (size_is 0)

(* scenario_start after end_date yields an empty list. *)
let test_enumerate_empty_when_start_after_end _ =
  assert_that
    (Runner.enumerate_starts
       ~scenario_start:(date ~y:2021 ~m:Month.Jan ~d:1)
       ~end_date:(date ~y:2020 ~m:Month.Jan ~d:1)
       ~stride_days:91)
    (size_is 0)

(* A non-positive stride is rejected. *)
let test_enumerate_rejects_nonpositive_stride _ =
  assert_raises
    (Invalid_argument "enumerate_starts: stride_days must be positive, got 0")
    (fun () ->
      Runner.enumerate_starts
        ~scenario_start:(date ~y:2011 ~m:Month.Jan ~d:1)
        ~end_date:(date ~y:2012 ~m:Month.Jan ~d:1)
        ~stride_days:0)

(* ----- enumerate_starts_jittered ----- *)

let jittered_start = date ~y:2011 ~m:Month.Jan ~d:1
let jittered_end = date ~y:2012 ~m:Month.Jan ~d:1

let jittered ~jitter_seed =
  Runner.enumerate_starts_jittered ~scenario_start:jittered_start
    ~end_date:jittered_end ~stride_days:91 ~jitter_seed

(* Pinned exact dates for seed 42: the base grid is Jan-1 / Apr-2 / Jul-2 /
   Oct-1; the first point is unjittered, every later point is shifted forward by
   a deterministic uniform offset in [0, 91). The offsets for seed 42 land at
   77 / 38 / 0 days -> Jun-18 / Aug-9 / Oct-1, all strictly before the Jan-1
   end. This is the determinism contract: same (inputs, seed) -> same dates. *)
let test_jitter_pins_exact_dates_for_seed _ =
  assert_that (jittered ~jitter_seed:42)
    (elements_are
       [
         equal_to (date ~y:2011 ~m:Month.Jan ~d:1);
         equal_to (date ~y:2011 ~m:Month.Jun ~d:18);
         equal_to (date ~y:2011 ~m:Month.Aug ~d:9);
         equal_to (date ~y:2011 ~m:Month.Oct ~d:1);
       ])

(* Same seed -> identical output (pure function of inputs + seed). *)
let test_jitter_deterministic _ =
  assert_that (jittered ~jitter_seed:7)
    (elements_are (List.map (jittered ~jitter_seed:7) ~f:equal_to))

(* The first start is pinned to scenario_start (no jitter on k=0), every start
   is strictly before end_date, and the sequence is strictly ascending. *)
let test_jitter_first_pinned_and_in_range _ =
  let starts = jittered ~jitter_seed:99 in
  let ascending = List.is_sorted_strictly starts ~compare:Date.compare in
  assert_that starts
    (all_of
       [
         field List.hd_exn (equal_to jittered_start);
         field
           (fun s -> List.for_all s ~f:(fun d -> Date.( < ) d jittered_end))
           (equal_to true);
         field (fun _ -> ascending) (equal_to true);
       ])

(* Each non-first jittered start sits within [base, base + stride) of its base
   grid point — the jitter only shifts forward, never past the next stride. *)
let test_jitter_within_stride_of_base _ =
  let base =
    Runner.enumerate_starts ~scenario_start:jittered_start
      ~end_date:jittered_end ~stride_days:91
  in
  let jit = jittered ~jitter_seed:123 in
  (* jit may be shorter than base (a late jittered point can cross end_date), so
     compare against the matching base prefix: each jittered point is in
     [b, b + 91). *)
  let base_prefix = List.take base (List.length jit) in
  let within =
    List.for_all2_exn base_prefix jit ~f:(fun b j ->
        Date.( <= ) b j && Date.diff j b < 91)
  in
  assert_that within (equal_to true)

(* A non-positive stride is rejected (delegates to enumerate_starts). *)
let test_jitter_rejects_nonpositive_stride _ =
  assert_raises
    (Invalid_argument "enumerate_starts: stride_days must be positive, got 0")
    (fun () ->
      Runner.enumerate_starts_jittered ~scenario_start:jittered_start
        ~end_date:jittered_end ~stride_days:0 ~jitter_seed:1)

(* ----- bah_cagr_pct ----- *)

(* A benchmark that doubled over ~1 inclusive year: entry close at/after start =
   100, exit close at/before end = 200 -> +100% total return, ~100% CAGR. The
   intermediate bar and the bars outside [start, end] are ignored. *)
let test_bah_cagr_full_year _ =
  let cagr =
    Runner.bah_cagr_pct
      ~start_date:(date ~y:2011 ~m:Month.Jan ~d:1)
      ~end_date:(date ~y:2011 ~m:Month.Dec ~d:31)
      ~close_series:
        [
          (date ~y:2010 ~m:Month.Dec ~d:31, 99.0);
          (* before window: ignored *)
          (date ~y:2011 ~m:Month.Jan ~d:3, 100.0);
          (* entry *)
          (date ~y:2011 ~m:Month.Jul ~d:1, 150.0);
          (date ~y:2011 ~m:Month.Dec ~d:30, 200.0);
          (* exit *)
          (date ~y:2012 ~m:Month.Jan ~d:2, 250.0);
          (* after window: ignored *)
        ]
  in
  assert_that cagr (is_between (module Float_ord) ~low:99.0 ~high:101.0)

(* An empty series, or one with a single usable bar in the window, cannot be
   priced -> NaN (the caller renders a blank cell). *)
let test_bah_cagr_nan_when_unpriceable _ =
  let nan_empty =
    Runner.bah_cagr_pct
      ~start_date:(date ~y:2011 ~m:Month.Jan ~d:1)
      ~end_date:(date ~y:2011 ~m:Month.Dec ~d:31)
      ~close_series:[]
  in
  let nan_single =
    Runner.bah_cagr_pct
      ~start_date:(date ~y:2011 ~m:Month.Jan ~d:1)
      ~end_date:(date ~y:2011 ~m:Month.Dec ~d:31)
      ~close_series:[ (date ~y:2011 ~m:Month.Jun ~d:1, 100.0) ]
  in
  assert_that
    (Float.is_nan nan_empty && Float.is_nan nan_single)
    (equal_to true)

(* ----- per_start_of_summary ----- *)

let make_summary ~start_date ~end_date ~initial_cash ~final_value ~metrics :
    Backtest.Summary.t =
  {
    start_date;
    end_date;
    universe_size = 1;
    n_steps = 1;
    initial_cash;
    final_portfolio_value = final_value;
    n_round_trips = 0;
    stale_held_symbols = [];
    metrics = Metric_types.of_alist_exn metrics;
  }

(* A run that exactly doubled over one year (365 inclusive days = ~0.997y) has a
   total return of 100%, so CAGR ~= 100%; the underwater / maxdd metrics are read
   straight from the metric set. *)
let test_per_start_extracts_metrics _ =
  let start_date = date ~y:2011 ~m:Month.Jan ~d:1 in
  let end_date = date ~y:2011 ~m:Month.Dec ~d:31 in
  let summary =
    make_summary ~start_date ~end_date ~initial_cash:1_000_000.0
      ~final_value:2_000_000.0
      ~metrics:
        [
          (Metric_types.MaxUnderwaterVsInitialPct, -12.5);
          (Metric_types.MaxDrawdown, -42.0);
        ]
  in
  let per_start = Runner.per_start_of_summary ~start_date ~end_date summary in
  assert_that per_start
    (all_of
       [
         field (fun (p : RT.per_start) -> p.start_date) (equal_to start_date);
         field
           (fun (p : RT.per_start) -> p.max_underwater_vs_initial_pct)
           (float_equal (-12.5));
         field
           (fun (p : RT.per_start) -> p.max_drawdown_pct)
           (float_equal (-42.0));
         (* 100% total return over ~1y annualises to ~100% CAGR. *)
         field
           (fun (p : RT.per_start) -> p.cagr_pct)
           (is_between (module Float_ord) ~low:99.0 ~high:101.0);
       ])

(* Missing metrics surface as NaN rather than a crash — the caller decides how to
   render "no data" (mirrors the Dispersion_stats empty-list contract). *)
let test_per_start_missing_metrics_are_nan _ =
  let start_date = date ~y:2011 ~m:Month.Jan ~d:1 in
  let end_date = date ~y:2012 ~m:Month.Jan ~d:1 in
  let summary =
    make_summary ~start_date ~end_date ~initial_cash:1_000_000.0
      ~final_value:1_000_000.0 ~metrics:[]
  in
  let per_start = Runner.per_start_of_summary ~start_date ~end_date summary in
  assert_that per_start
    (all_of
       [
         field
           (fun (p : RT.per_start) ->
             Float.is_nan p.max_underwater_vs_initial_pct)
           (equal_to true);
         field
           (fun (p : RT.per_start) -> Float.is_nan p.max_drawdown_pct)
           (equal_to true);
         (* Zero total return -> 0% CAGR (well-defined, not NaN). *)
         field (fun (p : RT.per_start) -> p.cagr_pct) (float_equal 0.0);
         (* No benchmark supplied -> benchmark/edge are NaN. *)
         field
           (fun (p : RT.per_start) -> Float.is_nan p.benchmark_cagr_pct)
           (equal_to true);
         field
           (fun (p : RT.per_start) -> Float.is_nan p.edge_pct)
           (equal_to true);
       ])

(* When a benchmark CAGR is supplied, edge = strategy CAGR - benchmark CAGR. *)
let test_per_start_edge_from_benchmark _ =
  let start_date = date ~y:2011 ~m:Month.Jan ~d:1 in
  let end_date = date ~y:2011 ~m:Month.Dec ~d:31 in
  let summary =
    make_summary ~start_date ~end_date ~initial_cash:1_000_000.0
      ~final_value:2_000_000.0 ~metrics:[]
  in
  (* ~100% strategy CAGR; benchmark fixed at 14.0 -> edge ~= 86. *)
  let per_start =
    Runner.per_start_of_summary ~benchmark_cagr_pct:14.0 ~start_date ~end_date
      summary
  in
  assert_that per_start
    (all_of
       [
         field
           (fun (p : RT.per_start) -> p.benchmark_cagr_pct)
           (float_equal 14.0);
         field
           (fun (p : RT.per_start) -> p.edge_pct)
           (is_between (module Float_ord) ~low:85.0 ~high:87.0);
       ])

(* Sharpe is read from the metric set; realized return strips UnrealizedPnl from
   the terminal value; time-underwater comes from the supplied equity curve.
   final=2.0M, unrealized=0.5M, initial=1.0M -> realized = (2.0 - 0.5 - 1.0)/1.0
   = 50%. Equity curve [100;90;110] -> one point (90) below the prior high
   (100), then a new high -> 1/3 underwater ~= 33.33%. *)
let test_per_start_realized_sharpe_and_underwater _ =
  let start_date = date ~y:2011 ~m:Month.Jan ~d:1 in
  let end_date = date ~y:2011 ~m:Month.Dec ~d:31 in
  let summary =
    make_summary ~start_date ~end_date ~initial_cash:1_000_000.0
      ~final_value:2_000_000.0
      ~metrics:
        [
          (Metric_types.SharpeRatio, 0.85);
          (Metric_types.UnrealizedPnl, 500_000.0);
        ]
  in
  let per_start =
    Runner.per_start_of_summary ~equity_curve:[ 100.0; 90.0; 110.0 ] ~start_date
      ~end_date summary
  in
  assert_that per_start
    (all_of
       [
         field (fun (p : RT.per_start) -> p.sharpe) (float_equal 0.85);
         field
           (fun (p : RT.per_start) -> p.realized_return_pct)
           (float_equal 50.0);
         field
           (fun (p : RT.per_start) -> p.time_underwater_pct)
           (is_between (module Float_ord) ~low:33.0 ~high:33.4);
       ])

let suite =
  "rolling_start_runner"
  >::: [
         "enumerate_quarterly" >:: test_enumerate_quarterly;
         "enumerate_first_and_last" >:: test_enumerate_first_and_last;
         "enumerate_empty_when_start_eq_end"
         >:: test_enumerate_empty_when_start_eq_end;
         "enumerate_empty_when_start_after_end"
         >:: test_enumerate_empty_when_start_after_end;
         "enumerate_rejects_nonpositive_stride"
         >:: test_enumerate_rejects_nonpositive_stride;
         "jitter_pins_exact_dates_for_seed"
         >:: test_jitter_pins_exact_dates_for_seed;
         "jitter_deterministic" >:: test_jitter_deterministic;
         "jitter_first_pinned_and_in_range"
         >:: test_jitter_first_pinned_and_in_range;
         "jitter_within_stride_of_base" >:: test_jitter_within_stride_of_base;
         "jitter_rejects_nonpositive_stride"
         >:: test_jitter_rejects_nonpositive_stride;
         "bah_cagr_full_year" >:: test_bah_cagr_full_year;
         "bah_cagr_nan_when_unpriceable" >:: test_bah_cagr_nan_when_unpriceable;
         "per_start_extracts_metrics" >:: test_per_start_extracts_metrics;
         "per_start_missing_metrics_are_nan"
         >:: test_per_start_missing_metrics_are_nan;
         "per_start_edge_from_benchmark" >:: test_per_start_edge_from_benchmark;
         "per_start_realized_sharpe_and_underwater"
         >:: test_per_start_realized_sharpe_and_underwater;
       ]

let () = run_test_tt_main suite
