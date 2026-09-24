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
    the non-empty path is unchanged, is [test_window_filter.ml].

    The sweep-side cases here pin both halves of
    [Sweep_weekly_start_lib.run_one]'s documented contract: the degenerate
    window is absorbed into [Error dropped], and {i only} the degenerate window
    is — any other failure propagates. The second half needs its own case
    because the mutation that breaks it (widening the handler to
    [| exception exn ->]) leaves the handler body byte-identical and is exactly
    the shape a later simplification would take. *)

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

let _sweep_config () : Sweep_weekly_start.Sweep_weekly_start_lib.config =
  {
    symbol = "SPY";
    initial_cash = 100_000.0;
    years_back = 3;
    end_date = Date.of_string _end_date;
    fixtures_root = _resolve_fixtures_root ();
    universe_path = "universes/spy-only.sexp";
    max_end_date_gap_days =
      Sweep_weekly_start.Sweep_weekly_start_lib.default_max_end_date_gap_days;
  }

let _pinned_spy_sector_map () =
  match _spy_sector_map () with
  | Some tbl -> tbl
  | None ->
      assert_failure
        "universes/spy-only.sexp resolved to Full_sector_map; expected a \
         pinned single-symbol universe"

(** A sector map whose only symbol is the empty string — an invalid symbol
    rather than a merely absent one. [Csv_snapshot_builder] rejects it outright
    ([Csv_storage.create ""] → ["Symbol cannot be empty"]) while building the
    run's in-process snapshot, so the failure surfaces from deep inside the
    panel build, well before {!Backtest.Window_filter.of_steps} ever judges the
    window. That is what makes it the right probe here: it is the cheapest input
    reachable from [run_one]'s own arguments that fails for a reason other than
    the degenerate window, with no dependence on which bar series happen to be
    on disk. *)
let _invalid_sector_map () =
  let tbl = Hashtbl.create (module String) in
  Hashtbl.set tbl ~key:"" ~data:"Technology";
  tbl

(** Flattened outcome of one [Sweep_weekly_start_lib.run_one] call.
    Distinguishes the four things that can happen to a cell, so a test can
    assert {i which} one occurred instead of only that the call did not crash.
*)
type run_one_outcome =
  | Cell_produced
  | Cell_skipped of Sweep_weekly_start.Sweep_weekly_start_lib.dropped_cell
      (** [Error dropped] — the documented degenerate-window tolerance *)
  | Empty_window_propagated
  | Other_exn_propagated of string  (** the exception text *)
[@@deriving eq, show]

let _run_one_outcome cfg start_date ~sector_map_override =
  match
    Sweep_weekly_start.Sweep_weekly_start_lib.run_one cfg start_date
      ~sector_map_override
  with
  | Ok (_ : Sweep_weekly_start.Sweep_weekly_start_lib.cell) -> Cell_produced
  | Error dropped -> Cell_skipped dropped
  | exception Backtest.Window_filter.Empty_measurement_window _ ->
      Empty_window_propagated
  | exception e -> Other_exn_propagated (Stdlib.Printexc.to_string e)

(** The sweep's own cell runner — the caller that #2632 killed — must absorb the
    degenerate window and return [Error dropped] rather than propagate. This is
    the "one arm must not take down the others" contract, checked at the exact
    function [Sweep_weekly_start_lib.run] maps over the Mondays. The dropped
    record must name the Monday and carry the rendered exception as its [reason]
    — that text is what the report's [## Dropped cells] section shows (issue
    #2915). *)
let test_sweep_run_one_skips_the_cell _ =
  assert_that
    (_run_one_outcome (_sweep_config ())
       (Date.of_string _start_date)
       ~sector_map_override:(_pinned_spy_sector_map ()))
    (matching ~msg:"expected Cell_skipped"
       (function Cell_skipped d -> Some d | _ -> None)
       (all_of
          [
            field
              (fun (d : Sweep_weekly_start.Sweep_weekly_start_lib.dropped_cell)
                 -> d.start_date)
              (equal_to (Date.of_string _start_date));
            field
              (fun (d : Sweep_weekly_start.Sweep_weekly_start_lib.dropped_cell)
                 -> d.reason)
              (contains_substring
                 (Printf.sprintf "measurement window %s..%s" _start_date
                    _end_date));
          ]))

(** The other half of the same contract, and the one that is easy to lose: the
    tolerance is scoped to the degenerate window {i only}. Widening [run_one]'s
    handler to [| exception exn ->] leaves its body byte-identical, so nothing
    about the code looks wrong afterwards — but every genuine failure would then
    become a silently-dropped cell, and [run]'s [List.partition_result] would
    report a successful sweep over an arm it never actually measured. That is
    the same "silently wrong data, not an error" hazard the typed exception
    exists to prevent, moved one layer up. *)
let test_sweep_run_one_propagates_a_genuine_failure _ =
  assert_that
    (_run_one_outcome (_sweep_config ())
       (Date.of_string _start_date)
       ~sector_map_override:(_invalid_sector_map ()))
    (matching
       ~msg:
         "a non-Empty_measurement_window failure must propagate out of \
          run_one, never be swallowed into Error"
       (function Other_exn_propagated msg -> Some msg | _ -> None)
       (contains_substring "Symbol cannot be empty"))

(** What the skipped cell reports on stderr. [run] drops the cell from [cells]
    and records it in [dropped_cells] (rendered in the report since #2915); the
    stderr line is the workflow-log copy naming the Monday and why. Pinning the
    pure {!Sweep_weekly_start_lib.skip_message} pins that content; the [eprintf]
    side effect itself is not asserted (capturing the process's stderr from
    inside OUnit is not worth the fixture), so a mutation that stops
    {i printing} the message still passes — what this test defends is that the
    message keeps naming the cell and the reason. *)
let test_skip_message_names_the_cell_and_the_reason _ =
  assert_that
    (Sweep_weekly_start.Sweep_weekly_start_lib.skip_message
       (Date.of_string _start_date)
       (Backtest.Window_filter.Empty_measurement_window
          {
            start_date = Date.of_string _start_date;
            end_date = Date.of_string _end_date;
            n_sim_steps = 0;
            n_steps_in_range = 0;
          }))
    (all_of
       [
         contains_substring ("start_date=" ^ _start_date);
         contains_substring
           (Printf.sprintf "measurement window %s..%s" _start_date _end_date);
       ])

module SWS = Sweep_weekly_start.Sweep_weekly_start_lib

(** How far past the last committed SPY bar the clamp test requests its
    [end_date] — well beyond the 7-day tolerance, so the guard must clamp. *)
let _clamp_gap_days = 60

(** One year of Mondays keeps the full [run] fast while still spanning many
    cells. *)
let _clamp_years_back = 1

(** The last committed SPY bar, read through the same guard [run] uses. Derived
    rather than hardcoded so the test stays meaningful when [ops-data] extends
    the series. *)
let _last_spy_bar () =
  (SWS.load_coverage
     ~data_dir:(Data_path.default_data_dir ())
     ~symbol:"SPY" ~requested_end_date:(Date.of_string _end_date)
     ~tolerance_days:SWS.default_max_end_date_gap_days)
    .last_bar_date

let _cell_exn cfg start_date =
  match
    SWS.run_one cfg start_date ~sector_map_override:(_pinned_spy_sector_map ())
  with
  | Ok cell -> cell
  | Error d -> assert_failure ("unexpected dropped cell: " ^ d.reason)

(** Issue #2915, the wiring of [run] itself: with [end_date] far past the last
    bar, the Monday window trails the last bar, every cell is measured to it,
    [result.end_date] is the last bar and [result.coverage] records the clamp.
    The CAGR check is numeric: the first cell must equal a [run_one] measured to
    the last bar, so a [run] that still annualizes over the dead days goes red
    even while the clamp flag says otherwise. *)
let test_run_clamps_cells_to_last_bar _ =
  let last_bar = _last_spy_bar () in
  let requested = Date.add_days last_bar _clamp_gap_days in
  let cfg =
    {
      (_sweep_config ()) with
      end_date = requested;
      years_back = _clamp_years_back;
    }
  in
  let mondays =
    SWS.mondays_in_window ~end_date:last_bar ~years_back:_clamp_years_back
  in
  let expected =
    _cell_exn { cfg with end_date = last_bar } (List.hd_exn mondays)
  in
  assert_that (SWS.run cfg)
    (all_of
       [
         field (fun (r : SWS.sweep_result) -> r.end_date) (equal_to last_bar);
         field
           (fun (r : SWS.sweep_result) -> r.coverage)
           (is_some_and
              (equal_to
                 ({
                    requested_end_date = requested;
                    last_bar_date = last_bar;
                    tolerance_days = SWS.default_max_end_date_gap_days;
                    clamped = true;
                  }
                   : SWS.coverage)));
         field
           (fun (r : SWS.sweep_result) ->
             List.map r.cells ~f:(fun (c : SWS.cell) -> c.start_date))
           (equal_to mondays);
         field (fun (r : SWS.sweep_result) -> r.dropped_cells) is_empty;
         field
           (fun (r : SWS.sweep_result) -> List.hd r.cells)
           (is_some_and
              (field (fun (c : SWS.cell) -> c.cagr) (float_equal expected.cagr)));
       ])

(** Companion to the clamp test: measuring the same cell to the requested
    (dead-day) end gives a different CAGR, so the numeric check above can
    actually tell the two end dates apart. *)
let test_requested_end_changes_cagr _ =
  let last_bar = _last_spy_bar () in
  let cfg = { (_sweep_config ()) with years_back = _clamp_years_back } in
  let start =
    List.hd_exn
      (SWS.mondays_in_window ~end_date:last_bar ~years_back:_clamp_years_back)
  in
  let clamped = _cell_exn { cfg with end_date = last_bar } start in
  assert_that
    (_cell_exn
       { cfg with end_date = Date.add_days last_bar _clamp_gap_days }
       start)
    (field (fun (c : SWS.cell) -> c.cagr) (not_ (float_equal clamped.cagr)))

let suite =
  "Runner_empty_window"
  >::: [
         "run_backtest on a bar-less window raises \
          Window_filter.Empty_measurement_window"
         >:: test_run_backtest_raises_typed_empty_window;
         "Sweep_weekly_start.run_one returns Error dropped instead of aborting \
          the sweep" >:: test_sweep_run_one_skips_the_cell;
         "Sweep_weekly_start.run_one propagates a non-empty-window failure"
         >:: test_sweep_run_one_propagates_a_genuine_failure;
         "Sweep_weekly_start.skip_message names the skipped cell and the reason"
         >:: test_skip_message_names_the_cell_and_the_reason;
         "Sweep_weekly_start.run clamps every cell to the last bar"
         >:: test_run_clamps_cells_to_last_bar;
         "Measuring to the requested end changes a cell's CAGR"
         >:: test_requested_end_changes_cagr;
       ]

let () = run_test_tt_main suite
