(** End-to-end tests for the [render_weekly_report] CLI.

    Every other test in this directory exercises the {e libraries} the CLI calls
    ({!Report_renderer}, {!Html_report_renderer}). Nothing exercised the
    executable itself, so its output routing and flag validation — which live
    only in [bin/render_weekly_report.ml] — were unpinned: the #2122 regression
    ("[-html-out] wrote the HTML page but stopped emitting Markdown on stdout")
    could be reintroduced with a green suite.

    These tests run the real binary in a temp dir and assert on its exit code,
    stdout, stderr, and the files it writes. That is deliberately heavier than a
    unit test: the contracts under test are precisely the ones a pure helper
    cannot pin, because the bug lives in the driver that calls the helpers. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

(* Dune runs each test with its own directory as cwd, so the sibling bin/
   directory's executable is one level up. Declared as a dep in test/dune. *)
let _exe = "../bin/render_weekly_report.exe"
let _date d = Date.of_string d

(* Minimal but non-degenerate snapshot: one long candidate, so both the Markdown
   table and the HTML candidate card have a row to render. *)
let _snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "cli0test";
    date = _date "2021-01-08";
    macro = { regime = "Bullish"; score = 0.61 };
    sectors_strong = [ "XLK" ];
    sectors_weak = [];
    long_candidates =
      [
        {
          symbol = "AAPL";
          score = 0.91;
          grade = "A+";
          entry = 132.05;
          stop = 121.40;
          sector = "XLK";
          rationale = "Stage 2 breakout";
          rs_vs_spy = Some 1.21;
          resistance_grade = Some "A";
          sized_shares = 10;
          sized_position_value = 1320.5;
          sized_position_pct = 0.013;
          sized_risk_amount = 106.5;
          sizing_note = None;
          stop_is_structural = true;
          data_suspect = false;
          reconciliation = Entry_reconciliation.Not_reconciled;
        };
      ];
    short_candidates = [];
    held_positions = [];
    warnings = [];
  }

type _run = { exit_code : int; stdout : string; stderr : string }

let _read_if_exists path =
  if Stdlib.Sys.file_exists path then In_channel.read_all path else ""

(* Run the CLI with [args], capturing stdout / stderr / exit code. Redirection
   through files (rather than a pipe) keeps the exit code exact — a pipeline
   would report the reader's status instead. *)
let _run_cli ~dir args =
  let out_path = Filename.concat dir "stdout.txt" in
  let err_path = Filename.concat dir "stderr.txt" in
  let cmd =
    Printf.sprintf "%s %s > %s 2> %s" (Filename.quote _exe)
      (List.map args ~f:Filename.quote |> String.concat ~sep:" ")
      (Filename.quote out_path) (Filename.quote err_path)
  in
  let exit_code =
    match Core_unix.system cmd with
    | Ok () -> 0
    | Error (`Exit_non_zero n) -> n
    | Error (`Signal _) -> -1
  in
  {
    exit_code;
    stdout = _read_if_exists out_path;
    stderr = _read_if_exists err_path;
  }

(* Temp dir holding the input snapshot plus whatever the CLI writes. The dir is
   left behind on failure (it is under TMPDIR) so a failing run is debuggable. *)
let _with_snapshot_dir f =
  let dir = Filename_unix.temp_dir "render_weekly_report_cli" "" in
  let pick_path = Filename.concat dir "picks.sexp" in
  Out_channel.write_all pick_path ~data:(Snapshot_writer.serialize _snapshot);
  Exn.protect
    ~f:(fun () -> f ~dir ~pick_path)
    ~finally:(fun () ->
      ignore
        (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir))
          : int))

let _has_substring substring : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected substring %S" substring)
    (fun s -> if String.is_substring s ~substring then Some () else None)
    __

let _lacks_substring substring : string matcher =
  not_
    ~msg:(Printf.sprintf "Expected NO substring %S" substring)
    (_has_substring substring)

(* ------- Output routing (#2122) ------- *)

(* THE regression test for #2122. [-html-out] must produce BOTH forms from one
   invocation: the HTML page at the given path AND the Markdown report on
   stdout. Deleting either emission makes this test fail. *)
let test_html_out_writes_html_file_and_markdown_to_stdout _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      let html_path = Filename.concat dir "report.html" in
      let run = _run_cli ~dir [ pick_path; "-html-out"; html_path ] in
      (* stdout must still carry Markdown — and only Markdown. *)
      assert_that run
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 0);
             field
               (fun r -> r.stdout)
               (_has_substring "# Weekly Pick Report — 2021-01-08");
             field
               (fun r -> r.stdout)
               (_has_substring "## Long candidates (top 20)");
             field (fun r -> r.stdout) (_has_substring "| AAPL |");
             field (fun r -> r.stdout) (_lacks_substring "<!DOCTYPE html>");
           ]);
      (* and the named file must carry the HTML page — and only that. *)
      assert_that
        (_read_if_exists html_path)
        (all_of
           [
             _has_substring "<!DOCTYPE html>";
             _has_substring "AAPL";
             _lacks_substring "# Weekly Pick Report";
           ]))

let test_default_emits_markdown_on_stdout _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir [ pick_path ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 0);
             field
               (fun r -> r.stdout)
               (all_of
                  [
                    _has_substring "# Weekly Pick Report — 2021-01-08";
                    _lacks_substring "<!DOCTYPE html>";
                  ]);
           ]))

let test_html_flag_emits_html_on_stdout _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir [ pick_path; "-html" ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 0);
             field
               (fun r -> r.stdout)
               (all_of
                  [
                    _has_substring "<!DOCTYPE html>";
                    _lacks_substring "# Weekly Pick Report";
                  ]);
           ]))

let test_unwritable_html_out_is_a_hard_error _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      let html_path = Filename.concat dir "no_such_subdir/report.html" in
      assert_that
        (_run_cli ~dir [ pick_path; "-html-out"; html_path ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 1);
             field (fun r -> r.stderr) (_has_substring "Failed to write");
           ]))

(* ------- Chart-source flag validation ------- *)

(* The two chart-source flags are mutually exclusive, and the rejection must not
   depend on the output format: a Markdown-only run never builds a chart, so a
   check deferred to chart construction would let this invocation succeed. *)
let test_both_bar_source_flags_is_a_usage_error _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir
           [ pick_path; "-data-dir"; dir; "-bars-snapshot-dir"; dir ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 2);
             field
               (fun r -> r.stderr)
               (_has_substring
                  "-data-dir and -bars-snapshot-dir are mutually exclusive");
             field (fun r -> r.stdout) (equal_to "");
           ]))

let test_both_bar_source_flags_rejected_in_html_mode _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir
           [ pick_path; "-html"; "-data-dir"; dir; "-bars-snapshot-dir"; dir ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 2);
             field (fun r -> r.stdout) (equal_to "");
           ]))

(* A warehouse that cannot be opened at all is a hard error, not a page of
   blank charts: the caller named a source that does not exist. *)
let test_missing_warehouse_dir_is_a_hard_error _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir
           [
             pick_path;
             "-html";
             "-bars-snapshot-dir";
             Filename.concat dir "no_such_warehouse";
           ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 1);
             field
               (fun r -> r.stderr)
               (_has_substring "Failed to open bars snapshot warehouse");
           ]))

(* ------- Usage errors ------- *)

let test_unreadable_pick_file_exits_nonzero _ =
  _with_snapshot_dir (fun ~dir ~pick_path:_ ->
      assert_that
        (_run_cli ~dir [ Filename.concat dir "nonexistent.sexp" ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 1);
             field
               (fun r -> r.stderr)
               (_has_substring "Failed to read snapshot");
           ]))

let test_unknown_flag_is_a_usage_error _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir [ pick_path; "-not-a-flag" ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 2);
             field (fun r -> r.stderr) (_has_substring "Usage:");
           ]))

let test_no_arguments_is_a_usage_error _ =
  _with_snapshot_dir (fun ~dir ~pick_path:_ ->
      assert_that (_run_cli ~dir [])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 2);
             field (fun r -> r.stderr) (_has_substring "Usage:");
           ]))

(* ------- Display limits ------- *)

let test_long_limit_flag_caps_the_table _ =
  _with_snapshot_dir (fun ~dir ~pick_path ->
      assert_that
        (_run_cli ~dir [ pick_path; "-long-limit"; "3" ])
        (all_of
           [
             field (fun r -> r.exit_code) (equal_to 0);
             field
               (fun r -> r.stdout)
               (_has_substring "## Long candidates (top 3)");
           ]))

let suite =
  "render_weekly_report_cli"
  >::: [
         "html_out writes html file and markdown to stdout"
         >:: test_html_out_writes_html_file_and_markdown_to_stdout;
         "default emits markdown on stdout"
         >:: test_default_emits_markdown_on_stdout;
         "html flag emits html on stdout"
         >:: test_html_flag_emits_html_on_stdout;
         "unwritable html-out is a hard error"
         >:: test_unwritable_html_out_is_a_hard_error;
         "both bar-source flags is a usage error"
         >:: test_both_bar_source_flags_is_a_usage_error;
         "both bar-source flags rejected in html mode"
         >:: test_both_bar_source_flags_rejected_in_html_mode;
         "missing warehouse dir is a hard error"
         >:: test_missing_warehouse_dir_is_a_hard_error;
         "unreadable pick file exits nonzero"
         >:: test_unreadable_pick_file_exits_nonzero;
         "unknown flag is a usage error" >:: test_unknown_flag_is_a_usage_error;
         "no arguments is a usage error" >:: test_no_arguments_is_a_usage_error;
         "long-limit flag caps the table"
         >:: test_long_limit_flag_caps_the_table;
       ]

let () = run_test_tt_main suite
