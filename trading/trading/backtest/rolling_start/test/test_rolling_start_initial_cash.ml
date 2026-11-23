(** [Rolling_start_runner.run] honours the scenario's [initial_cash] (#3696).

    Runs the tier-1 smoke scenario [smoke/panel-golden-2019-full.sexp]
    (universes/parity-7sym.sexp, 2019-05-01..2020-01-03) as a one-start rolling
    sweep twice: at the spec's default $1M and with [initial_cash = 100_000.0].
    Every [per_start] column is a ratio, so the pin is the difference itself: at
    1/10 the cash, integer-share sizing and the $1 commission minimum move the
    run's return, so the two starts' [cagr_pct] must differ. If [_run_one]
    stopped passing [~initial_cash], both runs would start at $1M and be
    bit-identical. *)

open OUnit2
open Core
open Matchers
module Runner = Rolling_start.Rolling_start_runner
module Scenario = Scenario_lib.Scenario

let _small_cash = 100_000.0

(* Wider than the 2019-05-01..2020-01-03 window, so one start is enumerated. *)
let _stride_days = 400

let _fixtures_root () =
  Filename.concat
    (Data_path.default_data_dir () |> Fpath.to_string)
    "backtest_scenarios"

let _scenario () =
  Scenario.load
    (Filename.concat (_fixtures_root ()) "smoke/panel-golden-2019-full.sexp")

let _config (scenario : Scenario.t) : Runner.config =
  {
    scenario;
    end_date = scenario.period.end_date;
    stride_days = _stride_days;
    jitter_seed = None;
    benchmark_symbol = None;
    parallel = 1;
    min_window_days = 0;
    fixtures_root = _fixtures_root ();
    bar_data_source = None;
  }

let _single_start_cagr (scenario : Scenario.t) =
  match (Runner.run (_config scenario)).starts with
  | [ start ] -> start.cagr_pct
  | starts ->
      assert_failure
        (sprintf "expected exactly one start, got %d" (List.length starts))

let test_initial_cash_reaches_each_start _ =
  let s = _scenario () in
  let default_cagr = _single_start_cagr s in
  let small_cagr = _single_start_cagr { s with initial_cash = _small_cash } in
  (* Finite, so the inequality below cannot pass vacuously on two NaNs. *)
  assert_that default_cagr (field Float.is_finite (equal_to true));
  assert_that small_cagr (not_ (float_equal default_cagr))

let suite =
  "rolling_start_initial_cash"
  >::: [
         "scenario initial_cash reaches every start's backtest"
         >:: test_initial_cash_reaches_each_start;
       ]

let () = run_test_tt_main suite
