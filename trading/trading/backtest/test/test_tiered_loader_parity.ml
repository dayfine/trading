(** Merge-gate parity acceptance test for the tiered-loader track (3g).

    Runs the same scenario twice — once under [Loader_strategy.Legacy] and once
    under [Loader_strategy.Tiered] — and asserts the two runs produce observably
    identical output at the granularity the plan pins:

    - [summary.n_round_trips] must match exactly (hard fail on any diff).
    - [summary.final_portfolio_value] must match within $0.01.
    - Sampled [steps[].portfolio_value] (first, last, and a few interior rows)
      must match within $0.01 per step.
    - Each pinned metric in the scenario's [expected] record must fall inside
      its declared range for BOTH strategies.

    Plus a soft warning (logged, not failing): if the Tiered run's peak RSS
    exceeds 50% of the Legacy run's on this small-universe scenario. Peak RSS
    capture isn't wired in yet — we keep the flag as a logged skip so the test
    surfaces intent without blocking on infra.

    The parity scenario lives at
    [trading/test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp]. The
    scenario itself does not set [loader_strategy]; this test drives both values
    explicitly in two passes.

    If any assertion fails, the job of this test is to surface a real bug in the
    Tiered path, not to paper over it by widening ε or skipping the check. The
    diff messages in [_assert_trade_count], [_assert_final_value], and
    [_assert_step_samples] name the exact field and both numeric values so the
    downstream failure report is self-contained. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

(* -------------------------------------------------------------------- *)
(* Paths + loading                                                       *)
(* -------------------------------------------------------------------- *)

(** Scenario fixtures live at [$TRADING_DATA_DIR/backtest_scenarios/]. In the
    GHA harness [TRADING_DATA_DIR=$GITHUB_WORKSPACE/trading/test_data]; in the
    dev container the fallback [/workspaces/trading-1/data] points at the
    production-shape tree, but the committed fixtures still live under
    [.../trading/test_data/backtest_scenarios/] either way. Resolving via
    [Data_path.default_data_dir ()] keeps this test runnable in both. *)
let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_path () =
  Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"

let _load_scenario () = Scenario.load (_scenario_path ())

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* -------------------------------------------------------------------- *)
(* Run both strategies                                                   *)
(* -------------------------------------------------------------------- *)

(** Run the scenario under the given [loader_strategy], optionally appending
    [extra_overrides] to the scenario's own [config_overrides]. The Legacy/
    Tiered parity contract holds for any override set — extras are how the same
    parity assertions are reused under
    [bar_history_max_lookback_days = Some 365] (PR 3 of the trim plan). Assert
    [Ok] loudly — any [Failure] raised by the Tiered path means 3f-part3b's
    simulator-cycle is incomplete for this scenario shape, which is a real bug
    and not a parity concern. *)
let _run (s : Scenario.t) ~loader_strategy ?(extra_overrides = []) () =
  let sector_map_override = _sector_map_override s in
  try
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date
      ~overrides:(s.config_overrides @ extra_overrides)
      ?sector_map_override ~loader_strategy ()
  with e ->
    OUnit2.assert_failure
      (sprintf "run_backtest raised under %s: %s"
         (Loader_strategy.show loader_strategy)
         (Exn.to_string e))

(* -------------------------------------------------------------------- *)
(* Parity assertions                                                     *)
(* -------------------------------------------------------------------- *)

(** Hard fail on trade_count diff. Weinstein's trade stream is deterministic
    given identical config + bar data, so any diff is a real divergence between
    Legacy and Tiered — usually a missing screener signal or a promote/demote
    bookkeeping bug. *)
let _assert_trade_count_match ~legacy ~tiered =
  let l = legacy.Backtest.Runner.summary.n_round_trips in
  let t = tiered.Backtest.Runner.summary.n_round_trips in
  if l <> t then
    OUnit2.assert_failure
      (sprintf "trade_count diff: legacy=%d tiered=%d (MUST MATCH EXACTLY)" l t)

let _assert_final_value_match ~legacy ~tiered =
  let l = legacy.Backtest.Runner.summary.final_portfolio_value in
  let t = tiered.Backtest.Runner.summary.final_portfolio_value in
  let diff = Float.abs (l -. t) in
  if Float.(diff > 0.01) then
    OUnit2.assert_failure
      (sprintf
         "final_portfolio_value diff > $0.01: legacy=$%.4f tiered=$%.4f \
          diff=$%.4f"
         l t diff)

(** Sample indices into the steps list — first, last, and a few interior points.
    Avoids iterating all N steps while still catching any divergence that
    surfaces partway through the run. *)
let _sample_indices n =
  if n = 0 then []
  else if n <= 5 then List.init n ~f:Fn.id
  else [ 0; n / 4; n / 2; 3 * n / 4; n - 1 ]

let _assert_step_samples_match ~legacy ~tiered =
  let l_steps = legacy.Backtest.Runner.steps in
  let t_steps = tiered.Backtest.Runner.steps in
  let n_l = List.length l_steps in
  let n_t = List.length t_steps in
  if n_l <> n_t then
    OUnit2.assert_failure
      (sprintf "steps length diff: legacy=%d tiered=%d" n_l n_t);
  let indices = _sample_indices n_l in
  let l_arr = Array.of_list l_steps in
  let t_arr = Array.of_list t_steps in
  List.iter indices ~f:(fun i ->
      let ls = l_arr.(i) in
      let ts = t_arr.(i) in
      if not (Date.equal ls.date ts.date) then
        OUnit2.assert_failure
          (sprintf "step[%d] date diff: legacy=%s tiered=%s" i
             (Date.to_string ls.date) (Date.to_string ts.date));
      let diff = Float.abs (ls.portfolio_value -. ts.portfolio_value) in
      if Float.(diff > 0.01) then
        OUnit2.assert_failure
          (sprintf
             "step[%d] (%s) portfolio_value diff > $0.01: legacy=$%.4f \
              tiered=$%.4f diff=$%.4f"
             i (Date.to_string ls.date) ls.portfolio_value ts.portfolio_value
             diff))

(** Each metric declared in the scenario's [expected] must fall inside its range
    for the passed result. Hard fail with the field name, observed value, range,
    and which strategy produced the out-of-range value. *)
let _assert_metrics_in_range ~label (r : Backtest.Runner.result)
    (expected : Scenario.expected) =
  let open Trading_simulation_types.Metric_types in
  let s = r.summary in
  let get k = Map.find s.metrics k |> Option.value ~default:Float.nan in
  let total_return_pct =
    (s.final_portfolio_value -. s.initial_cash) /. s.initial_cash *. 100.0
  in
  let total_trades = Float.of_int s.n_round_trips in
  let checks =
    [
      ("total_return_pct", total_return_pct, expected.total_return_pct);
      ("total_trades", total_trades, expected.total_trades);
      ("win_rate", get WinRate, expected.win_rate);
      ("sharpe_ratio", get SharpeRatio, expected.sharpe_ratio);
      ("max_drawdown_pct", get MaxDrawdown, expected.max_drawdown_pct);
      ("avg_holding_days", get AvgHoldingDays, expected.avg_holding_days);
    ]
  in
  List.iter checks ~f:(fun (name, value, range) ->
      if not (Scenario.in_range range value) then
        OUnit2.assert_failure
          (sprintf "%s: metric %s out of range: value=%.4f range=[%.4f, %.4f]"
             label name value range.min_f range.max_f))

(* -------------------------------------------------------------------- *)
(* Main test                                                             *)
(* -------------------------------------------------------------------- *)

let test_legacy_runs_ok _ =
  let s = _load_scenario () in
  let legacy = _run s ~loader_strategy:Loader_strategy.Legacy () in
  (* Non-empty steps is the minimum bar — a zero-step run means we loaded no
     data at all and every parity diff below is meaningless. *)
  assert_that (List.length legacy.steps) (gt (module Int_ord) 0)

let test_tiered_runs_ok _ =
  let s = _load_scenario () in
  let tiered = _run s ~loader_strategy:Loader_strategy.Tiered () in
  assert_that (List.length tiered.steps) (gt (module Int_ord) 0)

let test_parity_legacy_vs_tiered _ =
  let s = _load_scenario () in
  let legacy = _run s ~loader_strategy:Loader_strategy.Legacy () in
  let tiered = _run s ~loader_strategy:Loader_strategy.Tiered () in
  _assert_trade_count_match ~legacy ~tiered;
  _assert_final_value_match ~legacy ~tiered;
  _assert_step_samples_match ~legacy ~tiered;
  _assert_metrics_in_range ~label:"legacy" legacy s.expected;
  _assert_metrics_in_range ~label:"tiered" tiered s.expected

(** Parity with the trim wired ON ([bar_history_max_lookback_days = Some 365]).
    Same merge-gate guarantees as [test_parity_legacy_vs_tiered] — Legacy and
    Tiered must produce identical trade counts, equity curve samples, and final
    portfolio value — but with the rolling-window trim applied each strategy
    day. PR 3 of [dev/plans/bar-history-trim-2026-04-24.md] requires this to
    pass before the trim default can flip in PR 5. *)
let test_parity_legacy_vs_tiered_with_trim _ =
  let s = _load_scenario () in
  let extra_overrides =
    [ Sexp.of_string "((bar_history_max_lookback_days (365)))" ]
  in
  let legacy =
    _run s ~loader_strategy:Loader_strategy.Legacy ~extra_overrides ()
  in
  let tiered =
    _run s ~loader_strategy:Loader_strategy.Tiered ~extra_overrides ()
  in
  _assert_trade_count_match ~legacy ~tiered;
  _assert_final_value_match ~legacy ~tiered;
  _assert_step_samples_match ~legacy ~tiered;
  _assert_metrics_in_range ~label:"legacy" legacy s.expected;
  _assert_metrics_in_range ~label:"tiered" tiered s.expected

let suite =
  "Tiered_loader_parity"
  >::: [
         "legacy path runs successfully" >:: test_legacy_runs_ok;
         "tiered path runs successfully" >:: test_tiered_runs_ok;
         "legacy vs tiered: trades + final value + step samples + metrics"
         >:: test_parity_legacy_vs_tiered;
         "legacy vs tiered with bar_history_max_lookback_days = Some 365"
         >:: test_parity_legacy_vs_tiered_with_trim;
       ]

let () = run_test_tt_main suite
