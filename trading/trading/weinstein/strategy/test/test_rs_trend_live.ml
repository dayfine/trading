(** Issue #2380 — the RS trend classifier must actually classify.

    Before this pin, [Weinstein_strategy_config.lookback_bars = 52] fed {!Rs}
    exactly [rs_ma_period] aligned weeks. The Mansfield MA consumes
    [rs_ma_period - 1] of them, leaving a {b one-entry} RS history, and
    [Rs._classify_trend]'s [n < 2] guard then returned [Positive_flat] for every
    symbol in every run — 4,231 tickets across three independently-run arms,
    zero non-flat. Nothing caught it: [Positive_flat] is a legitimate-looking
    value (not a [None]), and no test asserted the {i distribution} of the enum.

    The existing unit tests over this enum (e.g. [test_entry_ticket_tags.ml])
    hand-build a [Stock_analysis.t] with a chosen [rs] field, so they pin the
    consumers while being structurally blind to the producer. Everything here
    therefore runs through the {b real panel path} the screener uses —
    [Bar_reader.weekly_view_for ~n:config.lookback_bars] ->
    {!Panel_callbacks.stock_analysis_callbacks_of_weekly_views} ->
    {!Stock_analysis.analyze_with_callbacks} — so the depth actually under test
    is the one the strategy ships.

    Four pins:
    - the config default covers {!Rs.min_aligned_bars_for_trend} (the arithmetic
      tripwire that would have caught the defect at its source);
    - a constructed zero-cross series classifies [Bullish_crossover] and a
      constructed accelerating series [Positive_rising];
    - across a multi-symbol run the enum takes more than one value (the
      distribution tripwire that was missing);
    - the degenerate paths still degrade as documented: at the old depth the
      same series collapses to [Positive_flat], and below [rs_ma_period] the
      analysis is [None]. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _index_symbol = "BENCH"
let _start_friday = Date.of_string "2023-01-06"

(** One weekly bar. Friday-spaced daily bars each land in their own week, so a
    list of these reads back as a weekly view of the same length. *)
let _bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

(** [n] consecutive Friday bars whose close at index [i] is [price_at i]. *)
let _series ~n ~price_at =
  List.init n ~f:(fun i ->
      _bar ~date:(Date.add_days _start_friday (i * 7)) ~price:(price_at i))

let _rs_cfg = Rs.default_config
let _min_bars = Rs.min_aligned_bars_for_trend _rs_cfg

(* Fixture series, all [_min_bars] long against a flat benchmark, so the raw RS
   ratio is the price series itself scaled by 100. Index [i] runs 0 (oldest) to
   [_min_bars - 1] (newest); the classifier compares the newest normalized value
   against the one [trend_lookback = 4] history entries back, i.e. bar
   [_min_bars - 5]. *)

(** Drifts gently {i below} its own 52-week average, then jumps in the final
    four weeks — normalized RS crosses 1.0 from under it. *)
let _crossing_price i =
  if i < _min_bars - 4 then 100.0 -. (0.1 *. Float.of_int i)
  else 110.0 +. (10.0 *. Float.of_int (i - (_min_bars - 4)))

(** Flat, then a sustained advance that keeps outrunning its own trailing
    average — normalized RS is above 1.0 at both comparison points and higher at
    the newer one. *)
let _rising_price i =
  if i < 40 then 100.0 else 100.0 +. (2.0 *. Float.of_int (i - 39))

(** A steady decline: normalized RS is below 1.0 at both comparison points and
    lower at the newer one. *)
let _falling_price i = 100.0 -. (0.5 *. Float.of_int i)

let _flat_price _ = 100.0

let _fixtures =
  [
    ("XOVR", _crossing_price); ("RISE", _rising_price); ("FALL", _falling_price);
  ]

(** A reader carrying every fixture symbol plus the flat benchmark, each
    [_min_bars] weeks deep. *)
let _reader () =
  Bar_reader.of_in_memory_bars
    ((_index_symbol, _series ~n:_min_bars ~price_at:_flat_price)
    :: List.map _fixtures ~f:(fun (symbol, price_at) ->
        (symbol, _series ~n:_min_bars ~price_at)))

let _as_of = Date.add_days _start_friday ((_min_bars - 1) * 7)

(** Run the screener's own Phase-2 wiring for [symbol] over a [depth]-week
    weekly view and return the RS trend it classified. [depth] defaults to the
    shipped [lookback_bars]; passing a smaller value reproduces a shallower
    config without changing the underlying bars. *)
let _trend_of ?depth reader symbol =
  let config =
    Weinstein_strategy.default_config
      ~universe:(List.map _fixtures ~f:fst)
      ~index_symbol:_index_symbol
  in
  let n = Option.value depth ~default:config.lookback_bars in
  let view_for s =
    Bar_reader.weekly_view_for reader ~symbol:s ~n ~as_of:_as_of
  in
  let analysis_config = Stock_analysis.default_config in
  let callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ~config:analysis_config ~stock:(view_for symbol)
      ~benchmark:(view_for _index_symbol) ()
  in
  let analysis =
    Stock_analysis.analyze_with_callbacks ~config:analysis_config ~ticker:symbol
      ~callbacks ~prior_stage:None ~as_of_date:_as_of
  in
  Option.map analysis.Stock_analysis.rs ~f:(fun r -> r.Rs.trend)

(* ------------------------------------------------------------------ *)
(* 1. The arithmetic tripwire                                           *)
(* ------------------------------------------------------------------ *)

(** The shipped weekly-view depth must cover the RS trend's minimum. This is the
    check whose absence let a 52-vs-52 collision sit undetected: both numbers
    were individually reasonable, and only their relation was wrong. *)
let test_lookback_covers_rs_trend_floor _ =
  let config =
    Weinstein_strategy.default_config ~universe:[ "ZZZ" ]
      ~index_symbol:_index_symbol
  in
  assert_that config.lookback_bars (ge (module Int_ord) _min_bars)

(** Pins the derivation itself, so a change to [rs_ma_period] or
    [trend_lookback] that silently re-breaks the relation is visible here as
    well as at the config. *)
let test_min_aligned_bars_derivation _ =
  assert_that
    (Rs.min_aligned_bars_for_trend
       { _rs_cfg with rs_ma_period = 10; trend_lookback = 3 })
    (equal_to 13)

(* ------------------------------------------------------------------ *)
(* 2. Real classifications through the panel path                       *)
(* ------------------------------------------------------------------ *)

(** The signal §4.5 [rs_zero_cross] and the screener's crossover scoring bonus
    both key on, reached end-to-end for the first time. *)
let test_zero_cross_classifies_bullish_crossover _ =
  assert_that
    (_trend_of (_reader ()) "XOVR")
    (is_some_and (equal_to Weinstein_types.Bullish_crossover))

let test_accelerating_advance_classifies_positive_rising _ =
  assert_that
    (_trend_of (_reader ()) "RISE")
    (is_some_and (equal_to Weinstein_types.Positive_rising))

(* ------------------------------------------------------------------ *)
(* 3. Distribution tripwire                                            *)
(* ------------------------------------------------------------------ *)

(** Over a multi-symbol run the enum must take more than one value. A classifier
    that is live for one hand-picked fixture but degenerate in general still
    passes the two pins above; it cannot pass this one. The exact per-symbol
    expectation is asserted alongside the count so the tripwire cannot be
    satisfied by an unintended pair of values. *)
let test_trend_distribution_is_not_degenerate _ =
  let reader = _reader () in
  let trends = List.map _fixtures ~f:(fun (s, _) -> _trend_of reader s) in
  let distinct =
    List.filter_map trends ~f:(Option.map ~f:Weinstein_types.show_rs_trend)
    |> List.dedup_and_sort ~compare:String.compare
  in
  assert_that
    (List.length distinct, trends)
    (all_of
       [
         field fst (ge (module Int_ord) 2);
         field snd
           (elements_are
              [
                is_some_and (equal_to Weinstein_types.Bullish_crossover);
                is_some_and (equal_to Weinstein_types.Positive_rising);
                is_some_and (equal_to Weinstein_types.Negative_declining);
              ]);
       ])

(* ------------------------------------------------------------------ *)
(* 4. The degenerate paths still degrade as documented                 *)
(* ------------------------------------------------------------------ *)

(** The defect, reproduced: the identical bars read through a
    [rs_ma_period]-deep view leave a one-entry history, and the [n < 2] guard
    returns [Positive_flat] where the deeper view sees a crossover. The
    difference is attributable to depth alone. *)
let test_old_depth_collapses_to_positive_flat _ =
  assert_that
    (_trend_of ~depth:_rs_cfg.rs_ma_period (_reader ()) "XOVR")
    (is_some_and (equal_to Weinstein_types.Positive_flat))

(** Below [rs_ma_period] there is no zero-line MA at all, so the analysis
    reports [None] rather than a fabricated trend. *)
let test_below_ma_period_yields_no_rs _ =
  assert_that
    (_trend_of ~depth:(_rs_cfg.rs_ma_period - 1) (_reader ()) "XOVR")
    is_none

let suite =
  "rs_trend_live"
  >::: [
         "lookback_covers_rs_trend_floor"
         >:: test_lookback_covers_rs_trend_floor;
         "min_aligned_bars_derivation" >:: test_min_aligned_bars_derivation;
         "zero_cross_classifies_bullish_crossover"
         >:: test_zero_cross_classifies_bullish_crossover;
         "accelerating_advance_classifies_positive_rising"
         >:: test_accelerating_advance_classifies_positive_rising;
         "trend_distribution_is_not_degenerate"
         >:: test_trend_distribution_is_not_degenerate;
         "old_depth_collapses_to_positive_flat"
         >:: test_old_depth_collapses_to_positive_flat;
         "below_ma_period_yields_no_rs" >:: test_below_ma_period_yields_no_rs;
       ]

let () = run_test_tt_main suite
