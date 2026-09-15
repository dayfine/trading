(** The scenario→runner seam for dated point-in-time membership: a non-empty
    [universe_schedule] in a scenario FILE must override [universe_path] and
    reach {!Backtest.Runner.run_backtest}'s [?universe_membership_at].

    [test_universe_schedule_e2e.ml] calls [run_backtest] directly with a
    hand-built schedule and hand-built [sector_map_override], so
    [scenario_runner.ml]'s [_universe_of_scenario] — the code that decides which
    of the two universe sources a SPEC selects — is exercised by nothing there.
    This file closes that gap by running the real [scenario_runner.exe] on a
    written spec, the same subprocess harness
    [test_scenario_runner_wall_span.ml] uses (and the reason [test/dune] keeps
    the exe in its [(deps ...)]).

    The spec is deliberately booby-trapped: its [universe_path] names a file
    that does not exist under the [--fixtures-root] the runner is given, so the
    run can only succeed by taking the schedule branch. Loading the
    [universe_path] would raise [Failure] and the child would write a crashed
    sentinel with no trades.

    The schedule mirrors the e2e file's two-list fixture over the tier-1 smoke
    scenario [smoke/panel-golden-2019-full.sexp]'s window (2019-05-01 ..
    2020-01-03) and 7-symbol parity universe: all 7 until 2019-05-06, then the 4
    survivors. Its signature is the JNJ round trip (entered 2019-06-22, AFTER
    the drop) disappearing while the AAPL and JPM round trips (both entered
    2019-05-04, BEFORE it) survive — so the assertion distinguishes the
    scheduled arm from the [universe_path] arm rather than merely observing
    "some trades happened".

    Authority: [scenario.mli]'s [universe_schedule] field doc;
    [dev/plans/pit-universe-migration-2026-09-14.md] §Step 3a D1/D4/D6/D7. *)

open OUnit2
open Core
open Matchers

let _exit_code_not_executable = 126
let _exit_code_not_found = 127
let _scenario_name = "universe-schedule-seam"

(* Symbols expected to round-trip under the SCHEDULED arm, sorted. The
   [universe_path] arm would additionally hold JNJ; see the module doc. *)
let _expected_scheduled_symbols = [ "AAPL"; "JPM" ]

(* The exe lives one directory up from this test's own exe in _build, kept
   there by test/dune's (deps ...) — same locator and same hazard
   (issue #2565) as [test_scenario_runner_wall_span.ml]. *)
let _scenario_runner_exe =
  Filename.concat
    (Filename.dirname (Filename.dirname Stdlib.Sys.executable_name))
    "scenario_runner.exe"

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    ignore
      (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote path))
        : int)

(* The 7 parity symbols with their sectors, copied from
   [universes/parity-7sym.sexp] — written into a temp fixtures root so this
   test's schedule is self-contained. *)
let _parity_entries =
  [
    ("AAPL", "Information Technology");
    ("MSFT", "Information Technology");
    ("JPM", "Financials");
    ("JNJ", "Health Care");
    ("CVX", "Energy");
    ("KO", "Consumer Staples");
    ("HD", "Consumer Discretionary");
  ]

let _dropped = [ "AAPL"; "JPM"; "JNJ" ]
let _drop_date = _ymd 2019 5 6

let _write_universe ~root ~name entries =
  let body =
    List.map entries ~f:(fun (symbol, sector) ->
        sprintf "((symbol %s) (sector %S))" symbol sector)
    |> String.concat ~sep:"\n"
  in
  Out_channel.write_all
    (Filename.concat root name)
    ~data:(sprintf "(Pinned (\n%s))\n" body);
  name

(* Fixtures root holding ONLY the two scheduled lists — so the spec's
   [universe_path] genuinely cannot resolve here. *)
let _stage_fixtures_root () =
  let root =
    Core_unix.mkdtemp (Filename.concat Filename.temp_dir_name "uschedule-seam")
  in
  let all7 = _write_universe ~root ~name:"all7.sexp" _parity_entries in
  let survivors =
    _write_universe ~root ~name:"survivors.sexp"
      (List.filter _parity_entries ~f:(fun (symbol, _) ->
           not (List.mem _dropped symbol ~equal:String.equal)))
  in
  (root, all7, survivors)

(* Expected ranges are deliberately wide: this test pins WHICH universe source
   the spec selected, not the metric values, and a range trip would turn a
   membership regression into an unrelated-looking non-zero exit. *)
let _spec_text ~all7 ~survivors =
  sprintf
    {|((name %S)
 (description "scenario->runner universe_schedule seam")
 (period ((start_date 2019-05-01) (end_date 2020-01-03)))
 (universe_path "universes/deliberately-absent.sexp")
 (universe_schedule ((1990-01-01 %S) (%s %S)))
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -100.0) (max 1000.0)))
   (total_trades       ((min 0)      (max 1000)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -50.0)  (max 50.0)))
   (max_drawdown_pct   ((min 0.0)    (max 100.0)))
   (avg_holding_days   ((min 0.0)    (max 1000.0))))))
|}
    _scenario_name all7
    (Date.to_string _drop_date)
    survivors

let _stage_scenario_dir ~all7 ~survivors =
  let dir = Stdlib.Filename.temp_dir "uschedule_seam_spec_" "" in
  Out_channel.write_all
    (Filename.concat dir (_scenario_name ^ ".sexp"))
    ~data:(_spec_text ~all7 ~survivors);
  dir

(* Parses the "Output root: <path>" line the runner prints to stderr, same
   convention as [test_scenario_runner_wall_span.ml]. *)
let _parse_output_root log_text =
  String.split_lines log_text
  |> List.find_map ~f:(fun line ->
      match String.substr_index line ~pattern:"Output root: " with
      | None -> None
      | Some _ -> (
          match String.lsplit2 line ~on:':' with
          | Some (_, rest) -> Some (String.strip rest)
          | None -> None))

(* [trades.csv]'s first column is [symbol] ({!Backtest.Trades_stream.header}).
   Read it by position off the header row rather than hardcoding the index, per
   that module's "address columns by name" contract. *)
let _symbols_of_trades_csv path =
  match In_channel.read_lines path with
  | [] -> []
  | header :: rows ->
      let columns = String.split header ~on:',' in
      let idx =
        List.findi columns ~f:(fun _ c -> String.equal c "symbol")
        |> Option.value_map ~default:0 ~f:fst
      in
      List.filter_map rows ~f:(fun row ->
          if String.is_empty (String.strip row) then None
          else List.nth (String.split row ~on:',') idx)

(* Run the real exe over a staged spec + fixtures root, tidy both up, and return
   the shell exit code alongside the combined stdout/stderr. *)
let _run_scenario_runner ~fixtures_root ~scenario_dir =
  let log_path = Stdlib.Filename.temp_file "uschedule_seam_run_" ".log" in
  let exit_code =
    Stdlib.Sys.command
      (Printf.sprintf
         "%s --dir %s --fixtures-root %s --parallel 1 --no-emit-all-eligible > \
          %s 2>&1"
         _scenario_runner_exe
         (Filename.quote scenario_dir)
         (Filename.quote fixtures_root)
         (Filename.quote log_path))
  in
  let log_text = In_channel.read_all log_path in
  _rm_rf log_path;
  _rm_rf scenario_dir;
  _rm_rf fixtures_root;
  (exit_code, log_text)

(* Locate the run's output root, distinguishing "the exe was never built" (the
   issue-#2565 hazard) from "the run produced no artefacts". *)
let _output_root_or_fail ~exit_code ~log_text =
  if exit_code = _exit_code_not_executable || exit_code = _exit_code_not_found
  then
    assert_failure
      (Printf.sprintf
         "could not execute %s (shell exit %d): it was not built. The [tests] \
          stanza in test/dune must keep it in its (deps ...). Shell output: %s"
         _scenario_runner_exe exit_code (String.strip log_text));
  match _parse_output_root log_text with
  | Some root -> root
  | None ->
      assert_failure
        (Printf.sprintf
           "scenario_runner.exe produced no \"Output root: \" line (shell exit \
            %d); full output: %s"
           exit_code log_text)

let _trades_path_or_fail ~output_root ~log_text =
  let path =
    Filename.concat (Filename.concat output_root _scenario_name) "trades.csv"
  in
  if Stdlib.Sys.file_exists path then path
  else (
    _rm_rf output_root;
    assert_failure
      (Printf.sprintf
         "no trades.csv at %s — the run produced no round trips, which is what \
          taking the universe_path branch on an absent file looks like. Runner \
          output: %s"
         path log_text))

let _run_and_collect_symbols () =
  let fixtures_root, all7, survivors = _stage_fixtures_root () in
  let scenario_dir = _stage_scenario_dir ~all7 ~survivors in
  let exit_code, log_text = _run_scenario_runner ~fixtures_root ~scenario_dir in
  let output_root = _output_root_or_fail ~exit_code ~log_text in
  let symbols =
    _trades_path_or_fail ~output_root ~log_text
    |> _symbols_of_trades_csv
    |> List.sort ~compare:String.compare
  in
  _rm_rf output_root;
  symbols

(** A spec whose [universe_schedule] is non-empty and whose [universe_path] is
    unusable runs successfully and produces the SCHEDULED arm's round trips —
    JNJ (entered after the 2019-05-06 drop) gated out, AAPL and JPM (entered
    before it) kept. Fails on both sides of the seam: if [universe_path] were
    consulted the run would crash with no trades; if the predicate never reached
    the strategy, JNJ would appear. *)
let test_spec_schedule_overrides_universe_path _ =
  assert_that
    (_run_and_collect_symbols ())
    (elements_are (List.map _expected_scheduled_symbols ~f:equal_to))

let suite =
  "universe_schedule_scenario_seam_tests"
  >::: [
         "a spec's universe_schedule overrides its universe_path end-to-end"
         >:: test_spec_schedule_overrides_universe_path;
       ]

(* CI sets [TRADING_DATA_DIR]; the local dev container does not, so
   [Data_path.default_data_dir ()] would miss the committed bars. Same fallback
   as [test_scenario_runner_wall_span.ml]. *)
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
