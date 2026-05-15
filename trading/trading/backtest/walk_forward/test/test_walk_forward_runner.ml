(** Unit tests for {!Walk_forward.Walk_forward_runner}. Pure scenario-shape
    checks — no backtest invocation. *)

open OUnit2
open Core
open Matchers
module WFR = Walk_forward.Walk_forward_runner
module WS = Walk_forward.Window_spec
module Scenario = Scenario_lib.Scenario

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _make_base ?(name = "base-test") ?(description = "base-desc")
    ?(universe_path = "universes/parity-7sym.sexp") ?(config_overrides = [])
    ?(slippage_bps = None) ?(strategy = Backtest.Strategy_choice.default) () :
    Scenario.t =
  let expected : Scenario.expected =
    {
      total_return_pct = { min_f = -100.0; max_f = 500.0 };
      total_trades = { min_f = 0.0; max_f = 1000.0 };
      win_rate = { min_f = 0.0; max_f = 100.0 };
      sharpe_ratio = { min_f = -2.0; max_f = 3.0 };
      max_drawdown_pct = { min_f = 0.0; max_f = 90.0 };
      avg_holding_days = { min_f = 0.0; max_f = 500.0 };
      open_positions_value = None;
      unrealized_pnl = None;
      sortino_ratio_annualized = None;
      calmar_ratio = None;
      ulcer_index = None;
      wall_seconds = None;
    }
  in
  {
    name;
    description;
    period = { start_date = _date 2020 1 1; end_date = _date 2020 1 31 };
    universe_path;
    config_overrides;
    strategy;
    slippage_bps;
    expected;
  }

let _make_fold ?(index = 0) ?(name = "fold-000") ?(train = None)
    ?(test_start = _date 2021 1 1) ?(test_end = _date 2021 6 30) () : WS.fold =
  {
    index;
    name;
    train_period = train;
    test_period = { start_date = test_start; end_date = test_end };
  }

(* ---------- build_fold_scenario ---------- *)

let test_name_composes_base_variant_fold _ =
  let base = _make_base ~name:"sp500" () in
  let fold = _make_fold ~name:"fold-005" () in
  let variant : WFR.variant = { label = "cell-E"; overrides = [] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  assert_that s.name (equal_to "sp500-cell-E-fold-005")

let test_period_is_test_period_of_fold _ =
  let base = _make_base () in
  let fold =
    _make_fold ~test_start:(_date 2021 5 1) ~test_end:(_date 2021 8 31) ()
  in
  let variant : WFR.variant = { label = "v"; overrides = [] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  assert_that s.period
    (all_of
       [
         field
           (fun (p : Scenario.period) -> p.start_date)
           (equal_to (_date 2021 5 1));
         field
           (fun (p : Scenario.period) -> p.end_date)
           (equal_to (_date 2021 8 31));
       ])

let test_overrides_appended_last _ =
  let base_ov = Sexp.of_string "((initial_stop_buffer 1.05))" in
  let variant_ov = Sexp.of_string "((initial_stop_buffer 1.20))" in
  let base = _make_base ~config_overrides:[ base_ov ] () in
  let fold = _make_fold () in
  let variant : WFR.variant = { label = "v"; overrides = [ variant_ov ] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  (* Variant override appended last; the [Backtest.Runner._apply_overrides]
     contract is last-writer-wins, so 1.20 should be the effective value. *)
  assert_that s.config_overrides
    (elements_are [ equal_to base_ov; equal_to variant_ov ])

let test_universe_and_strategy_preserved _ =
  let base = _make_base ~universe_path:"universes/custom.sexp" () in
  let fold = _make_fold () in
  let variant : WFR.variant = { label = "v"; overrides = [] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  assert_that s
    (all_of
       [
         field
           (fun (sc : Scenario.t) -> sc.universe_path)
           (equal_to "universes/custom.sexp");
         field
           (fun (sc : Scenario.t) -> sc.strategy)
           (equal_to Backtest.Strategy_choice.default);
       ])

let test_slippage_bps_preserved _ =
  let base = _make_base ~slippage_bps:(Some 5) () in
  let fold = _make_fold () in
  let variant : WFR.variant = { label = "v"; overrides = [] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  assert_that s.slippage_bps (is_some_and (equal_to 5))

let test_description_marks_fold_and_variant _ =
  let base = _make_base ~description:"orig desc" () in
  let fold = _make_fold ~name:"fold-007" () in
  let variant : WFR.variant = { label = "cellX"; overrides = [] } in
  let s = WFR.build_fold_scenario ~base ~fold ~variant in
  assert_that s.description
    (all_of
       [
         (* Both labels present *)
         field
           (fun d -> String.is_substring d ~substring:"fold-007")
           (equal_to true);
         field
           (fun d -> String.is_substring d ~substring:"cellX")
           (equal_to true);
         field
           (fun d -> String.is_substring d ~substring:"orig desc")
           (equal_to true);
       ])

(* ---------- build_all: cross product order ---------- *)

let test_build_all_cross_product _ =
  let base = _make_base ~name:"X" () in
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 6 30;
      train_days = 0;
      test_days = 30;
      step_days = 60;
    }
  in
  (* Folds at 01-01, 03-01, 05-01 (step=60) = 3 folds. Wait: 01-01 + 60 = 03-01,
     +60 = 05-01. test 05-01..05-30 ends by 06-30. fold-3 anchor 06-30, test
     ends past 06-30 → drop. So 3 folds. *)
  let variants : WFR.variant list =
    [ { label = "A"; overrides = [] }; { label = "B"; overrides = [] } ]
  in
  let scenarios = WFR.build_all ~base ~spec ~variants in
  let names = List.map scenarios ~f:(fun (s : Scenario.t) -> s.name) in
  assert_that names
    (elements_are
       [
         equal_to "X-A-fold-000";
         equal_to "X-A-fold-001";
         equal_to "X-A-fold-002";
         equal_to "X-B-fold-000";
         equal_to "X-B-fold-001";
         equal_to "X-B-fold-002";
       ])

let test_build_all_empty_variants_yields_empty _ =
  let base = _make_base () in
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 6 30;
      train_days = 0;
      test_days = 30;
      step_days = 30;
    }
  in
  let scenarios = WFR.build_all ~base ~spec ~variants:[] in
  assert_that scenarios (size_is 0)

(* ---------- Variant sexp round-trip ---------- *)

let test_variant_sexp_round_trip _ =
  let ov = Sexp.of_string "((some_key 0.5))" in
  let v : WFR.variant = { label = "cell-X"; overrides = [ ov ] } in
  let parsed = WFR.variant_of_sexp (WFR.sexp_of_variant v) in
  assert_that parsed
    (all_of
       [
         field (fun (v : WFR.variant) -> v.label) (equal_to "cell-X");
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are [ equal_to ov ]);
       ])

let suite =
  "Walk_forward_runner"
  >::: [
         "name composes base/variant/fold"
         >:: test_name_composes_base_variant_fold;
         "period is fold's test_period" >:: test_period_is_test_period_of_fold;
         "overrides appended last" >:: test_overrides_appended_last;
         "universe + strategy preserved"
         >:: test_universe_and_strategy_preserved;
         "slippage_bps preserved" >:: test_slippage_bps_preserved;
         "description marks fold + variant"
         >:: test_description_marks_fold_and_variant;
         "build_all cross product order" >:: test_build_all_cross_product;
         "build_all empty variants yields empty"
         >:: test_build_all_empty_variants_yields_empty;
         "variant sexp round-trip" >:: test_variant_sexp_round_trip;
       ]

let () = run_test_tt_main suite
