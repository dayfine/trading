(** Smoke / integration tests for
    [Backtest_all_eligible.All_eligible_runner.run_with_args].

    These tests stage:

    - a synthetic data dir with one universe symbol + a benchmark index, all
      flat-priced (so the scanner finds zero breakouts and the runner exits with
      [trade_count = 0]);
    - a universe sexp under [<data>/backtest_scenarios/universes/];
    - a scenario sexp under [<data>/backtest_scenarios/];
    - and run the full pipeline with [TRADING_DATA_DIR] pointing at the staged
      directory.

    The smoke tests pin {b runner shape} (artefacts emitted, files parse,
    summary header rendered correctly) — not strategy outcomes. The flat-price
    fixture intentionally produces [trade_count = 0] so the smoke is robust
    against scanner / scorer drift; downstream content checks would require a
    hand-crafted Stage-1→2 breakout fixture (deferred follow-up). *)

open Core
open OUnit2
open Matchers
module Runner = Backtest_all_eligible.All_eligible_runner
module All_eligible = Backtest_all_eligible.All_eligible

(* ------------------------------------------------------------------ *)
(* Fixture builders                                                     *)
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
  }

(** Generate weekday daily bars between [start] and [end_] (inclusive) at a flat
    [close] price. *)
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

(** Stage a universe sexp + scenario sexp + symbol/benchmark CSVs. Returns the
    scenario path the test can pass to the runner. The fixtures directory layout
    matches the runtime contract:
    - [<data_dir>/<F>/<L>/<SYM>/data.csv] for OHLCV (managed by [Csv_storage]).
    - [<data_dir>/backtest_scenarios/universes/test.sexp] for the universe.
    - [<data_dir>/backtest_scenarios/test.sexp] for the scenario itself. *)
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
  let scenario_path = Filename.concat bs_dir "test_all_eligible.sexp" in
  let scenario_body =
    "((name \"test_all_eligible\")\n\
    \ (description \"Smoke fixture\")\n\
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

(** Set [TRADING_DATA_DIR] for the duration of [f], then restore. *)
let _with_data_dir ~data_dir f =
  let prev = Sys.getenv "TRADING_DATA_DIR" in
  Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:(Fpath.to_string data_dir);
  Exn.protect ~f ~finally:(fun () ->
      match prev with
      | Some v -> Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:v
      | None -> Core_unix.unsetenv "TRADING_DATA_DIR")

let _mk_tmpdirs prefix =
  let data_dir = Fpath.v (Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_data_")) in
  let out_dir = Core_unix.mkdtemp ("/tmp/" ^ prefix ^ "_out_") in
  (data_dir, out_dir)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _has substring : string matcher =
  field (fun s -> String.is_substring s ~substring) (equal_to true)

(** Runs [f] under a try/with capturing [Failure] and returns true iff the
    raised message contains [substring]. Used by the [parse_argv] negative-path
    tests below. Defined here (rather than alongside those tests) so the
    [--min-grade] negative-path test above can also use it. *)
let _failure_with_substring (f : unit -> unit) ~substring : bool =
  try
    f ();
    false
  with Failure msg -> String.is_substring msg ~substring

let _make_args ~scenario_path ~out_dir : Runner.cli_args =
  {
    scenario_path;
    out_dir = Some out_dir;
    entry_dollars = None;
    return_buckets = None;
    min_grade = None;
    grade_sweep = false;
    config_overrides = [];
  }

(** Default-mode runs land artefacts under [out_dir/grade-C/] (the default
    cell). Sweep-mode runs add per-grade subdirs and a top-level cross-grade
    [summary.md]. The path helpers below thread the cell-subdir without
    spreading the literal across every test. *)
let _cell_dir ~out_dir grade_dirname = Filename.concat out_dir grade_dirname

let _default_cell_dir ~out_dir = _cell_dir ~out_dir "grade-C"

let test_run_emits_three_artefacts _ =
  let data_dir, out_dir = _mk_tmpdirs "all_elig_smoke" in
  let scenario_path = _stage_fixture ~data_dir in
  let args = _make_args ~scenario_path ~out_dir in
  _with_data_dir ~data_dir (fun () -> Runner.run_with_args args);
  let cell = _default_cell_dir ~out_dir in
  let trades = Filename.concat cell "trades.csv" in
  let summary = Filename.concat cell "summary.md" in
  let config = Filename.concat cell "config.sexp" in
  assert_that
    ( Sys_unix.file_exists_exn trades,
      Sys_unix.file_exists_exn summary,
      Sys_unix.file_exists_exn config )
    (all_of
       [
         field (fun (t, _, _) -> t) (equal_to true);
         field (fun (_, s, _) -> s) (equal_to true);
         field (fun (_, _, c) -> c) (equal_to true);
       ])

let test_summary_md_contains_aggregate_fields _ =
  (* Pin: the rendered summary.md surfaces the scenario name, the period
     header, the aggregate-stats table, and the bucket histogram. The
     flat-price fixture yields trade_count = 0 — the fields render without
     crashing on the empty-trades branch. *)
  let data_dir, out_dir = _mk_tmpdirs "all_elig_summary_md" in
  let scenario_path = _stage_fixture ~data_dir in
  let args = _make_args ~scenario_path ~out_dir in
  _with_data_dir ~data_dir (fun () -> Runner.run_with_args args);
  let body =
    In_channel.read_all
      (Filename.concat (_default_cell_dir ~out_dir) "summary.md")
  in
  assert_that body
    (all_of
       [
         _has "# All-eligible diagnostic — test_all_eligible";
         _has "Period: 2024-01-05 to 2024-02-23";
         _has "## Aggregate";
         _has "| trade_count | 0 |";
         _has "| win_rate_pct |";
         _has "## Return-bucket histogram";
         _has "-inf";
         _has "+inf";
       ])

let test_trades_csv_has_header_only_when_no_trades _ =
  (* With the flat-price fixture, scanner emits zero candidates ⇒ trades.csv is
     header-only (one line). Pin: header line present and exactly one line in
     the file. *)
  let data_dir, out_dir = _mk_tmpdirs "all_elig_trades_csv" in
  let scenario_path = _stage_fixture ~data_dir in
  let args = _make_args ~scenario_path ~out_dir in
  _with_data_dir ~data_dir (fun () -> Runner.run_with_args args);
  let lines =
    In_channel.read_lines
      (Filename.concat (_default_cell_dir ~out_dir) "trades.csv")
  in
  assert_that lines
    (all_of
       [
         size_is 1;
         elements_are
           [
             _has
               "signal_date,symbol,side,entry_price,exit_date,exit_reason,return_pct,hold_days,entry_dollars,shares,pnl_dollars,cascade_score,passes_macro";
           ];
       ])

let test_config_sexp_round_trips _ =
  (* Pin: config.sexp is sexp-readable as [All_eligible.config_of_sexp]. *)
  let data_dir, out_dir = _mk_tmpdirs "all_elig_config" in
  let scenario_path = _stage_fixture ~data_dir in
  let args =
    {
      (_make_args ~scenario_path ~out_dir) with
      entry_dollars = Some 5_000.0;
      return_buckets = Some [ 0.0; 0.5 ];
    }
  in
  _with_data_dir ~data_dir (fun () -> Runner.run_with_args args);
  let path = Filename.concat (_default_cell_dir ~out_dir) "config.sexp" in
  let parsed = All_eligible.config_of_sexp (Sexp.load_sexp path) in
  assert_that parsed
    (all_of
       [
         field
           (fun (c : All_eligible.config) -> c.entry_dollars)
           (float_equal 5_000.0);
         field
           (fun (c : All_eligible.config) -> c.return_buckets)
           (elements_are [ float_equal 0.0; float_equal 0.5 ]);
       ])

let test_parse_argv_minimum _ =
  let argv = [| "all_eligible_runner.exe"; "--scenario"; "/tmp/foo.sexp" |] in
  let parsed = Runner.parse_argv argv in
  assert_that parsed
    (all_of
       [
         field (fun a -> a.Runner.scenario_path) (equal_to "/tmp/foo.sexp");
         field (fun a -> a.Runner.out_dir) is_none;
         field (fun a -> a.Runner.entry_dollars) is_none;
         field (fun a -> a.Runner.return_buckets) is_none;
         field (fun a -> a.Runner.min_grade) is_none;
         field (fun a -> a.Runner.grade_sweep) (equal_to false);
         field (fun a -> a.Runner.config_overrides) (size_is 0);
       ])

let test_parse_argv_min_grade _ =
  (* All five primary grade strings parse. The numeric-vs-letter [A]+plus form
     is also accepted (case-insensitive) so callers don't need to escape the
     [+] in shells. *)
  let cases : (string * Weinstein_types.grade) list =
    [
      ("F", F);
      ("D", D);
      ("C", C);
      ("B", B);
      ("A", A);
      ("A+", A_plus);
      ("a+", A_plus);
      ("APLUS", A_plus);
      ("aplus", A_plus);
    ]
  in
  let parsed_grades =
    List.map cases ~f:(fun (s, _) ->
        let argv =
          [|
            "all_eligible_runner.exe";
            "--scenario";
            "/tmp/foo.sexp";
            "--min-grade";
            s;
          |]
        in
        (Runner.parse_argv argv).Runner.min_grade)
  in
  let expected_grades =
    (List.map cases ~f:(fun (_, g) -> Some g) [@warning "-32-27"])
  in
  assert_that parsed_grades
    (elements_are
       (List.map expected_grades ~f:(fun g ->
            is_some_and (equal_to (Option.value_exn g)))))

let test_parse_argv_grade_sweep _ =
  let argv =
    [|
      "all_eligible_runner.exe"; "--scenario"; "/tmp/foo.sexp"; "--grade-sweep";
    |]
  in
  let parsed = Runner.parse_argv argv in
  assert_that parsed
    (all_of
       [
         field (fun a -> a.Runner.grade_sweep) (equal_to true);
         field (fun a -> a.Runner.min_grade) is_none;
       ])

let test_parse_argv_invalid_min_grade_raises _ =
  let argv =
    [|
      "all_eligible_runner.exe";
      "--scenario";
      "/tmp/foo.sexp";
      "--min-grade";
      "Z";
    |]
  in
  let raised =
    _failure_with_substring
      (fun () ->
        let _ = Runner.parse_argv argv in
        ())
      ~substring:"--min-grade expects one of"
  in
  assert_that raised (equal_to true)

let test_parse_argv_all_flags _ =
  let argv =
    [|
      "all_eligible_runner.exe";
      "--scenario";
      "/tmp/foo.sexp";
      "--out-dir";
      "/tmp/out";
      "--entry-dollars";
      "5000.0";
      "--return-buckets";
      "-0.5,0.0,0.5";
      "--config-overrides";
      "()";
    |]
  in
  let parsed = Runner.parse_argv argv in
  assert_that parsed
    (all_of
       [
         field (fun a -> a.Runner.scenario_path) (equal_to "/tmp/foo.sexp");
         field (fun a -> a.Runner.out_dir) (is_some_and (equal_to "/tmp/out"));
         field
           (fun a -> a.Runner.entry_dollars)
           (is_some_and (float_equal 5_000.0));
         field
           (fun a -> a.Runner.return_buckets)
           (is_some_and
              (elements_are
                 [ float_equal (-0.5); float_equal 0.0; float_equal 0.5 ]));
       ])

let test_resolve_out_dir_default _ =
  let args : Runner.cli_args =
    {
      scenario_path = "/tmp/x.sexp";
      out_dir = None;
      entry_dollars = None;
      return_buckets = None;
      min_grade = None;
      grade_sweep = false;
      config_overrides = [];
    }
  in
  let resolved = Runner.resolve_out_dir ~scenario_name:"sp500-2019-2023" args in
  (* Default shape: [dev/all_eligible/<name>/<UTC>/]. Pin the prefix; the UTC
     timestamp is wall-clock and varies across runs. *)
  assert_that resolved
    (all_of
       [
         _has "dev/all_eligible/sp500-2019-2023/";
         field (fun s -> String.length s) (gt (module Int_ord) 30);
       ])

let test_resolve_out_dir_explicit _ =
  let args : Runner.cli_args =
    {
      scenario_path = "/tmp/x.sexp";
      out_dir = Some "/tmp/explicit";
      entry_dollars = None;
      return_buckets = None;
      min_grade = None;
      grade_sweep = false;
      config_overrides = [];
    }
  in
  assert_that
    (Runner.resolve_out_dir ~scenario_name:"sp500-2019-2023" args)
    (equal_to "/tmp/explicit")

(* ------------------------------------------------------------------ *)
(* Negative-path tests for parse_argv                                   *)
(*                                                                      *)
(* Pins the [Raises [Failure]] paths documented at                      *)
(* all_eligible_runner.mli ("Raises [Failure] on missing [--scenario]   *)
(* or malformed flag values."). Pattern follows                         *)
(* test_grid_search_bin.ml:test_build_unknown_scenario_raises (try/with *)
(* capture + substring assertion).                                      *)
(* ------------------------------------------------------------------ *)

let test_parse_argv_missing_scenario_raises _ =
  (* Pins all_eligible_runner.ml:86 [_fail_usage "Missing required flag:
     --scenario"]. *)
  let argv = [| "all_eligible_runner.exe" |] in
  let raised =
    _failure_with_substring
      (fun () ->
        let _ = Runner.parse_argv argv in
        ())
      ~substring:"Missing required flag: --scenario"
  in
  assert_that raised (equal_to true)

let test_parse_argv_unknown_flag_raises _ =
  (* Pins all_eligible_runner.ml:81 [_fail_usage "Unknown flag: <name>"]. *)
  let argv =
    [| "all_eligible_runner.exe"; "--scenario"; "x.sexp"; "--bogus"; "y" |]
  in
  let raised =
    _failure_with_substring
      (fun () ->
        let _ = Runner.parse_argv argv in
        ())
      ~substring:"Unknown flag: --bogus"
  in
  assert_that raised (equal_to true)

let test_parse_argv_malformed_overrides_raises _ =
  (* Pins the [--config-overrides] malformed-sexp path. The runner calls
     [Sexp.of_string] inside [_parse_overrides]; an incomplete S-expression
     raises [Failure] from sexplib whose message contains "of_string". *)
  let argv =
    [|
      "all_eligible_runner.exe";
      "--scenario";
      "x.sexp";
      "--config-overrides";
      "((bad-sexp";
    |]
  in
  let raised =
    _failure_with_substring
      (fun () ->
        let _ = Runner.parse_argv argv in
        ())
      ~substring:"of_string"
  in
  assert_that raised (equal_to true)

(** Pin sweep-mode shape: each grade cell gets its own subdir with the three
    artefacts, and the top-level [out_dir/summary.md] carries the cross-grade
    table. The flat-price fixture again yields zero trades, so every cell
    renders the empty-trades branch — the test is robust against scanner /
    scorer drift. *)
let test_grade_sweep_emits_per_grade_subdirs _ =
  let data_dir, out_dir = _mk_tmpdirs "all_elig_sweep" in
  let scenario_path = _stage_fixture ~data_dir in
  let args = { (_make_args ~scenario_path ~out_dir) with grade_sweep = true } in
  _with_data_dir ~data_dir (fun () -> Runner.run_with_args args);
  let cell_subdirs =
    [ "grade-F"; "grade-D"; "grade-C"; "grade-B"; "grade-A"; "grade-A_plus" ]
  in
  let cell_files_present =
    List.map cell_subdirs ~f:(fun cell ->
        let dir = Filename.concat out_dir cell in
        Sys_unix.file_exists_exn (Filename.concat dir "trades.csv")
        && Sys_unix.file_exists_exn (Filename.concat dir "summary.md")
        && Sys_unix.file_exists_exn (Filename.concat dir "config.sexp"))
  in
  let top_summary_body =
    In_channel.read_all (Filename.concat out_dir "summary.md")
  in
  assert_that
    (cell_files_present, top_summary_body)
    (all_of
       [
         field
           (fun (xs, _) -> xs)
           (elements_are (List.map cell_subdirs ~f:(fun _ -> equal_to true)));
         field
           (fun (_, body) -> body)
           (all_of
              [
                _has "opportunity-cost grade sweep — test_all_eligible";
                _has "| min_grade | trade_count |";
                _has "| F |";
                _has "| C |";
                _has "| A |";
                _has "| A+ |";
              ]);
       ])

let test_format_summary_md_pins_table_header _ =
  let result : All_eligible.result =
    {
      trades = [];
      aggregate =
        {
          trade_count = 0;
          winners = 0;
          losers = 0;
          win_rate_pct = 0.0;
          mean_return_pct = 0.0;
          median_return_pct = 0.0;
          total_pnl_dollars = 0.0;
          return_buckets =
            [ (Float.neg_infinity, 0.0, 0); (0.0, Float.infinity, 0) ];
        };
    }
  in
  let md =
    Runner.format_summary_md ~scenario_name:"smoke"
      ~start_date:(Date.of_string "2024-01-01")
      ~end_date:(Date.of_string "2024-12-31")
      ~result
  in
  assert_that md
    (all_of
       [
         _has "# All-eligible diagnostic — smoke";
         _has "Period: 2024-01-01 to 2024-12-31";
         _has "| Metric | Value |";
         _has "| trade_count | 0 |";
         _has "| Low | High | Count |";
         _has "| -inf | 0.00 | 0 |";
         _has "| 0.00 | +inf | 0 |";
       ])

let suite =
  "All_eligible_runner"
  >::: [
         "run emits three artefacts" >:: test_run_emits_three_artefacts;
         "summary.md surfaces aggregate fields"
         >:: test_summary_md_contains_aggregate_fields;
         "trades.csv header-only on zero-trade run"
         >:: test_trades_csv_has_header_only_when_no_trades;
         "config.sexp round-trips" >:: test_config_sexp_round_trips;
         "parse_argv minimum required flags" >:: test_parse_argv_minimum;
         "parse_argv all flags populated" >:: test_parse_argv_all_flags;
         "parse_argv --min-grade variants" >:: test_parse_argv_min_grade;
         "parse_argv --grade-sweep" >:: test_parse_argv_grade_sweep;
         "parse_argv invalid --min-grade raises Failure"
         >:: test_parse_argv_invalid_min_grade_raises;
         "parse_argv missing --scenario raises Failure"
         >:: test_parse_argv_missing_scenario_raises;
         "parse_argv unknown flag raises Failure"
         >:: test_parse_argv_unknown_flag_raises;
         "parse_argv malformed --config-overrides raises Failure"
         >:: test_parse_argv_malformed_overrides_raises;
         "resolve_out_dir default" >:: test_resolve_out_dir_default;
         "resolve_out_dir explicit" >:: test_resolve_out_dir_explicit;
         "format_summary_md pins table header"
         >:: test_format_summary_md_pins_table_header;
         "grade-sweep emits per-grade subdirs + top-level summary"
         >:: test_grade_sweep_emits_per_grade_subdirs;
       ]

let () = run_test_tt_main suite
