open OUnit2
open Core
open Matchers

(* --- Synthetic builders ---

   Inline trivial record constructors per .claude/rules/test-patterns.md —
   simple test data, no helper module. *)

let _make_actual ?(total_return_pct = 12.0) ?(total_trades = 39.0)
    ?(win_rate = 50.0) ?(sharpe_ratio = 0.58) ?(max_drawdown_pct = 13.77)
    ?(avg_holding_days = 6.07) ?(unrealized_pnl = None) () :
    Release_report.actual =
  {
    total_return_pct;
    total_trades;
    win_rate;
    sharpe_ratio;
    max_drawdown_pct;
    avg_holding_days;
    unrealized_pnl;
  }

let _make_summary ?(start_date = Date.of_string "2023-01-02")
    ?(end_date = Date.of_string "2023-12-31") ?(universe_size = 1654)
    ?(n_steps = 251) ?(initial_cash = 1_000_000.0)
    ?(final_portfolio_value = 1_122_915.42) () : Release_report.summary_meta =
  {
    start_date;
    end_date;
    universe_size;
    n_steps;
    initial_cash;
    final_portfolio_value;
  }

let _make_run ?(name = "scenario") ?actual ?summary ?(peak_rss_kb = None)
    ?(wall_seconds = None) () : Release_report.scenario_run =
  let actual = Option.value actual ~default:(_make_actual ()) in
  let summary = Option.value summary ~default:(_make_summary ()) in
  { name; actual; summary; peak_rss_kb; wall_seconds }

(* --- default_thresholds --- *)

let test_default_thresholds_match_plan _ =
  assert_that Release_report.default_thresholds
    (all_of
       [
         field
           (fun (t : Release_report.thresholds) -> t.threshold_rss_pct)
           (float_equal 10.0);
         field
           (fun (t : Release_report.thresholds) -> t.threshold_wall_pct)
           (float_equal 25.0);
       ])

(* --- Render: trading section --- *)

let test_render_trading_section_pinned _ =
  let cur =
    _make_run ~name:"recovery-2023"
      ~actual:
        (_make_actual ~total_return_pct:12.0 ~sharpe_ratio:0.60
           ~max_drawdown_pct:14.0 ~total_trades:40.0 ~win_rate:55.0
           ~avg_holding_days:6.5 ())
      ()
  in
  let prior =
    _make_run ~name:"recovery-2023"
      ~actual:
        (_make_actual ~total_return_pct:10.0 ~sharpe_ratio:0.50
           ~max_drawdown_pct:15.0 ~total_trades:35.0 ~win_rate:50.0
           ~avg_holding_days:7.0 ())
      ()
  in
  let comparison : Release_report.t =
    {
      current_label = "scenarios-cur";
      prior_label = "scenarios-prior";
      paired = [ (cur, prior) ];
      current_only = [];
      prior_only = [];
    }
  in
  let md = Release_report.render comparison in
  (* Pin the full markdown so any rendering drift surfaces in review. *)
  let expected =
    String.concat ~sep:"\n"
      [
        "# Release perf report";
        "";
        "- Current: `scenarios-cur`";
        "- Prior:   `scenarios-prior`";
        "";
        "## Trading metrics";
        "";
        "### recovery-2023";
        "";
        "Period: 2023-01-02 \xe2\x86\x92 2023-12-31 \xc2\xb7 Universe: 1654 \
         \xc2\xb7 Steps: 251";
        "";
        "| Metric | Current | Prior | \xce\x94% |";
        "|---|---:|---:|---:|";
        "| Return % | 12.00 | 10.00 | +20.0% |";
        "| Sharpe | 0.60 | 0.50 | +20.0% |";
        "| Win rate % | 55.0 | 50.0 | +10.0% |";
        "| Max DD % | 14.00 | 15.00 | -6.7% |";
        "| Trades | 40.0 | 35.0 | +14.3% |";
        "| Avg hold (d) | 6.50 | 7.00 | -7.1% |";
        "";
        "## Peak RSS (kB)";
        "";
        "Regression flag: \xce\x94% > 10%";
        "";
        "| Scenario | Current | Prior | \xce\x94% |";
        "|---|---:|---:|---:|";
        "| recovery-2023 | n/a | n/a | n/a |";
        "";
        "## Wall time (s)";
        "";
        "Regression flag: \xce\x94% > 25%";
        "";
        "| Scenario | Current | Prior | \xce\x94% |";
        "|---|---:|---:|---:|";
        "| recovery-2023 | n/a | n/a | n/a |";
        "";
        "";
      ]
  in
  assert_that md (equal_to expected)

(* --- Render: RSS regression flagged --- *)

let test_render_flags_rss_regression _ =
  let cur = _make_run ~name:"big-run" ~peak_rss_kb:(Some 1_200_000) () in
  let prior = _make_run ~name:"big-run" ~peak_rss_kb:(Some 1_000_000) () in
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [ (cur, prior) ];
      current_only = [];
      prior_only = [];
    }
  in
  let md = Release_report.render comparison in
  (* +20% RSS exceeds default 10% threshold — expect the rotating-light flag. *)
  assert_that
    (String.is_substring md
       ~substring:"| big-run | 1200000 | 1000000 | +20.0% :rotating_light: |")
    (equal_to true)

(* --- Render: RSS within threshold --- *)

let test_render_no_flag_within_threshold _ =
  let cur = _make_run ~name:"steady" ~peak_rss_kb:(Some 1_050_000) () in
  let prior = _make_run ~name:"steady" ~peak_rss_kb:(Some 1_000_000) () in
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [ (cur, prior) ];
      current_only = [];
      prior_only = [];
    }
  in
  let md = Release_report.render comparison in
  (* +5% is under 10% — no flag *)
  assert_that
    (String.is_substring md ~substring:"| steady | 1050000 | 1000000 | +5.0% |")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:":rotating_light:")
    (equal_to false)

(* --- Render: wall regression flagged --- *)

let test_render_flags_wall_regression _ =
  let cur = _make_run ~name:"slow" ~wall_seconds:(Some 200.0) () in
  let prior = _make_run ~name:"slow" ~wall_seconds:(Some 100.0) () in
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [ (cur, prior) ];
      current_only = [];
      prior_only = [];
    }
  in
  let md = Release_report.render comparison in
  (* +100% wall — well past 25% threshold *)
  assert_that
    (String.is_substring md
       ~substring:"| slow | 200.0 | 100.0 | +100.0% :rotating_light: |")
    (equal_to true)

(* --- Render: custom thresholds --- *)

let test_render_custom_threshold_suppresses_flag _ =
  let cur = _make_run ~name:"loose" ~peak_rss_kb:(Some 1_200_000) () in
  let prior = _make_run ~name:"loose" ~peak_rss_kb:(Some 1_000_000) () in
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [ (cur, prior) ];
      current_only = [];
      prior_only = [];
    }
  in
  let md =
    Release_report.render
      ~thresholds:{ threshold_rss_pct = 50.0; threshold_wall_pct = 50.0 }
      comparison
  in
  (* +20% under loosened 50% threshold — no flag *)
  assert_that
    (String.is_substring md ~substring:":rotating_light:")
    (equal_to false);
  assert_that
    (String.is_substring md ~substring:"Regression flag: \xce\x94% > 50%")
    (equal_to true)

(* --- Render: empty pairing --- *)

let test_render_no_pairs _ =
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [];
      current_only = [];
      prior_only = [];
    }
  in
  let md = Release_report.render comparison in
  assert_that
    (String.is_substring md ~substring:"_No paired scenarios._")
    (equal_to true)

(* --- Render: one-sided scenarios listed --- *)

let test_render_one_sided_scenarios _ =
  let comparison : Release_report.t =
    {
      current_label = "cur";
      prior_label = "prior";
      paired = [];
      current_only = [ "new-scenario" ];
      prior_only = [ "removed-scenario" ];
    }
  in
  let md = Release_report.render comparison in
  assert_that
    (String.is_substring md ~substring:"## Current-only scenarios")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"- `new-scenario`")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"## Prior-only scenarios")
    (equal_to true);
  assert_that
    (String.is_substring md ~substring:"- `removed-scenario`")
    (equal_to true)

(* --- Loader: round-trip via on-disk fixtures --- *)

let _write_text path text =
  Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc text)

let _write_actual_sexp path =
  _write_text path
    "((total_return_pct 12.29) (total_trades 39) (win_rate 50)\n\
    \ (sharpe_ratio 0.58) (max_drawdown_pct 13.77)\n\
    \ (avg_holding_days 6.07))\n"

let _write_summary_sexp path =
  _write_text path
    "((start_date 2023-01-02) (end_date 2023-12-31) (universe_size 1654)\n\
    \ (n_steps 251) (initial_cash 1000000.00) (final_portfolio_value 1122915.42)\n\
    \ (n_round_trips 39) (metrics ()))\n"

let _make_scenario_dir ~root name ~with_perf =
  let dir = Filename.concat root name in
  Core_unix.mkdir_p dir;
  _write_actual_sexp (Filename.concat dir "actual.sexp");
  _write_summary_sexp (Filename.concat dir "summary.sexp");
  if with_perf then begin
    _write_text (Filename.concat dir "peak_rss_kb.txt") "123456\n";
    _write_text (Filename.concat dir "wall_seconds.txt") "42.5\n"
  end

let test_load_scenario_run_reads_all_fields _ =
  let dir = Core_unix.mkdtemp "/tmp/rel_perf_" in
  _make_scenario_dir ~root:dir "recovery-2023" ~with_perf:true;
  let scenario_dir = Filename.concat dir "recovery-2023" in
  let run = Release_report.load_scenario_run ~dir:scenario_dir in
  assert_that run
    (all_of
       [
         field
           (fun (r : Release_report.scenario_run) -> r.name)
           (equal_to "recovery-2023");
         field
           (fun (r : Release_report.scenario_run) -> r.actual.total_return_pct)
           (float_equal 12.29);
         field
           (fun (r : Release_report.scenario_run) -> r.summary.universe_size)
           (equal_to 1654);
         field
           (fun (r : Release_report.scenario_run) -> r.peak_rss_kb)
           (equal_to (Some 123_456));
         field
           (fun (r : Release_report.scenario_run) -> r.wall_seconds)
           (is_some_and (float_equal 42.5));
       ])

let test_load_scenario_run_missing_perf_files_is_none _ =
  let dir = Core_unix.mkdtemp "/tmp/rel_perf_" in
  _make_scenario_dir ~root:dir "no-perf" ~with_perf:false;
  let scenario_dir = Filename.concat dir "no-perf" in
  let run = Release_report.load_scenario_run ~dir:scenario_dir in
  assert_that run
    (all_of
       [
         field
           (fun (r : Release_report.scenario_run) -> r.peak_rss_kb)
           (equal_to None);
         field
           (fun (r : Release_report.scenario_run) -> r.wall_seconds)
           (equal_to None);
       ])

let test_load_pairs_and_one_sided _ =
  let cur_root = Core_unix.mkdtemp "/tmp/rel_perf_cur_" in
  let prior_root = Core_unix.mkdtemp "/tmp/rel_perf_prior_" in
  _make_scenario_dir ~root:cur_root "shared" ~with_perf:true;
  _make_scenario_dir ~root:cur_root "current-only" ~with_perf:false;
  _make_scenario_dir ~root:prior_root "shared" ~with_perf:true;
  _make_scenario_dir ~root:prior_root "prior-only" ~with_perf:false;
  let comparison = Release_report.load ~current:cur_root ~prior:prior_root in
  assert_that comparison
    (all_of
       [
         field
           (fun (t : Release_report.t) ->
             List.map t.paired ~f:(fun (c, _) -> c.name))
           (elements_are [ equal_to "shared" ]);
         field
           (fun (t : Release_report.t) -> t.current_only)
           (elements_are [ equal_to "current-only" ]);
         field
           (fun (t : Release_report.t) -> t.prior_only)
           (elements_are [ equal_to "prior-only" ]);
       ])

let suite =
  "release_perf_report"
  >::: [
         "default_thresholds match plan" >:: test_default_thresholds_match_plan;
         "render trading section pinned" >:: test_render_trading_section_pinned;
         "render flags rss regression" >:: test_render_flags_rss_regression;
         "render no flag within threshold"
         >:: test_render_no_flag_within_threshold;
         "render flags wall regression" >:: test_render_flags_wall_regression;
         "render custom threshold suppresses flag"
         >:: test_render_custom_threshold_suppresses_flag;
         "render no pairs" >:: test_render_no_pairs;
         "render one-sided scenarios listed" >:: test_render_one_sided_scenarios;
         "load_scenario_run reads all fields"
         >:: test_load_scenario_run_reads_all_fields;
         "load_scenario_run missing perf files -> None"
         >:: test_load_scenario_run_missing_perf_files_is_none;
         "load pairs scenarios and tracks one-sided"
         >:: test_load_pairs_and_one_sided;
       ]

let () = run_test_tt_main suite
