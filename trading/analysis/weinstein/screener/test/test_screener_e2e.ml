(** End-to-end tests for the Weinstein screener cascade (Milestone 3).

    Demonstrates: "You can run a weekly scan and get a ranked list of buy and
    short candidates, graded, with suggested entries, stops, and risk
    percentages."

    Uses real cached data for a small diverse universe: AAPL + MSFT (Tech), JPM
    (Financials), JNJ (Health Care), CVX (Energy), KO (Consumer Staples), HD
    (Consumer Discretionary). All seven have cached daily bars from the 1980s or
    earlier. GSPC.INDX is the benchmark.

    See {!Test_data_loader} for the real-data loader.

    Sector map is left empty (Neutral by fall-through) because per-stock sector
    metadata is not yet populated on [Instrument_info.sector] — see
    [dev/notes/sector-data-plan.md]. Once that's wired, a follow-up can add a
    populated sector map here. *)

open Core
open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Seven well-known stocks with long cached history, spanning six sectors. *)
let _universe = [ "AAPL"; "MSFT"; "JPM"; "JNJ"; "CVX"; "KO"; "HD" ]

let _analyze_ticker ~start_date ~end_date ticker =
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:ticker ~start_date ~end_date
  in
  let benchmark_weekly =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX" ~start_date ~end_date
  in
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
    ~bars:weekly ~benchmark_bars:benchmark_weekly ~prior_stage:None
    ~as_of_date:end_date

let _analyze_universe ~start_date ~end_date =
  List.map _universe ~f:(_analyze_ticker ~start_date ~end_date)

let _empty_sector_map () = Hashtbl.create (module String)

(** Build a matcher callback for [elements_are] that pins one candidate by
    ticker, score, and ranges on the price-derived fields. The
    [suggested_entry], [suggested_stop], and [risk_pct] are functions of cached
    price data and screener config — using ranges insulates against minor data
    refreshes while still catching real regressions. The stop-vs-entry direction
    depends on [~side]: longs put the stop below the entry, shorts above. *)
let _candidate_matcher ~side ~ticker ~score ~entry_low ~entry_high ~stop_low
    ~stop_high ~risk_low ~risk_high (c : Screener.scored_candidate) =
  let stop_vs_entry =
    match side with
    | `Long -> Float.(c.Screener.suggested_stop < c.Screener.suggested_entry)
    | `Short -> Float.(c.Screener.suggested_stop > c.Screener.suggested_entry)
  in
  assert_that c
    (all_of
       [
         field (fun c -> c.Screener.ticker) (equal_to ticker);
         field (fun c -> c.Screener.score) (equal_to score);
         field
           (fun c -> c.Screener.suggested_entry)
           (is_between (module Float_ord) ~low:entry_low ~high:entry_high);
         field
           (fun c -> c.Screener.suggested_stop)
           (is_between (module Float_ord) ~low:stop_low ~high:stop_high);
         field
           (fun c -> c.Screener.risk_pct)
           (is_between (module Float_ord) ~low:risk_low ~high:risk_high);
         field
           (fun c -> List.length c.Screener.rationale)
           (gt (module Int_ord) 0);
       ]);
  assert_that stop_vs_entry (equal_to true)

(* ------------------------------------------------------------------ *)
(* Pinned candidate sets                                                *)
(* ------------------------------------------------------------------ *)

(** Buy candidates the cascade returns over the 7-stock universe in the
    2021-01-01 → 2023-12-29 window. Captured empirically from the screener;
    ranges are wide enough to absorb a minor data refresh but narrow enough that
    a real regression in the cascade would break them. Used by both the bullish-
    macro test and the neutral-macro test, since the same buy path is active in
    each and the screener output is deterministic in the data. *)
let _expected_2021_2023_buy_matchers =
  [
    _candidate_matcher ~side:`Long ~ticker:"HD" ~score:55 ~entry_low:340.0
      ~entry_high:346.0 ~stop_low:313.0 ~stop_high:319.0 ~risk_low:0.075
      ~risk_high:0.085;
    _candidate_matcher ~side:`Long ~ticker:"AAPL" ~score:50 ~entry_low:197.0
      ~entry_high:202.0 ~stop_low:181.0 ~stop_high:186.0 ~risk_low:0.075
      ~risk_high:0.085;
    _candidate_matcher ~side:`Long ~ticker:"JPM" ~score:45 ~entry_low:158.0
      ~entry_high:163.0 ~stop_low:145.0 ~stop_high:150.0 ~risk_low:0.075
      ~risk_high:0.085;
    _candidate_matcher ~side:`Long ~ticker:"MSFT" ~score:42 ~entry_low:366.0
      ~entry_high:371.0 ~stop_low:336.0 ~stop_high:342.0 ~risk_low:0.075
      ~risk_high:0.085;
  ]

(* ------------------------------------------------------------------ *)
(* M3 Test 1: Full screener cascade — bullish macro, diverse universe  *)
(* ------------------------------------------------------------------ *)

(** Runs the full screener pipeline over a 7-stock diverse universe during a
    sustained bull regime (2021-01 → 2023-12). Bullish macro permits buy
    candidates through the gate; the empty sector map gives every ticker a
    Neutral rating by fall-through. Pins the exact buy_candidates list (HD,
    AAPL, JPM, MSFT) — shape, ticker, score, and price-derived ranges — so that
    a regression that silently drops the list to [] (e.g. a tightened gate) will
    fail. Short candidates must be empty under Bullish macro (gate semantics).
*)
let test_full_cascade_bullish _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bullish
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.Screener.macro_trend (equal_to Bullish);
  assert_that result.Screener.short_candidates is_empty;
  assert_that result.Screener.buy_candidates
    (elements_are _expected_2021_2023_buy_matchers)

(* ------------------------------------------------------------------ *)
(* M3 Test 2: Bearish macro gates all buy candidates                    *)
(* ------------------------------------------------------------------ *)

(** When macro is [Bearish], the cascade's first gate unconditionally blocks all
    buy candidates regardless of stock strength. Uses the same diverse universe
    to confirm that even strong stocks are excluded. Short candidates may or may
    not appear depending on per-stock criteria — the test asserts nothing about
    them. *)
let test_bearish_macro_blocks_buys _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result
    (all_of
       [
         field (fun (r : Screener.result) -> r.macro_trend) (equal_to Bearish);
         field (fun (r : Screener.result) -> r.buy_candidates) is_empty;
       ])

(* ------------------------------------------------------------------ *)
(* M3 Test 3: Held tickers are excluded from output                     *)
(* ------------------------------------------------------------------ *)

(** Hold half the universe and assert none of the held tickers appear in either
    buy or short candidates. The non-held half may or may not produce candidates
    — we only assert the held ones are suppressed. *)
let test_held_tickers_excluded _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let held = [ "AAPL"; "MSFT"; "JPM"; "JNJ" ] in
  let held_set = Set.of_list (module String) held in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Neutral
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:held
  in
  let all_candidates = result.buy_candidates @ result.short_candidates in
  let held_tickers_in_output =
    List.filter all_candidates ~f:(fun c -> Set.mem held_set c.Screener.ticker)
  in
  assert_that held_tickers_in_output is_empty

(* ------------------------------------------------------------------ *)
(* M3 Test 4: Output record fields populated on Neutral-macro run       *)
(* ------------------------------------------------------------------ *)

(** Under a [Neutral] macro, both buy and short candidate paths are active. Pins
    the buy list to the exact same four candidates as the bullish test (since
    the cascade gate is identical for buys under Bullish vs Neutral, only
    differing on shorts) so that a silent regression that drops everything to []
    is caught. Shorts are empty here because the 2021-2023 window has no Stage 4
    breakdowns; see {!test_short_candidate_populated} for the short-path
    coverage. *)
let test_candidate_fields_populated _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Neutral
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.Screener.macro_trend (equal_to Neutral);
  assert_that result.Screener.short_candidates is_empty;
  assert_that result.Screener.buy_candidates
    (elements_are _expected_2021_2023_buy_matchers)

(* ------------------------------------------------------------------ *)
(* M3 Test 5: Short-path populated under Bearish macro (COVID crash)    *)
(* ------------------------------------------------------------------ *)

(** Runs the screener over the same 7-stock universe at the COVID crash low
    (2018-01-01 → 2020-03-20) under [Bearish] macro. JPM, KO, and CVX are in
    early Stage 4 with breakdown-volume confirmation: JPM scores 72 (Stage 4 +
    Strong breakdown volume + bearish RS crossover + Moderate support below), KO
    scores 55 (Stage 4 + Adequate breakdown volume + bearish RS crossover; Heavy
    support below contributes no clean-space bonus), and CVX scores 52 (Stage 4
    \+ Adequate breakdown volume + RS negative & declining + Moderate support
    below), all clearing the grade-C floor. The remaining four tickers fail the
    short-side gate. The test pins the exact short_candidates list and shape
    (entry, stop>entry, risk_pct) and asserts that no buy candidates leak
    through under Bearish macro. This is the deterministic counterpart to the
    bullish test. *)
let test_short_candidate_populated _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2018-01-01")
      ~end_date:(Date.of_string "2020-03-20")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.Screener.macro_trend (equal_to Bearish);
  assert_that result.Screener.buy_candidates is_empty;
  assert_that result.Screener.short_candidates
    (elements_are
       [
         _candidate_matcher ~side:`Short ~ticker:"JPM" ~score:72
           ~entry_low:139.0 ~entry_high:144.0 ~stop_low:151.0 ~stop_high:155.0
           ~risk_low:0.075 ~risk_high:0.085;
         _candidate_matcher ~side:`Short ~ticker:"KO" ~score:55 ~entry_low:56.0
           ~entry_high:60.0 ~stop_low:61.0 ~stop_high:65.0 ~risk_low:0.075
           ~risk_high:0.085;
         _candidate_matcher ~side:`Short ~ticker:"CVX" ~score:52
           ~entry_low:125.0 ~entry_high:130.0 ~stop_low:135.0 ~stop_high:141.0
           ~risk_low:0.075 ~risk_high:0.085;
       ])

(* ------------------------------------------------------------------ *)
(* M3 Test 6: Ch.11 spot-check — 2022 bear shorts on real data         *)
(* ------------------------------------------------------------------ *)

(** Ch.11 spot-check: at 2022-07-15 (mid-bear, six weeks past the June-2022
    relief rally peak), the screener over the same 7-stock universe under
    [Bearish] macro emits exactly two Stage 4 short candidates whose rationale
    cleanly maps onto Weinstein's Ch.11 short-entry checklist
    (weinstein-book-reference.md §6.1):

    - {b MSFT}: score 45 — "Early Stage4" + "RS bearish crossover". Tech
      mega-cap that had topped in late 2021, broke its 30-week MA in early 2022,
      and printed a fresh bearish RS crossover vs the S&P. Enters Stage 4 with
      negative-and-deteriorating RS, the textbook Ch. 11 short setup.
    - {b JPM}: score 45 — "Early Stage4" + "Adequate breakdown volume" + "RS
      negative & declining". Financials sector breakdown with confirming volume
      on the move below support. Hits items 1, 4, 5, and 6 of the §6.1
      checklist; volume is a bonus signal, not required (§6.2: "stocks can truly
      fall of their own weight").

    {b What this test pins:}
    - Stage 4 + negative RS + Bearish macro → short emitted (Ch.11 checklist
      items 1, 4, 5).
    - Volume confirmation either as Strong/Adequate breakdown or as bearish RS
      crossover (Ch.11 §6.2 — volume is supporting, not gating, evidence).
    - No buy candidates leak into the output (Ch.11 §6.1 item 1 — bearish macro
      is the unconditional gate).

    {b Why mid-2022 and not later:} the 2022 bear bottomed in October 2022 with
    intervening relief rallies. The screener's "Early Stage4" detector triggers
    when the prior_stage transitions or the breakdown is fresh; the most
    consistent short-side window with the cached 7-stock universe is mid-July
    (after the relief rally peaked in June). End-of-2022 (2022-12-30) also
    produces shorts (AAPL + MSFT) but is captured implicitly by the
    [test_short_candidate_populated] coverage of the 2020 COVID crash; the
    mid-2022 pin is the cleaner Ch.11 spot-check because both shorts here have
    distinct Ch.11 rationale paths (RS bearish crossover for MSFT, classic
    breakdown-volume + RS-negative-declining for JPM).

    See [dev/notes/short-side-ch11-spotcheck-2026-04-27.md] for the per-pattern
    mapping. *)
let test_ch11_spotcheck_2022_bear _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-07-15")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.Screener.macro_trend (equal_to Bearish);
  assert_that result.Screener.buy_candidates is_empty;
  assert_that result.Screener.short_candidates
    (elements_are
       [
         _candidate_matcher ~side:`Short ~ticker:"MSFT" ~score:45
           ~entry_low:349.0 ~entry_high:354.0 ~stop_low:377.0 ~stop_high:382.0
           ~risk_low:0.075 ~risk_high:0.085;
         _candidate_matcher ~side:`Short ~ticker:"JPM" ~score:45
           ~entry_low:171.0 ~entry_high:176.0 ~stop_low:185.0 ~stop_high:190.0
           ~risk_low:0.075 ~risk_high:0.085;
       ])

(* ------------------------------------------------------------------ *)
(* M3 Test 7: Ch.11 negative — never short Stage 2 (positive RS gate) *)
(* ------------------------------------------------------------------ *)

(** Ch.11 negative confirmation: under a [Bullish] macro covering the same 2022
    mid-bear window, the screener emits {b zero} short candidates even though
    the underlying stocks include Stage 4 names (MSFT, JPM) with negative RS.
    The [Bullish] gate at the top of the cascade overrides the short-side path
    entirely (Ch.11 §6.1 item 1: "Market trend is bearish [DJI in Stage 4]").
    This pins the {b absolute-rule} contract from the book: shorts only fire
    when macro confirms.

    Note: this is the {b cascade-gate} mirror of the never-short-Stage-2 rule.
    The per-stock never-short-Stage-2 rule is pinned at the unit level by
    [test_positive_rs_blocks_short] in [test_screener.ml]; this test pins the
    macro-gate version of the same Ch. 11 invariant. Together, the two cover
    both the per-stock and per-regime arms of the never-short rules. *)
let test_ch11_no_shorts_under_bullish_macro_2022 _ =
  let stocks =
    _analyze_universe
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-07-15")
  in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bullish
      ~sector_map:(_empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result
    (all_of
       [
         field (fun (r : Screener.result) -> r.macro_trend) (equal_to Bullish);
         field (fun (r : Screener.result) -> r.short_candidates) is_empty;
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("screener_e2e"
    >::: [
           "full cascade — bullish macro, 7-stock universe"
           >:: test_full_cascade_bullish;
           "bearish macro gates all buys" >:: test_bearish_macro_blocks_buys;
           "held tickers excluded from output" >:: test_held_tickers_excluded;
           "candidate output fields populated (neutral macro)"
           >:: test_candidate_fields_populated;
           "short candidates populated under bearish macro"
           >:: test_short_candidate_populated;
           "Ch.11 spot-check: 2022 bear shorts (MSFT + JPM)"
           >:: test_ch11_spotcheck_2022_bear;
           "Ch.11 negative: bullish macro emits zero shorts (2022 window)"
           >:: test_ch11_no_shorts_under_bullish_macro_2022;
         ])
