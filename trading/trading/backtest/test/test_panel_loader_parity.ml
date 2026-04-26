(** Panel-mode round-trips golden parity gate — see
    [dev/plans/data-panels-stage3-2026-04-25.md] §PR 3.1.

    Stage 3 PR 3.1 wired [~bar_panels] into [Panel_runner._build_strategy] so
    the inner Weinstein strategy reads bars from {!Data_panel.Bar_panels}
    instead of the parallel {!Bar_history} cache. As of that wiring, Panel-mode
    and Tiered-mode round_trips diverge by design: Tiered seeds [Bar_history]
    incrementally per Friday Full-tier promote (not-yet-promoted symbols read as
    empty), while [Bar_panels] is fully populated up-front from CSV. Same
    strategy + same data → different trade decisions because the bar visibility
    timing differs. The pre-3.1 [Tiered_vs_Panel] parity test is therefore
    obsolete; the long-term parity gate is a Tiered-side test that will be
    deleted in PR 3.3 once Tiered is removed entirely.

    This test pins Panel-mode behaviour to a checked-in golden sexp. For each
    scenario the test:

    - Loads the scenario, runs [run_backtest ~loader_strategy:Panel].
    - Extracts the [round_trips] list (every [Metrics.trade_metrics] field).
    - Compares against [test_data/backtest_scenarios/panel_goldens/<name>.sexp].

    Float fields use [equal_to] on bit-equal floats. Sexp roundtrip preserves
    IEEE 754 bit patterns at default precision, so comparing the parsed golden
    via [equal_to] is bit-equality. Any drift (recompiled kernel, floating-point
    reorder, strategy logic change) fails the test.

    {b Regenerating goldens.} Set [PANEL_GOLDEN_REGENERATE=1] in the environment
    and run the test once; missing or stale goldens are written to disk and the
    assertion is skipped. Diff the result, eyeball the trades for sanity (sym,
    dates within scenario bounds, exit_reason valid), then commit the new
    goldens. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Metrics = Trading_simulation.Metrics

(* -------------------------------------------------------------------- *)
(* Golden trade record + sexp roundtrip                                  *)
(* -------------------------------------------------------------------- *)

type golden_trade = {
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
[@@deriving sexp, eq]
(** Mirror of [Metrics.trade_metrics] with sexp deriving. Kept local to this
    test rather than added to [Metrics] (the simulation library does not depend
    on [ppx_sexp_conv]; widening that for a single test is heavier than mapping
    here). Adding/removing fields here without mirroring [trade_metrics] is a
    test-build break, which is the desired coupling. *)

let _to_golden (t : Metrics.trade_metrics) : golden_trade =
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
(* Paths + scenario loading                                              *)
(* -------------------------------------------------------------------- *)

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _goldens_dir () = Filename.concat (_fixtures_root ()) "panel_goldens"
let _scenario_path rel = Filename.concat (_fixtures_root ()) rel
let _golden_path ~name = Filename.concat (_goldens_dir ()) (name ^ ".sexp")
let _load_scenario rel = Scenario.load (_scenario_path rel)

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run_panel (s : Scenario.t) : Metrics.trade_metrics list =
  let sector_map_override = _sector_map_override s in
  let result =
    try
      Backtest.Runner.run_backtest ~start_date:s.period.start_date
        ~end_date:s.period.end_date ~overrides:s.config_overrides
        ?sector_map_override ~loader_strategy:Loader_strategy.Panel ()
    with e ->
      OUnit2.assert_failure
        (sprintf "run_backtest raised under Panel: %s" (Exn.to_string e))
  in
  result.round_trips

(* -------------------------------------------------------------------- *)
(* Golden read / write                                                   *)
(* -------------------------------------------------------------------- *)

let _regenerate_requested () =
  match Sys.getenv "PANEL_GOLDEN_REGENERATE" with
  | Some "1" -> true
  | _ -> false

let _write_golden ~path goldens =
  Core_unix.mkdir_p (Filename.dirname path);
  let sexp = [%sexp_of: golden_trade list] goldens in
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum sexp);
      Out_channel.output_char oc '\n')

let _load_golden ~path : golden_trade list =
  [%of_sexp: golden_trade list] (Sexp.load_sexp path)

(** Whole-record bit-equality. Uses the [@@deriving eq] generated comparator,
    which on floats is structural [=] — bit-equal for any non-NaN value (and no
    NaN occurs in panel-mode trade fields by construction). Sexp roundtrip
    preserves IEEE 754 bit patterns at default precision, so the parsed-golden
    record compares bit-equal to a freshly-computed one when nothing has
    drifted. Failure messages use the [@@deriving show] formatter so a diverging
    trade prints all fields side-by-side. *)
let _trade_matcher (g : golden_trade) : golden_trade matcher = equal_to g

(* -------------------------------------------------------------------- *)
(* Scenario fixtures                                                     *)
(* -------------------------------------------------------------------- *)

(** Each entry: ([scenario_name], [scenario_relpath]). [scenario_name] is the
    stem used for the golden file ([panel_goldens/<name>.sexp]). *)
let _scenarios : (string * string) list =
  [
    ("tiered-loader-parity", "smoke/tiered-loader-parity.sexp");
    ("panel-golden-2019-full", "smoke/panel-golden-2019-full.sexp");
  ]

(* -------------------------------------------------------------------- *)
(* Test logic                                                            *)
(* -------------------------------------------------------------------- *)

(** Run the panel backtest, capture the goldens to disk, and print a brief
    summary so the human running the regenerate has a one-pass view of what
    landed. Caller decides whether to assert equality afterwards. *)
let _capture_and_skip ~name ~path ~observed =
  _write_golden ~path observed;
  printf
    "[panel-goldens] regenerated %s (%d round_trips) — assertion skipped\n%!"
    name (List.length observed);
  OUnit2.skip_if true (sprintf "PANEL_GOLDEN_REGENERATE=1 — wrote %s" path)

let _assert_round_trips_match_golden ~name ~scenario_rel _ctxt =
  let observed =
    List.map (_run_panel (_load_scenario scenario_rel)) ~f:_to_golden
  in
  let path = _golden_path ~name in
  let regenerate = _regenerate_requested () in
  let golden_missing =
    not (Core_unix.access path [ `Exists ] |> Result.is_ok)
  in
  if regenerate || golden_missing then _capture_and_skip ~name ~path ~observed
  else
    let golden = _load_golden ~path in
    assert_that observed (elements_are (List.map golden ~f:_trade_matcher))

let _make_test (name, scenario_rel) =
  "panel-mode round_trips match golden: " ^ name
  >:: _assert_round_trips_match_golden ~name ~scenario_rel

let suite = "Panel_round_trips_golden" >::: List.map _scenarios ~f:_make_test
let () = run_test_tt_main suite
