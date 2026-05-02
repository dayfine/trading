(** Unit tests for [Backtest_optimal.Stage_transition_scanner].

    Covers:
    - Sexp round-trip on every [Optimal_types] record (forward-compat: PR-3 /
      PR-4 read sibling artefacts via these schemas).
    - Scanner emits exactly one [candidate_entry] per breakout-passing analysis,
      in arrival order.
    - Symbols whose breakout predicate fails are dropped.
    - [passes_macro] is set from [week.macro_trend] (true for Bullish/Neutral,
      false for Bearish), independent of whether the candidate is otherwise
      admitted.
    - End-to-end divergence: a [Bearish] [macro_trend] threaded into the scanner
      causes [Optimal_portfolio_filler] under the [Constrained] variant to
      reject the candidate while [Relaxed_macro] admits it; a [Neutral]
      counterpart pins that both variants admit when macro permits — pinning
      that [Bearish] is the discriminator at the scanner→filler seam. (The
      isolated [passes_macro] tag is pinned by
      [test_scan_week_passes_macro_bearish] / [_neutral]; the isolated variant
      filter is pinned by [test_optimal_portfolio_filler.ml]; the divergence
      tests join them.)
    - Sector context is resolved through [sector_map]; missing entries fall back
      to the "Unknown" stub.
    - Multi-week scan via [scan_panel] preserves arrival order across weeks.
    - Empty-universe / empty-week-list edge cases produce empty output. *)

open OUnit2
open Core
open Matchers
module S = Backtest_optimal.Stage_transition_scanner
module F = Backtest_optimal.Optimal_portfolio_filler
module OT = Backtest_optimal.Optimal_types

(* ------------------------------------------------------------------ *)
(* Builders                                                             *)
(* ------------------------------------------------------------------ *)

let _date d = Date.of_string d

(** Build a synthetic [Stock_analysis.t] with all required sub-records. The
    optional parameters let each test override only the fields it cares about —
    keeps assertions focused on the field(s) under test. *)
let make_analysis ?(ticker = "AAPL")
    ?(stage_value =
      Weinstein_types.Stage2 { weeks_advancing = 2; late = false })
    ?(prior_stage = Some (Weinstein_types.Stage1 { weeks_in_base = 8 }))
    ?(ma_value = 100.0) ?(ma_direction = Weinstein_types.Rising)
    ?(ma_slope_pct = 0.02) ?(volume_quality = Some (Weinstein_types.Strong 2.5))
    ?(rs_trend = Some Weinstein_types.Positive_rising)
    ?(breakout_price = Some 105.0) ?(as_of_date = _date "2024-01-19") () :
    Stock_analysis.t =
  let stage : Stage.result =
    {
      stage = stage_value;
      ma_value;
      ma_direction;
      ma_slope_pct;
      transition = None;
      above_ma_count = 5;
    }
  in
  let volume : Volume.result option =
    Option.map volume_quality ~f:(fun confirmation ->
        {
          Volume.confirmation;
          event_volume = 1_000_000;
          avg_volume = 500_000.0;
          volume_ratio =
            (match confirmation with Strong r | Adequate r | Weak r -> r);
        })
  in
  let rs : Rs.result option =
    Option.map rs_trend ~f:(fun trend ->
        { Rs.current_rs = 1.05; current_normalized = 0.5; trend; history = [] })
  in
  {
    ticker;
    stage;
    rs;
    volume;
    resistance = None;
    support = None;
    breakout_price;
    breakdown_price = None;
    prior_stage;
    as_of_date;
  }

(** Build an analysis that fails [is_breakout_candidate]: Stage 1, no
    transition, no volume. *)
let make_non_breakout ?(ticker = "FAIL") () : Stock_analysis.t =
  make_analysis ~ticker
    ~stage_value:(Stage1 { weeks_in_base = 4 })
    ~prior_stage:None ~volume_quality:None ()

(** Build a sector_map populated from [(symbol, sector_name, rating)] triples.
*)
let make_sector_map entries : (string, Screener.sector_context) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (sym, sector_name, rating) ->
      let ctx : Screener.sector_context =
        {
          sector_name;
          rating;
          stage = Stage2 { weeks_advancing = 4; late = false };
        }
      in
      Hashtbl.set tbl ~key:sym ~data:ctx);
  tbl

(** Default scanner config — built from [Screener.default_config]. *)
let default_config = S.config_of_screener_config Screener.default_config

(* ------------------------------------------------------------------ *)
(* Sexp round-trip — every record type must round-trip cleanly         *)
(* ------------------------------------------------------------------ *)

let test_candidate_entry_sexp_round_trip _ =
  let entry : OT.candidate_entry =
    {
      symbol = "AAPL";
      entry_week = _date "2024-01-19";
      side = Long;
      entry_price = 105.50;
      suggested_stop = 97.06;
      risk_pct = 0.08;
      sector = "Information Technology";
      cascade_grade = A;
      cascade_score = 75;
      passes_macro = true;
    }
  in
  let round = OT.candidate_entry_of_sexp (OT.sexp_of_candidate_entry entry) in
  assert_that round
    (all_of
       [
         field (fun (e : OT.candidate_entry) -> e.symbol) (equal_to "AAPL");
         field
           (fun (e : OT.candidate_entry) -> e.entry_price)
           (float_equal 105.50);
         field
           (fun (e : OT.candidate_entry) -> e.cascade_grade)
           (equal_to Weinstein_types.A);
         field (fun (e : OT.candidate_entry) -> e.passes_macro) (equal_to true);
       ])

let test_scored_candidate_sexp_round_trip _ =
  let entry : OT.candidate_entry =
    {
      symbol = "MSFT";
      entry_week = _date "2024-02-02";
      side = Long;
      entry_price = 200.0;
      suggested_stop = 184.0;
      risk_pct = 0.08;
      sector = "Information Technology";
      cascade_grade = B;
      cascade_score = 60;
      passes_macro = true;
    }
  in
  let scored : OT.scored_candidate =
    {
      entry;
      exit_week = _date "2024-05-03";
      exit_price = 240.0;
      exit_trigger = Stage3_transition;
      raw_return_pct = 0.20;
      hold_weeks = 13;
      initial_risk_per_share = 16.0;
      r_multiple = 2.5;
    }
  in
  let round =
    OT.scored_candidate_of_sexp (OT.sexp_of_scored_candidate scored)
  in
  assert_that round
    (all_of
       [
         field
           (fun (s : OT.scored_candidate) -> s.exit_trigger)
           (equal_to OT.Stage3_transition);
         field (fun (s : OT.scored_candidate) -> s.r_multiple) (float_equal 2.5);
         field
           (fun (s : OT.scored_candidate) -> s.entry.symbol)
           (equal_to "MSFT");
       ])

let test_optimal_round_trip_sexp_round_trip _ =
  let rt : OT.optimal_round_trip =
    {
      symbol = "GOOG";
      side = Long;
      entry_week = _date "2024-03-01";
      entry_price = 140.0;
      exit_week = _date "2024-06-07";
      exit_price = 155.0;
      exit_trigger = Stop_hit;
      shares = 100.0;
      initial_risk_dollars = 1_120.0;
      pnl_dollars = 1_500.0;
      r_multiple = 1.34;
      cascade_grade = A_plus;
      passes_macro = false;
    }
  in
  let round =
    OT.optimal_round_trip_of_sexp (OT.sexp_of_optimal_round_trip rt)
  in
  assert_that round
    (all_of
       [
         field
           (fun (r : OT.optimal_round_trip) -> r.exit_trigger)
           (equal_to OT.Stop_hit);
         field
           (fun (r : OT.optimal_round_trip) -> r.passes_macro)
           (equal_to false);
         field
           (fun (r : OT.optimal_round_trip) -> r.pnl_dollars)
           (float_equal 1_500.0);
       ])

let test_optimal_summary_sexp_round_trip _ =
  let summary : OT.optimal_summary =
    {
      total_round_trips = 50;
      winners = 30;
      losers = 20;
      total_return_pct = 0.42;
      win_rate_pct = 0.60;
      avg_r_multiple = 1.8;
      profit_factor = 2.1;
      max_drawdown_pct = 0.18;
      variant = Constrained;
    }
  in
  let round = OT.optimal_summary_of_sexp (OT.sexp_of_optimal_summary summary) in
  assert_that round
    (all_of
       [
         field
           (fun (s : OT.optimal_summary) -> s.variant)
           (equal_to OT.Constrained);
         field
           (fun (s : OT.optimal_summary) -> s.total_round_trips)
           (equal_to 50);
         field
           (fun (s : OT.optimal_summary) -> s.win_rate_pct)
           (float_equal 0.60);
       ])

(* ------------------------------------------------------------------ *)
(* Scanner: scan_week                                                   *)
(* ------------------------------------------------------------------ *)

let test_scan_week_emits_one_per_breakout _ =
  (* Three analyses: AAPL passes, NOPE fails (Stage 1, no transition),
     MSFT passes. Expect two candidates emitted, AAPL and MSFT only,
     in that order. *)
  let aapl = make_analysis ~ticker:"AAPL" () in
  let nope = make_non_breakout ~ticker:"NOPE" () in
  let msft = make_analysis ~ticker:"MSFT" ~breakout_price:(Some 200.0) () in
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bullish;
      analyses = [ aapl; nope; msft ];
      sector_map =
        make_sector_map
          [
            ("AAPL", "Information Technology", Strong);
            ("MSFT", "Information Technology", Strong);
          ];
    }
  in
  let candidates = S.scan_week ~config:default_config week in
  assert_that candidates
    (elements_are
       [
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "AAPL");
             field
               (fun (c : OT.candidate_entry) -> c.entry_week)
               (equal_to (_date "2024-01-19"));
             field
               (fun (c : OT.candidate_entry) -> c.side)
               (equal_to Trading_base.Types.Long);
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to true);
             field
               (fun (c : OT.candidate_entry) -> c.sector)
               (equal_to "Information Technology");
           ];
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "MSFT");
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to true);
           ];
       ])

let test_scan_week_drops_non_breakout _ =
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bullish;
      analyses =
        [
          make_non_breakout ~ticker:"FOO" (); make_non_breakout ~ticker:"BAR" ();
        ];
      sector_map = make_sector_map [];
    }
  in
  assert_that (S.scan_week ~config:default_config week) (size_is 0)

let test_scan_week_passes_macro_bearish _ =
  (* Even when macro is Bearish, the scanner still emits the breakout
     candidate — but tags [passes_macro = false]. The renderer uses this
     tag to split between constrained and relaxed-macro variants. *)
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bearish;
      analyses = [ make_analysis ~ticker:"AAPL" () ];
      sector_map =
        make_sector_map [ ("AAPL", "Information Technology", Strong) ];
    }
  in
  assert_that
    (S.scan_week ~config:default_config week)
    (elements_are
       [
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "AAPL");
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to false);
           ];
       ])

let test_scan_week_passes_macro_neutral _ =
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Neutral;
      analyses = [ make_analysis ~ticker:"AAPL" () ];
      sector_map =
        make_sector_map [ ("AAPL", "Information Technology", Strong) ];
    }
  in
  assert_that
    (S.scan_week ~config:default_config week)
    (elements_are
       [
         field (fun (c : OT.candidate_entry) -> c.passes_macro) (equal_to true);
       ])

(* ------------------------------------------------------------------ *)
(* End-to-end divergence: scanner [Bearish] -> filler [Constrained]    *)
(* rejects while [Relaxed_macro] admits.                                *)
(*                                                                      *)
(* This pins the chain PR #676 wires up: macro_trend at scan time flows *)
(* through [passes_macro] on the candidate and through the filler's    *)
(* variant filter to produce divergent round-trip sets. The scanner    *)
(* tests above ([test_scan_week_passes_macro_bearish] /                *)
(* [_neutral]) pin only the [passes_macro] tag; the filler tests in    *)
(* [test_optimal_portfolio_filler.ml] pin only the variant-filter      *)
(* behaviour given hand-built candidates. This test joins them so a    *)
(* break anywhere along the chain (scanner stops setting              *)
(* [passes_macro]; filler stops honouring it; or the lookup loses the  *)
(* macro trend before it reaches the scanner) is caught here.          *)
(* ------------------------------------------------------------------ *)

(** Promote a [candidate_entry] into a synthetic [scored_candidate] by adding a
    plausible exit four weeks out at a fixed +2R outcome. Bypasses
    {!Outcome_scorer} — this test exercises the macro divergence chain at the
    scanner→filler seam, not the scorer's exit-trigger logic (which has its own
    test file). *)
let _scored_of_candidate ?(exit_week_offset_weeks = 4) ?(r_multiple = 2.0)
    (c : OT.candidate_entry) : OT.scored_candidate =
  let initial_risk_per_share = Float.abs (c.entry_price -. c.suggested_stop) in
  let raw_return_pct =
    r_multiple *. (initial_risk_per_share /. c.entry_price)
  in
  let exit_price = c.entry_price *. (1.0 +. raw_return_pct) in
  let exit_week = Date.add_days c.entry_week (7 * exit_week_offset_weeks) in
  {
    entry = c;
    exit_week;
    exit_price;
    exit_trigger = OT.End_of_run;
    raw_return_pct;
    hold_weeks = exit_week_offset_weeks;
    initial_risk_per_share;
    r_multiple;
  }

(** Scan one Friday with the given [macro_trend] and a single breakout-eligible
    analysis, then run the filler under both variants. Returns
    [(constrained_round_trips, relaxed_round_trips)] for the caller to pin. *)
let _run_chain ~macro_trend :
    OT.optimal_round_trip list * OT.optimal_round_trip list =
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend;
      analyses = [ make_analysis ~ticker:"AAPL" () ];
      sector_map =
        make_sector_map [ ("AAPL", "Information Technology", Strong) ];
    }
  in
  let candidates = S.scan_week ~config:default_config week in
  let scored = List.map candidates ~f:_scored_of_candidate in
  let constrained =
    F.fill ~config:F.default_config
      { candidates = scored; variant = OT.Constrained }
  in
  let relaxed =
    F.fill ~config:F.default_config
      { candidates = scored; variant = OT.Relaxed_macro }
  in
  (constrained, relaxed)

let test_bearish_macro_diverges_constrained_vs_relaxed _ =
  (* Bearish macro: scanner stamps passes_macro=false; Constrained drops it,
     Relaxed_macro keeps it. *)
  let constrained, relaxed = _run_chain ~macro_trend:Weinstein_types.Bearish in
  assert_that constrained (size_is 0);
  assert_that relaxed
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "AAPL");
       ])

let test_neutral_macro_admits_under_both_variants _ =
  (* Neutral macro: scanner stamps passes_macro=true; both variants admit.
     Confirms Bearish is the discriminator in the test above (not some other
     gate). *)
  let constrained, relaxed = _run_chain ~macro_trend:Weinstein_types.Neutral in
  assert_that constrained
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "AAPL");
       ]);
  assert_that relaxed
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "AAPL");
       ])

let test_scan_week_unknown_sector_falls_back _ =
  (* No sector_map entry for AAPL — sector should resolve to "Unknown".
     The screener's defaulting policy is to admit (Neutral rating), so
     the candidate is still emitted. *)
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bullish;
      analyses = [ make_analysis ~ticker:"AAPL" () ];
      sector_map = make_sector_map [];
    }
  in
  assert_that
    (S.scan_week ~config:default_config week)
    (elements_are
       [
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "AAPL");
             field
               (fun (c : OT.candidate_entry) -> c.sector)
               (equal_to "Unknown");
           ];
       ])

let test_scan_week_empty_analyses _ =
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bullish;
      analyses = [];
      sector_map = make_sector_map [];
    }
  in
  assert_that (S.scan_week ~config:default_config week) (size_is 0)

let test_scan_week_emits_entry_and_stop_consistent _ =
  (* The scanner uses the same per-candidate price formulas as the live
     screener: suggested_entry = breakout * (1 + entry_buffer_pct), then
     suggested_stop = entry * (1 - initial_stop_pct), then
     risk_pct = |entry - stop| / entry.
     With defaults (0.005 entry buffer, 0.08 initial stop) and
     breakout_price = 100.0, we expect entry = 100.50, stop = 92.46,
     risk_pct ≈ 0.08. *)
  let week : S.week_input =
    {
      date = _date "2024-01-19";
      macro_trend = Bullish;
      analyses =
        [ make_analysis ~ticker:"AAPL" ~breakout_price:(Some 100.0) () ];
      sector_map =
        make_sector_map [ ("AAPL", "Information Technology", Strong) ];
    }
  in
  assert_that
    (S.scan_week ~config:default_config week)
    (elements_are
       [
         all_of
           [
             field
               (fun (c : OT.candidate_entry) -> c.entry_price)
               (float_equal 100.50);
             field
               (fun (c : OT.candidate_entry) -> c.suggested_stop)
               (float_equal ~epsilon:0.01 92.46);
             field
               (fun (c : OT.candidate_entry) -> c.risk_pct)
               (float_equal ~epsilon:0.001 0.08);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Scanner: scan_panel — multi-week aggregation                         *)
(* ------------------------------------------------------------------ *)

let test_scan_panel_concatenates_in_order _ =
  let mk_week date_str ticker macro =
    {
      S.date = _date date_str;
      macro_trend = macro;
      analyses = [ make_analysis ~ticker () ];
      sector_map =
        make_sector_map [ (ticker, "Information Technology", Strong) ];
    }
  in
  let weeks =
    [
      mk_week "2024-01-19" "AAPL" Bullish;
      mk_week "2024-01-26" "MSFT" Bearish;
      mk_week "2024-02-02" "GOOG" Neutral;
    ]
  in
  let candidates = S.scan_panel ~config:default_config weeks in
  assert_that candidates
    (elements_are
       [
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "AAPL");
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to true);
           ];
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "MSFT");
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to false);
           ];
         all_of
           [
             field (fun (c : OT.candidate_entry) -> c.symbol) (equal_to "GOOG");
             field
               (fun (c : OT.candidate_entry) -> c.passes_macro)
               (equal_to true);
           ];
       ])

let test_scan_panel_empty_weeks _ =
  assert_that (S.scan_panel ~config:default_config []) (size_is 0)

(* ------------------------------------------------------------------ *)
(* Test suite                                                          *)
(* ------------------------------------------------------------------ *)

let suite =
  "Stage_transition_scanner"
  >::: [
         "candidate_entry sexp round-trip"
         >:: test_candidate_entry_sexp_round_trip;
         "scored_candidate sexp round-trip"
         >:: test_scored_candidate_sexp_round_trip;
         "optimal_round_trip sexp round-trip"
         >:: test_optimal_round_trip_sexp_round_trip;
         "optimal_summary sexp round-trip"
         >:: test_optimal_summary_sexp_round_trip;
         "scan_week emits one per breakout in order"
         >:: test_scan_week_emits_one_per_breakout;
         "scan_week drops non-breakout analyses"
         >:: test_scan_week_drops_non_breakout;
         "scan_week tags passes_macro = false on Bearish"
         >:: test_scan_week_passes_macro_bearish;
         "scan_week tags passes_macro = true on Neutral"
         >:: test_scan_week_passes_macro_neutral;
         "Bearish macro -> Constrained rejects, Relaxed_macro admits \
          (scanner+filler)"
         >:: test_bearish_macro_diverges_constrained_vs_relaxed;
         "Neutral macro -> both variants admit (scanner+filler)"
         >:: test_neutral_macro_admits_under_both_variants;
         "scan_week falls back to Unknown sector"
         >:: test_scan_week_unknown_sector_falls_back;
         "scan_week empty analyses → empty output"
         >:: test_scan_week_empty_analyses;
         "scan_week entry/stop/risk match screener formulas"
         >:: test_scan_week_emits_entry_and_stop_consistent;
         "scan_panel concatenates per-week output in order"
         >:: test_scan_panel_concatenates_in_order;
         "scan_panel empty weeks → empty output" >:: test_scan_panel_empty_weeks;
       ]

let () = run_test_tt_main suite
