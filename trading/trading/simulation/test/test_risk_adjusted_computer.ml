(** Pinned tests for {!Risk_adjusted_computer} (M5.2c).

    Each test pins the entire output set (Omega for the step-based computer;
    Sortino / MAR for the derived computers) against hand-computed values. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_step ~date ~portfolio_value : Simulator_types.step_result =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ()
  in
  {
    date;
    portfolio;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
  }

let _config =
  {
    Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-12-31";
    initial_cash = 10_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

(* ==================== Omega ==================== *)

let _run_omega steps =
  let computer = Trading_simulation.Risk_adjusted_computer.computer () in
  computer.run ~config:_config ~steps

(** Empty input: Omega is 0 because there are no returns above or below the
    threshold (numerator and denominator both 0; convention is [0.0]). *)
let test_omega_empty _ =
  let metrics = _run_omega [] in
  assert_that (Map.find metrics OmegaRatio) (is_some_and (float_equal 0.0))

(** Three steps: 10000 → 10500 → 9975. Returns = [+5%, -5%]. Upside sum = 5;
    downside sum = 5. Omega = 5 / 5 = 1.0. *)
let test_omega_balanced _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:9_975.0;
    ]
  in
  let metrics = _run_omega steps in
  assert_that
    (Map.find metrics OmegaRatio)
    (is_some_and (float_equal ~epsilon:1e-6 1.0))

(** Two equal-magnitude up-moves and one down-move:
    - 10000 → 10500 = +5%
    - 10500 → 11025 = +5%
    - 11025 → 9922.5 = -10%

    Upside sum = 5 + 5 = 10. Downside sum = 10. Omega = 10 / 10 = 1.0. (Pinning
    a known equality makes this an obvious sanity check that the area model
    isn't double-counting.) *)
let test_omega_two_ups_one_down _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:11_025.0;
      _make_step ~date:(_date "2024-01-05") ~portfolio_value:9_922.5;
    ]
  in
  let metrics = _run_omega steps in
  assert_that
    (Map.find metrics OmegaRatio)
    (is_some_and (float_equal ~epsilon:1e-6 1.0))

(** All-positive returns → infinity. *)
let test_omega_all_positive_is_infinity _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:10_500.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:11_025.0;
    ]
  in
  let metrics = _run_omega steps in
  assert_that
    (Map.find metrics OmegaRatio)
    (is_some_and (equal_to Float.infinity))

(** Asymmetric upside vs. downside.
    - 10000 → 11000 = +10%
    - 11000 → 10450 = -5%

    Upside sum = 10. Downside sum = 5. Omega = 10 / 5 = 2.0. *)
let test_omega_asymmetric _ =
  let steps =
    [
      _make_step ~date:(_date "2024-01-02") ~portfolio_value:10_000.0;
      _make_step ~date:(_date "2024-01-03") ~portfolio_value:11_000.0;
      _make_step ~date:(_date "2024-01-04") ~portfolio_value:10_450.0;
    ]
  in
  let metrics = _run_omega steps in
  assert_that
    (Map.find metrics OmegaRatio)
    (is_some_and (float_equal ~epsilon:1e-6 2.0))

(* ==================== Sortino ==================== *)

let _run_sortino base_metrics =
  Trading_simulation.Risk_adjusted_computer.sortino_ratio_derived.compute
    ~config:_config ~base_metrics

(** With CAGR = 20% and DownsideDev = 10%, Sortino = 2.0. *)
let test_sortino_basic _ =
  let base =
    of_alist_exn [ (CAGR, 20.0); (DownsideDeviationPctAnnualized, 10.0) ]
  in
  let metrics = _run_sortino base in
  assert_that
    (Map.find metrics SortinoRatioAnnualized)
    (is_some_and (float_equal ~epsilon:1e-6 2.0))

(** Zero downside dev → 0 (avoid division by zero). *)
let test_sortino_zero_downside _ =
  let base =
    of_alist_exn [ (CAGR, 20.0); (DownsideDeviationPctAnnualized, 0.0) ]
  in
  let metrics = _run_sortino base in
  assert_that
    (Map.find metrics SortinoRatioAnnualized)
    (is_some_and (float_equal 0.0))

(** Negative CAGR → negative Sortino. *)
let test_sortino_negative_cagr _ =
  let base =
    of_alist_exn [ (CAGR, -10.0); (DownsideDeviationPctAnnualized, 5.0) ]
  in
  let metrics = _run_sortino base in
  assert_that
    (Map.find metrics SortinoRatioAnnualized)
    (is_some_and (float_equal ~epsilon:1e-6 (-2.0)))

(* ==================== MAR ==================== *)

let _run_mar base_metrics =
  Trading_simulation.Risk_adjusted_computer.mar_ratio_derived.compute
    ~config:_config ~base_metrics

(** With CAGR = 25% and MaxDrawdown = 10%, MAR = 2.5. *)
let test_mar_basic _ =
  let base = of_alist_exn [ (CAGR, 25.0); (MaxDrawdown, 10.0) ] in
  let metrics = _run_mar base in
  assert_that
    (Map.find metrics MarRatio)
    (is_some_and (float_equal ~epsilon:1e-6 2.5))

(** Zero max DD → 0 (avoid division by zero). *)
let test_mar_zero_max_dd _ =
  let base = of_alist_exn [ (CAGR, 25.0); (MaxDrawdown, 0.0) ] in
  let metrics = _run_mar base in
  assert_that (Map.find metrics MarRatio) (is_some_and (float_equal 0.0))

(** MAR matches the canonical CalmarRatio formula on the same inputs (= CAGR /
    MaxDrawdown). This is the cross-check called out in the M5.2c plan. *)
let test_mar_matches_calmar_formula _ =
  let cagr = 30.0 in
  let max_dd = 12.0 in
  let base = of_alist_exn [ (CAGR, cagr); (MaxDrawdown, max_dd) ] in
  let mar = Map.find_exn (_run_mar base) MarRatio in
  let expected_calmar = cagr /. max_dd in
  assert_that mar (float_equal ~epsilon:1e-6 expected_calmar)

let suite =
  "Risk_adjusted_computer"
  >::: [
         "omega: empty steps yields 0" >:: test_omega_empty;
         "omega: balanced up/down → 1.0" >:: test_omega_balanced;
         "omega: two ups + one offsetting down → 1.0"
         >:: test_omega_two_ups_one_down;
         "omega: all-positive returns → infinity"
         >:: test_omega_all_positive_is_infinity;
         "omega: asymmetric upside dominates → 2.0" >:: test_omega_asymmetric;
         "sortino: 20%/10% → 2.0" >:: test_sortino_basic;
         "sortino: zero downside dev → 0" >:: test_sortino_zero_downside;
         "sortino: negative CAGR → negative Sortino"
         >:: test_sortino_negative_cagr;
         "mar: 25%/10% → 2.5" >:: test_mar_basic;
         "mar: zero max DD → 0" >:: test_mar_zero_max_dd;
         "mar matches calmar formula on shared inputs"
         >:: test_mar_matches_calmar_formula;
       ]

let () = run_test_tt_main suite
