(** Cross-artifact identity (issue #2122 slice b).

    {!Report_renderer} (Markdown) and {!Html_report_renderer} (HTML) render the
    same snapshot in two formats. The broker-facing {b order instruction} must
    be character-identical across the two — a reader who copies the ticket from
    either report must get the same order. Today only unit-level pins exist
    ({!Report_shared.instruction} is called by both). This suite extends those
    to a {b whole-artifact} comparison: it renders BOTH full artifacts from one
    snapshot and asserts that, for every candidate, the shared instruction
    string appears verbatim in each.

    {1 Why substring-against-the-seam}

    Both renderers derive the ticket from {!Report_shared.instruction}; the HTML
    one wraps it in [Html_page.escape]. So the identity claim is exactly
    "neither renderer post-processes the string beyond its own format's
    escaping". The test proves this by computing [Report_shared.instruction c]
    itself and asserting the Markdown carries it raw and the HTML carries
    [escape] of it — a string no [_has_substring] literal here hard-codes, so a
    renderer that formatted its own lookalike sentence would drift and fail.
    Because [Html_page.escape] is the identity on these tickets (they carry no
    HTML metacharacters), the two artifacts carry byte-identical instruction
    text. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _date d = Date.of_string d

let _has_substring substring : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected substring %S" substring)
    (fun s -> if String.is_substring s ~substring then Some () else None)
    __

(* A candidate with every field set; callers override the reconciliation /
   sizing fields to select a ticket shape. *)
let _candidate ~symbol ~score ~reconciliation ~sized_shares ~sizing_note :
    Weekly_snapshot.candidate =
  {
    symbol;
    score;
    grade = "A+";
    entry = 28.49;
    stop = 26.21;
    sector = "Health Care";
    rationale = "Stage1 to Stage2 breakout; Strong volume";
    rs_vs_spy = Some 1.1;
    resistance_grade = Some "Clean (0.20)";
    sized_shares;
    sized_position_value = 1651.0;
    sized_position_pct = 0.016;
    sized_risk_amount = 198.0;
    sizing_note;
    stop_is_structural = true;
    data_suspect = false;
    reconciliation;
    score_components = [];
  }

(* Every reconciliation class that produces a distinct ticket verb, plus the
   post-#2171 STOPLIMIT / LIMIT cap wording:
   - [Not_reconciled] sized ...... BUY STOP
   - [Valid_stop] with a cap ...... BUY STOPLIMIT (issue #2158)
   - [Through_entry] with a cap ... BUY LIMIT (issue #2103/#2158)
   - [Extended] ................... NO ORDER — do not chase (rendered in watch)
   - a 0-share short with a note .. the note verbatim
   The share counts / notes are distinct so no two instructions collide. *)
let _buy_stop =
  _candidate ~symbol:"AAA" ~score:100.0
    ~reconciliation:Entry_reconciliation.Not_reconciled ~sized_shares:55
    ~sizing_note:None

let _buy_stoplimit =
  _candidate ~symbol:"BBB" ~score:98.0
    ~reconciliation:
      (Entry_reconciliation.Valid_stop
         { close = 28.0; overshoot_pct = -1.7; cap = 30.05 })
    ~sized_shares:54 ~sizing_note:None

let _buy_limit =
  _candidate ~symbol:"CCC" ~score:96.0
    ~reconciliation:
      (Entry_reconciliation.Through_entry
         { close = 30.55; overshoot_pct = 7.3; cap = 30.05 })
    ~sized_shares:53 ~sizing_note:None

let _extended =
  _candidate ~symbol:"DDD" ~score:94.0
    ~reconciliation:
      (Entry_reconciliation.Extended
         { close = 40.0; overshoot_pct = 40.4; cap = 30.05 })
    ~sized_shares:0 ~sizing_note:None

let _short_note =
  _candidate ~symbol:"EEE" ~score:80.0
    ~reconciliation:Entry_reconciliation.Not_reconciled ~sized_shares:0
    ~sizing_note:(Some "0 sh — cash / caps exhausted")

let _all_classes_snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "cafe1234";
    date = _date "2026-07-24";
    macro = { regime = "Bullish"; score = 1.0 };
    sectors_strong = [ "Health Care" ];
    sectors_weak = [];
    long_candidates = [ _buy_stop; _buy_stoplimit; _buy_limit; _extended ];
    short_candidates = [ _short_note ];
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
    held_positions = [];
    warnings = [];
  }

(* For one rendered pair, every candidate's instruction appears verbatim in the
   Markdown and escaped-verbatim in the HTML. Two [assert_that]s (one per
   rendered artifact), each composing the per-candidate checks via [all_of]. *)
let _assert_instruction_identity (t : Weekly_snapshot.t) =
  let candidates = t.long_candidates @ t.short_candidates in
  let md = Report_renderer.render t in
  let html = Html_report_renderer.render t in
  let in_md c = _has_substring (Report_shared.instruction c) in
  let in_html c =
    _has_substring (Html_page.escape (Report_shared.instruction c))
  in
  assert_that md (all_of (List.map candidates ~f:in_md));
  assert_that html (all_of (List.map candidates ~f:in_html))

(* Sanity that the synthetic fixture really does exercise the four distinct
   ticket verbs — otherwise the identity assertion could be green on a fixture
   that never produced a STOPLIMIT / LIMIT / do-not-chase line. *)
let test_synthetic_fixture_covers_every_ticket_verb _ =
  let md = Report_renderer.render _all_classes_snapshot in
  assert_that md
    (all_of
       [
         _has_substring "BUY STOP 55 sh";
         _has_substring "BUY STOPLIMIT 54 sh";
         _has_substring "BUY LIMIT 53 sh";
         _has_substring "NO ORDER — do not chase";
         _has_substring "0 sh — cash / caps exhausted";
       ])

let test_synthetic_instruction_is_identical_across_artifacts _ =
  _assert_instruction_identity _all_classes_snapshot

(* The same whole-artifact check against a REAL committed record (the 07-24 v3
   report, 20 reconciled long candidates), so a divergence introduced by either
   renderer on production-shaped data — not just the synthetic fixture — turns
   this red. *)
let _committed_790d_path = "fixtures/picks/790d23a06-2026-07-24.sexp"

let _read_fixture path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err -> failwith ("Failed to read fixture: " ^ Status.show err)

let test_committed_record_instruction_is_identical_across_artifacts _ =
  _assert_instruction_identity (_read_fixture _committed_790d_path)

let suite =
  "report_cross_artifact"
  >::: [
         "synthetic_fixture_covers_every_ticket_verb"
         >:: test_synthetic_fixture_covers_every_ticket_verb;
         "synthetic_instruction_is_identical_across_artifacts"
         >:: test_synthetic_instruction_is_identical_across_artifacts;
         "committed_record_instruction_is_identical_across_artifacts"
         >:: test_committed_record_instruction_is_identical_across_artifacts;
       ]

let () = run_test_tt_main suite
