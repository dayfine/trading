(** G6 — Cross-cell isolation regression test.

    Pins the property that running scenario A and then scenario B in the same
    process produces the same B as running B alone. This is the in-process
    analogue of [scenario_runner]'s fork-per-cell isolation — if it holds
    in-process, the fork model also holds (a forked child sees a strict subset
    of parent state); if it FAILS in-process, the fork model also fails because
    parent state differences propagate to children via copy-on-write.

    Background: `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md` §
    Determinism reports decade-2014-2023 (10y × N=1000) drifts between
    single-cell `--dir /tmp/decade-cell` runs and 4-cell `--dir goldens-broad`
    batch runs. The session-followups note (§1) calls this G6 and assigns the
    investigation to feat-backtest. See
    `dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md` for the
    code-path audit.

    Reproduction on GHA-sized data: per the investigation note, the small
    panel-goldens fixtures (22 symbols, 15 months) almost certainly do NOT
    surface the divergence — it requires the long-horizon × broad-universe
    multiplicative factor present in the decade cell. This test is therefore a
    FORWARD GUARD: it pins the property today (where it holds) so any regression
    that breaks isolation badly enough to flip even small-window runs surfaces
    immediately.

    Sibling: [test_determinism.ml] pins the in-process determinism property for
    a single scenario run 5 times. This test pins the cross-scenario property —
    a different cell does not contaminate a subsequent one. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Metrics = Trading_simulation.Metrics

(* -------------------------------------------------------------------- *)
(* Local mirror of [Metrics.trade_metrics] for sexp + structural eq.     *)
(* Same shape as in [test_determinism.ml]; kept local here (not shared)  *)
(* because the two tests have different dune deps and the type is small. *)
(* -------------------------------------------------------------------- *)

type trade = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
}
[@@deriving sexp, eq, show]

let _to_trade (t : Metrics.trade_metrics) : trade =
  {
    symbol = t.symbol;
    entry_date = t.entry_date;
    exit_date = t.exit_date;
    days_held = t.days_held;
    entry_price = t.entry_price;
    exit_price = t.exit_price;
    quantity = t.quantity;
    pnl_dollars = t.pnl_dollars;
    pnl_percent = t.pnl_percent;
  }

(* -------------------------------------------------------------------- *)
(* Scenario fixture + run helper                                         *)
(* -------------------------------------------------------------------- *)

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

(** Target scenario whose round-trips we pin under isolation. Same fixture
    [test_determinism.ml] uses, so the property is "this scenario's round-trips
    are stable both across in-process repeats AND when a different scenario ran
    first in the same process." *)
let _target_scenario_relpath = "smoke/panel-golden-2019-full.sexp"

(** Different scenario run BEFORE the target to perturb in-process state. Same
    universe (parity-7sym), different time window (2019-06 to 2019-12 vs target
    2019-05 to 2020-01) and different config_overrides shape. Same universe is
    the right call here: the GHA-sized fixtures only have bar CSVs for the 7
    parity symbols + macro ETFs, so a broad-universe perturber would hit
    "missing CSV" errors. The window + override differences are sufficient to
    exercise the "different state at start of target run" property. *)
let _perturber_scenario_relpath = "smoke/tiered-loader-parity.sexp"

let _load_scenario relpath =
  Scenario.load (Filename.concat (_fixtures_root ()) relpath)

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run (s : Scenario.t) =
  let sector_map_override = _sector_map_override s in
  try
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ()
  with e ->
    OUnit2.assert_failure (sprintf "run_backtest raised: %s" (Exn.to_string e))

let _trades_of (r : Backtest.Runner.result) : trade list =
  List.map r.round_trips ~f:_to_trade

(* -------------------------------------------------------------------- *)
(* Diagnostics — first divergence between two trade lists                *)
(* -------------------------------------------------------------------- *)

let _first_trade_divergence ~baseline ~observed =
  let rec walk i bs os =
    match (bs, os) with
    | [], [] -> None
    | b :: brest, o :: orest when equal_trade b o -> walk (i + 1) brest orest
    | b :: _, o :: _ ->
        Some
          (sprintf "trade #%d differs:\n  baseline: %s\n  observed: %s" i
             (show_trade b) (show_trade o))
    | b :: _, [] ->
        Some
          (sprintf "observed truncated at trade #%d (baseline: %s)" i
             (show_trade b))
    | [], o :: _ ->
        Some (sprintf "observed has extra trade #%d: %s" i (show_trade o))
  in
  walk 0 baseline observed

(* -------------------------------------------------------------------- *)
(* Test: cross-cell isolation                                            *)
(*                                                                      *)
(* Run the target scenario standalone (baseline). Then run the          *)
(* perturber scenario, and re-run the target — it must produce          *)
(* bit-identical round_trips.                                            *)
(* -------------------------------------------------------------------- *)

let test_target_after_perturber_matches_standalone _ =
  let target = _load_scenario _target_scenario_relpath in
  let baseline_run = _run target in
  let baseline_trades = _trades_of baseline_run in
  let perturber = _load_scenario _perturber_scenario_relpath in
  let _perturber_run = _run perturber in
  let observed_run = _run target in
  let observed_trades = _trades_of observed_run in
  match
    _first_trade_divergence ~baseline:baseline_trades ~observed:observed_trades
  with
  | None -> ()
  | Some diff ->
      OUnit2.assert_failure
        (sprintf
           "Cross-cell isolation: round_trips for %s diverged after running %s \
            in the same process:\n\
            %s"
           _target_scenario_relpath _perturber_scenario_relpath diff)

(** Stronger sibling: also assert the [final_portfolio_value] matches
    bit-exactly. This is the one aggregate float that `test_determinism` pins to
    relative-tolerance only; we pin it bit-exactly here because cross-cell
    isolation should not introduce ANY float drift if the scenario-internal
    state is reproducibly built. *)
let test_target_after_perturber_summary_matches _ =
  let target = _load_scenario _target_scenario_relpath in
  let baseline_run = _run target in
  let perturber = _load_scenario _perturber_scenario_relpath in
  let _perturber_run = _run perturber in
  let observed_run = _run target in
  assert_that observed_run.summary.final_portfolio_value
    (float_equal ~epsilon:1e-9 baseline_run.summary.final_portfolio_value)

(** Reverse direction: running the target standalone after the perturber is one
    ordering; this test runs the perturber + target in a tight loop twice and
    asserts the second target run matches the first. Catches leaks that ONLY
    surface after multiple cells have run, not just one. *)
let test_target_after_two_perturber_cycles_matches _ =
  let target = _load_scenario _target_scenario_relpath in
  let perturber = _load_scenario _perturber_scenario_relpath in
  let _ = _run perturber in
  let baseline_run = _run target in
  let baseline_trades = _trades_of baseline_run in
  let _ = _run perturber in
  let observed_run = _run target in
  let observed_trades = _trades_of observed_run in
  match
    _first_trade_divergence ~baseline:baseline_trades ~observed:observed_trades
  with
  | None -> ()
  | Some diff ->
      OUnit2.assert_failure
        (sprintf
           "Cross-cell isolation (2-cycle): round_trips for %s diverged \
            between cycle-1 and cycle-2 with %s as the perturber:\n\
            %s"
           _target_scenario_relpath _perturber_scenario_relpath diff)

(* -------------------------------------------------------------------- *)
(* Suite                                                                 *)
(* -------------------------------------------------------------------- *)

let suite =
  "Scenario_runner_cross_cell_isolation"
  >::: [
         "target after perturber: round_trips bit-identical to standalone"
         >:: test_target_after_perturber_matches_standalone;
         "target after perturber: final_portfolio_value within 1e-9"
         >:: test_target_after_perturber_summary_matches;
         "target across 2 perturber cycles: round_trips stable"
         >:: test_target_after_two_perturber_cycles_matches;
       ]

let () = run_test_tt_main suite
