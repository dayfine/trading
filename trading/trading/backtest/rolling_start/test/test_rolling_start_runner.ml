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
  assert_raises (Invalid_argument "enumerate_starts: stride_days must be positive, got 0")
    (fun () ->
      Runner.enumerate_starts
        ~scenario_start:(date ~y:2011 ~m:Month.Jan ~d:1)
        ~end_date:(date ~y:2012 ~m:Month.Jan ~d:1)
        ~stride_days:0)

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
         "per_start_extracts_metrics" >:: test_per_start_extracts_metrics;
         "per_start_missing_metrics_are_nan"
         >:: test_per_start_missing_metrics_are_nan;
       ]

let () = run_test_tt_main suite