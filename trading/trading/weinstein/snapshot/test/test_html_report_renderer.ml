(** Tests for {!Html_report_renderer} — self-contained HTML weekly report.

    Fixture design note: the long candidate, the short candidate and the held
    position carry {b distinguishable} symbols, prices, flags and bar series.
    That is deliberate — a fixture whose arms are interchangeable lets a whole
    rendering arm be deleted with the suite still green. Here every arm is
    asserted by its own symbol and its own price levels, so mutating (say) the
    short-candidate chart call to {!Html_report_renderer.no_bars} turns a test
    red. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _date d = Date.of_string d

let _bar ~day ~price : Types.Daily_price.t =
  Types.Daily_price.make
    ~date:(Date.add_days (_date "2020-08-01") day)
    ~open_price:price ~high_price:price ~low_price:price ~close_price:price
    ~volume:1000 ~adjusted_close:price ()

(* Three bars per symbol, each series scaled to that symbol's own price area so
   the three charts are not interchangeable. *)
let _series base =
  List.init 3 ~f:(fun i -> _bar ~day:i ~price:(base +. Float.of_int i))

let _bars_table = [ ("LONGA", _series 98.0); ("SHRTB", _series 48.0) ]

let _bars_for ~symbol =
  Option.value
    (List.Assoc.find _bars_table ~equal:String.equal symbol)
    ~default:[]

(* Bars for the held symbol only — used by the held-chart test so a long/short
   chart cannot satisfy its assertion by accident. *)
let _held_bars_for ~symbol =
  if String.equal symbol "GOOG" then _series 1398.0 else []

let _long_candidate : Weekly_snapshot.candidate =
  {
    symbol = "LONGA";
    score = 0.91;
    grade = "A+";
    entry = 100.0;
    stop = 90.0;
    sector = "XLK";
    rationale = "Stage 2 breakout, 2.1x volume";
    rs_vs_spy = Some 1.34;
    resistance_grade = Some "Virgin_territory (0.95)";
    sized_shares = 10;
    sized_position_value = 1000.0;
    sized_position_pct = 0.05;
    sized_risk_amount = 100.0;
    sizing_note = None;
    stop_is_structural = true;
    data_suspect = false;
    reconciliation = Entry_reconciliation.Not_reconciled;
  }

(* Deliberately the opposite of [_long_candidate] on every rendered flag: a
   fallback stop, spike-flagged, no resistance grade, unsized, and a stop ABOVE
   the entry (short convention). *)
let _short_candidate : Weekly_snapshot.candidate =
  {
    _long_candidate with
    symbol = "SHRTB";
    score = 0.77;
    grade = "B";
    entry = 50.0;
    stop = 55.0;
    rationale = "Stage 4 breakdown";
    resistance_grade = None;
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    stop_is_structural = false;
    data_suspect = true;
    reconciliation = Entry_reconciliation.Not_reconciled;
  }

let _held : Weekly_snapshot.held_position =
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
    warnings = [];
  }

let _full_snapshot : Weekly_snapshot.t =
  {
    _empty_snapshot with
    system_version = "c93bf39d";
    date = _date "2020-08-28";
    macro = { regime = "Bullish"; score = 0.72 };
    sectors_strong = [ "XLK"; "XLY" ];
    long_candidates = [ _long_candidate ];
    short_candidates = [ _short_candidate ];
    held_positions = [ _held ];
    warnings = [ "SNSE: dropped — sparse tail (6/15 bars)" ];
  }

let _has_substring substring : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected substring %S" substring)
    (fun s -> if String.is_substring s ~substring then Some () else None)
    __

let _starts_with prefix : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected prefix %S" prefix)
    (fun s -> if String.is_prefix s ~prefix then Some () else None)
    __

let _ends_with suffix : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected suffix %S" suffix)
    (fun s -> if String.is_suffix s ~suffix then Some () else None)
    __

(* Asserts the needles appear in the given order, each after the previous. *)
let _in_order needles : string matcher =
  matching
    ~msg:
      (Printf.sprintf "Expected in order: %s"
         (String.concat ~sep:" < " needles))
    (fun s ->
      let positions =
        List.map needles ~f:(fun n -> String.substr_index s ~pattern:n)
      in
      match Option.all positions with
      | Some ps when List.is_sorted_strictly ps ~compare:Int.compare -> Some ()
      | _ -> None)
    __

let _count s ~needle =
  List.length (String.substr_index_all s ~may_overlap:false ~pattern:needle)

(* ------- Document shell ------- *)

let test_document_is_self_contained _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         (* Prefix AND suffix, not substrings: the .mli claims a "complete
            HTML document ... terminated by a final newline", and a truncated
            format string that drops the closing tags satisfies every
            substring assertion while emitting unterminated markup. *)
         _starts_with "<!DOCTYPE html>\n<html lang=\"en\">\n";
         _ends_with "\n</body>\n</html>\n";
         _has_substring "<meta charset=\"utf-8\">";
         _has_substring "<title>Weekly Pick Report — 2020-08-28</title>";
         _has_substring "<style>";
         _has_substring "svg.spark .lvl-stop";
         not_ ~msg:"no external stylesheet" (_has_substring "<link");
         not_ ~msg:"no script tag" (_has_substring "<script");
       ])

let test_header_and_macro _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<h1>Weekly Pick Report — 2020-08-28</h1>";
         _has_substring
           "<p class=\"subtitle\">System version: <code>c93bf39d</code></p>";
         _has_substring
           "<p class=\"macro\"><strong>Bullish</strong> (score 0.72)</p>";
       ])

let test_bearish_macro_rendered _ =
  let snap =
    { _empty_snapshot with macro = { regime = "Bearish"; score = -0.45 } }
  in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring "<strong>Bearish</strong> (score -0.45)")

let test_section_order_matches_markdown_report _ =
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (_in_order
       [
         "<h2>Macro</h2>";
         "<h2>Strong sectors</h2>";
         "<h2>Long candidates (top 7)</h2>";
         "<h2>Short candidates (top 5)</h2>";
         "<h2>Held positions</h2>";
         "<h2>Warnings</h2>";
       ])

(* ------- Empty sections ------- *)

let test_every_empty_section_renders_the_none_marker _ =
  let html = Html_report_renderer.render _empty_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<h2>Strong sectors</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring
           "<h2>Long candidates (top 7)</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring
           "<h2>Short candidates (top 5)</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring "<h2>Held positions</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring "<h2>Warnings</h2>\n<p class=\"empty\">(none)</p>";
       ])

(* ------- Lists ------- *)

let test_sectors_and_warnings_render_as_bullets _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<ul><li>XLK</li><li>XLY</li></ul>";
         _has_substring "<li>SNSE: dropped — sparse tail (6/15 bars)</li>";
       ])

(* ------- Candidate rows ------- *)

(* The header row and the body row are pinned COMPLETE and adjacent, because
   only the pair fixes column ORDER. Loose per-cell substrings do not: swapping
   the Entry and Stop cells inside [_candidate_row] leaves both "$100.00" and
   "$90.00" present somewhere in the document, so the page renders
   "Entry $90.00 / Stop $100.00" under headers saying the opposite while every
   substring assertion still holds. Risk % = (100 - 90) / 100 * 100. *)
let test_long_candidate_row_cells _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<thead><tr><th>Rank</th><th>Symbol</th><th>Grade</th><th>Score</th><th>Entry</th><th>Close \
            vs entry</th><th>Stop</th><th>Risk \
            %</th><th>Resistance</th><th>Rationale</th><th>Instruction</th><th>Chart</th></tr></thead>";
         _has_substring
           "<tr><td class=\"num\">1</td><td class=\"\">LONGA</td><td \
            class=\"\">A+</td><td class=\"num\">0.91</td><td \
            class=\"num\">$100.00</td><td class=\"num\">$90.00</td><td \
            class=\"num\">10.0%</td><td class=\"\">Virgin_territory \
            (0.95)</td><td class=\"rationale\">Stage 2 breakout, 2.1x \
            volume</td><td class=\"instruction\">BUY STOP 10 sh @ $100.00 \
            (~$1000, 5.0% of book, risk $100); on fill place SELL STOP @ \
            $90.00, GTC; cancel if unfilled by Friday close</td><td \
            class=\"chart\" data-chart=\"long:LONGA\"><span \
            class=\"nochart\">no chart data</span></td></tr>";
       ])

let test_short_candidate_row_is_rendered_in_its_own_table _ =
  (* The short arm is a separate table with its own rank-1 row. Its risk cell
     is negative — the long-convention formula applied to a stop above entry —
     which no long fixture can produce, so this cell cannot be satisfied by the
     long table. *)
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (_in_order
       [
         "<h2>Short candidates (top 5)</h2>";
         (* Complete row, same reason as the long arm: cell ORDER is only
            pinned by the whole <tr>. Every cell here differs from the long
            fixture's — flagged symbol, fallback stop, negative risk, no
            grade, unsized instruction — so this cannot be satisfied by the
            long table's output. *)
         "<tr><td class=\"num\">1</td><td class=\"\">SHRTB <span \
          class=\"flag\">(!)</span></td><td class=\"\">B</td><td \
          class=\"num\">0.77</td><td class=\"num\">$50.00</td><td \
          class=\"num\">$55.00*</td><td class=\"num\">-10.0%</td><td \
          class=\"\">-</td><td class=\"rationale\">Stage 4 breakdown</td><td \
          class=\"instruction\">-</td><td class=\"chart\" \
          data-chart=\"short:SHRTB\"><span class=\"nochart\">no chart \
          data</span></td></tr>";
       ])

let test_structural_stop_has_no_asterisk _ =
  let snap = { _empty_snapshot with long_candidates = [ _long_candidate ] } in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "<td class=\"num\">$90.00</td>";
         not_ ~msg:"no fallback legend when every shown stop is structural"
           (_has_substring "fallback stop");
       ])

let test_fallback_stop_marked_and_explained _ =
  let snap = { _empty_snapshot with long_candidates = [ _short_candidate ] } in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "<td class=\"num\">$55.00*</td>";
         _has_substring "<p class=\"note\">* fallback stop:";
       ])

let test_clean_candidate_has_no_flag_marker _ =
  let snap = { _empty_snapshot with long_candidates = [ _long_candidate ] } in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "<td class=\"\">LONGA</td>";
         not_ ~msg:"no data-suspect legend when nothing is flagged"
           (_has_substring "data-suspect");
       ])

let test_data_suspect_marked_and_explained_on_the_short_arm _ =
  (* Pins the marker + legend through the SHORT table specifically — three of
     the last four defects on this track were an unpinned secondary arm. *)
  let snap = { _empty_snapshot with short_candidates = [ _short_candidate ] } in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "SHRTB <span class=\"flag\">(!)</span>";
         _has_substring "<p class=\"note\">(!) data-suspect:";
       ])

let test_missing_resistance_grade_renders_a_dash _ =
  let snap = { _empty_snapshot with long_candidates = [ _short_candidate ] } in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring "<td class=\"\">-</td>")

let test_zero_share_candidate_renders_a_dash_instruction _ =
  let snap = { _empty_snapshot with long_candidates = [ _short_candidate ] } in
  assert_that
    (Html_report_renderer.render snap)
    (all_of
       [
         _has_substring "<td class=\"instruction\">-</td>";
         not_ ~msg:"an unsized candidate must not render an order"
           (_has_substring "BUY STOP");
       ])

let test_zero_share_reason_rendered _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [
          {
            _short_candidate with
            sizing_note = Some "0 sh — cash / caps exhausted";
          };
        ];
    }
  in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring
       "<td class=\"instruction\">0 sh — cash / caps exhausted</td>")

(* ------- Truncation ------- *)

let _n_candidates ~n ~score_of =
  List.init n ~f:(fun i ->
      {
        _long_candidate with
        symbol = Printf.sprintf "SYM%02d" i;
        score = score_of i;
      })

let test_long_table_truncated_with_tie_honest_note _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates = _n_candidates ~n:12 ~score_of:(fun _ -> 0.85);
    }
  in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "<td class=\"\">SYM06</td>";
         not_ ~msg:"row 8 truncated"
           (_has_substring "<td class=\"\">SYM07</td>");
         _has_substring
           "<p class=\"note\">5 more candidates not shown; 5 tie the cutoff \
            score (0.85).";
       ])

let test_short_table_truncated_at_its_own_limit _ =
  (* The short table's cap is independent of the long one: 8 shorts under the
     default short limit of 5 hides 3. *)
  let snap =
    {
      _empty_snapshot with
      short_candidates =
        _n_candidates ~n:8 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01));
    }
  in
  assert_that
    (Html_report_renderer.render snap)
    (all_of
       [
         _has_substring "<td class=\"\">SYM04</td>";
         not_ ~msg:"short row 6 truncated"
           (_has_substring "<td class=\"\">SYM05</td>");
         _has_substring "<p class=\"note\">3 lower-scored candidates not shown.";
       ])

let test_limit_overrides_are_honoured _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        _n_candidates ~n:12 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01));
      short_candidates =
        _n_candidates ~n:12 ~score_of:(fun i -> 1.0 -. (Float.of_int i *. 0.01));
    }
  in
  let html = Html_report_renderer.render ~long_limit:3 ~short_limit:2 snap in
  assert_that html
    (all_of
       [
         _has_substring "<h2>Long candidates (top 3)</h2>";
         _has_substring "<h2>Short candidates (top 2)</h2>";
         _has_substring "<p class=\"note\">9 lower-scored candidates not shown.";
         _has_substring
           "<p class=\"note\">10 lower-scored candidates not shown.";
       ])

let test_untruncated_table_has_no_note _ =
  let snap = { _empty_snapshot with long_candidates = [ _long_candidate ] } in
  assert_that
    (Html_report_renderer.render snap)
    (not_ ~msg:"no note when nothing is hidden" (_has_substring "not shown"))

(* ------- Held positions ------- *)

let test_held_row_cells _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<thead><tr><th>Symbol</th><th>Shares</th><th>Entry</th><th>Current</th><th>Unrealized \
            %</th><th>Stop</th><th>Suggested \
            stop</th><th>Entered</th><th>Status</th><th>Chart</th></tr></thead>";
         _has_substring
           "<td class=\"\">GOOG</td><td class=\"num\">3</td><td \
            class=\"num\">$1400.00</td><td class=\"num\">$1500.00</td><td \
            class=\"num\">7.1%</td><td class=\"num\">$1365.00</td><td \
            class=\"num\">$1420.00 (+55.00)</td><td \
            class=\"\">2020-06-19</td><td class=\"\">Holding</td>";
       ])

let test_held_row_without_recomputed_stop_renders_a_dash _ =
  let snap =
    {
      _empty_snapshot with
      held_positions = [ { _held with recommended_stop = None } ];
    }
  in
  assert_that
    (Html_report_renderer.render snap)
    (all_of
       [
         _has_substring
           "<td class=\"num\">$1365.00</td><td class=\"num\">-</td>";
         not_ ~msg:"no delta when nothing was recomputed"
           (_has_substring "(+55.00)");
       ])

(* ------- Charts, per arm ------- *)

let test_long_candidate_chart_rendered _ =
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"long:LONGA\"><svg class=\"spark\"";
         _has_substring "<title>entry $100.00</title>";
         _has_substring "<title>stop $90.00</title>";
       ])

let test_short_candidate_chart_rendered _ =
  (* Mutating the short arm's chart call to [no_bars] — or dropping the Chart
     cell from the short table — fails here. The levels are the SHORT
     candidate's own prices, which no other arm produces. *)
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"short:SHRTB\"><svg class=\"spark\"";
         _has_substring "<title>entry $50.00</title>";
         _has_substring "<title>stop $55.00</title>";
       ])

let test_held_position_chart_rendered _ =
  (* Held charts use the FILL price and the CURRENT stop. [_held_bars_for]
     supplies bars for GOOG only, so a candidate chart cannot satisfy this. *)
  let html =
    Html_report_renderer.render ~bars_for:_held_bars_for _full_snapshot
  in
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"held:GOOG\"><svg class=\"spark\"";
         _has_substring "<title>fill $1400.00</title>";
         _has_substring "<title>stop $1365.00</title>";
       ])

let test_chart_carries_band_and_volume _ =
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of [ _has_substring "class=\"band\""; _has_substring "class=\"vol\"" ])

let test_all_three_arms_chart_independently _ =
  (* One render, one bar source covering every symbol: exactly three charts,
     one per arm. A missing arm shows up as a count of 2. *)
  let bars_for ~symbol =
    if String.equal symbol "GOOG" then _series 1398.0 else _bars_for ~symbol
  in
  let html = Html_report_renderer.render ~bars_for _full_snapshot in
  assert_that (_count html ~needle:"<svg class=\"spark\"") (equal_to 3);
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"long:LONGA\"><svg";
         _has_substring "data-chart=\"short:SHRTB\"><svg";
         _has_substring "data-chart=\"held:GOOG\"><svg";
       ])

(* ------- Graceful degradation ------- *)

let test_default_bar_source_degrades_every_chart_cell _ =
  (* No bar source at all: the page is still complete — headers, rows, notes —
     and every chart cell carries the marker instead of an svg. *)
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "data-chart=\"long:LONGA\"><span class=\"nochart\">no chart \
            data</span>";
         _has_substring "data-chart=\"short:SHRTB\"><span class=\"nochart\">";
         _has_substring "data-chart=\"held:GOOG\"><span class=\"nochart\">";
         _has_substring "<td class=\"num\">$100.00</td>";
         _has_substring "<li>SNSE: dropped — sparse tail (6/15 bars)</li>";
         not_ ~msg:"no svg without bars" (_has_substring "<svg class=\"spark\"");
       ])

let test_partial_bar_coverage_degrades_only_the_uncovered_row _ =
  (* [_bars_for] knows LONGA and SHRTB but not GOOG. *)
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"long:LONGA\"><svg";
         _has_substring "data-chart=\"held:GOOG\"><span class=\"nochart\">";
       ])

let test_single_bar_symbol_degrades _ =
  (* One bar is below [Svg_chart]'s two-bar floor — the row degrades rather
     than emitting a degenerate chart. *)
  let bars_for ~symbol =
    if String.equal symbol "LONGA" then [ _bar ~day:0 ~price:100.0 ] else []
  in
  assert_that
    (Html_report_renderer.render ~bars_for _full_snapshot)
    (_has_substring "data-chart=\"long:LONGA\"><span class=\"nochart\">")

(* ------- Escaping ------- *)

let test_snapshot_text_is_escaped _ =
  let snap =
    {
      _empty_snapshot with
      macro = { regime = "<b>Bull</b>"; score = 0.1 };
      sectors_strong = [ "X&Y" ];
      long_candidates =
        [ { _long_candidate with rationale = "<script>alert(1)</script>" } ];
      warnings = [ "AT&T: dropped" ];
    }
  in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "&lt;script&gt;alert(1)&lt;/script&gt;";
         _has_substring "<strong>&lt;b&gt;Bull&lt;/b&gt;</strong>";
         _has_substring "<li>X&amp;Y</li>";
         _has_substring "<li>AT&amp;T: dropped</li>";
         not_ ~msg:"no raw script element from snapshot text"
           (_has_substring "<script>");
       ])

(* ------- Determinism ------- *)

let test_render_is_deterministic _ =
  let first = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  let second = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that first (equal_to second)

let test_no_bars_is_the_empty_source _ =
  assert_that (Html_report_renderer.no_bars ~symbol:"LONGA") (elements_are [])

(* ------------------------------------------------------------------ *)
(* Entry reconciliation (issue #2103)                                   *)
(* ------------------------------------------------------------------ *)

(* A through-entry LONG and an extended SHORT, so both rendering arms carry a
   chip and neither arm's assertion can be satisfied by the other's row. *)
let _reconciled_snapshot =
  {
    _full_snapshot with
    long_candidates =
      [
        {
          _long_candidate with
          reconciliation =
            Entry_reconciliation.Through_entry
              { close = 107.3; overshoot_pct = 7.3 };
          sized_shares = 57;
          sized_position_value = 6116.10;
          sized_position_pct = 0.061161;
          sized_risk_amount = 986.10;
        };
      ];
    short_candidates =
      [
        {
          _short_candidate with
          reconciliation =
            Entry_reconciliation.Extended { close = 65.5; overshoot_pct = 34.5 };
        };
      ];
  }

(* The class rides as a tag chip with a per-class CSS modifier, and the chip's
   text is the SAME string the Markdown column shows — both come from
   [Report_shared.close_vs_entry], so the two formats cannot drift.

   The Risk % cell is asserted here too. The first version of this test had NO
   Risk % assertion on a reconciled row, which is exactly why the HTML side of
   the stale-risk defect survived eight mutations invisibly (review round 1):
   (107.30 - 90.00) / 107.30 = 16.1% at the fill, where the entry-based figure
   reads 10.0%. Same number the Markdown renderer pins, so the two formats are
   held to one arithmetic. *)
let test_through_entry_chip_rendered_on_the_long_arm _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<td class=\"num\"><span class=\"chip chip-through-entry\">$107.30 \
            (+7.3% through)</span></td>";
         _has_substring "<td class=\"num\">16.1%</td>";
         not_
           ~msg:"Risk % must not be quoted against the already-breached entry"
           (_has_substring "<td class=\"num\">10.0%</td>");
         _has_substring
           "<td class=\"instruction\">BUY MARKET 57 sh @ ~$107.30 (~$6116, \
            6.1% of book, risk $986)";
         _has_substring "close vs entry:";
       ])

(* The SHORT arm gets the mirrored treatment: an over-extended short carries the
   EXTENDED chip and its ticket is suppressed. Mutating the short-side reconcile
   wiring to a no-op leaves [Not_reconciled], which renders a plain "-" cell and
   fails the first matcher.

   Risk % for an EXTENDED row stays quoted against the ENTRY, because there is
   no order and therefore no fill to price: this short is entry $50.00 / stop
   $55.00, so (50 - 55) / 50 = -10.0%. Re-anchoring every reconciled class to
   the close indiscriminately would give (65.50 - 55) / 65.50 = 16.0% instead,
   so this matcher separates "risk at the expected fill" from "risk at the
   close". *)
let test_extended_chip_and_suppression_on_the_short_arm _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<td class=\"num\"><span class=\"chip chip-extended\">$65.50 \
            (+34.5% EXTENDED)</span></td>";
         _has_substring "<td class=\"num\">-10.0%</td>";
         _has_substring
           "<td class=\"instruction\">NO ORDER — do not chase: +34.5% past the";
       ])

(* The chip classes are actually styled — a chip with no CSS rule would render
   as undifferentiated text. *)
let test_chip_styles_present_in_stylesheet _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  assert_that html
    (all_of
       [
         _has_substring ".chip-through-entry";
         _has_substring ".chip-extended";
         _has_substring ".chip-valid-stop";
       ])

(* An unreconciled table (the disarmed default) renders a plain dash cell, no
   chip and no legend. *)
let test_unreconciled_rows_render_plain_cells _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<td class=\"num\">-</td>";
         not_ ~msg:"no chip when nothing was reconciled"
           (_has_substring "class=\"chip");
         not_ ~msg:"no reconciliation legend when nothing was re-anchored"
           (_has_substring "close vs entry:");
       ])

let suite =
  "html_report_renderer"
  >::: [
         "through_entry_chip_rendered_on_the_long_arm"
         >:: test_through_entry_chip_rendered_on_the_long_arm;
         "extended_chip_and_suppression_on_the_short_arm"
         >:: test_extended_chip_and_suppression_on_the_short_arm;
         "chip_styles_present_in_stylesheet"
         >:: test_chip_styles_present_in_stylesheet;
         "unreconciled_rows_render_plain_cells"
         >:: test_unreconciled_rows_render_plain_cells;
         "document_is_self_contained" >:: test_document_is_self_contained;
         "header_and_macro" >:: test_header_and_macro;
         "bearish_macro_rendered" >:: test_bearish_macro_rendered;
         "section_order_matches_markdown_report"
         >:: test_section_order_matches_markdown_report;
         "every_empty_section_renders_the_none_marker"
         >:: test_every_empty_section_renders_the_none_marker;
         "sectors_and_warnings_render_as_bullets"
         >:: test_sectors_and_warnings_render_as_bullets;
         "long_candidate_row_cells" >:: test_long_candidate_row_cells;
         "short_candidate_row_is_rendered_in_its_own_table"
         >:: test_short_candidate_row_is_rendered_in_its_own_table;
         "structural_stop_has_no_asterisk"
         >:: test_structural_stop_has_no_asterisk;
         "fallback_stop_marked_and_explained"
         >:: test_fallback_stop_marked_and_explained;
         "clean_candidate_has_no_flag_marker"
         >:: test_clean_candidate_has_no_flag_marker;
         "data_suspect_marked_and_explained_on_the_short_arm"
         >:: test_data_suspect_marked_and_explained_on_the_short_arm;
         "missing_resistance_grade_renders_a_dash"
         >:: test_missing_resistance_grade_renders_a_dash;
         "zero_share_candidate_renders_a_dash_instruction"
         >:: test_zero_share_candidate_renders_a_dash_instruction;
         "zero_share_reason_rendered" >:: test_zero_share_reason_rendered;
         "long_table_truncated_with_tie_honest_note"
         >:: test_long_table_truncated_with_tie_honest_note;
         "short_table_truncated_at_its_own_limit"
         >:: test_short_table_truncated_at_its_own_limit;
         "limit_overrides_are_honoured" >:: test_limit_overrides_are_honoured;
         "untruncated_table_has_no_note" >:: test_untruncated_table_has_no_note;
         "held_row_cells" >:: test_held_row_cells;
         "held_row_without_recomputed_stop_renders_a_dash"
         >:: test_held_row_without_recomputed_stop_renders_a_dash;
         "long_candidate_chart_rendered" >:: test_long_candidate_chart_rendered;
         "short_candidate_chart_rendered"
         >:: test_short_candidate_chart_rendered;
         "held_position_chart_rendered" >:: test_held_position_chart_rendered;
         "chart_carries_band_and_volume" >:: test_chart_carries_band_and_volume;
         "all_three_arms_chart_independently"
         >:: test_all_three_arms_chart_independently;
         "default_bar_source_degrades_every_chart_cell"
         >:: test_default_bar_source_degrades_every_chart_cell;
         "partial_bar_coverage_degrades_only_the_uncovered_row"
         >:: test_partial_bar_coverage_degrades_only_the_uncovered_row;
         "single_bar_symbol_degrades" >:: test_single_bar_symbol_degrades;
         "snapshot_text_is_escaped" >:: test_snapshot_text_is_escaped;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "no_bars_is_the_empty_source" >:: test_no_bars_is_the_empty_source;
       ]

let () = run_test_tt_main suite
