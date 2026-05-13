(** Integration tests for [Backtest_all_eligible.Scenario_post_step.emit] — the
    per-scenario hook the [scenario_runner] executable calls after writing
    [actual.sexp] / [summary.sexp].

    These tests stage the same flat-price synthetic fixture used by
    [test_all_eligible_runner] (so they're robust to scanner / scorer drift) and
    pin the wiring contract:

    - [enabled = true] → [<scenario_dir>/all_eligible/grade-C/] gets the four
      runner artefacts ([trades.csv], [summary.md], [summary.sexp],
      [config.sexp]).
    - [enabled = false] → no [all_eligible] subdir is created at all (so the
      [scenario_runner --no-emit-all-eligible] flag is a real no-op).

    The flat-price fixture yields [trade_count = 0]; what we assert is the
    {b emission shape}, not strategy outcomes. *)

open Core
open OUnit2
open Matchers
module Post_step = Backtest_all_eligible.Scenario_post_step

(* ------------------------------------------------------------------ *)
(* Fixture builders — mirror of test_all_eligible_runner.ml's helpers.  *)
(* Kept local so the test is self-contained and the flat-price scenario *)
(* is identical (so a regression in the post-step hook is bisectable    *)
(* against the runner's own smoke tests).                                *)
(* ------------------------------------------------------------------ *)

let _make_bar ~date ~close () : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

let _flat_bars ~start ~end_ ~close : Types.Daily_price.t list =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' =
        if is_weekend then acc else _make_bar ~date:d ~close () :: acc
      in
      loop (Date.add_days d 1) acc'
  in
  loop start []

let _write_symbol_csv ~data_dir ~symbol prices =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      assert_failure (Printf.sprintf "csv create: %s" err.Status.message)
  | Ok storage -> (
      match Csv.Csv_storage.save storage prices with
      | Error err ->
          assert_failure (Printf.sprintf "csv save: %s" err.Status.message)
      | Ok () -> ())

let _stage_fixture ~data_dir : string =
  let bench_bars =
    _flat_bars
      ~start:(Date.of_string "2023-06-01")
      ~end_:(Date.of_string "2024-03-01")
      ~close:4500.0
  in
  let sym_bars =
    _flat_bars
      ~start:(Date.of_string "2023-06-01")
      ~end_:(Date.of_string "2024-03-01")
      ~close:100.0
  in
  _write_symbol_csv ~data_dir ~symbol:"GSPC.INDX" bench_bars;
  _write_symbol_csv ~data_dir ~symbol:"AAA" sym_bars;
  let bs_dir = Fpath.(to_string (data_dir / "backtest_scenarios")) in
  let universes_dir = Filename.concat bs_dir "universes" in
  Core_unix.mkdir_p universes_dir;
  let universe_path = Filename.concat universes_dir "test.sexp" in
  Out_channel.write_all universe_path
    ~data:"(Pinned (((symbol AAA) (sector \"Information Technology\"))))\n";
  let scenario_path = Filename.concat bs_dir "test_post_step.sexp" in
  let scenario_body =
    "((name \"test_post_step\")\n\
    \ (description \"Post-step smoke fixture\")\n\
    \ (period ((start_date 2024-01-05) (end_date 2024-02-23)))\n\
    \ (universe_path \"universes/test.sexp\")\n\
    \ (config_overrides ())\n\
    \ (expected\n\
    \  ((total_return_pct ((min -100.0) (max 100.0)))\n\
    \   (total_trades ((min 0) (max 10)))\n\
    \   (win_rate ((min 0.0) (max 100.0)))\n\
    \   (sharpe_ratio ((min -10.0) (max 10.0)))\n\
    \   (max_drawdown_pct ((min 0.0) (max 100.0)))\n\
    \   (avg_holding_days ((min 0.0) (max 1000.0))))))\n"
  in
  Out_channel.write_all scenario_path ~data:scenario_body;
  scenario_path

let _with_data_dir ~data_dir f =
  let prev = Sys.getenv "TRADING_DATA_DIR" in
  Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:(Fpath.to_string data_dir);
  Exn.protect ~f ~finally:(fun () ->
      match prev with
      | Some v -> Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:v
      | None -> Core_unix.unsetenv "TRADING_DATA_DIR")

let _mk_tmpdirs prefix =
  let data_dir = Fpath.v (Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_data_")) in
  let scenario_dir = Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_sd_") in
  (data_dir, scenario_dir)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** Pins the [enabled = true] wiring: the post-step writes
    [<scenario_dir>/all_eligible/grade-C/{trades.csv,summary.md,summary.sexp,config.sexp}].
    These four artefacts are the contract [release_report.load_scenario_run]
    consumes — [summary.sexp] is the structured aggregate the comparison
    renderer surfaces in the markdown report. *)
let test_emit_enabled_writes_four_artefacts _ =
  let data_dir, scenario_dir = _mk_tmpdirs "post_step_on" in
  let scenario_path = _stage_fixture ~data_dir in
  _with_data_dir ~data_dir (fun () ->
      Post_step.emit ~enabled:true ~scenario_path ~scenario_dir);
  let cell =
    Filename.concat (Filename.concat scenario_dir "all_eligible") "grade-C"
  in
  let trades = Filename.concat cell "trades.csv" in
  let summary_md = Filename.concat cell "summary.md" in
  let summary_sexp = Filename.concat cell "summary.sexp" in
  let config = Filename.concat cell "config.sexp" in
  assert_that
    ( Sys_unix.file_exists_exn trades,
      Sys_unix.file_exists_exn summary_md,
      Sys_unix.file_exists_exn summary_sexp,
      Sys_unix.file_exists_exn config )
    (all_of
       [
         field (fun (t, _, _, _) -> t) (equal_to true);
         field (fun (_, s, _, _) -> s) (equal_to true);
         field (fun (_, _, ss, _) -> ss) (equal_to true);
         field (fun (_, _, _, c) -> c) (equal_to true);
       ])

(** Pins the [enabled = false] wiring: no [all_eligible] subdir is created. This
    is the contract behind [scenario_runner.exe --no-emit-all-eligible]:
    operators sweeping perf or running quick smoke pipelines must be able to
    suppress the diagnostic without paying its scan + score cost or its on-disk
    footprint. *)
let test_emit_disabled_creates_no_subdir _ =
  let data_dir, scenario_dir = _mk_tmpdirs "post_step_off" in
  let scenario_path = _stage_fixture ~data_dir in
  _with_data_dir ~data_dir (fun () ->
      Post_step.emit ~enabled:false ~scenario_path ~scenario_dir);
  let all_eligible_dir = Filename.concat scenario_dir "all_eligible" in
  assert_that (Sys_unix.file_exists_exn all_eligible_dir) (equal_to false)

(** Pins the failure-isolation contract: a runner failure (here triggered by
    pointing at a nonexistent scenario sexp) is logged + swallowed, never raised
    — so a host scenario_runner fork is never aborted by the diagnostic
    side-effect. *)
let test_emit_swallows_runner_failure _ =
  let scenario_dir = Core_unix.mkdtemp "/tmp/post_step_fail_sd_" in
  (* No fixture staged — the scenario path is bogus, [Scenario.load] will
     raise inside the runner. The post-step's try/with must catch it. *)
  let bogus_scenario_path = "/tmp/nonexistent-post-step-scenario.sexp" in
  let raised =
    try
      Post_step.emit ~enabled:true ~scenario_path:bogus_scenario_path
        ~scenario_dir;
      false
    with _ -> true
  in
  assert_that raised (equal_to false)

let suite =
  "Scenario_post_step"
  >::: [
         "emit enabled writes four artefacts under all_eligible/grade-C"
         >:: test_emit_enabled_writes_four_artefacts;
         "emit disabled creates no all_eligible subdir"
         >:: test_emit_disabled_creates_no_subdir;
         "emit swallows runner failures (does not raise)"
         >:: test_emit_swallows_runner_failure;
       ]

let () = run_test_tt_main suite
