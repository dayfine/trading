(** Stage 1 integration parity gate — see
    [dev/plans/columnar-data-shape-2026-04-25.md] §Stage 1.

    Runs the same scenario twice — once under [Loader_strategy.Tiered] and once
    under [Loader_strategy.Panel] — and asserts the two runs produce observably
    identical output:

    - [summary.n_round_trips] must match exactly.
    - [summary.final_portfolio_value] must match within $0.01.
    - Sampled [steps[].portfolio_value] (first, last, and a few interior rows)
      must match within $0.01 per step.

    Because the Weinstein strategy does not yet consume [get_indicator], Panel
    mode is behaviourally equivalent to Tiered: the panel-backed [get_indicator]
    is constructed each tick but never queried by the inner strategy. This test
    pins that "additive only" property — a regression here means the panel
    wrapper is perturbing some other observable (e.g. by writing into the wrong
    panel column, or by failing to forward [get_price]).

    Reuses [test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp]. Same
    fixture pattern as [test_tiered_loader_parity]. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_path () =
  Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"

let _load_scenario () = Scenario.load (_scenario_path ())

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run (s : Scenario.t) ~loader_strategy =
  let sector_map_override = _sector_map_override s in
  try
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~loader_strategy ()
  with e ->
    OUnit2.assert_failure
      (sprintf "run_backtest raised under %s: %s"
         (Loader_strategy.show loader_strategy)
         (Exn.to_string e))

let _assert_trade_count_match ~tiered ~panel =
  let t = tiered.Backtest.Runner.summary.n_round_trips in
  let p = panel.Backtest.Runner.summary.n_round_trips in
  if t <> p then
    OUnit2.assert_failure
      (sprintf "trade_count diff: tiered=%d panel=%d (MUST MATCH EXACTLY)" t p)

let _assert_final_value_match ~tiered ~panel =
  let t = tiered.Backtest.Runner.summary.final_portfolio_value in
  let p = panel.Backtest.Runner.summary.final_portfolio_value in
  let diff = Float.abs (t -. p) in
  if Float.( > ) diff 0.01 then
    OUnit2.assert_failure
      (sprintf
         "final_portfolio_value diff > $0.01: tiered=$%.4f panel=$%.4f \
          diff=$%.4f"
         t p diff)

let _sample_indices n =
  if n = 0 then []
  else if n <= 5 then List.init n ~f:Fn.id
  else [ 0; n / 4; n / 2; 3 * n / 4; n - 1 ]

let _assert_step_samples_match ~tiered ~panel =
  let t_steps = tiered.Backtest.Runner.steps in
  let p_steps = panel.Backtest.Runner.steps in
  let n_t = List.length t_steps in
  let n_p = List.length p_steps in
  if n_t <> n_p then
    OUnit2.assert_failure
      (sprintf "steps length diff: tiered=%d panel=%d" n_t n_p);
  let indices = _sample_indices n_t in
  let t_arr = Array.of_list t_steps in
  let p_arr = Array.of_list p_steps in
  List.iter indices ~f:(fun i ->
      let ts = t_arr.(i) in
      let ps = p_arr.(i) in
      if not (Date.equal ts.date ps.date) then
        OUnit2.assert_failure
          (sprintf "step[%d] date diff: tiered=%s panel=%s" i
             (Date.to_string ts.date) (Date.to_string ps.date));
      let diff = Float.abs (ts.portfolio_value -. ps.portfolio_value) in
      if Float.( > ) diff 0.01 then
        OUnit2.assert_failure
          (sprintf
             "step[%d] (%s) portfolio_value diff > $0.01: tiered=$%.4f \
              panel=$%.4f diff=$%.4f"
             i (Date.to_string ts.date) ts.portfolio_value ps.portfolio_value
             diff))

let test_panel_runs_ok _ =
  let s = _load_scenario () in
  let panel = _run s ~loader_strategy:Loader_strategy.Panel in
  assert_that (List.length panel.steps) (gt (module Int_ord) 0)

let test_parity_tiered_vs_panel _ =
  let s = _load_scenario () in
  let tiered = _run s ~loader_strategy:Loader_strategy.Tiered in
  let panel = _run s ~loader_strategy:Loader_strategy.Panel in
  _assert_trade_count_match ~tiered ~panel;
  _assert_final_value_match ~tiered ~panel;
  _assert_step_samples_match ~tiered ~panel

let suite =
  "Panel_loader_parity"
  >::: [
         "panel path runs successfully" >:: test_panel_runs_ok;
         "tiered vs panel: trades + final value + step samples"
         >:: test_parity_tiered_vs_panel;
       ]

let () = run_test_tt_main suite
