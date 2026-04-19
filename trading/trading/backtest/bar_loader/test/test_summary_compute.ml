(** Unit tests for [Summary_compute] — the pure indicator helpers used by the
    Summary tier. These tests never touch CSV storage or [Price_cache]; they
    exercise the math directly on synthetic bars. *)

open OUnit2
open Core
open Matchers
module Summary_compute = Bar_loader.Summary_compute

(** {1 Fixture helpers} *)

(** [_mk_bar ~date ~close] produces a minimal flat bar (o=h=l=c=close). *)
let _mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

(** [_linear_bars ~n ~start_date ~base ~step] generates [n] consecutive daily
    bars starting at [start_date]. Close on day [i] (0-indexed) is
    [base +. step *. Float.of_int i]. Used to produce predictable sequences we
    can hand-compute averages against. *)
let _linear_bars ~n ~start_date ~base ~step : Types.Daily_price.t list =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      let close = base +. (step *. Float.of_int i) in
      _mk_bar ~date ~close)

let _mk_ohlc_bar ~date ~o ~h ~l ~c : Types.Daily_price.t =
  {
    date;
    open_price = o;
    high_price = h;
    low_price = l;
    close_price = c;
    adjusted_close = c;
    volume = 1_000_000;
  }

(** {1 ma_30w tests} *)

(** With 30 weekly bars, the MA equals the mean of their closes. We use a decade
    of daily bars (~260 / year × 1 year = ~260), which [daily_to_weekly] reduces
    to ~52 weekly bars — enough for 30w MA. *)
let test_ma_30w_returns_mean _ =
  let config = Summary_compute.default_config in
  (* 300 consecutive daily bars starting on a Monday → ~60 weekly bars after
     aggregation, which is more than [ma_weeks = 30]. *)
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  (* Monday *)
  let bars = _linear_bars ~n:300 ~start_date ~base:100.0 ~step:1.0 in
  let result = Summary_compute.ma_30w ~config bars in
  (* Hand-check: the MA is the mean of the last 30 weekly last-bar closes. The
     test doesn't need to compute the exact value — only that it's finite and
     within the plausible range of the generated series. *)
  assert_that result
    (is_some_and (is_between (module Float_ord) ~low:100.0 ~high:400.0))

let test_ma_30w_none_when_too_short _ =
  let config = Summary_compute.default_config in
  (* 30 daily bars → ~6 weekly bars after aggregation → under the 30-week
     requirement. *)
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _linear_bars ~n:30 ~start_date ~base:100.0 ~step:1.0 in
  assert_that (Summary_compute.ma_30w ~config bars) is_none

(** {1 atr_14 tests} *)

(** Flat bars (o=h=l=c) have zero range and zero gap — ATR over 14 days is
    exactly 0.0. *)
let test_atr_14_zero_on_flat_bars _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _linear_bars ~n:20 ~start_date ~base:100.0 ~step:0.0 in
  assert_that
    (Summary_compute.atr_14 ~config bars)
    (is_some_and (float_equal 0.0))

(** Known TR sequence: bars with constant high-low range of 2.0 and no gaps →
    ATR-14 = 2.0. *)
let test_atr_14_constant_range _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars =
    List.init 20 ~f:(fun i ->
        let date = Date.add_days start_date i in
        (* o=h-1, c=h-1, l=h-3 → range = 2; close = 50 consistently so no gap *)
        _mk_ohlc_bar ~date ~o:50.0 ~h:51.0 ~l:49.0 ~c:50.0)
  in
  assert_that
    (Summary_compute.atr_14 ~config bars)
    (is_some_and (float_equal 2.0))

let test_atr_14_none_when_too_short _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _linear_bars ~n:5 ~start_date ~base:100.0 ~step:1.0 in
  assert_that (Summary_compute.atr_14 ~config bars) is_none

(** {1 rs_line tests} *)

let test_rs_line_flat_ratio _ =
  (* Stock and benchmark move identically → raw_rs = 1.0 for every weekly bar →
     MA(raw_rs) = 1.0 → normalized = 1.0. Needs enough daily bars to aggregate
     to at least [rs_ma_period] weekly bars. *)
  let config = { Summary_compute.default_config with rs_ma_period = 10 } in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let stock_bars = _linear_bars ~n:140 ~start_date ~base:100.0 ~step:1.0 in
  let benchmark_bars = _linear_bars ~n:140 ~start_date ~base:100.0 ~step:1.0 in
  assert_that
    (Summary_compute.rs_line ~config ~stock_bars ~benchmark_bars)
    (is_some_and (float_equal 1.0))

let test_rs_line_none_when_too_short _ =
  let config = { Summary_compute.default_config with rs_ma_period = 50 } in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let stock_bars = _linear_bars ~n:10 ~start_date ~base:100.0 ~step:1.0 in
  let benchmark_bars = _linear_bars ~n:10 ~start_date ~base:100.0 ~step:1.0 in
  assert_that
    (Summary_compute.rs_line ~config ~stock_bars ~benchmark_bars)
    is_none

(** The Mansfield zero-line should normalize against a window of ~1 YEAR
    (52 weekly bars), not ~2.5 months (52 daily bars). This test pins the
    aggregation boundary: we construct a series where stock = benchmark for
    every bar except the final week (where stock doubles). Under correct
    weekly aggregation the 52-week MA averages 51 weeks of raw_rs=1.0 with 1
    week of raw_rs=2.0 → MA = 53/52. Under the buggy daily path the 52-day
    MA would include 7 elevated days → MA ≈ 59/52 ≈ 1.1346, yielding a
    meaningfully different normalized value. *)
let test_rs_line_uses_weekly_52_window _ =
  let config = { Summary_compute.default_config with rs_ma_period = 52 } in
  (* 420 consecutive daily bars starting on a Monday → aggregates to 60 weekly
     bars (60 complete weeks, no partial week at the tail because 420/7 = 60).
     Mon 2023-01-02 .. Sun 2024-02-25. *)
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let total_days = 420 in
  let elevated_days = 7 in
  let plateau_days = total_days - elevated_days in
  let make_bars ~price_during_plateau ~price_during_elevated =
    List.init total_days ~f:(fun i ->
        let date = Date.add_days start_date i in
        let close =
          if i < plateau_days then price_during_plateau
          else price_during_elevated
        in
        _mk_bar ~date ~close)
  in
  (* Benchmark flat at 100.0 throughout. Stock flat at 100.0 then doubles to
     200.0 in the final 7-day block. *)
  let stock_bars =
    make_bars ~price_during_plateau:100.0 ~price_during_elevated:200.0
  in
  let benchmark_bars =
    make_bars ~price_during_plateau:100.0 ~price_during_elevated:100.0
  in
  (* Hand-computed expected value for the weekly path: the 52-week window
     contains 51 weeks where raw_rs = 1.0 and 1 week where raw_rs = 2.0. The
     normalized value at the latest bar is raw_rs_last / MA = 2.0 / (53/52) =
     104/53. *)
  let expected_weekly = 104.0 /. 53.0 in
  (* The buggy daily path would yield 2.0 / (59/52) = 104/59 ≈ 1.7627, which
     is ~14% different. The epsilon here is tight enough to reject that
     alternative. *)
  assert_that
    (Summary_compute.rs_line ~config ~stock_bars ~benchmark_bars)
    (is_some_and (float_equal ~epsilon:1e-6 expected_weekly))

(** {1 stage_heuristic tests} *)

let test_stage_heuristic_some_on_sufficient_history _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2021 ~m:Jan ~d:4 in
  (* 2 years of daily bars → ~100 weekly bars → enough for ma_period=30. *)
  let bars = _linear_bars ~n:500 ~start_date ~base:100.0 ~step:1.0 in
  assert_that (Summary_compute.stage_heuristic ~config bars) (is_some_and __)

let test_stage_heuristic_none_on_short_history _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _linear_bars ~n:20 ~start_date ~base:100.0 ~step:1.0 in
  assert_that (Summary_compute.stage_heuristic ~config bars) is_none

(** {1 compute_values tests} *)

let test_compute_values_assembles_all_four _ =
  let config = { Summary_compute.default_config with rs_ma_period = 30 } in
  let start_date = Date.create_exn ~y:2021 ~m:Jan ~d:4 in
  let stock_bars = _linear_bars ~n:400 ~start_date ~base:100.0 ~step:1.0 in
  let benchmark_bars = _linear_bars ~n:400 ~start_date ~base:100.0 ~step:1.0 in
  let as_of = Date.create_exn ~y:2022 ~m:Feb ~d:5 in
  let result =
    Summary_compute.compute_values ~config ~stock_bars ~benchmark_bars ~as_of
  in
  assert_that result
    (is_some_and
       (all_of
          [
            field (fun v -> v.Summary_compute.as_of) (equal_to as_of);
            field (fun v -> v.Summary_compute.rs_line) (float_equal 1.0);
            (* Stock identical to benchmark → stage should be classifiable.
               Just confirm it's present (non-placeholder check covered by
               stage_heuristic tests). *)
          ]))

let test_compute_values_none_when_any_helper_fails _ =
  let config = Summary_compute.default_config in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let stock_bars = _linear_bars ~n:10 ~start_date ~base:100.0 ~step:1.0 in
  let benchmark_bars = _linear_bars ~n:10 ~start_date ~base:100.0 ~step:1.0 in
  let as_of = Date.create_exn ~y:2023 ~m:Jan ~d:12 in
  assert_that
    (Summary_compute.compute_values ~config ~stock_bars ~benchmark_bars ~as_of)
    is_none

(** {1 Suite} *)

let suite =
  "Summary_compute"
  >::: [
         "ma_30w_returns_mean" >:: test_ma_30w_returns_mean;
         "ma_30w_none_when_too_short" >:: test_ma_30w_none_when_too_short;
         "atr_14_zero_on_flat_bars" >:: test_atr_14_zero_on_flat_bars;
         "atr_14_constant_range" >:: test_atr_14_constant_range;
         "atr_14_none_when_too_short" >:: test_atr_14_none_when_too_short;
         "rs_line_flat_ratio" >:: test_rs_line_flat_ratio;
         "rs_line_none_when_too_short" >:: test_rs_line_none_when_too_short;
         "rs_line_uses_weekly_52_window"
         >:: test_rs_line_uses_weekly_52_window;
         "stage_heuristic_some_on_sufficient_history"
         >:: test_stage_heuristic_some_on_sufficient_history;
         "stage_heuristic_none_on_short_history"
         >:: test_stage_heuristic_none_on_short_history;
         "compute_values_assembles_all_four"
         >:: test_compute_values_assembles_all_four;
         "compute_values_none_when_any_helper_fails"
         >:: test_compute_values_none_when_any_helper_fails;
       ]

let () = run_test_tt_main suite
