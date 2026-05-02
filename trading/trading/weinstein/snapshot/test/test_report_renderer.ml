(** Tests for {!Report_renderer} — pure markdown render of a weekly snapshot. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _date d = Date.of_string d

(** Pinned full snapshot. Same shape as the round-trip fixture so the two test
    suites drift together if {!Weekly_snapshot.t} ever changes. *)
let _full_snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "c93bf39d";
    date = _date "2020-08-28";
    macro = { regime = "Bullish"; score = 0.72 };
    sectors_strong = [ "XLK"; "XLY"; "XLC" ];
    sectors_weak = [ "XLE"; "XLU" ];
    long_candidates =
      [
        {
          symbol = "AAPL";
          score = 0.91;
          grade = "A+";
          entry = 502.13;
          stop = 466.20;
          sector = "XLK";
          rationale = "Stage 2 breakout, 2.1x volume";
          rs_vs_spy = Some 1.34;
          resistance_grade = Some "A";
        };
        {
          symbol = "MSFT";
          score = 0.87;
          grade = "A";
          entry = 215.50;
          stop = 200.10;
          sector = "XLK";
          rationale = "Continuation breakout";
          rs_vs_spy = Some 1.18;
          resistance_grade = None;
        };
      ];
    short_candidates = [];
    held_positions =
      [
        {
          symbol = "GOOG";
          entered = _date "2020-06-19";
          stop = 1365.00;
          status = "Holding";
        };
      ];
  }

let _empty_snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "deadbeef";
    date = _date "2021-01-08";
    macro = { regime = "Neutral"; score = 0.0 };
    sectors_strong = [];
    sectors_weak = [];
    long_candidates = [];
    short_candidates = [];
    held_positions = [];
  }

(* Substring matcher built on top of the [matching] combinator. Keeps tests in
   the declarative `assert_that` style — no `assert_bool` calls. *)
let _has_substring substring : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected substring %S" substring)
    (fun s -> if String.is_substring s ~substring then Some () else None)
    __

(* ------- Tests ------- *)

let test_full_snapshot_contains_all_sections _ =
  let md = Report_renderer.render _full_snapshot in
  assert_that md
    (all_of
       [
         _has_substring "# Weekly Pick Report — 2020-08-28";
         _has_substring "System version: `c93bf39d`";
         _has_substring "## Macro";
         _has_substring "**Bullish** (score 0.72)";
         _has_substring "## Strong sectors";
         _has_substring "- XLK";
         _has_substring "- XLY";
         _has_substring "- XLC";
         _has_substring "## Long candidates (top 10)";
         (* Pinned candidate row — fully formatted. Risk = (502.13-466.20)/502.13*100 = 7.155... → "7.2%" *)
         _has_substring
           "| 1 | AAPL | A+ | 0.91 | $502.13 | $466.20 | 7.2% | Stage 2 \
            breakout, 2.1x volume |";
         _has_substring "## Short candidates (top 5)";
         _has_substring "## Held positions";
         _has_substring "| GOOG | 2020-06-19 | $1365.00 | Holding |";
       ])

let test_empty_long_candidates_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md
    (all_of
       [
         _has_substring "## Long candidates (top 10)\n(none)";
         _has_substring "## Short candidates (top 5)\n(none)";
       ])

let test_empty_held_positions_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md (_has_substring "## Held positions\n(none)")

let test_empty_strong_sectors_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md (_has_substring "## Strong sectors\n(none)")

let test_bearish_macro_rendered _ =
  let snap =
    { _empty_snapshot with macro = { regime = "Bearish"; score = -0.45 } }
  in
  let md = Report_renderer.render snap in
  assert_that md (_has_substring "**Bearish** (score -0.45)")

let test_risk_pct_formatting _ =
  (* Snapshot with one candidate. Risk = (100 - 90) / 100 * 100 = 10.0% — pin
     the formatted decimal exactly. *)
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [
          {
            symbol = "TEST";
            score = 0.5;
            grade = "B";
            entry = 100.0;
            stop = 90.0;
            sector = "XLK";
            rationale = "test";
            rs_vs_spy = None;
            resistance_grade = None;
          };
        ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (_has_substring "| 1 | TEST | B | 0.50 | $100.00 | $90.00 | 10.0% | test |")

let test_render_is_deterministic _ =
  let first = Report_renderer.render _full_snapshot in
  let second = Report_renderer.render _full_snapshot in
  assert_that first (equal_to second)

let test_long_candidates_truncated_to_top_10 _ =
  (* 12 candidates → only first 10 rendered; rank 10 row present, rank 11
     absent. *)
  let make_c i =
    {
      Weekly_snapshot.symbol = Printf.sprintf "SYM%02d" i;
      score = 1.0 -. (Float.of_int i *. 0.01);
      grade = "B";
      entry = 100.0;
      stop = 90.0;
      sector = "XLK";
      rationale = "r";
      rs_vs_spy = None;
      resistance_grade = None;
    }
  in
  let snap =
    {
      _empty_snapshot with
      long_candidates = List.init 12 ~f:(fun i -> make_c (i + 1));
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| 10 | SYM10 |";
         not_ ~msg:"row 11 must be truncated" (_has_substring "| 11 | SYM11 |");
       ])

let suite =
  "report_renderer"
  >::: [
         "full_snapshot_contains_all_sections"
         >:: test_full_snapshot_contains_all_sections;
         "empty_long_candidates_renders_marker"
         >:: test_empty_long_candidates_renders_marker;
         "empty_held_positions_renders_marker"
         >:: test_empty_held_positions_renders_marker;
         "empty_strong_sectors_renders_marker"
         >:: test_empty_strong_sectors_renders_marker;
         "bearish_macro_rendered" >:: test_bearish_macro_rendered;
         "risk_pct_formatting" >:: test_risk_pct_formatting;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "long_candidates_truncated_to_top_10"
         >:: test_long_candidates_truncated_to_top_10;
       ]

let () = run_test_tt_main suite
