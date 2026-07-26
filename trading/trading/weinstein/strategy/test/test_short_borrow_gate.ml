(** Unit tests for the [short_borrow_availability] short-entry gate (margin
    M3a).

    Pins the no-op-default contract and the gating behaviour of
    {!Weinstein_strategy.Short_borrow_gate.filter}:

    - [min_dollar_adv = 0.0] (default) → identity: every candidate is retained,
      so the entry candidate list is bit-identical to prior behaviour and every
      existing golden/baseline replays unchanged.
    - A positive floor drops {b short} candidates whose dollar-ADV is below it
      ("no borrow available"); long candidates are never affected.
    - A [None] dollar-ADV reading never drops a candidate.

    Plus the strategy-side adapter {!Short_borrow_gate.apply}: that it measures
    borrow supply on {b exactly the same basis} as the entry gate — i.e. it
    honours [liquidity_config.adv_aggregation] — which is the contract that
    justified passing the whole {!Liquidity_config.t} rather than a bare
    lookback. *)

open OUnit2
open Core
open Matchers
open Weinstein_types
module Bar_reader = Weinstein_strategy.Bar_reader
module Liquidity_config = Weinstein_strategy.Liquidity_config
module Liquidity_metric = Weinstein_strategy.Liquidity_metric
module Short_borrow_gate = Weinstein_strategy.Short_borrow_gate

let _make_candidate ~ticker ~side : Screener.scored_candidate =
  {
    ticker;
    analysis =
      Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
        ~bars:[] ~benchmark_bars:[] ~prior_stage:None
        ~as_of_date:(Date.of_string "2024-01-01");
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry = 20.0;
    suggested_stop = 21.6;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _short ~ticker = _make_candidate ~ticker ~side:Trading_base.Types.Short
let _long ~ticker = _make_candidate ~ticker ~side:Trading_base.Types.Long

(* Fixed ADV lookup: THIN trades $100k/day, THICK $5M/day, and NOREAD has no
   reading. *)
let adv_for = function
  | "THIN" -> Some 100_000.0
  | "THICK" -> Some 5_000_000.0
  | _ -> None

let tickers result = List.map result ~f:(fun c -> c.Screener.ticker)

let test_zero_floor_is_noop _ =
  let candidates = [ _short ~ticker:"THIN"; _short ~ticker:"THICK" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:0.0 ~dollar_adv_for:adv_for
          candidates))
    (elements_are [ equal_to "THIN"; equal_to "THICK" ])

let test_floor_drops_illiquid_short_keeps_liquid _ =
  let candidates = [ _short ~ticker:"THIN"; _short ~ticker:"THICK" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (elements_are [ equal_to "THICK" ])

let test_floor_never_drops_longs _ =
  (* A LONG named THIN (below the floor) is retained — borrow is short-only. *)
  let candidates = [ _long ~ticker:"THIN"; _short ~ticker:"THIN" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (elements_are [ equal_to "THIN" ])

let test_missing_reading_keeps_short _ =
  (* NOREAD has no dollar-ADV reading → kept (a missing reading never drops). *)
  let candidates = [ _short ~ticker:"NOREAD" ] in
  assert_that
    (List.length
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (equal_to 1)

(* ---------------------------------------------------------------------- *)
(* Consumer-level: [apply] measures on the entry gate's basis               *)
(*                                                                         *)
(* [filter] takes the dollar-ADV reading as GIVEN. These tests pin the      *)
(* adapter's measurement basis: the same spoofed bar history is read as     *)
(* $2,000,080 under [Mean] (borrow "available", short kept) and $100 under  *)
(* [Median] (no borrow, short dropped). Only [adv_aggregation] differs, so  *)
(* de-threading it from [apply] turns both assertions red.                  *)
(* ---------------------------------------------------------------------- *)

let _borrow_floor = 1_000_000.0
let _spoof_lookback = 5
let _spoof_close = 10.0
let _spoof_start = Date.of_string "2024-03-25"
let _spoof_bar_count = 5
let _spoof_spike_index = 2
let _honest_dollar_volume = 100.0
let _spoof_dollar_volume = 10_000_000.0

(* 5 bars of a near-dead name plus one block print. mean = (4*100 + 10M)/5 =
   2,000,080 (clears the $1M floor); median = 100 (fails it). *)
let _spoof_bar i : Types.Daily_price.t =
  let dollar_volume =
    if i = _spoof_spike_index then _spoof_dollar_volume
    else _honest_dollar_volume
  in
  {
    date = Date.add_days _spoof_start i;
    open_price = _spoof_close;
    high_price = _spoof_close;
    low_price = _spoof_close;
    close_price = _spoof_close;
    adjusted_close = _spoof_close;
    volume = Float.to_int (dollar_volume /. _spoof_close);
    active_through = None;
  }

let _spoof_bars = List.init _spoof_bar_count ~f:_spoof_bar
let _spoof_as_of = Date.add_days _spoof_start (_spoof_bar_count - 1)

let _apply_survivors aggregation =
  let liquidity_config =
    {
      Liquidity_config.default_config with
      adv_lookback_days = _spoof_lookback;
      adv_aggregation = aggregation;
    }
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("SPOOF", _spoof_bars) ] in
  tickers
    (Short_borrow_gate.apply ~min_dollar_adv:_borrow_floor ~liquidity_config
       ~bar_reader ~current_date:_spoof_as_of
       [ _short ~ticker:"SPOOF" ])

let test_apply_mean_keeps_spoofed_short _ =
  assert_that
    (_apply_survivors Liquidity_metric.Mean)
    (elements_are [ equal_to "SPOOF" ])

let test_apply_median_drops_spoofed_short _ =
  assert_that (_apply_survivors Liquidity_metric.Median) (elements_are [])

let () =
  run_test_tt_main
    ("short_borrow_gate"
    >::: [
           "zero floor is a no-op" >:: test_zero_floor_is_noop;
           "floor drops illiquid short, keeps liquid"
           >:: test_floor_drops_illiquid_short_keeps_liquid;
           "floor never drops longs" >:: test_floor_never_drops_longs;
           "missing reading keeps short" >:: test_missing_reading_keeps_short;
           "apply: Mean keeps the spoofed short"
           >:: test_apply_mean_keeps_spoofed_short;
           "apply: Median drops the spoofed short"
           >:: test_apply_median_drops_spoofed_short;
         ])
