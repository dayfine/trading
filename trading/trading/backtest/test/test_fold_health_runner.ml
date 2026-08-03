(** Runner-path tests for the {!Backtest.Fold_health} divergence guard (#1557
    item 1). Exercises the wiring that
    {!Backtest.Fold_health_runner.divergence_findings} threads — open portfolio
    positions ([final_portfolio]) vs strategy positions still under stop
    evaluation ([n_stop_eligible_positions]) — rather than the pure
    {!Backtest.Fold_health.check_divergence} (already pinned by
    [test_fold_health.ml]).

    The motivating specimen (#1553): a position the portfolio holds whose
    strategy state is terminally [Exiting] after a rejected exit fill — the stop
    machinery only re-evaluates [Holding], so it rode an adverse move unbounded.
    The runner surfaces it as the gap between the two counts.

    - {b Firing}: a [Runner.result] with two open portfolio positions but only
      one stop-eligible → [open_position_count = 2] and a single
      [Stuck_held_positions { n_open_positions = 2; n_stop_eligible = 1 }]
      finding.
    - {b Healthy}: two open positions, two stop-eligible → no divergence finding
      (the default-0 tolerance is exactly met, gap = 0). *)

open OUnit2
open Core
open Matchers

let _date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:15

(** Single-lot open position keyed by [symbol]. Quantity is positive (long); the
    divergence guard counts positions, not direction. *)
let _make_position ~symbol : Trading_portfolio.Types.portfolio_position =
  {
    symbol;
    accounting_method = Trading_portfolio.Types.AverageCost;
    lots =
      [
        {
          lot_id = symbol ^ "-1";
          quantity = 100.0;
          cost_basis = 5_000.0;
          acquisition_date = _date;
        };
      ];
  }

let _make_portfolio ~positions : Trading_portfolio.Portfolio.t =
  {
    initial_cash = 100_000.0;
    trade_history = [];
    current_cash = 50_000.0;
    positions;
    accounting_method = Trading_portfolio.Types.AverageCost;
    unrealized_pnl_per_position = [];
    locked_collateral = 0.0;
    accrued_borrow_fee = 0.0;
    exempt_closing_trades_from_cash_floor = false;
    long_margin_debit = 0.0;
  }

let _empty_summary : Backtest.Summary.t =
  {
    start_date = _date;
    end_date = _date;
    universe_size = 1;
    n_steps = 0;
    initial_cash = 100_000.0;
    final_portfolio_value = 100_000.0;
    n_round_trips = 0;
    stale_held_symbols = [];
    metrics = Trading_simulation_types.Metric_types.empty;
  }

(** [Runner.result] with [n_open] open portfolio positions and [n_stop_eligible]
    strategy positions still under stop evaluation. Only the two divergence
    inputs are meaningful; the remaining fields are empty since
    {!Backtest.Fold_health_runner.divergence_findings} reads none of them. *)
let _make_result ?(summary = _empty_summary) ~n_open ~n_stop_eligible () :
    Backtest.Runner.result =
  let positions =
    List.init n_open ~f:(fun i -> _make_position ~symbol:(sprintf "SYM%d" i))
  in
  {
    summary;
    round_trips = [];
    steps = [];
    final_portfolio = _make_portfolio ~positions;
    n_stop_eligible_positions = n_stop_eligible;
    overrides = [];
    stop_infos = [];
    audit = [];
    cascade_summaries = [];
    force_liquidations = [];
    stale_holds = [];
    final_prices = [];
    universe = [];
  }

let config = Backtest.Fold_health.default_config

(* A held position the strategy no longer monitors (stuck-[Exiting] zombie) →
   open count exceeds stop-eligible count → the divergence finding fires through
   the runner bridge. *)
let test_divergence_fires_through_runner _ =
  let result = _make_result ~n_open:2 ~n_stop_eligible:1 () in
  assert_that
    (Backtest.Fold_health_runner.open_position_count result.final_portfolio)
    (equal_to 2);
  assert_that
    (Backtest.Fold_health_runner.divergence_findings ~config result)
    (elements_are
       [
         equal_to
           (Backtest.Fold_health.Stuck_held_positions
              { n_open_positions = 2; n_stop_eligible = 1 });
       ])

(* Every open position is [Holding] (under stop evaluation) → no gap → silent.
   The tripwire stays quiet on healthy runs. *)
let test_no_divergence_when_aligned _ =
  let result = _make_result ~n_open:2 ~n_stop_eligible:2 () in
  assert_that
    (Backtest.Fold_health_runner.divergence_findings ~config result)
    (size_is 0)

(* No open positions and none eligible → trivially aligned → silent. *)
let test_no_divergence_when_flat _ =
  let result = _make_result ~n_open:0 ~n_stop_eligible:0 () in
  assert_that
    (Backtest.Fold_health_runner.divergence_findings ~config result)
    (size_is 0)

(* [all_findings] unions the {!Fold_health.check} invariants with the divergence
   guard, check findings first. A 60-step zero-round-trip run (trips the
   long-window guard) that also holds a stuck position yields both, in order. *)
let test_all_findings_unions_check_and_divergence _ =
  let summary = { _empty_summary with n_steps = 60; n_round_trips = 0 } in
  let result = _make_result ~summary ~n_open:2 ~n_stop_eligible:1 () in
  assert_that
    (Backtest.Fold_health_runner.all_findings ~config result)
    (elements_are
       [
         equal_to
           (Backtest.Fold_health.Zero_round_trips_over_long_window
              { n_steps = 60 });
         equal_to
           (Backtest.Fold_health.Stuck_held_positions
              { n_open_positions = 2; n_stop_eligible = 1 });
       ])

(* A healthy run (short window, aligned counts) trips nothing on either axis. *)
let test_all_findings_healthy_is_empty _ =
  let result = _make_result ~n_open:2 ~n_stop_eligible:2 () in
  assert_that
    (Backtest.Fold_health_runner.all_findings ~config result)
    (size_is 0)

(* [emit] writes the finding union to [<output_dir>/fold_health.sexp]; the file
   round-trips back to the same list. *)
let test_emit_writes_findings_sexp _ =
  let result = _make_result ~n_open:2 ~n_stop_eligible:1 () in
  let output_dir = Filename_unix.temp_dir "fold_health_emit" "" in
  Backtest.Fold_health_runner.emit ~output_dir result;
  let loaded = Sexp.load_sexp (Filename.concat output_dir "fold_health.sexp") in
  assert_that
    ([%of_sexp: Backtest.Fold_health.finding list] loaded)
    (elements_are
       [
         equal_to
           (Backtest.Fold_health.Stuck_held_positions
              { n_open_positions = 2; n_stop_eligible = 1 });
       ])

let suite =
  "fold_health_runner"
  >::: [
         "divergence fires through runner"
         >:: test_divergence_fires_through_runner;
         "no divergence when aligned" >:: test_no_divergence_when_aligned;
         "no divergence when flat" >:: test_no_divergence_when_flat;
         "all_findings unions check and divergence"
         >:: test_all_findings_unions_check_and_divergence;
         "all_findings healthy is empty" >:: test_all_findings_healthy_is_empty;
         "emit writes findings sexp" >:: test_emit_writes_findings_sexp;
       ]

let () = run_test_tt_main suite
