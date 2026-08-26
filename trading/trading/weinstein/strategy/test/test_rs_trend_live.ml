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

    Five pins:
    - the config default covers {!Rs.min_aligned_bars_for_trend} (the arithmetic
      tripwire that would have caught the defect at its source);
    - a constructed zero-cross series classifies [Bullish_crossover] and a
      constructed accelerating series [Positive_rising];
    - across a multi-symbol run the enum takes more than one value (the
      distribution tripwire that was missing);
    - the degenerate paths still degrade as documented: at the old depth the
      same series collapses to [Positive_flat], below [rs_ma_period] the
      analysis is [None], and in the [rs_ma_period + 1 .. floor - 1] band the
      comparison silently clamps to a shorter span;
    - {!Screener_admission.rs_blocks_short} — the admission consumer whose
      verdict flips with the depth — is pinned on both sides of the floor. *)

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

(** Flat, then a strong advance to a peak at [i = 51], then a decline that never
    gets back below the 52-week average — normalized RS is above 1.0 at BOTH
    comparison points (1.75 four entries back, 1.264 now) and lower at the newer
    one. That is the positive-zone-but-falling shape issue #2556 arms
    {!Weinstein_types.Positive_declining} for; every other fixture here sits in
    a different quadrant, so none of them can reach that branch. *)
let _pos_declining_price i =
  if i < 40 then 100.0
  else if i <= 51 then 100.0 +. (8.0 *. Float.of_int (i - 39))
  else 196.0 -. (12.0 *. Float.of_int (i - 51))

let _flat_price _ = 100.0

let _fixtures =
  [
    ("XOVR", _crossing_price);
    ("RISE", _rising_price);
    ("FALL", _falling_price);
    ("PDEC", _pos_declining_price);
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
    weekly view and return the whole {!Rs.result} it produced. [depth] defaults
    to the shipped [lookback_bars]; passing a smaller value reproduces a
    shallower config without changing the underlying bars.

    Returning the result rather than just its [trend] lets the admission
    consumer ({!Screener_admission.rs_blocks_short}) be exercised on exactly the
    value the screener would hand it.

    [?armed] arms [Rs.config.enable_positive_declining] (#2556) the same way
    [Weinstein_strategy_screening._rs_config_for] does from
    [Weinstein_strategy_config.enable_rs_positive_declining]; it defaults to the
    shipped [false] so every other pin here reads the production classifier. *)
let _rs_of ?depth ?(armed = false) reader symbol =
  let config =
    Weinstein_strategy.default_config
      ~universe:(List.map _fixtures ~f:fst)
      ~index_symbol:_index_symbol
  in
  let n = Option.value depth ~default:config.lookback_bars in
  let view_for s =
    Bar_reader.weekly_view_for reader ~symbol:s ~n ~as_of:_as_of
  in
  let analysis_config =
    {
      Stock_analysis.default_config with
      rs = { Rs.default_config with enable_positive_declining = armed };
    }
  in
  let callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ~config:analysis_config ~stock:(view_for symbol)
      ~benchmark:(view_for _index_symbol) ()
  in
  let analysis =
    Stock_analysis.analyze_with_callbacks ~config:analysis_config ~ticker:symbol
      ~callbacks ~prior_stage:None ~as_of_date:_as_of
  in
  analysis.Stock_analysis.rs

let _trend_of ?depth ?armed reader symbol =
  Option.map (_rs_of ?depth ?armed reader symbol) ~f:(fun r -> r.Rs.trend)

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
                (* "PDEC" is positive-zone-but-falling. UNARMED — which is what
                   the default config ships — it folds into [Positive_flat],
                   exactly as it did before #2556. Its armed reading is pinned
                   separately below; keeping it in this list makes the R1
                   no-op claim visible on the production path. *)
                is_some_and (equal_to Weinstein_types.Positive_flat);
              ]);
       ])

(** #2556, through the same real panel path: at the shipped depth, "PDEC"'s
    normalized RS runs 1.75 -> 1.264 — both above the Mansfield zero line, the
    newer one lower — and the classifier reports [Positive_declining] once
    armed. Asserted as a PAIR against the unarmed reading of the identical bars,
    so the difference is attributable to the flag alone and the R1 no-op claim
    is pinned by the same assertion that pins the mechanism.

    The unit suite pins this branch on 8 hand-checkable bars; this pins that the
    strategy's own depth and wiring actually reach it — the distinction issue
    #2380 was created by, where a classifier correct in isolation was degenerate
    in production. *)
let test_positive_declining_needs_the_flag _ =
  let reader = _reader () in
  assert_that
    (_trend_of reader "PDEC", _trend_of ~armed:true reader "PDEC")
    (equal_to
       ( Some Weinstein_types.Positive_flat,
         Some Weinstein_types.Positive_declining ))

(** Arming must not disturb the other three fixtures: only the positive-zone
    sub-threshold arm changes, so every classification pinned above must survive
    the flag being on. Without this, the pair above could be satisfied by a flag
    that broke the classifier generally. *)
let test_arming_leaves_other_fixtures_unchanged _ =
  let reader = _reader () in
  assert_that
    (List.map [ "XOVR"; "RISE"; "FALL" ] ~f:(_trend_of ~armed:true reader))
    (elements_are
       [
         is_some_and (equal_to Weinstein_types.Bullish_crossover);
         is_some_and (equal_to Weinstein_types.Positive_rising);
         is_some_and (equal_to Weinstein_types.Negative_declining);
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

(** The third degenerate regime, the one between the other two:
    [rs_ma_period + 1 .. min_aligned_bars_for_trend - 1] weekly bars (53-55 at
    the defaults) leave [2..trend_lookback] history entries, so
    [Rs._classify_trend]'s
    [List.nth_exn history (max 0 (n - 1 - trend_lookback))] saturates at index
    [0] and compares across a {i shorter} span than [trend_lookback]. It does
    not error and it does not return [None] — it returns a plausible-looking
    classification computed over the wrong window, which is the same failure
    mode this whole pin exists to close.

    "XOVR" makes the clamp observable: its zero-line cross sits between four and
    five history entries back, so the full [trend_lookback]-span comparison
    reaches under the line and reports [Bullish_crossover] (pinned above), while
    every clamped span stays inside the final advance and reports
    [Positive_rising] instead. The whole band is asserted so the boundary cannot
    drift on one side unnoticed. *)
let test_clamp_band_compares_over_a_shorter_span _ =
  let reader = _reader () in
  let band =
    List.init
      (_min_bars - 1 - _rs_cfg.rs_ma_period)
      ~f:(fun i -> _rs_cfg.rs_ma_period + 1 + i)
  in
  assert_that
    (List.map band ~f:(fun depth -> _trend_of ~depth reader "XOVR"))
    (elements_are
       (List.map band ~f:(fun _ ->
            is_some_and (equal_to Weinstein_types.Positive_rising))))

(* ------------------------------------------------------------------ *)
(* 5. The admission consumer whose verdict flips with the depth        *)
(* ------------------------------------------------------------------ *)

(** {!Screener_admission.rs_blocks_short} is a {b hard} gate — [screener.ml]'s
    short branch is an unconditional [-> None] on it — and it returns [true] for
    [Positive_rising | Positive_flat | Bullish_crossover]. At the old depth the
    trend was [Positive_flat] for every candidate carrying RS data, so the gate
    was universally [true] and no such candidate could ever be shorted. At the
    shipped depth the same bars classify [Negative_declining] and the gate
    admits them.

    "FALL" is the fixture whose deeper view is [Negative_declining] (pinned by
    the distribution test above), so both arms below read the same bars and the
    flip is attributable to depth alone — the same construction as
    {!test_old_depth_collapses_to_positive_flat}, carried one step further into
    the consumer. The existing short-side suite cannot see this: its fixture has
    {i absent} RS ([test_short_side_bear_window.ml]), which takes the
    [rs_blocks_short None = false] path either way. *)
let test_rs_blocks_short_flips_with_depth _ =
  let reader = _reader () in
  assert_that
    ( Screener_admission.rs_blocks_short
        (_rs_of ~depth:_rs_cfg.rs_ma_period reader "FALL"),
      Screener_admission.rs_blocks_short (_rs_of reader "FALL") )
    (equal_to (true, false))

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
         "positive_declining_needs_the_flag"
         >:: test_positive_declining_needs_the_flag;
         "arming_leaves_other_fixtures_unchanged"
         >:: test_arming_leaves_other_fixtures_unchanged;
         "old_depth_collapses_to_positive_flat"
         >:: test_old_depth_collapses_to_positive_flat;
         "below_ma_period_yields_no_rs" >:: test_below_ma_period_yields_no_rs;
         "clamp_band_compares_over_a_shorter_span"
         >:: test_clamp_band_compares_over_a_shorter_span;
         "rs_blocks_short_flips_with_depth"
         >:: test_rs_blocks_short_flips_with_depth;
       ]

let () = run_test_tt_main suite
