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
    early Stage 4 with breakdown-volume confirmation: JPM scores 65 (Stage 4 +
    Strong breakdown volume + bearish RS crossover), KO scores 55 (Stage 4 +
    Adequate breakdown volume + bearish RS crossover), and CVX scores 45 (Stage
    4 + Adequate breakdown volume + RS negative & declining), all clearing the
    grade-C floor. The remaining four tickers fail the short-side gate. The test
    pins the exact short_candidates list and shape (entry, stop>entry, risk_pct)
    and asserts that no buy candidates leak through under Bearish macro. This is
    the deterministic counterpart to the bullish test. *)
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
         _candidate_matcher ~side:`Short ~ticker:"JPM" ~score:65
           ~entry_low:139.0 ~entry_high:144.0 ~stop_low:151.0 ~stop_high:155.0
           ~risk_low:0.075 ~risk_high:0.085;
         _candidate_matcher ~side:`Short ~ticker:"KO" ~score:55 ~entry_low:56.0
           ~entry_high:60.0 ~stop_low:61.0 ~stop_high:65.0 ~risk_low:0.075
           ~risk_high:0.085;
         _candidate_matcher ~side:`Short ~ticker:"CVX" ~score:45
           ~entry_low:125.0 ~entry_high:130.0 ~stop_low:135.0 ~stop_high:141.0
           ~risk_low:0.075 ~risk_high:0.085;
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
         ])
