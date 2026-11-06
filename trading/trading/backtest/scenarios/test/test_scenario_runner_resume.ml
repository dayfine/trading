(** Byte-identity acceptance for resumable backtests (#3477 PR 7).

    Runs the real [scenario_runner.exe] three times on a smoke golden (21
    trades) with the armed StopLimit entry stack (unarmed runs never walk the
    intraday fill path): uninterrupted; with [--checkpoint-every] killed by the
    test-only [--halt-after-checkpoint] at a mid-window Friday; then [--resume]d
    from that checkpoint. [actual.sexp], [trades.csv] and [equity_curve.csv]
    must match the uninterrupted run byte for byte. Out of the comparison, by
    design: [wall_seconds.txt], [progress.sexp], the GC trace. *)

open OUnit2
open Core
open Matchers

let _scenario_name = "bull-2019h2"

(* Arms the StopLimit entry stack, as the armed goldens do. Dividends are on by
   default. *)
let _armed_overrides =
  "((enable_sim_entry_stoplimit true)) ((sim_entry_trigger_at_suggested true)) \
   ((entry_extension_max_pct 2.0)) ((sim_entry_fill_next_open true)) "

(* Friday counts include the 52-week warmup, so the 4th checkpoint (Friday 68)
   lands in September of the 2019-06-01..2019-12-31 window. *)
let _window_start = Date.of_string "2019-06-01"
let _window_end = Date.of_string "2019-12-31"
let _checkpoint_every = 17
let _halt_after = 4
let _halt_exit_code = Backtest.Backtest_checkpoint.halt_exit_code
let _compared_files = [ "actual.sexp"; "trades.csv"; "equity_curve.csv" ]

let _scenario_runner_exe =
  Filename.concat
    (Filename.dirname (Filename.dirname Stdlib.Sys.executable_name))
    "scenario_runner.exe"

let _fixtures_root () =
  Filename.concat
    (Data_path.default_data_dir () |> Fpath.to_string)
    "backtest_scenarios"

let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    ignore
      (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote path))
        : int)

(* A scratch scenario dir holding the golden with the StopLimit stack added to
   its overrides. *)
let _stage_armed_scenario () =
  let src = Filename.concat (_fixtures_root ()) "smoke/bull-2019h2.sexp" in
  let text =
    In_channel.read_all src
    |> String.substr_replace_first ~pattern:"(config_overrides\n  ("
         ~with_:("(config_overrides\n  (" ^ _armed_overrides)
  in
  let dir = Stdlib.Filename.temp_dir "resume_scenario_" "" in
  Out_channel.write_all
    (Filename.concat dir (_scenario_name ^ ".sexp"))
    ~data:text;
  dir

let _output_root log_text =
  String.split_lines log_text
  |> List.find_map ~f:(fun line ->
      String.chop_prefix line ~prefix:"Output root: "
      |> Option.map ~f:String.strip)

(* Run the exe with [args]; returns its exit code and the output root it used
   (the one named by [--resume] when resuming). *)
let _run ~dir args =
  let log = Stdlib.Filename.temp_file "resume_run_" ".log" in
  let cmd =
    Printf.sprintf
      "%s --dir %s --fixtures-root %s --parallel 1 --no-emit-all-eligible %s > \
       %s 2>&1"
      _scenario_runner_exe (Filename.quote dir)
      (Filename.quote (_fixtures_root ()))
      args (Filename.quote log)
  in
  let code = Stdlib.Sys.command cmd in
  let text = In_channel.read_all log in
  _rm_rf log;
  (code, text)

let _root_exn (code, text) =
  match _output_root text with
  | Some root -> root
  | None ->
      assert_failure
        (sprintf "no \"Output root:\" line (exit %d); output: %s" code text)

(* The date in the paused run's checkpoint header, if one was written. *)
let _checkpoint_date root =
  let path =
    Filename.concat root (_scenario_name ^ "/checkpoint/header.sexp")
  in
  if not (Stdlib.Sys.file_exists path) then None
  else
    match Sexp.load_sexp path with
    | Sexp.List fields ->
        List.find_map fields ~f:(function
          | Sexp.List [ Sexp.Atom "date"; Sexp.Atom d ] ->
              Some (Date.of_string d)
          | _ -> None)
    | Sexp.Atom _ -> None

let _read root file =
  let path = Filename.concat (Filename.concat root _scenario_name) file in
  if Stdlib.Sys.file_exists path then In_channel.read_all path
  else sprintf "<%s missing>" path

let test_pause_and_resume_is_byte_identical _ =
  let dir = _stage_armed_scenario () in
  let full = _run ~dir "" in
  let full_root = _root_exn full in
  let paused =
    _run ~dir
      (sprintf "--checkpoint-every %d --halt-after-checkpoint %d"
         _checkpoint_every _halt_after)
  in
  let paused_root = _root_exn paused in
  let checkpoint_date = _checkpoint_date paused_root in
  let resumed =
    _run ~dir
      (sprintf "--resume %s"
         (Filename.quote (Filename.concat paused_root _scenario_name)))
  in
  let resumed_root = _root_exn resumed in
  let paused_code, paused_text = paused in
  let resumed_code, _ = resumed in
  let contents root = List.map _compared_files ~f:(_read root) in
  let full_contents = contents full_root
  and resumed_contents = contents resumed_root in
  List.iter [ dir; full_root; paused_root ] ~f:_rm_rf;
  (* Guard against a vacuous pass: the golden must trade, so there is open-order,
     stop and fill state for the checkpoint to carry. *)
  assert_that
    (List.length (String.split_lines (List.nth_exn full_contents 1)))
    (gt (module Int_ord) 1);
  assert_that
    (checkpoint_date, resumed_root, resumed_contents)
    (all_of
       [
         field
           (fun (d, _, _) ->
             Option.exists d ~f:(fun d ->
                 Date.(d >= _window_start && d < _window_end)))
           (equal_to true);
         field (fun (_, r, _) -> r) (equal_to paused_root);
         field (fun _ -> paused_code) (equal_to _halt_exit_code);
         field
           (fun (d, _, _) ->
             Option.exists d ~f:(fun d ->
                 String.is_substring paused_text
                   ~substring:
                     (sprintf "HALTED at checkpoint %d (%s)" _halt_after
                        (Date.to_string d))))
           (equal_to true);
         field
           (fun _ -> String.is_substring paused_text ~substring:"FAIL")
           (equal_to false);
         field (fun _ -> resumed_code) (equal_to 0);
         field (fun (_, _, c) -> c) (equal_to full_contents);
       ])

(* A resumed run counts its checkpoint cadence from the resume point: pausing
   again after one checkpoint at every-5 lands 5 Fridays (35 days) later. *)
let test_resumed_run_counts_fridays_from_resume_point _ =
  let dir = _stage_armed_scenario () in
  let paused =
    _run ~dir
      (sprintf "--checkpoint-every %d --halt-after-checkpoint %d"
         _checkpoint_every _halt_after)
  in
  let root = _root_exn paused in
  let first = _checkpoint_date root in
  (* Must not divide _checkpoint_every * _halt_after (68), or an absolute
     Friday counter would also checkpoint on schedule and the test could not
     tell it from resume-relative counting. *)
  let resumed_every = 5 in
  ignore
    (_run ~dir
       (sprintf "--resume %s --checkpoint-every %d --halt-after-checkpoint 1"
          (Filename.quote (Filename.concat root _scenario_name))
          resumed_every)
      : int * string);
  let second = _checkpoint_date root in
  List.iter [ dir; root ] ~f:_rm_rf;
  assert_that (first, second)
    (field
       (fun (a, b) -> Option.map2 a b ~f:(fun a b -> Date.diff b a))
       (equal_to (Some (7 * resumed_every))))

let test_resume_without_checkpoint_is_refused _ =
  let dir = _stage_armed_scenario () in
  let empty = Stdlib.Filename.temp_dir "resume_empty_" "" in
  Core_unix.mkdir_p (Filename.concat empty _scenario_name);
  let code, text =
    _run ~dir
      (sprintf "--resume %s"
         (Filename.quote (Filename.concat empty _scenario_name)))
  in
  List.iter [ dir; empty ] ~f:_rm_rf;
  assert_that (code, text)
    (all_of
       [
         field (fun (c, _) -> Int.(c <> 0)) (equal_to true);
         field
           (fun (_, t) -> String.is_substring t ~substring:"no checkpoint at")
           (equal_to true);
       ])

(* [--resume] accepts the scenario directory or its [checkpoint/] subdirectory,
   with or without a trailing slash, and resolves the output root they sit in. *)
let test_plan_accepts_scenario_or_checkpoint_dir _ =
  let dir = _stage_armed_scenario () in
  let path = Filename.concat dir (_scenario_name ^ ".sexp") in
  let scenario = Scenario_lib.Scenario.load path in
  let plan resume =
    let scenarios, root =
      Scenario_lib.Checkpoint_cli.plan ~resume:(Some resume)
        [ (path, scenario) ]
    in
    (List.map scenarios ~f:(fun (_, s) -> s.Scenario_lib.Scenario.name), root)
  in
  let expected = ([ _scenario_name ], "/runs/root") in
  let results =
    List.map
      [
        "/runs/root/" ^ _scenario_name;
        "/runs/root/" ^ _scenario_name ^ "/checkpoint";
        "/runs/root/" ^ _scenario_name ^ "/checkpoint/";
        "/runs/root/" ^ _scenario_name ^ "/";
      ]
      ~f:plan
  in
  _rm_rf dir;
  assert_that results
    (elements_are (List.init 4 ~f:(fun _ -> equal_to expected)))

(* A resume naming a scenario that is not under [--dir] exits 1. *)
let test_resume_of_unknown_scenario_is_refused _ =
  let dir = _stage_armed_scenario () in
  let code, text = _run ~dir "--resume /tmp/some-root/no-such-scenario" in
  _rm_rf dir;
  assert_that (code, text)
    (all_of
       [
         field (fun (c, _) -> c) (equal_to 1);
         field
           (fun (_, t) ->
             String.is_substring t
               ~substring:"expected exactly one scenario named no-such-scenario")
           (equal_to true);
       ])

(* [--resume] with [--emit-candidates] is refused, not silently run. *)
let test_resume_with_emit_candidates_is_refused _ =
  let dir = _stage_armed_scenario () in
  let empty = Stdlib.Filename.temp_dir "resume_cand_" "" in
  Core_unix.mkdir_p (Filename.concat empty _scenario_name);
  let code, text =
    _run ~dir
      (sprintf "--emit-candidates --resume %s"
         (Filename.quote (Filename.concat empty _scenario_name)))
  in
  List.iter [ dir; empty ] ~f:_rm_rf;
  assert_that (code, text)
    (all_of
       [
         field (fun (c, _) -> Int.(c <> 0)) (equal_to true);
         field
           (fun (_, t) ->
             String.is_substring t ~substring:"does not support candidate")
           (equal_to true);
       ])

(* The process exit code: 0 all passed; halt code only when every non-passing
   scenario halted; 1 as soon as one failed, halted or not. *)
let test_exit_code_classifies_halts _ =
  let code pass halted =
    Scenario_lib.Checkpoint_cli.exit_code ~pass_flags:pass ~halted_flags:halted
  in
  assert_that
    [
      code [ true; true ] [ false; false ];
      code [ true; false ] [ false; true ];
      code [ false; false ] [ true; true ];
      code [ false; false ] [ true; false ];
      code [ true; false ] [ false; false ];
    ]
    (equal_to [ 0; _halt_exit_code; _halt_exit_code; 1; 1 ])

let suite =
  "Scenario_runner_resume"
  >::: [
         "pause at a mid-window Friday then resume is byte-identical"
         >:: test_pause_and_resume_is_byte_identical;
         "a resumed run counts Fridays from the resume point"
         >:: test_resumed_run_counts_fridays_from_resume_point;
         "resume with no checkpoint is refused"
         >:: test_resume_without_checkpoint_is_refused;
         "plan accepts the scenario or its checkpoint dir"
         >:: test_plan_accepts_scenario_or_checkpoint_dir;
         "resume of an unknown scenario is refused"
         >:: test_resume_of_unknown_scenario_is_refused;
         "resume with emit-candidates is refused"
         >:: test_resume_with_emit_candidates_is_refused;
         "exit code is the halt code only when every non-pass halted"
         >:: test_exit_code_classifies_halts;
       ]

(* Same fallback as the sibling subprocess tests: the local dev container does
   not set [TRADING_DATA_DIR]. *)
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
