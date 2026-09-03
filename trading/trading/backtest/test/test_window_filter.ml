(** Regression tests for {!Backtest.Window_filter.of_steps} — the
    measurement-window carve-out and its empty-window guard (issue #2632).

    Before the guard, [Runner._assemble_result] read the final portfolio value
    with [List.last_exn steps]. When the requested window contained no trading
    day — the routine case for the weekly-start sweep, whose [end_date] floats
    with the run date while the committed bars stop at a fixed floor — that
    killed the process with a raw stdlib [Invalid_argument "List.last"], taking
    every other arm of the sweep down with it. The workflow failed ≥16
    consecutive scheduled runs.

    Two halves here:

    - {b The guard.} Both shapes that empty the trading-day window are pinned:
      [start_date] past every step ([n_steps_in_range = 0]) and a populated
      window in which no step saw market bars ([n_steps_in_range > 0]). The
      payload's counts are asserted, since discriminating those two is the whole
      reason the exception carries them.
    - {b The non-empty path is unchanged.} A crash fix must move no backtest
      result, so the happy path is pinned too: [steps_in_range] keeps every
      calendar day, [steps] keeps only trading days, and [final_portfolio_value]
      is the {i last trading day's} value — not the last calendar day's.

    The end-to-end counterpart, driving the same guard through the real
    {!Backtest.Runner.run_backtest} path, is in [test_runner_empty_window.ml].
*)

open OUnit2
open Core
open Matchers
module Sim_types = Trading_simulation_types.Simulator_types

let _cash = 10_000.0

let _empty_portfolio_summary () =
  Trading_simulation_types.Portfolio_summary.of_portfolio
    (Trading_portfolio.Portfolio.create ~initial_cash:_cash ())
    ~position_value_total:0.0

(** Synthetic step carrying only the three fields this module reads: [date],
    [had_market_bars] and [portfolio_value]. *)
let _step ~date ~had_market_bars ~portfolio_value : Sim_types.step_result =
  {
    date = Date.of_string date;
    portfolio = _empty_portfolio_summary ();
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars;
  }

(** The observable outcome of one {!Backtest.Window_filter.of_steps} call,
    flattened so a single [assert_that] can pin it. [Other_exn] carries the
    exception text so a regression that reinstates the raw
    [Invalid_argument "List.last"] shows up in the failure message rather than
    as an opaque mismatch. *)
type outcome =
  | Window of {
      dates_in_range : string list;
      trading_dates : string list;
      final_portfolio_value : float;
    }
  | Empty_window of { n_sim_steps : int; n_steps_in_range : int }
  | Other_exn of string
[@@deriving eq, show]

let _dates (steps : Sim_types.step_result list) =
  List.map steps ~f:(fun s -> Date.to_string s.date)

let _run steps ~start_date ~end_date =
  match
    Backtest.Window_filter.of_steps steps
      ~start_date:(Date.of_string start_date)
      ~end_date:(Date.of_string end_date)
  with
  | w ->
      Window
        {
          dates_in_range = _dates w.steps_in_range;
          trading_dates = _dates w.steps;
          final_portfolio_value = w.final_portfolio_value;
        }
  | exception
      Backtest.Window_filter.Empty_measurement_window
        { n_sim_steps; n_steps_in_range; _ } ->
      Empty_window { n_sim_steps; n_steps_in_range }
  | exception e -> Other_exn (Stdlib.Printexc.to_string e)

(* -------------------------------------------------------------------- *)
(* The guard                                                            *)
(* -------------------------------------------------------------------- *)

(** [start_date] past every simulated step — the production shape from #2632: a
    sweep Monday later than the last committed bar. Nothing survives the
    [date >= start_date] filter, so [n_steps_in_range = 0]. *)
let test_start_date_past_every_step _ =
  let steps =
    [
      _step ~date:"2024-01-02" ~had_market_bars:true ~portfolio_value:100.0;
      _step ~date:"2024-01-03" ~had_market_bars:true ~portfolio_value:110.0;
    ]
  in
  assert_that
    (_run steps ~start_date:"2024-06-01" ~end_date:"2024-06-30")
    (equal_to (Empty_window { n_sim_steps = 2; n_steps_in_range = 0 }))

(** In-range steps exist but none saw market bars — the second way the
    trading-day window empties (a stretch of calendar days past the end of the
    data, or a full-market closure). [n_steps_in_range > 0] is what
    distinguishes it from the case above, which is why the payload carries both
    counts. *)
let test_in_range_steps_but_no_market_bars _ =
  let steps =
    [
      _step ~date:"2024-01-02" ~had_market_bars:true ~portfolio_value:100.0;
      _step ~date:"2024-06-03" ~had_market_bars:false ~portfolio_value:110.0;
      _step ~date:"2024-06-04" ~had_market_bars:false ~portfolio_value:110.0;
    ]
  in
  assert_that
    (_run steps ~start_date:"2024-06-01" ~end_date:"2024-06-30")
    (equal_to (Empty_window { n_sim_steps = 3; n_steps_in_range = 2 }))

(** An entirely empty simulator step series degrades the same way rather than
    raising something else. *)
let test_no_steps_at_all _ =
  assert_that
    (_run [] ~start_date:"2024-06-01" ~end_date:"2024-06-30")
    (equal_to (Empty_window { n_sim_steps = 0; n_steps_in_range = 0 }))

(* -------------------------------------------------------------------- *)
(* The non-empty path is unchanged                                      *)
(* -------------------------------------------------------------------- *)

(** Happy path. Pins all three fields at once:

    - [steps_in_range] drops the pre-[start_date] warmup step and keeps the
      non-trading day (round-trip extraction needs every calendar day);
    - [steps] drops the non-trading day;
    - [final_portfolio_value] is the last {i trading} day's value (130.0), not
      the last calendar day's (999.0). The simulator reports
      [portfolio_value = cash] on bar-less days, so reading the last calendar
      day would publish a spurious cliff. *)
let test_non_empty_window_is_unchanged _ =
  let steps =
    [
      _step ~date:"2024-05-31" ~had_market_bars:true ~portfolio_value:90.0;
      _step ~date:"2024-06-03" ~had_market_bars:true ~portfolio_value:120.0;
      _step ~date:"2024-06-04" ~had_market_bars:true ~portfolio_value:130.0;
      _step ~date:"2024-06-05" ~had_market_bars:false ~portfolio_value:999.0;
    ]
  in
  assert_that
    (_run steps ~start_date:"2024-06-01" ~end_date:"2024-06-30")
    (equal_to
       (Window
          {
            dates_in_range = [ "2024-06-03"; "2024-06-04"; "2024-06-05" ];
            trading_dates = [ "2024-06-03"; "2024-06-04" ];
            final_portfolio_value = 130.0;
          }))

(** A window whose only in-range step is a trading day is not degenerate — the
    guard must fire on emptiness, not on shortness. *)
let test_single_trading_day_window _ =
  let steps =
    [ _step ~date:"2024-06-03" ~had_market_bars:true ~portfolio_value:120.0 ]
  in
  assert_that
    (_run steps ~start_date:"2024-06-01" ~end_date:"2024-06-30")
    (equal_to
       (Window
          {
            dates_in_range = [ "2024-06-03" ];
            trading_dates = [ "2024-06-03" ];
            final_portfolio_value = 120.0;
          }))

(** The [Printexc] printer names the window and both counts, so an uncaught
    instance is diagnosable from a workflow log alone — the thing the raw
    [Invalid_argument "List.last"] could not do. *)
let test_exception_message_names_the_window _ =
  let steps =
    [ _step ~date:"2024-01-02" ~had_market_bars:true ~portfolio_value:100.0 ]
  in
  let message =
    match
      Backtest.Window_filter.of_steps steps
        ~start_date:(Date.of_string "2024-06-01")
        ~end_date:(Date.of_string "2024-06-30")
    with
    | (_ : Backtest.Window_filter.window) -> "no exception raised"
    | exception e -> Stdlib.Printexc.to_string e
  in
  assert_that message
    (all_of
       [
         contains_substring "2024-06-01";
         contains_substring "2024-06-30";
         contains_substring "no trading day";
       ])

let suite =
  "Window_filter"
  >::: [
         "of_steps: start_date past every step raises Empty_measurement_window"
         >:: test_start_date_past_every_step;
         "of_steps: in-range steps with no market bars raise \
          Empty_measurement_window" >:: test_in_range_steps_but_no_market_bars;
         "of_steps: empty step series raises Empty_measurement_window"
         >:: test_no_steps_at_all;
         "of_steps: non-empty window splits steps and takes the last trading \
          day's value" >:: test_non_empty_window_is_unchanged;
         "of_steps: a one-trading-day window is not degenerate"
         >:: test_single_trading_day_window;
         "Empty_measurement_window prints the window and both step counts"
         >:: test_exception_message_names_the_window;
       ]

let () = run_test_tt_main suite
