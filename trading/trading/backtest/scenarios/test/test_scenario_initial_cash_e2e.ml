(** End-to-end wiring of the scenario [initial_cash] field (#3696) through
    [Backtest.Runner.run_backtest]'s [?initial_cash] seam.

    Runs the tier-1 smoke scenario [smoke/panel-golden-2019-full.sexp]
    (universes/parity-7sym.sexp, 2019-05-01..2020-01-03) twice, the same way
    [scenario_runner] does ([Scenario_universe.of_scenario] for the universe,
    [s.initial_cash] for the starting cash):

    - {b default} — the committed spec, which has no [initial_cash] line, so it
      runs at {!Backtest.Runner.default_initial_cash} ($1M);
    - {b 100k} — the same spec with [(initial_cash 100000.0)] appended to the
      sexp before parsing.

    Sizing is a fraction of portfolio value, so the 100k run's first entries
    must be the same names on the same day at 1/10 the share count, up to
    integer-share rounding. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Metrics = Trading_simulation.Metrics

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_relpath = "smoke/panel-golden-2019-full.sexp"
let _small_cash = 100_000.0

(* Cash ratio between the default run and the small run. *)
let _cash_ratio = 10

let _spec_sexp () =
  Sexp.load_sexp (Filename.concat (_fixtures_root ()) _scenario_relpath)

let _default_scenario () = Scenario.t_of_sexp (_spec_sexp ())

(* The committed spec with an [(initial_cash 100000.0)] field appended, parsed
   through the real [Scenario.t_of_sexp]. *)
let _small_scenario () =
  match _spec_sexp () with
  | Sexp.List fields ->
      let field =
        Sexp.List
          [ Sexp.Atom "initial_cash"; Sexp.Atom (Float.to_string _small_cash) ]
      in
      Scenario.t_of_sexp (Sexp.List (fields @ [ field ]))
  | Sexp.Atom _ -> assert_failure "scenario spec is not a record sexp"

let _run (s : Scenario.t) =
  let sector_map_override, universe_membership_at =
    Scenario_lib.Scenario_universe.of_scenario
      ~fixtures_root:(_fixtures_root ()) s
  in
  Backtest.Runner.run_backtest ~start_date:s.period.start_date
    ~end_date:s.period.end_date ~initial_cash:s.initial_cash
    ~overrides:s.config_overrides ?sector_map_override ?universe_membership_at
    ~strategy_choice:s.strategy ()

let _default_result = lazy (_run (_default_scenario ()))
let _small_result = lazy (_run (_small_scenario ()))

(* Round trips entered on the run's earliest entry date, as
   [(symbol, entry_date, quantity)] sorted by symbol. *)
let _first_entries (result : Backtest.Runner.result) =
  let trades = result.round_trips in
  match
    List.min_elt trades ~compare:(fun (a : Metrics.trade_metrics) b ->
        Date.compare a.entry_date b.entry_date)
  with
  | None -> []
  | Some first ->
      List.filter trades ~f:(fun (t : Metrics.trade_metrics) ->
          Date.equal t.entry_date first.entry_date)
      |> List.map ~f:(fun (t : Metrics.trade_metrics) ->
          (t.symbol, t.entry_date, t.quantity))
      |> List.sort ~compare:(fun (a, _, _) (b, _, _) -> String.compare a b)

(** A spec without the field runs at $1M, recorded in the summary. *)
let test_spec_without_field_runs_at_default _ =
  let s = _default_scenario () in
  assert_that s.initial_cash (float_equal Backtest.Runner.default_initial_cash);
  assert_that (Lazy.force _default_result).summary.initial_cash
    (float_equal 1_000_000.0)

(** A spec with [(initial_cash 100000.0)] records 100000 in the summary. *)
let test_spec_with_field_records_it_in_summary _ =
  assert_that (Lazy.force _small_result).summary.initial_cash
    (float_equal _small_cash)

(* [small] is [big] / [_cash_ratio] up to integer-share flooring of each:
   [_cash_ratio * small] lies within one share-block of [big]. *)
let _scaled_quantity_matcher (symbol, date, big) =
  all_of
    [
      field (fun (s, _, _) -> s) (equal_to symbol);
      field (fun (_, d, _) -> d) (equal_to date);
      field
        (fun (_, _, small) ->
          Float.abs ((Float.of_int _cash_ratio *. small) -. big))
        (le (module Float_ord) (Float.of_int _cash_ratio));
    ]

(** The 100k run's first entries are the default run's names, same day, at 1/10
    the share count. The default run's list is checked non-empty first so the
    comparison is not vacuous. *)
let test_first_entry_sizes_scale_with_cash _ =
  let default_entries = _first_entries (Lazy.force _default_result) in
  assert_that default_entries (not_ is_empty);
  assert_that
    (_first_entries (Lazy.force _small_result))
    (elements_are (List.map default_entries ~f:_scaled_quantity_matcher))

let suite =
  "scenario_initial_cash_e2e"
  >::: [
         "spec without initial_cash runs at 1M"
         >:: test_spec_without_field_runs_at_default;
         "spec with initial_cash 100000 records it in the summary"
         >:: test_spec_with_field_records_it_in_summary;
         "first-entry sizes scale 1/10 with initial_cash"
         >:: test_first_entry_sizes_scale_with_cash;
       ]

let () = run_test_tt_main suite
