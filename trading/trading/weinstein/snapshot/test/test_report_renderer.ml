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
          sized_shares = 5;
          sized_position_value = 2510.65;
          sized_position_pct = 0.025;
          sized_risk_amount = 179.65;
          sizing_note = None;
          stop_is_structural = true;
          data_suspect = false;
          reconciliation = Entry_reconciliation.Not_reconciled;
          score_components = [];
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
          sized_shares = 0;
          sized_position_value = 0.0;
          sized_position_pct = 0.0;
          sized_risk_amount = 0.0;
          sizing_note = Some "0 sh — cash / caps exhausted";
          stop_is_structural = true;
          data_suspect = false;
          reconciliation = Entry_reconciliation.Not_reconciled;
          score_components = [];
        };
      ];
    short_candidates = [];
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
    held_positions =
      [
        {
          symbol = "GOOG";
          entered = _date "2020-06-19";
          stop = 1365.00;
          status = "Holding";
          shares = 3;
          entry_price = 1400.00;
          current_price = 1500.00;
          unrealized_pct = 7.14;
          recommended_stop = Some 1420.00;
        };
      ];
    warnings = [];
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
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
    held_positions = [];
    warnings = [];
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
         _has_substring "## Long candidates (top 20)";
         (* Pinned candidate row — fully formatted. Risk = (502.13-466.20)/502.13*100 = 7.155... → "7.2%".
            Resistance column shows the candidate's [resistance_grade] ("A"). *)
         _has_substring
           "| 1 | AAPL | A+ | 0.91 | $502.13 | - | $466.20 | 7.2% | A | Stage \
            2 breakout, 2.1x volume | BUY STOP 5 sh @ $502.13";
         (* Instruction cell carries the executable order end-to-end. *)
         _has_substring
           "on fill place SELL STOP @ $466.20, GTC; cancel if unfilled by \
            Friday close";
         _has_substring "## Short candidates (top 5)";
         _has_substring "## Held positions";
         (* Held row: shares, entry, current, unrealized %, current + suggested
            stop (with delta vs current). *)
         _has_substring
           "| GOOG | 3 | $1400.00 | $1500.00 | 7.1% | $1365.00 | $1420.00 \
            (+55.00) | 2020-06-19 | Holding |";
       ])

let test_empty_long_candidates_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md
    (all_of
       [
         _has_substring "## Long candidates (top 20)\n(none)";
         _has_substring "## Short candidates (top 5)\n(none)";
       ])

let test_empty_held_positions_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md (_has_substring "## Held positions\n(none)")

let test_empty_strong_sectors_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md (_has_substring "## Strong sectors\n(none)")

let test_empty_warnings_renders_marker _ =
  let md = Report_renderer.render _empty_snapshot in
  assert_that md (_has_substring "## Warnings\n(none)")

let test_warnings_rendered_as_bullets _ =
  let snap =
    {
      _empty_snapshot with
      warnings =
        [
          "SNSE: dropped from candidate consideration — sparse tail (6/15 \
           bars, need >= 10; see issue #2083)";
          "FTH: dropped from candidate consideration — sparse tail (3/15 bars, \
           need >= 10; see issue #2083)";
        ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "## Warnings";
         _has_substring "- SNSE: dropped from candidate consideration";
         _has_substring "- FTH: dropped from candidate consideration";
       ])

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
            sized_shares = 0;
            sized_position_value = 0.0;
            sized_position_pct = 0.0;
            sized_risk_amount = 0.0;
            sizing_note = None;
            stop_is_structural = true;
            data_suspect = false;
            reconciliation = Entry_reconciliation.Not_reconciled;
            score_components = [];
          };
        ];
    }
  in
  let md = Report_renderer.render snap in
  (* [resistance_grade = None] → the Resistance column renders "-". *)
  assert_that md
    (_has_substring
       "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00 | 10.0% | - | test |")

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
            sized_shares = 0;
            sized_position_value = 0.0;
            sized_position_pct = 0.0;
            sized_risk_amount = 0.0;
            sizing_note = None;
            stop_is_structural = true;
            data_suspect = false;
            reconciliation = Entry_reconciliation.Not_reconciled;
            score_components = [];
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
           "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00 | 10.0% | \
            Heavy_resistance (0.82) | test |";
         not_ ~msg:"grade string must carry no module-qualified prefix"
           (_has_substring "Weinstein_types.");
       ])

(* Candidate builder with the sizing fields exposed as optional params.
   [stop_is_structural] defaults to [true] (unmarked Stop cell) so the
   existing instruction-cell tests, which don't care about the stop-source
   marker, keep pinning a plain "$90.00" with no trailing asterisk.
   [data_suspect] defaults to [false] (unmarked Symbol cell) for the same
   reason — those tests pin a plain "| TEST |". *)
let _sized_cand ?(sized_shares = 0) ?(sized_position_value = 0.0)
    ?(sized_position_pct = 0.0) ?(sized_risk_amount = 0.0) ?(sizing_note = None)
    ?(stop_is_structural = true) ?(data_suspect = false)
    ?(reconciliation = Entry_reconciliation.Not_reconciled) () :
    Weekly_snapshot.candidate =
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
    sized_shares;
    sized_position_value;
    sized_position_pct;
    sized_risk_amount;
    sizing_note;
    stop_is_structural;
    data_suspect;
    reconciliation;
    score_components = [];
  }

let test_instruction_cell_rendered _ =
  (* A normally-sized long renders an executable BUY STOP order. *)
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [
          _sized_cand ~sized_shares:10 ~sized_position_value:1000.0
            ~sized_position_pct:0.05 ~sized_risk_amount:100.0 ();
        ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (_has_substring
       "BUY STOP 10 sh @ $100.00 (~$1000, 5.0% of book, risk $100); on fill \
        place SELL STOP @ $90.00, GTC; cancel if unfilled by Friday close")

let test_zero_share_reason_rendered _ =
  (* A 0-share result renders its reason, not an order. *)
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [ _sized_cand ~sizing_note:(Some "0 sh — cash / caps exhausted") () ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring
           "| 0.50 | $100.00 | - | $90.00 | 10.0% | - | test | 0 sh — cash / \
            caps exhausted |";
         not_ ~msg:"a 0-share result must not render an order"
           (_has_substring "BUY STOP");
       ])

let test_unsized_placeholder_rendered _ =
  (* A placeholder-sized long prefixes the UNSIZED note before the order. *)
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [
          _sized_cand ~sized_shares:10 ~sized_position_value:1000.0
            ~sized_position_pct:0.05 ~sized_risk_amount:100.0
            ~sizing_note:(Some "UNSIZED — set portfolio.sexp") ();
        ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (_has_substring "UNSIZED — set portfolio.sexp: BUY STOP 10 sh @ $100.00")

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
      sized_shares = 0;
      sized_position_value = 0.0;
      sized_position_pct = 0.0;
      sized_risk_amount = 0.0;
      sizing_note = None;
      stop_is_structural = true;
      data_suspect = false;
      reconciliation = Entry_reconciliation.Not_reconciled;
      score_components = [];
    }
  in
  { _empty_snapshot with long_candidates = List.init n ~f:(fun i -> make_c i) }

let test_default_limit_shows_full_screener_cap _ =
  (* The default long limit matches the screener's 20-candidate cap, so a
     default render hides nothing: 20 distinctly-scored candidates → rank 20
     rendered, no truncation note. *)
  let snap =
    _long_snap ~n:20 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| 20 | SYM19 |";
         not_ ~msg:"nothing hidden at the default limit"
           (_has_substring "not shown");
       ])

let test_long_candidates_truncated_at_limit _ =
  (* 12 distinctly-scored candidates at an explicit limit of 7 → rank 7
     present, rank 8 absent; note reports 5 lower-scored hidden (no ties at
     the cutoff). *)
  let snap =
    _long_snap ~n:12 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let md = Report_renderer.render ~long_limit:7 snap in
  assert_that md
    (all_of
       [
         _has_substring "| 7 | SYM06 |";
         not_ ~msg:"row 8 must be truncated" (_has_substring "| 8 | SYM07 |");
         _has_substring "_5 lower-scored candidates not shown._";
       ])

let test_truncation_note_flags_tied_cutoff _ =
  (* 12 candidates all tied at score 0.85, limit 7 → the cut is arbitrary
     among equals; the note must say 5 more are hidden and all 5 tie the
     cutoff. *)
  let snap = _long_snap ~n:12 ~score_of:(fun _ -> 0.85) in
  let md = Report_renderer.render ~long_limit:7 snap in
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
  let md = Report_renderer.render ~long_limit:7 snap in
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

(* Issue #2084 Finding 2: a fallback (non-structural) stop is marked with a
   trailing asterisk in the Stop cell, and the table gains an explanatory
   footnote below it. *)
let test_fallback_stop_marked_with_asterisk_and_note _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates = [ _sized_cand ~stop_is_structural:false () ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00* | 10.0% |";
         _has_substring "fallback stop";
       ])

(* A structural stop renders with no asterisk and no footnote — the default
   [_sized_cand] shape (see its docstring). *)
let test_structural_stop_has_no_asterisk_or_note _ =
  let snap = { _empty_snapshot with long_candidates = [ _sized_cand () ] } in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00 | 10.0% |";
         not_ ~msg:"no fallback-stop note when every shown stop is structural"
           (_has_substring "fallback stop");
       ])

(* Issue #2083 Finding 3: a spike-flagged candidate is marked with a trailing
   "(!)" in the Symbol cell and the table gains an explanatory footnote — but
   the row is still THERE (rank, entry, stop, instruction unchanged): the flag
   annotates, it does not drop.

   Mutation checks: reverting [_symbol_cell] to plain [c.symbol] fails the first
   matcher; dropping the [_data_suspect_note] legend from [_append_table_notes]
   fails the second. *)
let test_data_suspect_marked_with_marker_and_note _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates = [ _sized_cand ~data_suspect:true () ];
    }
  in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST (!) | B | 0.50 | $100.00 | - | $90.00 | 10.0% |";
         _has_substring "data-suspect";
       ])

(* An unflagged candidate renders with no marker and no footnote — the default
   [_sized_cand] shape (see its docstring). *)
let test_clean_candidate_has_no_marker_or_note _ =
  let snap = { _empty_snapshot with long_candidates = [ _sized_cand () ] } in
  let md = Report_renderer.render snap in
  assert_that md
    (all_of
       [
         _has_substring "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00 | 10.0% |";
         not_ ~msg:"no data-suspect note when no shown candidate is flagged"
           (_has_substring "data-suspect");
       ])

(* ------------------------------------------------------------------ *)
(* Entry reconciliation (issue #2103)                                   *)
(* ------------------------------------------------------------------ *)

let _reconciled_snap ~reconciliation ~sized_shares ~sized_position_value
    ~sized_position_pct ~sized_risk_amount =
  {
    _empty_snapshot with
    long_candidates =
      [
        _sized_cand ~sized_shares ~sized_position_value ~sized_position_pct
          ~sized_risk_amount ~reconciliation ();
      ];
  }

(* A THROUGH-ENTRY row: the Close-vs-entry column carries the close and the
   overshoot tagged "through", and the Instruction cell is a MARKET order at the
   close — not a resting BUY STOP at the (already-breached) $100.00 level. The
   sizes quoted are the fill-based ones the sizer produced (57 sh / $6116 /
   risk $986); the pre-fix ticket would have said "BUY STOP 100 sh @ $100.00
   … risk $1000". The legend explaining the column appears below the table.

   {b Risk % is quoted against the FILL}: (107.30 - 90.00) / 107.30 = 16.1%,
   which agrees with the instruction's own $986.10 / $6116.10 = 16.12%. The
   entry-based figure reads 10.0%, and the FIRST version of this test pinned
   exactly that — locking in a row whose Risk % cell contradicted the ticket
   printed beside it (review round 1). A row that disagrees with itself is issue
   #2103 in miniature, so the two numbers are now asserted together and a
   regression on either turns this red. *)
let test_through_entry_row_renders_market_order _ =
  let md =
    Report_renderer.render
      (_reconciled_snap
         ~reconciliation:
           (Entry_reconciliation.Through_entry
              { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
         ~sized_shares:57 ~sized_position_value:6116.10
         ~sized_position_pct:0.061161 ~sized_risk_amount:986.10)
  in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | $107.30 (+7.3% through) | $90.00 \
            | 16.1% |";
         _has_substring
           "BUY MARKET 57 sh @ ~$107.30 (~$6116, 6.1% of book, risk $986) — \
            price is 7.3% through the $100.00 entry level, so the order fills \
            at the market; sized on the expected fill, not the entry level; on \
            fill place SELL STOP @ $90.00, GTC";
         not_ ~msg:"a through-entry ticket must not be a resting stop"
           (_has_substring "BUY STOP");
         _has_substring "close vs entry:";
       ])

(* Issue #2158: an ARMED through-entry row (carrying a do-not-chase cap $115.00)
   renders a LIMIT buy at ~the close capped at the ceiling — NOT a MARKET order
   and NOT a resting stop. The sizes are the cap-based ones (40 sh / $4600 /
   worst-case risk $1000), and the Risk % column is quoted against the cap:
   (115.00 - 90.00) / 115.00 = 21.7%, agreeing with $1000 / $4600 = 21.7%. *)
let test_armed_through_entry_row_renders_limit_at_close _ =
  let md =
    Report_renderer.render
      (_reconciled_snap
         ~reconciliation:
           (Entry_reconciliation.Through_entry
              { close = 107.3; overshoot_pct = 7.3; cap = 115.0 })
         ~sized_shares:40 ~sized_position_value:4600.0 ~sized_position_pct:0.046
         ~sized_risk_amount:1000.0)
  in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | $107.30 (+7.3% through) | $90.00 \
            | 21.7% |";
         _has_substring
           "BUY LIMIT 40 sh @ ~$107.30, limit $115.00 (~$4600, 4.6% of book, \
            worst-case risk $1000) — price is 7.3% through the $100.00 entry \
            level; sized on the cap, not the entry level; on fill place SELL \
            STOP @ $90.00, GTC";
         not_ ~msg:"an armed through-entry ticket must not be a MARKET order"
           (_has_substring "BUY MARKET");
       ])

(* Issue #2158: an ARMED valid-stop row (price not yet at the entry, carrying a
   $115.00 cap) renders a resting STOPLIMIT quoting BOTH the trigger ($100.00)
   and the limit cap ($115.00), sized worst-case on the cap. *)
let test_armed_valid_stop_row_renders_stoplimit _ =
  let md =
    Report_renderer.render
      (_reconciled_snap
         ~reconciliation:
           (Entry_reconciliation.Valid_stop
              { close = 99.0; overshoot_pct = -1.0; cap = 115.0 })
         ~sized_shares:40 ~sized_position_value:4600.0 ~sized_position_pct:0.046
         ~sized_risk_amount:1000.0)
  in
  assert_that md
    (all_of
       [
         _has_substring
           "BUY STOPLIMIT 40 sh, trigger $100.00 limit $115.00 (~$4600, 4.6% \
            of book, worst-case risk $1000); on fill place SELL STOP @ $90.00, \
            GTC; cancel if unfilled by Friday close";
         not_ ~msg:"a stop-limit ticket must not be a plain resting stop"
           (_has_substring "BUY STOP 40");
       ])

(* Extended candidates leave the actionable table entirely: a mixed snapshot
   renders the valid candidate under "Long candidates" and the extended one
   under the watch section, each ranked within its own table (2026-07-27 user
   feedback: extended names must not consume actionable display slots). *)
let test_extended_candidate_moves_to_watch_section _ =
  let snap =
    _long_snap ~n:2 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  let snap =
    {
      snap with
      long_candidates =
        List.mapi snap.long_candidates ~f:(fun i c ->
            if i = 1 then
              {
                c with
                reconciliation =
                  Entry_reconciliation.Extended
                    { close = 134.5; overshoot_pct = 34.5; cap = 0.0 };
              }
            else c);
    }
  in
  let md = Report_renderer.render snap in
  let watch_at =
    String.substr_index_exn md ~pattern:"## Watch — extended, do not chase"
  in
  let sym01_at = String.substr_index_exn md ~pattern:"| SYM01 |" in
  assert_that md
    (all_of
       [
         _has_substring "| 1 | SYM00 |";
         (* The extended candidate ranks 1 within the watch table, not 2 in
            the actionable table. *)
         _has_substring "| 1 | SYM01 |";
         not_ ~msg:"extended must not hold an actionable rank"
           (_has_substring "| 2 | SYM01 |");
         (* And its row sits below the watch heading. *)
         matching ~msg:"SYM01 must render inside the watch section"
           (fun _ -> if sym01_at > watch_at then Some () else None)
           __;
       ])

let test_no_watch_section_without_extended _ =
  let snap =
    _long_snap ~n:2 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01))
  in
  assert_that
    (Report_renderer.render snap)
    (not_ ~msg:"watch section only exists when something is extended"
       (_has_substring "Watch — extended"))

(* An EXTENDED row KEEPS its place in the report (the issue is explicit about
   watch value) but carries NO executable order — only the do-not-chase reason,
   naming the overshoot, the entry level and the close. This is the MBX shape
   from the 2026-07-24 report. Since the watch-section split it renders under
   "Watch — extended, do not chase" rather than the actionable table. *)
let test_extended_row_is_kept_but_ticket_suppressed _ =
  let md =
    Report_renderer.render
      (_reconciled_snap
         ~reconciliation:
           (Entry_reconciliation.Extended
              { close = 134.5; overshoot_pct = 34.5; cap = 0.0 })
         ~sized_shares:0 ~sized_position_value:0.0 ~sized_position_pct:0.0
         ~sized_risk_amount:0.0)
  in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | $134.50 (+34.5% EXTENDED) | \
            $90.00 | 10.0% |";
         _has_substring
           "NO ORDER — do not chase: +34.5% past the $100.00 entry level \
            (close $134.50).";
         not_ ~msg:"an extended candidate must emit no buy order"
           (_has_substring "BUY ");
         _has_substring "close vs entry:";
       ])

(* A VALID-STOP row shows the close and a NEGATIVE overshoot, keeps today's
   resting-stop ticket, and needs no legend — the reconciliation changed
   nothing, so explaining it would be noise. *)
let test_valid_stop_row_keeps_resting_ticket_and_needs_no_legend _ =
  let md =
    Report_renderer.render
      (_reconciled_snap
         ~reconciliation:
           (Entry_reconciliation.Valid_stop
              { close = 96.0; overshoot_pct = -4.0; cap = 0.0 })
         ~sized_shares:100 ~sized_position_value:10_000.0
         ~sized_position_pct:0.10 ~sized_risk_amount:1000.0)
  in
  assert_that md
    (all_of
       [
         _has_substring
           "| 1 | TEST | B | 0.50 | $100.00 | $96.00 (-4.0%) | $90.00 | 10.0% |";
         _has_substring "BUY STOP 100 sh @ $100.00";
         not_ ~msg:"no reconciliation legend when nothing was re-anchored"
           (_has_substring "close vs entry:");
       ])

(* The disarmed default (R1): the column renders "-", the ticket is exactly
   today's resting stop, and no legend appears. *)
let test_unreconciled_row_renders_dash_and_todays_ticket _ =
  let md =
    Report_renderer.render
      (_reconciled_snap ~reconciliation:Entry_reconciliation.Not_reconciled
         ~sized_shares:100 ~sized_position_value:10_000.0
         ~sized_position_pct:0.10 ~sized_risk_amount:1000.0)
  in
  assert_that md
    (all_of
       [
         _has_substring "| 1 | TEST | B | 0.50 | $100.00 | - | $90.00 | 10.0% |";
         _has_substring
           "BUY STOP 100 sh @ $100.00 (~$10000, 10.0% of book, risk $1000); on \
            fill place SELL STOP @ $90.00, GTC; cancel if unfilled by Friday \
            close";
         not_ ~msg:"no reconciliation legend on an unreconciled table"
           (_has_substring "close vs entry:");
       ])

(* Issue #2122 slice d: the screener caps candidates at [max_buy_candidates];
   [long_eligible_beyond_cap] carries how many otherwise-eligible names it cut,
   so the report can say the shown list is a capped view. The line names the
   count and the lowest shown score (MSFT's 0.87 here — the last of the two
   shown rows). *)
let test_eligible_beyond_cap_line_rendered _ =
  let snap = { _full_snapshot with long_eligible_beyond_cap = 7 } in
  assert_that
    (Report_renderer.render snap)
    (_has_substring
       "7 additional eligible candidates beyond the displayed cap (lowest \
        shown score 0.87).")

(* A [0] count (the default of every pre-#2122 record) renders no such line. *)
let test_no_eligible_beyond_cap_line_when_zero _ =
  assert_that
    (Report_renderer.render _full_snapshot)
    (not_ ~msg:"no beyond-cap line when the count is zero"
       (_has_substring "additional eligible candidate"))

let suite =
  "report_renderer"
  >::: [
         "eligible_beyond_cap_line_rendered"
         >:: test_eligible_beyond_cap_line_rendered;
         "no_eligible_beyond_cap_line_when_zero"
         >:: test_no_eligible_beyond_cap_line_when_zero;
         "through_entry_row_renders_market_order"
         >:: test_through_entry_row_renders_market_order;
         "armed_through_entry_row_renders_limit_at_close"
         >:: test_armed_through_entry_row_renders_limit_at_close;
         "armed_valid_stop_row_renders_stoplimit"
         >:: test_armed_valid_stop_row_renders_stoplimit;
         "extended_candidate_moves_to_watch_section"
         >:: test_extended_candidate_moves_to_watch_section;
         "no_watch_section_without_extended"
         >:: test_no_watch_section_without_extended;
         "extended_row_is_kept_but_ticket_suppressed"
         >:: test_extended_row_is_kept_but_ticket_suppressed;
         "valid_stop_row_keeps_resting_ticket_and_needs_no_legend"
         >:: test_valid_stop_row_keeps_resting_ticket_and_needs_no_legend;
         "unreconciled_row_renders_dash_and_todays_ticket"
         >:: test_unreconciled_row_renders_dash_and_todays_ticket;
         "full_snapshot_contains_all_sections"
         >:: test_full_snapshot_contains_all_sections;
         "empty_long_candidates_renders_marker"
         >:: test_empty_long_candidates_renders_marker;
         "empty_held_positions_renders_marker"
         >:: test_empty_held_positions_renders_marker;
         "empty_strong_sectors_renders_marker"
         >:: test_empty_strong_sectors_renders_marker;
         "empty_warnings_renders_marker" >:: test_empty_warnings_renders_marker;
         "warnings_rendered_as_bullets" >:: test_warnings_rendered_as_bullets;
         "bearish_macro_rendered" >:: test_bearish_macro_rendered;
         "risk_pct_formatting" >:: test_risk_pct_formatting;
         "resistance_grade_column_rendered"
         >:: test_resistance_grade_column_rendered;
         "instruction_cell_rendered" >:: test_instruction_cell_rendered;
         "zero_share_reason_rendered" >:: test_zero_share_reason_rendered;
         "unsized_placeholder_rendered" >:: test_unsized_placeholder_rendered;
         "fallback_stop_marked_with_asterisk_and_note"
         >:: test_fallback_stop_marked_with_asterisk_and_note;
         "structural_stop_has_no_asterisk_or_note"
         >:: test_structural_stop_has_no_asterisk_or_note;
         "data_suspect_marked_with_marker_and_note"
         >:: test_data_suspect_marked_with_marker_and_note;
         "clean_candidate_has_no_marker_or_note"
         >:: test_clean_candidate_has_no_marker_or_note;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "default_limit_shows_full_screener_cap"
         >:: test_default_limit_shows_full_screener_cap;
         "long_candidates_truncated_at_limit"
         >:: test_long_candidates_truncated_at_limit;
         "truncation_note_flags_tied_cutoff"
         >:: test_truncation_note_flags_tied_cutoff;
         "no_note_when_not_truncated" >:: test_no_note_when_not_truncated;
         "long_limit_override" >:: test_long_limit_override;
       ]

let () = run_test_tt_main suite
