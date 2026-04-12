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
    [dev/status/sector-data-plan.md]. Once that's wired, a follow-up can add a
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

let _universe_set = Set.of_list (module String) _universe

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

(** Assert that a [scored_candidate] has the full shape contract: ticker is from
    the configured universe, prices are positive, risk_pct is in [0, 1],
    rationale is non-empty, and for a long candidate
    [suggested_stop < suggested_entry]. [~side] flips the stop-vs-entry check
    for shorts. *)
let _candidate_is_well_formed ~side (c : Screener.scored_candidate) =
  let stop_vs_entry =
    match side with
    | `Long -> Float.(c.Screener.suggested_stop < c.Screener.suggested_entry)
    | `Short -> Float.(c.Screener.suggested_stop > c.Screener.suggested_entry)
  in
  assert_that c
    (all_of
       [
         field
           (fun c -> Set.mem _universe_set c.Screener.ticker)
           (equal_to true);
         field (fun c -> c.Screener.suggested_entry) (gt (module Float_ord) 0.0);
         field (fun c -> c.Screener.suggested_stop) (gt (module Float_ord) 0.0);
         field
           (fun c -> c.Screener.risk_pct)
           (is_between (module Float_ord) ~low:0.0 ~high:1.0);
         field
           (fun c -> List.length c.Screener.rationale)
           (gt (module Int_ord) 0);
       ]);
  assert_that stop_vs_entry (equal_to true)

(* ------------------------------------------------------------------ *)
(* M3 Test 1: Full screener cascade — bullish macro, diverse universe  *)
(* ------------------------------------------------------------------ *)

(** Runs the full screener pipeline over a 7-stock diverse universe during a
    sustained bull regime (2021-01 → 2023-12). Bullish macro permits buy
    candidates through the gate; the empty sector map gives every ticker a
    Neutral rating by fall-through. Any buy candidate returned must satisfy the
    full shape contract. Short candidates must be empty under Bullish macro
    (gate semantics). *)
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
  assert_that result
    (all_of
       [
         field (fun (r : Screener.result) -> r.macro_trend) (equal_to Bullish);
         (* Short candidates must be gated out under Bullish macro. *)
         field (fun (r : Screener.result) -> r.short_candidates) is_empty;
       ]);
  List.iter result.buy_candidates ~f:(_candidate_is_well_formed ~side:`Long)

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
(* M3 Test 4: Output record fields populated on any Neutral-macro run   *)
(* ------------------------------------------------------------------ *)

(** Under a [Neutral] macro, both buy and short candidate paths are active.
    Every candidate returned — in either list — must satisfy the full shape
    contract (entry, stop, risk, rationale). Stop-vs-entry direction differs by
    side. Passing counts are data-dependent, so the test iterates rather than
    asserting counts. *)
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
  List.iter result.buy_candidates ~f:(_candidate_is_well_formed ~side:`Long);
  List.iter result.short_candidates ~f:(_candidate_is_well_formed ~side:`Short)

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
         ])
