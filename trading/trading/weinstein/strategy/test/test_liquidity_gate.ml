(** Unit tests for the [liquidity_gate] entry gate.

    Pins the no-op-default contract and the gating behaviour of
    {!Liquidity_gate.filter}:

    - [min_entry_dollar_adv = 0.0] (default) → identity: every candidate is
      retained, so the entry candidate list is bit-identical to prior behaviour
      and every existing golden/baseline replays unchanged.
    - [min_entry_dollar_adv > 0] → candidates (long OR short) whose
      [dollar_adv_for ticker] is below the threshold are dropped; those at/above
      are retained.
    - A candidate with no liquidity reading ([dollar_adv_for] returns [None]) is
      retained — a missing reading must never drop a candidate.

    Also pins the strategy-side adapter {!Entry_liquidity_gate.apply}: that it
    measures dollar-ADV on the basis carried by {!Liquidity_config} — so
    flipping [adv_aggregation] flips a real gate decision, not just a parsed
    field. *)

open OUnit2
open Core
open Matchers
open Weinstein_types

(* Minimal [scored_candidate] builder — only [ticker] / [side] are load-bearing
   for the gate; the rest carry inert placeholders. *)
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
    suggested_entry = 10.0;
    suggested_stop = 10.8;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _long ticker = _make_candidate ~ticker ~side:Trading_base.Types.Long
let _short ticker = _make_candidate ~ticker ~side:Trading_base.Types.Short

(* Per-ticker dollar-ADV lookup driven by an assoc list of [ticker -> float
   option]. A missing key and an explicit [None] both yield [None] (the gate
   treats both as "no reading"). *)
let _adv_for table ticker =
  Option.join (List.Assoc.find table ticker ~equal:String.equal)

(** Default [0.0] is a no-op: every candidate is retained, in order. *)
let test_zero_threshold_is_noop _ =
  let candidates = [ _long "A"; _short "B" ] in
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:0.0
      ~dollar_adv_for:(_adv_for [ ("A", Some 1.0); ("B", Some 1.0) ])
      candidates
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "A"; equal_to "B" ])

(** Threshold drops the illiquid candidate, retains the liquid one — on both
    sides (a low-ADV short is dropped just like a low-ADV long). *)
let test_threshold_drops_illiquid_both_sides _ =
  let candidates = [ _long "LIQUID"; _short "ILLIQUID" ] in
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:
        (_adv_for [ ("LIQUID", Some 5_000_000.0); ("ILLIQUID", Some 100.0) ])
      candidates
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "LIQUID" ])

(** A candidate priced exactly at the threshold is retained (gate is [>=]). *)
let test_threshold_boundary_is_inclusive _ =
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:(_adv_for [ ("EXACT", Some 1_000_000.0) ])
      [ _long "EXACT" ]
  in
  assert_that (List.length result) (equal_to 1)

(** A missing liquidity reading ([None]) never drops the candidate. *)
let test_missing_reading_is_retained _ =
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:(_adv_for [ ("NO_DATA", None) ])
      [ _long "NO_DATA" ]
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "NO_DATA" ])

(* ---------------------------------------------------------------------- *)
(* Consumer-level: the [Entry_liquidity_gate.apply] measurement basis       *)
(*                                                                         *)
(* [filter] above takes the dollar-ADV reading as GIVEN, so it cannot see   *)
(* how that reading was produced. These two tests pin the adapter: it reads *)
(* bars through [Liquidity_metric.dollar_adv] using the aggregation carried *)
(* by the config, so flipping [adv_aggregation] flips a real keep/drop      *)
(* decision (experiment-flag-discipline R2 — the axis changes behaviour,    *)
(* not just the parsed config).                                            *)
(*                                                                         *)
(* Fixture: the #2060 LINK spoof — 60 honest $250k/day bars with one $15.4M *)
(* block print inside the trailing 20-bar window. Its MEAN reads $1,007,500 *)
(* (clears the armed $1M entry floor by 0.75%); its MEDIAN reads the honest *)
(* $250k (fails the floor). Same shape as [test_liquidity_metric.ml]'s      *)
(* spoof fixture, here driven end-to-end through a real [Bar_reader].       *)
(* ---------------------------------------------------------------------- *)

module Bar_reader = Weinstein_strategy.Bar_reader
module Entry_liquidity_gate = Weinstein_strategy.Entry_liquidity_gate
module Liquidity_config = Weinstein_strategy.Liquidity_config
module Liquidity_metric = Weinstein_strategy.Liquidity_metric

let _spoof_ticker = "LINK"
let _spoof_close = 5.0
let _spoof_start = Date.of_string "2026-03-16"
let _spoof_bar_count = 60
let _spoof_spike_index = 50
let _spoof_lookback = 20
let _entry_floor = 1_000_000.0
let _honest_dollar_volume = 250_000.0
let _spoof_dollar_volume = 15_400_000.0

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

(* Tickers surviving the armed entry gate over the spoof fixture, read under
   [aggregation]. *)
let _entry_gate_survivors aggregation =
  let config =
    {
      Liquidity_config.default_config with
      adv_lookback_days = _spoof_lookback;
      min_entry_dollar_adv = _entry_floor;
      adv_aggregation = aggregation;
    }
  in
  let bar_reader =
    Bar_reader.of_in_memory_bars [ (_spoof_ticker, _spoof_bars) ]
  in
  Entry_liquidity_gate.apply ~config ~bar_reader ~current_date:_spoof_as_of
    [ _long _spoof_ticker ]
  |> List.map ~f:(fun c -> c.Screener.ticker)

(** [Mean] (the default) is spoofed past the floor: the candidate is KEPT. *)
let test_apply_mean_keeps_spoofed_candidate _ =
  assert_that
    (_entry_gate_survivors Liquidity_metric.Mean)
    (elements_are [ equal_to _spoof_ticker ])

(** [Median] is unmoved by the single block print: the candidate is DROPPED.
    Same bars, same threshold, same reader — only the config aggregation
    differs, so this pins that the adapter really threads it. *)
let test_apply_median_drops_spoofed_candidate _ =
  assert_that (_entry_gate_survivors Liquidity_metric.Median) (elements_are [])

let () =
  run_test_tt_main
    ("liquidity_gate"
    >::: [
           "zero threshold is a no-op" >:: test_zero_threshold_is_noop;
           "threshold drops illiquid both sides"
           >:: test_threshold_drops_illiquid_both_sides;
           "threshold boundary is inclusive"
           >:: test_threshold_boundary_is_inclusive;
           "missing reading is retained" >:: test_missing_reading_is_retained;
           "apply: Mean keeps the spoofed candidate"
           >:: test_apply_mean_keeps_spoofed_candidate;
           "apply: Median drops the spoofed candidate"
           >:: test_apply_median_drops_spoofed_candidate;
         ])
