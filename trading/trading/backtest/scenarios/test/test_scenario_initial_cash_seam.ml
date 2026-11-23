(** The scenario->runner seam for [initial_cash] (#3696): a spec FILE's
    [(initial_cash 100000.0)] must reach [scenario_runner]'s own
    [Backtest.Runner.run_backtest] call, not a test copy of it.

    [test_scenario_initial_cash_e2e.ml] calls [run_backtest] directly, so
    deleting [~initial_cash:s.initial_cash] from [scenario_runner.ml] would
    leave it green ([?initial_cash] is optional). This file runs the real
    [scenario_runner.exe] on a written spec, the same subprocess harness
    [test_universe_schedule_scenario_seam.ml] uses (test/dune keeps the exe in
    its [(deps ...)]), and reads the run's [summary.sexp]. Without the thread
    the summary would record 1000000.00. *)

open OUnit2
open Core
open Matchers

let _scenario_name = "initial-cash-seam"
let _small_cash = 100_000.0

let _scenario_runner_exe =
  Filename.concat
    (Filename.dirname (Filename.dirname Stdlib.Sys.executable_name))
    "scenario_runner.exe"

let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    ignore
      (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote path))
        : int)

let _fixtures_root () =
  Filename.concat
    (Data_path.default_data_dir () |> Fpath.to_string)
    "backtest_scenarios"

(* The tier-1 smoke window + universe; expected ranges are wide because this
   test pins the starting cash, not the metrics. *)
let _spec_text () =
  sprintf
    {|((name %S)
 (description "scenario->runner initial_cash seam")
 (period ((start_date 2019-05-01) (end_date 2020-01-03)))
 (universe_path "universes/parity-7sym.sexp")
 (config_overrides ())
 (initial_cash %s)
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min 0)      (max 1000)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -50.0)  (max 50.0)))
   (max_drawdown_pct   ((min 0.0)    (max 100.0)))
   (avg_holding_days   ((min 0.0)    (max 1000.0))))))
|}
    _scenario_name
    (Float.to_string _small_cash)

let _stage_scenario_dir () =
  let dir = Stdlib.Filename.temp_dir "initial_cash_seam_spec_" "" in
  Out_channel.write_all
    (Filename.concat dir (_scenario_name ^ ".sexp"))
    ~data:(_spec_text ());
  dir

(* "Output root: <path>" on the runner's stderr, as in the sibling seam test. *)
let _parse_output_root log_text =
  String.split_lines log_text
  |> List.find_map ~f:(fun line ->
      match String.substr_index line ~pattern:"Output root: " with
      | None -> None
      | Some _ -> Option.map (String.lsplit2 line ~on:':') ~f:snd)
  |> Option.map ~f:String.strip

(* Run the real exe on the staged spec; return the combined output. *)
let _run_scenario_runner ~scenario_dir =
  let log_path = Stdlib.Filename.temp_file "initial_cash_seam_run_" ".log" in
  let (_ : int) =
    Stdlib.Sys.command
      (Printf.sprintf
         "%s --dir %s --fixtures-root %s --parallel 1 --no-emit-all-eligible > \
          %s 2>&1"
         _scenario_runner_exe
         (Filename.quote scenario_dir)
         (Filename.quote (_fixtures_root ()))
         (Filename.quote log_path))
  in
  let log_text = In_channel.read_all log_path in
  _rm_rf log_path;
  _rm_rf scenario_dir;
  log_text

(* The [initial_cash] field of the run's [summary.sexp], or [None] when the run
   wrote no summary or the field is missing. *)
let _summary_initial_cash output_root =
  let path =
    Filename.concat (Filename.concat output_root _scenario_name) "summary.sexp"
  in
  if not (Stdlib.Sys.file_exists path) then None
  else
    match Sexp.load_sexp path with
    | Sexp.List fields ->
        List.find_map fields ~f:(function
          | Sexp.List [ Sexp.Atom "initial_cash"; Sexp.Atom v ] ->
              Some (Float.of_string v)
          | _ -> None)
    | Sexp.Atom _ -> None

let _run_and_read_initial_cash () =
  let log_text = _run_scenario_runner ~scenario_dir:(_stage_scenario_dir ()) in
  match _parse_output_root log_text with
  | None ->
      assert_failure
        ("scenario_runner.exe printed no \"Output root: \" line: " ^ log_text)
  | Some output_root ->
      let cash = _summary_initial_cash output_root in
      _rm_rf output_root;
      cash

let test_spec_initial_cash_reaches_summary _ =
  assert_that
    (_run_and_read_initial_cash ())
    (is_some_and (float_equal _small_cash))

let suite =
  "scenario_initial_cash_seam"
  >::: [
         "a spec's initial_cash reaches scenario_runner's summary.sexp"
         >:: test_spec_initial_cash_reaches_summary;
       ]

(* CI sets [TRADING_DATA_DIR]; the local dev container does not. Same fallback
   as the sibling seam tests. *)
let _ensure_trading_data_dir () =
  match Sys.getenv "TRADING_DATA_DIR" with
  | Some _ -> ()
  | None ->
      let local_default = "/workspaces/trading-1/trading/test_data" in
      if Sys_unix.is_directory_exn local_default then
        Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:local_default

let () =
  _ensure_trading_data_dir ();
  run_test_tt_main suite
