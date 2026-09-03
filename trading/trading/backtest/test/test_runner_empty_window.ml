(** End-to-end regression for issue #2632: a {!Backtest.Runner.run_backtest}
    window that contains no trading day must fail with the typed
    {!Backtest.Window_filter.Empty_measurement_window}, never with the raw
    stdlib [Invalid_argument "List.last"] that [Runner._assemble_result]'s
    [List.last_exn steps] used to produce.

    Why this matters, and why it is an end-to-end test rather than only a unit
    test on {!Backtest.Window_filter}: the caller that broke was the
    weekly-start sweep ([.github/workflows/weekly-start-sweep.yml]), which maps
    a BAH run over every Monday in a trailing 3-year window with [end_date]
    floating at the run date. The committed SPY bars stop at a fixed floor, so
    every Monday past that floor is unmeasurable — and one such Monday aborted
    the whole process, taking all the measurable cells with it. The workflow
    failed ≥16 consecutive scheduled runs, back to 2026-05-18. Driving the real
    runner path is what pins the fix at the layer where it actually failed.

    The window used here is deliberately far in the future (2035). Anchoring it
    just past today's data floor would silently stop testing anything the next
    time [ops-data] extends the SPY series — a test that quietly becomes vacuous
    is worse than no test. No bar series in this repo will ever reach 2035 while
    this test is meaningful.

    The unit-level companion, covering both empty-window shapes and the pin that
    the non-empty path is unchanged, is [test_window_filter.ml]. *)

open OUnit2
open Core
open Matchers
module Universe_file = Scenario_lib.Universe_file

(** Walk cwd parents looking for the worktree-local fixtures root —
    [trading/test_data/backtest_scenarios] under the repo root. Same trick as
    [test_bah_runner_e2e]; the universe file is part of the worktree's
    test_data, not the container-wide data mount. *)
let _worktree_fixtures_root () =
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate =
        Filename.concat dir "trading/test_data/backtest_scenarios"
      in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _resolve_fixtures_root () =
  match _worktree_fixtures_root () with
  | Some r -> r
  | None ->
      assert_failure
        (Printf.sprintf
           "scenario test-data dir not found from cwd=%s (expected \
            trading/test_data/backtest_scenarios under a parent)"
           (Stdlib.Sys.getcwd ()))

let _spy_sector_map () =
  let fixtures_root = _resolve_fixtures_root () in
  Universe_file.to_sector_map_override
    (Universe_file.load
       (Filename.concat fixtures_root "universes/spy-only.sexp"))

(** A window with no bars at all: 2035 is past every series in the repo, so
    every simulated step reports [had_market_bars = false]. Kept short (two
    months) so the calendar-day step loop stays fast. *)
let _start_date = "2035-01-01"

let _end_date = "2035-03-01"

(** Flattened outcome of one runner call. [Other_exn] carries the exception
    text, so a regression that reinstates [Invalid_argument "List.last"] reports
    it by name in the failure message instead of as an opaque mismatch. *)
type outcome =
  | Completed
  | Empty_window of string  (** the [start_date] named by the payload *)
  | Other_exn of string
[@@deriving eq, show]

let _run_empty_window () =
  let sector_map_override = _spy_sector_map () in
  match
    Backtest.Runner.run_backtest
      ~start_date:(Date.of_string _start_date)
      ~end_date:(Date.of_string _end_date) ?sector_map_override
      ~strategy_choice:
        (Backtest.Strategy_choice.Bah_benchmark { symbol = "SPY" })
      ()
  with
  | (_ : Backtest.Runner.result) -> Completed
  | exception Backtest.Window_filter.Empty_measurement_window { start_date; _ }
    ->
      Empty_window (Date.to_string start_date)
  | exception e -> Other_exn (Stdlib.Printexc.to_string e)

(** The guard, driven through the production entry point. Asserting the payload
    carries the requested [start_date] is what makes the sweep's per-cell skip
    message useful — the caller has to be able to say {i which} Monday it
    dropped. *)
let test_run_backtest_raises_typed_empty_window _ =
  assert_that (_run_empty_window ()) (equal_to (Empty_window _start_date))

(** The sweep's own cell runner — the caller that #2632 killed — must absorb the
    degenerate window and return [None] rather than propagate. This is the "one
    arm must not take down the others" contract, checked at the exact function
    [Sweep_weekly_start_lib.run] maps over the Mondays. *)
let test_sweep_run_one_skips_the_cell _ =
  let cfg : Sweep_weekly_start.Sweep_weekly_start_lib.config =
    {
      symbol = "SPY";
      initial_cash = 100_000.0;
      years_back = 3;
      end_date = Date.of_string _end_date;
      fixtures_root = _resolve_fixtures_root ();
      universe_path = "universes/spy-only.sexp";
    }
  in
  let sector_map_override =
    match _spy_sector_map () with
    | Some tbl -> tbl
    | None ->
        assert_failure
          "universes/spy-only.sexp resolved to Full_sector_map; expected a \
           pinned single-symbol universe"
  in
  assert_that
    (Sweep_weekly_start.Sweep_weekly_start_lib.run_one cfg
       (Date.of_string _start_date)
       ~sector_map_override)
    is_none

let suite =
  "Runner_empty_window"
  >::: [
         "run_backtest on a bar-less window raises \
          Window_filter.Empty_measurement_window"
         >:: test_run_backtest_raises_typed_empty_window;
         "Sweep_weekly_start.run_one returns None instead of aborting the sweep"
         >:: test_sweep_run_one_skips_the_cell;
       ]

let () = run_test_tt_main suite
