(** [barbell_overlay_runner] — run the deployable barbell overlay end-to-end on
    one scenario.

    Given a scenario sexp (which supplies the period + universe + snapshot
    context), run two capital sleeves — a FLOOR leg
    ({!Backtest.Strategy_choice.Spy_only_weinstein}, the SPY-timing floor) and
    an ENGINE leg (the full Weinstein Cell-E engine) — over that window, blend
    their equity curves to a constant [floor_weight : 1 - floor_weight] split on
    a configurable cadence, and write the combined NAV to
    [<out-dir>/equity_curve.csv].

    This is a thin CLI shim over {!Barbell_scenario.run}; the leg-thunk
    construction + blend live in that lib (unit-tested without a CLI) and in
    {!Barbell.Barbell_runner}. No core-module edits — each sleeve reuses
    {!Backtest.Runner.run_backtest} unchanged (Option A of
    [dev/plans/barbell-deployable-overlay-2026-06-21.md]).

    Default-off per [.claude/rules/experiment-flag-discipline.md]: with
    [--floor-weight 0.0] (the default) the blended NAV is the pure-engine curve,
    so invoking the overlay changes nothing until a weight is chosen. The
    documented promotion target is a light floor [~0.30-0.40]
    ([dev/backtest/barbell-grid-2026-06-20/FINDINGS.md]), but that flip is a
    separate, ledger-gated decision.

    Usage:
    {[
      barbell_overlay_runner --scenario <path.sexp> --out-dir <dir>
        [--floor-weight F] [--rebalance-weeks N] [--floor-symbol SYMBOL]
        [--floor-ma-weeks N] [--fixtures-root <path>] [--snapshot-dir <path>]
    ]}

    [--floor-weight F] (default [0.0]) is the FLOOR sleeve's target capital
    fraction in [[0,1]]; [0.0] = pure engine (no-op). [--rebalance-weeks N]
    (default [1]) is the cash-rebalance cadence (weekly; [1] reproduces the
    validated daily-equivalent blend at the runner's stride). [--floor-symbol]
    (default [SPY]) and [--floor-ma-weeks] (default [30], investor preset) tune
    the FLOOR leg. [--snapshot-dir] reads OHLCV from a pre-built snapshot
    warehouse (large-N path); omit for CSV mode. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Bar_source_resolver = Scenario_lib.Bar_source_resolver

type _cli_args = {
  scenario : string;
  out_dir : string;
  floor_weight : float;
  rebalance_weeks : int;
  floor_symbol : string;
  floor_ma_weeks : int;
  fixtures_root : string option;
  snapshot_dir : string option;
}

let _default_floor_weight = 0.0
let _default_rebalance_weeks = 1
let _default_floor_symbol = "SPY"
let _default_floor_ma_weeks = 30

let _usage () =
  eprintf
    "Usage: barbell_overlay_runner --scenario <path.sexp> --out-dir <dir> \
     [--floor-weight F] [--rebalance-weeks N] [--floor-symbol SYMBOL] \
     [--floor-ma-weeks N] [--fixtures-root <path>] [--snapshot-dir <path>]\n";
  Stdlib.exit 1

type _parse_acc = {
  mutable scenario : string option;
  mutable out_dir : string option;
  mutable floor_weight : float option;
  mutable rebalance_weeks : int option;
  mutable floor_symbol : string option;
  mutable floor_ma_weeks : int option;
  mutable fixtures_root : string option;
  mutable snapshot_dir : string option;
}

let _finalize (acc : _parse_acc) : _cli_args =
  match (acc.scenario, acc.out_dir) with
  | Some scenario, Some out_dir ->
      {
        scenario;
        out_dir;
        floor_weight =
          Option.value acc.floor_weight ~default:_default_floor_weight;
        rebalance_weeks =
          Option.value acc.rebalance_weeks ~default:_default_rebalance_weeks;
        floor_symbol =
          Option.value acc.floor_symbol ~default:_default_floor_symbol;
        floor_ma_weeks =
          Option.value acc.floor_ma_weeks ~default:_default_floor_ma_weeks;
        fixtures_root = acc.fixtures_root;
        snapshot_dir = acc.snapshot_dir;
      }
  | _ -> _usage ()

let _parse_flags args : _cli_args =
  let acc =
    {
      scenario = None;
      out_dir = None;
      floor_weight = None;
      rebalance_weeks = None;
      floor_symbol = None;
      floor_ma_weeks = None;
      fixtures_root = None;
      snapshot_dir = None;
    }
  in
  let rec loop = function
    | [] -> _finalize acc
    | "--scenario" :: p :: rest ->
        acc.scenario <- Some p;
        loop rest
    | "--out-dir" :: p :: rest ->
        acc.out_dir <- Some p;
        loop rest
    | "--floor-weight" :: f :: rest ->
        acc.floor_weight <- Some (Float.of_string f);
        loop rest
    | "--rebalance-weeks" :: n :: rest ->
        acc.rebalance_weeks <- Some (Int.of_string n);
        loop rest
    | "--floor-symbol" :: s :: rest ->
        acc.floor_symbol <- Some s;
        loop rest
    | "--floor-ma-weeks" :: n :: rest ->
        acc.floor_ma_weeks <- Some (Int.of_string n);
        loop rest
    | "--fixtures-root" :: p :: rest ->
        acc.fixtures_root <- Some p;
        loop rest
    | "--snapshot-dir" :: p :: rest ->
        acc.snapshot_dir <- Some p;
        loop rest
    | _ -> _usage ()
  in
  loop args

let () =
  let args = _parse_flags (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let bar_data_source = Bar_source_resolver.resolve args.snapshot_dir in
  let scenario = Scenario.load args.scenario in
  let config =
    {
      Barbell.Barbell_config.enable = true;
      floor_weight = args.floor_weight;
      rebalance_weeks = args.rebalance_weeks;
    }
  in
  let floor =
    Barbell_scenario.spy_floor_leg ~symbol:args.floor_symbol
      ~ma_period_weeks:args.floor_ma_weeks ()
  in
  let engine =
    Barbell_scenario.engine_leg ~strategy:scenario.strategy
      ~overrides:scenario.config_overrides ()
  in
  Core_unix.mkdir_p args.out_dir;
  let result =
    Barbell_scenario.run ~scenario ~fixtures_root ~bar_data_source ~config
      ~floor ~engine
  in
  Barbell.Barbell_runner.write_equity_curve result ~output_dir:args.out_dir;
  eprintf
    "barbell overlay: scenario=%s floor_weight=%.2f rebalance_weeks=%d -> \
     %s/equity_curve.csv (%d blended points)\n\
     %!"
    scenario.name args.floor_weight args.rebalance_weeks args.out_dir
    (List.length result.blend.nav_curve)
