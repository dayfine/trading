(** Tests for {!Html_report_renderer} — the self-contained HTML weekly report.

    {1 Assertion strategy}

    Two layers, deliberately.

    {b A body-only golden.} [test_body_matches_golden] renders the full fixture
    and compares the whole [<body>] against [fixtures/html_report_body.golden].
    That is what pins element ORDER, nesting, chip order, card composition and
    every literal string at once — the surface the previous revision tried to
    hold with hand-written full-row substrings. Those broke twice in two days: a
    PR added one cell, the rebase was textually clean, and only CI noticed. A
    golden cannot suffer that: the shape change IS the diff.

    It is the [<body>] and not the document because ~90 of a full-document
    golden's ~130 lines would be CSS, regenerated on every palette tweak and
    therefore promoted without being read. The [<style>] block has its own
    targeted assertions instead.

    {b Targeted semantic pins} for everything a golden states but does not
    EXPLAIN: which arm a card belongs to, that the ticket is
    {!Report_shared.instruction} rather than a lookalike, that risk is quoted
    against the expected fill, that the chart is weekly with a 30-week average,
    and every degradation path. Each is written so that mutating the production
    branch it covers turns exactly that test red.

    A golden alone would be promoted blind; targeted pins alone rot on shape
    churn. Together, a layout change costs one regeneration plus a semantic
    read, and a BEHAVIOUR change still turns a named test red.

    {1 Regenerating the golden}

    Run the suite; on mismatch it writes the actual body next to the test binary
    ([_build/default/trading/weinstein/snapshot/test/html_report_body.actual])
    and names the path in the failure. Read the diff, and if the change is
    intended copy that file over [test/fixtures/html_report_body.golden].

    {1 Fixture design}

    The long candidate, the short candidate and the held position carry
    {b distinguishable} symbols, prices, flags and bar series. That is
    deliberate: a fixture whose arms are interchangeable lets a whole rendering
    arm be deleted with the suite still green. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _date d = Date.of_string d

(* Weekly bars are what the report charts, so the fixture series is one bar per
   week — [_series n] yields [n] weekly-spaced bars, hence [n] weekly bars after
   aggregation. [_ma_bars] is long enough for the 30-week average to be defined
   at more than one point, which is what makes the average visible at all. *)
let _week_anchor = _date "2019-10-07"

let _bar ~week ~price : Types.Daily_price.t =
  Types.Daily_price.make
    ~date:(Date.add_days _week_anchor (week * 7))
    ~open_price:price ~high_price:price ~low_price:price ~close_price:price
    ~volume:1000 ~adjusted_close:price ()

let _ma_bars = 40

let _series ?(n = _ma_bars) base =
  List.init n ~f:(fun i -> _bar ~week:i ~price:(base +. Float.of_int i))

let _bars_table = [ ("LONGA", _series 98.0); ("SHRTB", _series 48.0) ]

let _bars_for ~symbol =
  Option.value
    (List.Assoc.find _bars_table ~equal:String.equal symbol)
    ~default:[]

(* Bars for the held symbol only — used by the held-chart test so a long/short
   chart cannot satisfy its assertion by accident. *)
let _held_bars_for ~symbol =
  if String.equal symbol "GOOG" then _series 1398.0 else []

let _all_bars_for ~symbol =
  if String.equal symbol "GOOG" then _series 1398.0 else _bars_for ~symbol

let _long_candidate : Weekly_snapshot.candidate =
  {
    symbol = "LONGA";
    score = 0.91;
    grade = "A+";
    entry = 100.0;
    stop = 90.0;
    sector = "XLK";
    rationale = "Stage1 to Stage2 breakout; Strong volume; RS positive";
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
   fallback stop, spike-flagged, no resistance grade, unsized, different
   rationale vocabulary, and a stop ABOVE the entry (short convention). *)
let _short_candidate : Weekly_snapshot.candidate =
  {
    _long_candidate with
    symbol = "SHRTB";
    score = 0.77;
    grade = "B";
    entry = 50.0;
    stop = 55.0;
    rationale = "Stage 4 breakdown; Adequate volume";
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
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
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

(* ------- Body golden ------- *)

let _golden_path = "fixtures/html_report_body.golden"
let _actual_path = "html_report_body.actual"
let _body_open = "<body>\n"
let _body_close = "\n</body>"

(* The document between its body tags. The renderer's own shell assertions pin
   that those tags exist; this only has to find them. *)
let _body_of html =
  match String.substr_index html ~pattern:_body_open with
  | None -> html
  | Some i -> (
      let start = i + String.length _body_open in
      match String.substr_index html ~pattern:_body_close with
      | None -> String.subo html ~pos:start
      | Some j -> String.sub html ~pos:start ~len:(j - start))

(* Best-effort: the regeneration aid must never turn a legible golden mismatch
   into an opaque Sys_error if the test's working directory is read-only. *)
let _try_write_actual actual =
  try Out_channel.write_all _actual_path ~data:actual with Sys_error _ -> ()

let test_body_matches_golden _ =
  let actual = _body_of (Html_report_renderer.render _full_snapshot) in
  let expected = In_channel.read_all _golden_path in
  if not (String.equal actual expected) then _try_write_actual actual;
  assert_that actual
    (matching
       ~msg:
         (Printf.sprintf
            "Rendered body differs from %s. Actual written to %s (relative to \
             the test's _build directory); copy it over the golden if the \
             change is intended."
            _golden_path _actual_path)
       (fun s -> if String.equal s expected then Some () else None)
       __)

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
         not_ ~msg:"no external stylesheet" (_has_substring "<link");
         not_ ~msg:"no script tag" (_has_substring "<script");
         (* A TradingView link is a link, not an asset: it fetches nothing. *)
         _has_substring "https://www.tradingview.com/chart/?symbol=LONGA";
       ])

(* Every mark the charts and the chips draw must actually be styled — an
   unstyled class renders as undifferentiated text or an invisible line. *)
let test_new_marks_are_styled _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "svg.spark .ma";
         _has_substring "svg.spark .last";
         _has_substring "svg.spark .lvl-label-entry";
         _has_substring "svg.spark .lvl-stop";
         _has_substring ".chip-structural";
         _has_substring ".chip-fallback";
         _has_substring ".chip-through-entry";
         _has_substring ".chip-extended";
         _has_substring ".cand-extended";
         _has_substring ".ticket-suppressed";
       ])

let test_masthead _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<h1>Weekly Pick Report — 2020-08-28</h1>";
         _has_substring
           "<div class=\"asof\">as-of 2020-08-28 close &middot; system \
            <code>c93bf39d</code></div>";
         _has_substring "<span class=\"chip chip-bullish\">Bullish 0.72</span>";
       ])

let test_bearish_regime_gets_its_own_variant _ =
  let snap =
    { _empty_snapshot with macro = { regime = "Bearish"; score = -0.45 } }
  in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring "<span class=\"chip chip-bearish\">Bearish -0.45</span>")

(* An unknown regime label still prints — only its colour is dropped. A class
   name is never derived from free-form snapshot text. *)
let test_unknown_regime_renders_a_plain_chip _ =
  let snap =
    { _empty_snapshot with macro = { regime = "Sideways"; score = 0.1 } }
  in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring "<span class=\"chip\">Sideways 0.10</span>")

let test_counts_strip_counts_the_full_lists _ =
  (* 12 longs under the default cap of 7: the strip says 12, so a reader can
     tell "7 shown of 12 found" from "7 found". *)
  let snap =
    {
      _full_snapshot with
      long_candidates =
        List.init 12 ~f:(fun i ->
            { _long_candidate with symbol = Printf.sprintf "SYM%02d" i });
    }
  in
  assert_that
    (Html_report_renderer.render snap)
    (all_of
       [
         _has_substring
           "<div class=\"stat\"><span class=\"label\">Long \
            candidates</span><b>12</b></div>";
         _has_substring
           "<div class=\"stat\"><span class=\"label\">Held \
            positions</span><b>1</b></div>";
         _has_substring
           "<div class=\"stat\"><span \
            class=\"label\">Warnings</span><b>1</b></div>";
       ])

let test_section_order _ =
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (_in_order
       [
         "<header>";
         "<div class=\"strip\">";
         "<h2>Strong sectors</h2>";
         "<h2>Long candidates (top 20)</h2>";
         "<h2>Short candidates (top 5)</h2>";
         "<h2>Held positions</h2>";
         "<h2>Warnings</h2>";
         "<footer>";
       ])

let test_every_empty_section_renders_the_none_marker _ =
  let html = Html_report_renderer.render _empty_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<h2>Strong sectors</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring
           "<h2>Long candidates (top 20)</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring
           "<h2>Short candidates (top 5)</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring "<h2>Held positions</h2>\n<p class=\"empty\">(none)</p>";
         _has_substring "<h2>Warnings</h2>\n<p class=\"empty\">(none)</p>";
       ])

let test_sectors_are_chips_and_warnings_are_bullets _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<span class=\"sectors\"><span class=\"chip \
            chip-sector\">XLK</span><span class=\"chip \
            chip-sector\">XLY</span></span>";
         _has_substring "<li>SNSE: dropped — sparse tail (6/15 bars)</li>";
       ])

(* ------- Candidate cards ------- *)

let test_long_candidate_card _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<span class=\"rank\">1</span><a class=\"sym\" \
            href=\"https://www.tradingview.com/chart/?symbol=LONGA\" \
            target=\"_blank\" rel=\"noopener\">LONGA</a>";
         (* Chips, in order and complete: score, the three rationale clauses
            verbatim, the resistance grade, the stop kind. A dropped or
            re-labelled chip fails here. *)
         _has_substring
           "<span class=\"chips\"><span class=\"chip chip-score\">A+ \
            0.91</span><span class=\"chip chip-breakout\">Stage1 to Stage2 \
            breakout</span><span class=\"chip chip-vol-strong\">Strong \
            volume</span><span class=\"chip chip-rs\">RS positive</span><span \
            class=\"chip chip-virgin\">Virgin_territory (0.95)</span><span \
            class=\"chip chip-structural\">structural stop</span></span>";
         (* Figures, in order. Risk = (100 - 90) / 100. *)
         _has_substring
           "<span class=\"nums\"><span class=\"num\"><i>Entry</i><span \
            class=\"num-value num-value-entry\">$100.00</span></span><span \
            class=\"num\"><i>Stop</i><span class=\"num-value \
            num-value-stop\">$90.00</span></span><span \
            class=\"num\"><i>Risk</i><span \
            class=\"num-value\">10.0%</span></span></span>";
       ])

(* The broker-facing text is [Report_shared.instruction] itself, asserted by
   CALLING it: a renderer that formatted its own lookalike sentence would drift
   from the Markdown report silently, and this cannot be satisfied by any
   string this test hard-codes. *)
let test_ticket_is_the_shared_instruction _ =
  let ticket c =
    Printf.sprintf "<div class=\"ticket\">%s</div>"
      (Html_page.escape (Report_shared.instruction c))
  in
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (all_of
       [
         _has_substring (ticket _long_candidate);
         (* The unsized short's ticket is the shared "-" — not omitted. *)
         _has_substring (ticket _short_candidate);
       ])

let test_short_candidate_card_is_its_own_arm _ =
  (* Every assertion here is on a value only the SHORT fixture produces: the
     fallback-stop chip, the suspect chip, the asterisked stop and a NEGATIVE
     risk (the long-convention formula applied to a stop above entry). None can
     be satisfied by the long card. *)
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (_in_order
       [
         "<h2>Short candidates (top 5)</h2>";
         "?symbol=SHRTB";
         (* The COMPLETE chips span: an unrecognised clause degrades to a plain
            chip, and the absent resistance grade emits nothing at all — both
            pinned by exhaustion rather than by a negative substring. *)
         "<span class=\"chips\"><span class=\"chip chip-score\">B \
          0.77</span><span class=\"chip\">Stage 4 breakdown</span><span \
          class=\"chip chip-vol-ok\">Adequate volume</span><span class=\"chip \
          chip-fallback\">fallback stop</span><span class=\"chip \
          chip-suspect\">(!) data-suspect</span></span>";
         "<span class=\"num-value num-value-stop\">$55.00*</span>";
         "<span class=\"num-value\">-10.0%</span>";
       ])

let test_unrecognised_rationale_clause_degrades_to_a_plain_chip _ =
  (* Screener vocabulary evolves. An unknown clause must still be printed —
     dropping it would silently lose a signal the screener recorded. *)
  let snap =
    {
      _empty_snapshot with
      long_candidates =
        [ { _long_candidate with rationale = "Some brand new signal" } ];
    }
  in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring "<span class=\"chip\">Some brand new signal</span>")

let test_structural_and_fallback_stops_are_chipped_and_explained _ =
  let render c =
    Html_report_renderer.render { _empty_snapshot with long_candidates = [ c ] }
  in
  assert_that (render _long_candidate)
    (all_of
       [
         _has_substring
           "<span class=\"chip chip-structural\">structural stop</span>";
         not_ ~msg:"no fallback legend when every shown stop is structural"
           (_has_substring "* fallback stop:");
       ]);
  assert_that (render _short_candidate)
    (all_of
       [
         _has_substring
           "<span class=\"chip chip-fallback\">fallback stop</span>";
         _has_substring "<p class=\"note\">* fallback stop:";
       ])

let test_data_suspect_is_chipped_and_explained _ =
  let clean =
    Html_report_renderer.render
      { _empty_snapshot with long_candidates = [ _long_candidate ] }
  in
  let flagged =
    Html_report_renderer.render
      { _empty_snapshot with short_candidates = [ _short_candidate ] }
  in
  assert_that clean
    (not_ ~msg:"no data-suspect legend when nothing is flagged"
       (_has_substring "(!) data-suspect:"));
  assert_that flagged
    (all_of
       [
         _has_substring
           "<span class=\"chip chip-suspect\">(!) data-suspect</span>";
         _has_substring "<p class=\"note\">(!) data-suspect:";
       ])

let test_resistance_grade_chip_variants _ =
  (* Virgin territory — no overhead supply at all — is the one resistance grade
     that changes what a reader does, so it escalates; every other grade is
     recessive. A missing grade emits NO chip, which the complete chips span in
     [test_short_candidate_card_is_its_own_arm] pins by exhaustion. *)
  let render grade =
    Html_report_renderer.render
      {
        _empty_snapshot with
        long_candidates = [ { _long_candidate with resistance_grade = grade } ];
      }
  in
  assert_that
    (render (Some "Clean (0.12)"))
    (_has_substring "<span class=\"chip chip-resistance\">Clean (0.12)</span>");
  assert_that (render None)
    (not_ ~msg:"no resistance chip when the grade was not computed"
       (_has_substring "chip-resistance\">"))

let test_zero_share_reason_is_the_ticket _ =
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
    (all_of
       [
         _has_substring
           "<div class=\"ticket\">0 sh — cash / caps exhausted</div>";
         not_ ~msg:"an unsized candidate must not render an order"
           (_has_substring "BUY STOP");
       ])

(* ------- Truncation ------- *)

let _n_candidates ~n ~score_of =
  List.init n ~f:(fun i ->
      {
        _long_candidate with
        symbol = Printf.sprintf "SYM%02d" i;
        score = score_of i;
      })

let test_long_section_truncated_with_tie_honest_note _ =
  let snap =
    {
      _empty_snapshot with
      long_candidates = _n_candidates ~n:12 ~score_of:(fun _ -> 0.85);
    }
  in
  let html = Html_report_renderer.render ~long_limit:7 snap in
  assert_that html
    (all_of
       [
         _has_substring "?symbol=SYM06";
         not_ ~msg:"card 8 truncated" (_has_substring "?symbol=SYM07");
         _has_substring
           "<p class=\"note\">5 more candidates not shown; 5 tie the cutoff \
            score (0.85).";
       ])

let test_short_section_truncated_at_its_own_limit _ =
  (* The short cap is independent of the long one: 8 shorts under the default
     short limit of 5 hides 3. *)
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
         _has_substring "?symbol=SYM04";
         not_ ~msg:"short card 6 truncated" (_has_substring "?symbol=SYM05");
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

let test_untruncated_section_has_no_note _ =
  let snap = { _empty_snapshot with long_candidates = [ _long_candidate ] } in
  assert_that
    (Html_report_renderer.render snap)
    (not_ ~msg:"no note when nothing is hidden" (_has_substring "not shown"))

(* ------- Held positions ------- *)

let test_held_card _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         (* No rank cell on an unranked arm. *)
         _has_substring
           "<div class=\"cand-main\"><a class=\"sym\" \
            href=\"https://www.tradingview.com/chart/?symbol=GOOG\" \
            target=\"_blank\" rel=\"noopener\">GOOG</a>";
         _has_substring
           "<span class=\"chip chip-status\">Holding</span><span \
            class=\"chip\">entered 2020-06-19</span>";
         _has_substring
           "<span class=\"num\"><i>Shares</i><span \
            class=\"num-value\">3</span></span><span \
            class=\"num\"><i>Fill</i><span class=\"num-value \
            num-value-entry\">$1400.00</span></span><span \
            class=\"num\"><i>Current</i><span \
            class=\"num-value\">$1500.00</span></span><span \
            class=\"num\"><i>Unrealized</i><span \
            class=\"num-value\">7.1%</span></span><span \
            class=\"num\"><i>Stop</i><span class=\"num-value \
            num-value-stop\">$1365.00</span></span>";
       ])

(* Weinstein's investor trailing method ratchets the sell-stop UP as the MA
   advances and leaves it alone otherwise (weinstein-book-reference.md §5.2
   "Trailing Stop — Investor Method"). All three arms of that guidance are
   pinned: raise, hold, and nothing recomputed. *)
let test_held_stop_line_says_which_way_it_points _ =
  let render recommended_stop =
    Html_report_renderer.render
      {
        _empty_snapshot with
        held_positions = [ { _held with recommended_stop } ];
      }
  in
  assert_that (render (Some 1420.00))
    (_has_substring
       "Stop in force $1365.00; this week&#39;s support floor is $1420.00 \
        (+55.00) — raise the stop to it.");
  assert_that (render (Some 1300.00))
    (_has_substring
       "Stop in force $1365.00; this week&#39;s support floor is $1300.00 \
        (-65.00), below the stop in force — leave the stop where it is.");
  assert_that (render None)
    (_has_substring
       "Stop in force $1365.00. No support floor was recomputed this week.")

(* ------- Charts, per arm ------- *)

let test_all_three_arms_chart_independently _ =
  (* One render, one bar source covering every symbol: exactly three charts,
     one per arm. A missing arm shows up as a count of 2. *)
  let html =
    Html_report_renderer.render ~bars_for:_all_bars_for _full_snapshot
  in
  assert_that (_count html ~needle:"<svg class=\"spark\"") (equal_to 3);
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"long:LONGA\"><svg class=\"spark\"";
         _has_substring "data-chart=\"short:SHRTB\"><svg class=\"spark\"";
         _has_substring "data-chart=\"held:GOOG\"><svg class=\"spark\"";
       ])

let test_candidate_charts_carry_their_own_levels _ =
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "<title>entry $100.00</title>";
         _has_substring "<title>stop $90.00</title>";
         (* The short arm's own prices, which no other arm produces. *)
         _has_substring "<title>entry $50.00</title>";
         _has_substring "<title>stop $55.00</title>";
       ])

let test_held_chart_uses_the_fill_and_the_current_stop _ =
  (* [_held_bars_for] supplies bars for GOOG only, so a candidate chart cannot
     satisfy this. *)
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

let test_charts_are_weekly_with_the_30_week_average _ =
  (* The aria-label names the average, the [.ma] polyline draws it, and the
     right-hand labels plus the last-close marker are on. Dropping [~ma_period]
     or [~annotate] fails one of these.

     It does NOT catch dropping the [weekly_bars] aggregation: this fixture's
     bars are already one per week, so aggregating them is the identity and the
     rendered bytes are the same either way. That arm is pinned by
     [test_single_weekly_bar_degrades], whose fixture is five DAILY bars inside
     one week — chartable as dailies, a single mark as weeklies. *)
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         (* 40 weekly bars in, 40 marks out. *)
         _has_substring
           "aria-label=\"price and volume sparkline, 40 bars; 30-period moving \
            average; levels: entry $100.00, stop $90.00\"";
         _has_substring "<polyline class=\"ma\"";
         _has_substring "<text class=\"lvl-label lvl-label-entry\"";
         _has_substring "<text class=\"lvl-label lvl-label-stop\"";
         (* The last WEEKLY bar's date and close. The 40th weekly bar of a
            series anchored at 2019-10-07 ends 39 weeks later. *)
         _has_substring "<title>last close 137.00 (2020-07-06)</title>";
       ])

let test_band_and_volume_survive _ =
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of [ _has_substring "class=\"band\""; _has_substring "class=\"vol\"" ])

(* ------- Graceful degradation ------- *)

let test_default_bar_source_degrades_every_chart _ =
  (* No bar source at all: the page is still complete — masthead, cards, notes —
     and every chart strip carries the marker instead of an svg. *)
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "data-chart=\"long:LONGA\"><span class=\"nochart\">no chart \
            data</span>";
         _has_substring "data-chart=\"short:SHRTB\"><span class=\"nochart\">";
         _has_substring "data-chart=\"held:GOOG\"><span class=\"nochart\">";
         _has_substring
           "<span class=\"num-value num-value-entry\">$100.00</span>";
         _has_substring "<li>SNSE: dropped — sparse tail (6/15 bars)</li>";
         not_ ~msg:"no svg without bars" (_has_substring "<svg class=\"spark\"");
       ])

let test_partial_bar_coverage_degrades_only_the_uncovered_card _ =
  (* [_bars_for] knows LONGA and SHRTB but not GOOG. *)
  let html = Html_report_renderer.render ~bars_for:_bars_for _full_snapshot in
  assert_that html
    (all_of
       [
         _has_substring "data-chart=\"long:LONGA\"><svg";
         _has_substring "data-chart=\"held:GOOG\"><span class=\"nochart\">";
       ])

let test_single_weekly_bar_degrades _ =
  (* Five DAILY bars inside one calendar week aggregate to ONE weekly bar, which
     is below the chart's two-mark floor. The card degrades rather than emitting
     a degenerate chart — and this also proves the renderer charts weekly bars,
     because five daily bars would have been chartable. *)
  let bars_for ~symbol =
    if String.equal symbol "LONGA" then
      List.init 5 ~f:(fun i ->
          Types.Daily_price.make
            ~date:(Date.add_days (_date "2020-08-03") i)
            ~open_price:100.0 ~high_price:100.0 ~low_price:100.0
            ~close_price:100.0 ~volume:10 ~adjusted_close:100.0 ())
    else []
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
        [
          {
            _long_candidate with
            symbol = "\"><script>x</script>";
            rationale = "<script>alert(1)</script>";
          };
        ];
      warnings = [ "AT&T: dropped" ];
    }
  in
  let html = Html_report_renderer.render snap in
  assert_that html
    (all_of
       [
         _has_substring "&lt;script&gt;alert(1)&lt;/script&gt;";
         _has_substring "&lt;b&gt;Bull&lt;/b&gt; 0.10";
         _has_substring "<span class=\"chip chip-sector\">X&amp;Y</span>";
         _has_substring "<li>AT&amp;T: dropped</li>";
         (* The symbol reaches an href AND a data attribute; neither may be
            broken out of. *)
         _has_substring
           "href=\"https://www.tradingview.com/chart/?symbol=&quot;&gt;&lt;script&gt;x&lt;/script&gt;\"";
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
   chip and neither arm's assertion can be satisfied by the other's card. *)
let _reconciled_snapshot =
  {
    _full_snapshot with
    long_candidates =
      [
        {
          _long_candidate with
          reconciliation =
            Entry_reconciliation.Through_entry
              { close = 107.3; overshoot_pct = 7.3; cap = 0.0 };
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
            Entry_reconciliation.Extended
              { close = 65.5; overshoot_pct = 34.5; cap = 0.0 };
        };
      ];
  }

(* The class rides as a chip whose TEXT is the same string the Markdown column
   shows — both come from [Report_shared.close_vs_entry], so the two formats
   cannot drift.

   Risk is asserted here too. The first version of this suite had NO risk
   assertion on a reconciled row, which is why the HTML side of the stale-risk
   defect survived eight mutations invisibly: (107.30 - 90.00) / 107.30 = 16.1%
   at the fill, where the entry-based figure reads 10.0%. *)
let test_through_entry_chip_on_the_long_arm _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<span class=\"chip chip-through-entry\">$107.30 (+7.3% \
            through)</span>";
         _has_substring "<span class=\"num-value\">16.1%</span>";
         not_ ~msg:"Risk must not be quoted against the already-breached entry"
           (_has_substring "<span class=\"num-value\">10.0%</span>");
         (* The observed close appears as its own figure only when a
            reconciliation supplied one. *)
         _has_substring "<i>Last</i><span class=\"num-value\">$107.30</span>";
         _has_substring
           "<div class=\"ticket\">BUY MARKET 57 sh @ ~$107.30 (~$6116, 6.1% of \
            book, risk $986)";
         _has_substring "close vs entry:";
       ])

(* Issue #2158: an ARMED through-entry candidate (carrying a $115.00 cap) draws
   the do-not-chase cap as a third chart level — a [lvl-cap] line named
   "cap $115.00" — alongside the entry and stop lines. Rendered WITH bars so a
   chart exists; an unreconciled candidate (or one with no cap) draws no such
   line. *)
let test_armed_through_entry_draws_the_cap_chart_line _ =
  let snap =
    {
      _full_snapshot with
      long_candidates =
        [
          {
            _long_candidate with
            reconciliation =
              Entry_reconciliation.Through_entry
                { close = 107.3; overshoot_pct = 7.3; cap = 115.0 };
            sized_shares = 40;
            sized_position_value = 4600.0;
            sized_position_pct = 0.046;
            sized_risk_amount = 1000.0;
          };
        ];
      short_candidates = [];
    }
  in
  let html = Html_report_renderer.render ~bars_for:_bars_for snap in
  assert_that html
    (all_of
       [ _has_substring "class=\"lvl lvl-cap\""; _has_substring "cap $115.00" ])

(* The SHORT arm gets the mirrored treatment: an over-extended short carries the
   EXTENDED chip, its card and its ticket strip are marked, and its ticket is
   suppressed.

   Risk for an EXTENDED row stays quoted against the ENTRY, because there is no
   order and therefore no fill to price: entry $50.00 / stop $55.00, so
   (50 - 55) / 50 = -10.0%. Re-anchoring every reconciled class to the close
   indiscriminately would give (65.50 - 55) / 65.50 = 16.0% instead. *)
let test_extended_chip_and_suppression_on_the_short_arm _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  assert_that html
    (all_of
       [
         _has_substring
           "<span class=\"chip chip-extended\">$65.50 (+34.5% EXTENDED)</span>";
         _has_substring "<span class=\"num-value\">-10.0%</span>";
         _has_substring "<div class=\"cand cand-extended\">";
         _has_substring
           "<div class=\"ticket ticket-suppressed\">NO ORDER — do not chase: \
            +34.5% past the";
       ])

(* Extended candidates leave the actionable sections: the short arm's only
   candidate is EXTENDED, so the Short section renders the empty marker and
   the extended card renders below the watch heading instead (2026-07-27 user
   feedback: extended names must not consume actionable display slots). *)
let test_extended_card_moves_to_watch_section _ =
  let html = Html_report_renderer.render _reconciled_snapshot in
  let watch_at =
    String.substr_index_exn html
      ~pattern:"<h2>Watch — extended, do not chase</h2>"
  in
  let card_at =
    String.substr_index_exn html ~pattern:"<div class=\"cand cand-extended\">"
  in
  assert_that html
    (all_of
       [
         _has_substring
           "<h2>Short candidates (top 5)</h2>\n<p class=\"empty\">(none)</p>";
         matching ~msg:"the extended card must render inside the watch section"
           (fun _ -> if card_at > watch_at then Some () else None)
           __;
       ])

(* Sharing the watch section does not mean sharing an arm tag: the extended
   SHORT's chart cell must still be addressed "short:SHRTB". Tagging every watch
   card "long" would make a short's chart indistinguishable from a long's to any
   consumer keying off [data-chart]. *)
let test_watch_card_keeps_its_own_arm_tag _ =
  assert_that
    (Html_report_renderer.render _reconciled_snapshot)
    (all_of
       [
         _has_substring "data-chart=\"short:SHRTB\"";
         not_ ~msg:"an extended short must not be tagged as a long"
           (_has_substring "data-chart=\"long:SHRTB\"");
       ])

let test_no_watch_section_without_extended _ =
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (not_ ~msg:"watch section only exists when something is extended"
       (_has_substring "Watch — extended"))

(* An unreconciled snapshot (the disarmed default) carries no chip, no Last
   figure and no legend. *)
let test_unreconciled_cards_are_plain _ =
  let html = Html_report_renderer.render _full_snapshot in
  assert_that html
    (all_of
       [
         not_ ~msg:"no reconciliation chip when nothing was reconciled"
           (_has_substring "chip-through-entry\">");
         not_ ~msg:"no Last figure without an observed close"
           (_has_substring "<i>Last</i>");
         not_ ~msg:"no reconciliation legend when nothing was re-anchored"
           (_has_substring "close vs entry:");
         not_ ~msg:"an ordinary card is not marked extended"
           (_has_substring "cand-extended\">");
       ])

(* Issue #2122 slice d: the screener-cap eligible-beyond-cap note, rendered as
   its own [<p class="note">]. [_full_snapshot]'s single shown long (LONGA,
   score 0.91) is the lowest shown row. *)
let test_eligible_beyond_cap_note_rendered _ =
  let snap = { _full_snapshot with long_eligible_beyond_cap = 7 } in
  assert_that
    (Html_report_renderer.render snap)
    (_has_substring
       "<p class=\"note\">7 additional eligible candidates beyond the \
        displayed cap (lowest shown score 0.91).</p>")

(* A [0] count (the pre-#2122 default) renders no such note. *)
let test_no_eligible_beyond_cap_note_when_zero _ =
  assert_that
    (Html_report_renderer.render _full_snapshot)
    (not_ ~msg:"no beyond-cap note when the count is zero"
       (_has_substring "additional eligible candidate"))

let suite =
  "html_report_renderer"
  >::: [
         "eligible_beyond_cap_note_rendered"
         >:: test_eligible_beyond_cap_note_rendered;
         "no_eligible_beyond_cap_note_when_zero"
         >:: test_no_eligible_beyond_cap_note_when_zero;
         "body_matches_golden" >:: test_body_matches_golden;
         "document_is_self_contained" >:: test_document_is_self_contained;
         "new_marks_are_styled" >:: test_new_marks_are_styled;
         "masthead" >:: test_masthead;
         "bearish_regime_gets_its_own_variant"
         >:: test_bearish_regime_gets_its_own_variant;
         "unknown_regime_renders_a_plain_chip"
         >:: test_unknown_regime_renders_a_plain_chip;
         "counts_strip_counts_the_full_lists"
         >:: test_counts_strip_counts_the_full_lists;
         "section_order" >:: test_section_order;
         "every_empty_section_renders_the_none_marker"
         >:: test_every_empty_section_renders_the_none_marker;
         "sectors_are_chips_and_warnings_are_bullets"
         >:: test_sectors_are_chips_and_warnings_are_bullets;
         "long_candidate_card" >:: test_long_candidate_card;
         "ticket_is_the_shared_instruction"
         >:: test_ticket_is_the_shared_instruction;
         "short_candidate_card_is_its_own_arm"
         >:: test_short_candidate_card_is_its_own_arm;
         "unrecognised_rationale_clause_degrades_to_a_plain_chip"
         >:: test_unrecognised_rationale_clause_degrades_to_a_plain_chip;
         "structural_and_fallback_stops_are_chipped_and_explained"
         >:: test_structural_and_fallback_stops_are_chipped_and_explained;
         "data_suspect_is_chipped_and_explained"
         >:: test_data_suspect_is_chipped_and_explained;
         "resistance_grade_chip_variants"
         >:: test_resistance_grade_chip_variants;
         "zero_share_reason_is_the_ticket"
         >:: test_zero_share_reason_is_the_ticket;
         "long_section_truncated_with_tie_honest_note"
         >:: test_long_section_truncated_with_tie_honest_note;
         "short_section_truncated_at_its_own_limit"
         >:: test_short_section_truncated_at_its_own_limit;
         "limit_overrides_are_honoured" >:: test_limit_overrides_are_honoured;
         "untruncated_section_has_no_note"
         >:: test_untruncated_section_has_no_note;
         "held_card" >:: test_held_card;
         "held_stop_line_says_which_way_it_points"
         >:: test_held_stop_line_says_which_way_it_points;
         "all_three_arms_chart_independently"
         >:: test_all_three_arms_chart_independently;
         "candidate_charts_carry_their_own_levels"
         >:: test_candidate_charts_carry_their_own_levels;
         "held_chart_uses_the_fill_and_the_current_stop"
         >:: test_held_chart_uses_the_fill_and_the_current_stop;
         "charts_are_weekly_with_the_30_week_average"
         >:: test_charts_are_weekly_with_the_30_week_average;
         "band_and_volume_survive" >:: test_band_and_volume_survive;
         "default_bar_source_degrades_every_chart"
         >:: test_default_bar_source_degrades_every_chart;
         "partial_bar_coverage_degrades_only_the_uncovered_card"
         >:: test_partial_bar_coverage_degrades_only_the_uncovered_card;
         "single_weekly_bar_degrades" >:: test_single_weekly_bar_degrades;
         "snapshot_text_is_escaped" >:: test_snapshot_text_is_escaped;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "no_bars_is_the_empty_source" >:: test_no_bars_is_the_empty_source;
         "through_entry_chip_on_the_long_arm"
         >:: test_through_entry_chip_on_the_long_arm;
         "armed_through_entry_draws_the_cap_chart_line"
         >:: test_armed_through_entry_draws_the_cap_chart_line;
         "extended_chip_and_suppression_on_the_short_arm"
         >:: test_extended_chip_and_suppression_on_the_short_arm;
         "extended_card_moves_to_watch_section"
         >:: test_extended_card_moves_to_watch_section;
         "watch_card_keeps_its_own_arm_tag"
         >:: test_watch_card_keeps_its_own_arm_tag;
         "no_watch_section_without_extended"
         >:: test_no_watch_section_without_extended;
         "unreconciled_cards_are_plain" >:: test_unreconciled_cards_are_plain;
       ]

let () = run_test_tt_main suite
