(** [barbell_floor_sweep_runner] — sweep the barbell overlay's [floor_weight]
    over a list of values and write the comparison surface.

    R2 completion for the deployable barbell overlay (gate #2): makes
    {!Barbell.Barbell_config.floor_weight} a {b searchable surface}. Given a
    scenario sexp (period + universe + snapshot context) and a list of floor
    weights, run the FLOOR and ENGINE legs {e once each} over the window, then
    blend their two equity curves at every requested weight — only the blend
    weight varies across the surface, so the legs are weight-independent and
    need not re-run per cell. Writes one metric row per weight to
    [<out-dir>/floor_sweep.csv].

    This is a thin CLI shim over {!Barbell_scenario.run} (to obtain the two leg
    curves once) + {!Barbell.Barbell_floor_sweep.metrics_table} (the pure axis
    expansion + per-cell blend). No core-module edits — each sleeve reuses
    {!Backtest.Runner.run_backtest} unchanged.

    Default-off per [.claude/rules/experiment-flag-discipline.md]: enumerating
    weights flips no default; [0.0] is a valid (pure-engine no-op) cell. The
    documented promotion target is a light floor [~0.30-0.40]
    ([dev/backtest/barbell-grid-2026-06-20/FINDINGS.md]), but promoting any
    weight is a separate, ledger-gated decision.

    Usage:
    {[
      barbell_floor_sweep_runner --scenario <path.sexp> --out-dir <dir>
        [--floor-weights 0.2,0.3,0.4] [--rebalance-weeks N]
        [--floor-symbol SYMBOL] [--floor-ma-weeks N]
        [--fixtures-root <path>] [--snapshot-dir <path>]
    ]}

    [--floor-weights] (default [0.2,0.3,0.4,0.5]) is the comma-separated list of
    FLOOR-sleeve target fractions to compare. The remaining flags match
    [barbell_overlay_runner]. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Bar_source_resolver = Scenario_lib.Bar_source_resolver
module Sweep = Barbell.Barbell_floor_sweep
module Blend = Barbell.Barbell_blend

type _cli_args = {
  scenario : string;
  out_dir : string;
  floor_weights : float list;
  rebalance_weeks : int;
  floor_symbol : string;
  floor_ma_weeks : int;
  fixtures_root : string option;
  snapshot_dir : string option;
}

let _default_floor_weights = [ 0.2; 0.3; 0.4; 0.5 ]
let _default_rebalance_weeks = 1
let _default_floor_symbol = "SPY"
let _default_floor_ma_weeks = 30

let _usage () =
  eprintf
    "Usage: barbell_floor_sweep_runner --scenario <path.sexp> --out-dir <dir> \
     [--floor-weights 0.2,0.3,0.4] [--rebalance-weeks N] [--floor-symbol \
     SYMBOL] [--floor-ma-weeks N] [--fixtures-root <path>] [--snapshot-dir \
     <path>]\n";
  Stdlib.exit 1

let _parse_weights s =
  String.split s ~on:',' |> List.map ~f:String.strip
  |> List.filter ~f:(fun t -> not (String.is_empty t))
  |> List.map ~f:Float.of_string

type _parse_acc = {
  mutable scenario : string option;
  mutable out_dir : string option;
  mutable floor_weights : float list option;
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
        floor_weights =
          Option.value acc.floor_weights ~default:_default_floor_weights;
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
      floor_weights = None;
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
    | "--floor-weights" :: s :: rest ->
        acc.floor_weights <- Some (_parse_weights s);
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

(* Run the two legs once (at weight 0.0 — the engine no-op, so the returned
   per-leg curves are the unblended leg NAVs) and return them. floor_weight only
   changes the blend, never the legs, so one run feeds the whole surface. *)
let _run_legs_once ~scenario ~fixtures_root ~bar_data_source ~floor ~engine
    ~rebalance_weeks : (Date.t * float) list * (Date.t * float) list =
  let probe_config =
    {
      Barbell.Barbell_config.enable = true;
      floor_weight = 0.0;
      rebalance_weeks;
    }
  in
  let result =
    Barbell_scenario.run ~scenario ~fixtures_root ~bar_data_source
      ~config:probe_config ~floor ~engine
  in
  (result.floor.equity_curve, result.engine.equity_curve)

let _write_csv ~out_dir (rows : Sweep.row list) : string =
  let path = Filename.concat out_dir "floor_sweep.csv" in
  let header =
    "floor_weight,total_return_pct,sharpe,max_drawdown_pct,calmar,ulcer_pct,n_points"
  in
  let line (r : Sweep.row) =
    let m = r.metrics in
    Printf.sprintf "%.2f,%.4f,%.4f,%.4f,%.4f,%.4f,%d" r.floor_weight
      m.Blend.total_return_pct m.sharpe m.max_drawdown_pct m.calmar m.ulcer_pct
      m.n_points
  in
  let body = List.map rows ~f:line in
  Out_channel.write_lines path (header :: body);
  path

let () =
  let args = _parse_flags (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let bar_data_source = Bar_source_resolver.resolve args.snapshot_dir in
  let scenario = Scenario.load args.scenario in
  let floor =
    Barbell_scenario.spy_floor_leg ~symbol:args.floor_symbol
      ~ma_period_weeks:args.floor_ma_weeks ()
  in
  let engine =
    Barbell_scenario.engine_leg ~strategy:scenario.strategy
      ~overrides:scenario.config_overrides ()
  in
  Core_unix.mkdir_p args.out_dir;
  let floor_curve, engine_curve =
    _run_legs_once ~scenario ~fixtures_root ~bar_data_source ~floor ~engine
      ~rebalance_weeks:args.rebalance_weeks
  in
  let axis =
    {
      Sweep.floor_weights = args.floor_weights;
      rebalance_weeks = args.rebalance_weeks;
    }
  in
  let rows =
    Sweep.metrics_table axis ~blend:(fun config ->
        (Blend.blend ~config ~floor_curve ~engine_curve).metrics)
  in
  let path = _write_csv ~out_dir:args.out_dir rows in
  eprintf
    "barbell floor sweep: scenario=%s weights=[%s] rebalance_weeks=%d -> %s \
     (%d rows)\n\
     %!"
    scenario.name
    (String.concat ~sep:","
       (List.map args.floor_weights ~f:(Printf.sprintf "%.2f")))
    args.rebalance_weeks path (List.length rows)
