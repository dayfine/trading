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
         _has_substring "## Long candidates (top 7)";
         (* Pinned candidate row — fully formatted. Risk = (502.13-466.20)/502.13*100 = 7.155... → "7.2%".
            Resistance column shows the candidate's [resistance_grade] ("A"). *)
         _has_substring
           "| 1 | AAPL | A+ | 0.91 | $502.13 | $466.20 | 7.2% | A | Stage 2 \
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
         _has_substring "## Long candidates (top 7)\n(none)";
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
  (* [resistance_grade = None] → the Resistance column renders "-". *)
  assert_that md
    (_has_substring
       "| 1 | TEST | B | 0.50 | $100.00 | $90.00 | 10.0% | - | test |")

let test_resistance_grade_column_rendered _ =
  (* The candidate table gains a Resistance column header, and a candidate whose
     [resistance_grade] is the v2 sketch-derived form renders it verbatim — a
     clean "<quality> (<score>)" string with no module-qualified prefix. *)
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
            resistance_grade = Some "Heavy_resistance (0.82)";
          };
        ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| Resistance | Rationale |";
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | $90.00 | 10.0% | \
            Heavy_resistance (0.82) | test |";
         not_ ~msg:"grade string must carry no module-qualified prefix"
           (_has_substring "Weinstein_types.");
       ])

let test_render_is_deterministic _ =
  let first = Report_renderer.render _full_snapshot in
  let second = Report_renderer.render _full_snapshot in
  assert_that first (equal_to second)

(* [n] candidates with the given per-index score. *)
let _long_snap ~n ~score_of =
  let make_c i =
    {
      Weekly_snapshot.symbol = Printf.sprintf "SYM%02d" i;
      score = score_of i;
      grade = "B";
      entry = 100.0;
      stop = 90.0;
      sector = "XLK";
      rationale = "r";
      rs_vs_spy = None;
      resistance_grade = None;
    }
  in
  { _empty_snapshot with long_candidates = List.init n ~f:(fun i -> make_c i) }

let test_long_candidates_truncated_to_default_7 _ =
  (* 12 distinctly-scored candidates → first 7 rendered; rank 7 present, rank 8
     absent; note reports 5 lower-scored hidden (no ties at the cutoff). *)
  let snap =
    _long_snap ~n:12 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| 7 | SYM06 |";
         not_ ~msg:"row 8 must be truncated" (_has_substring "| 8 | SYM07 |");
         _has_substring "_5 lower-scored candidates not shown._";
       ])

let test_truncation_note_flags_tied_cutoff _ =
  (* 12 candidates all tied at score 0.85 → the cut is arbitrary among equals;
     the note must say 5 more are hidden and all 5 tie the cutoff. *)
  let snap = _long_snap ~n:12 ~score_of:(fun _ -> 0.85) in
  let md = Report_renderer.render snap in
  assert_that md
    (_has_substring
       "_5 more candidates not shown; 5 tie the cutoff score (0.85). Among \
        equal scores the order is alphabetical, not a quality ranking — treat \
        the tied set as interchangeable._")

let test_no_note_when_not_truncated _ =
  (* Exactly [long_limit] candidates → no truncation, no note. *)
  let snap =
    _long_snap ~n:7 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let md = Report_renderer.render snap in
  assert_that md
    (not_ ~msg:"no note when nothing hidden" (_has_substring "not shown"))

let test_long_limit_override _ =
  (* Explicit [long_limit:3] tightens the cap and the header echoes it. *)
  let snap =
    _long_snap ~n:12 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let md = Report_renderer.render ~long_limit:3 snap in
  assert_that md
    (all_of
       [
         _has_substring "## Long candidates (top 3)";
         _has_substring "| 3 | SYM02 |";
         not_ ~msg:"row 4 truncated at limit 3" (_has_substring "| 4 | SYM03 |");
         _has_substring "_9 lower-scored candidates not shown._";
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
         "resistance_grade_column_rendered"
         >:: test_resistance_grade_column_rendered;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "long_candidates_truncated_to_default_7"
         >:: test_long_candidates_truncated_to_default_7;
         "truncation_note_flags_tied_cutoff"
         >:: test_truncation_note_flags_tied_cutoff;
         "no_note_when_not_truncated" >:: test_no_note_when_not_truncated;
         "long_limit_override" >:: test_long_limit_override;
       ]

let () = run_test_tt_main suite
