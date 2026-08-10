(** Pin {!Entry_ticket_tags} — the placement-time ticket audit tags of PR-5
    ([dev/plans/entry-ticket-async-v2-2026-08-10.md] §4 PR-5, §3-F6).

    Two contracts:
    - the F6 §4.5 triple-confirmation measurements are read off the analysis the
      strategy already holds ([docs/design/weinstein-book-reference.md] §4.5);
    - the F1 freshness basis is {i recovered} from
      [Stock_analysis.t.range_top_freshness] rather than guessed, so both basis
      values are distinguishable on the audit row. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _date s = Date.of_string s

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 3;
  }

(** Volume analysis carrying a known breakout multiple — §4.5 signal (1). *)
let _volume_result ~ratio : Volume.result =
  {
    confirmation = Weinstein_types.Strong ratio;
    event_volume = Float.to_int (1_000_000.0 *. ratio);
    avg_volume = 1_000_000.0;
    volume_ratio = ratio;
  }

(** RS analysis whose classified trend is [trend] — §4.5 signal (2) fires only
    on [Bullish_crossover], the book's own "RS crossed the zero line" state. *)
let _rs_result ~(trend : Weinstein_types.rs_trend) : Rs.result =
  { current_rs = 1.0; current_normalized = 0.1; trend; history = [] }

let _analysis ?volume ?rs ?breakout_price ?breakdown_price
    ?(range_top_freshness = None) () : Stock_analysis.t =
  {
    ticker = "ZZZZ";
    stage = _stage_result;
    rs;
    volume;
    resistance = None;
    support = None;
    breakout_price;
    breakdown_price;
    local_range_top = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission = false;
    range_top_freshness;
    require_breakout_volume = true;
    current_close = None;
    as_of_date = _date "2024-03-15";
  }

(* ------------------------------------------------------------------ *)
(* F6 — §4.5 triple confirmation                                        *)
(* ------------------------------------------------------------------ *)

(** All three §4.5 signals present: 3x breakout volume, RS zero-cross, and a
    base whose top sits 50% above its floor (National Semiconductor shape). *)
let test_triple_confirmation_captures_all_three_signals _ =
  let analysis =
    _analysis
      ~volume:(_volume_result ~ratio:3.0)
      ~rs:(_rs_result ~trend:Weinstein_types.Bullish_crossover)
      ~breakout_price:15.0 ~breakdown_price:10.0 ()
  in
  assert_that
    (Entry_ticket_tags.triple_confirmation_of_analysis analysis)
    (all_of
       [
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) ->
             t.breakout_volume_multiple)
           (is_some_and (float_equal 3.0));
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) -> t.rs_zero_cross)
           (equal_to true);
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) ->
             t.in_base_advance_pct)
           (is_some_and (float_equal 0.5));
       ])

(** A rising-but-not-crossing RS is NOT the §4.5 signal: the book's condition is
    the move {i from} near zero {i into} positive territory. *)
let test_triple_confirmation_rs_zero_cross_only_on_bullish_crossover _ =
  let analysis =
    _analysis ~rs:(_rs_result ~trend:Weinstein_types.Positive_rising) ()
  in
  assert_that
    (Entry_ticket_tags.triple_confirmation_of_analysis analysis)
    (field
       (fun (t : Entry_ticket_tags.triple_confirmation) -> t.rs_zero_cross)
       (equal_to false))

(** Missing inputs degrade to [None] / [false] rather than raising: a
    thin-history candidate still produces a row. *)
let test_triple_confirmation_is_total_on_missing_inputs _ =
  assert_that
    (Entry_ticket_tags.triple_confirmation_of_analysis (_analysis ()))
    (all_of
       [
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) ->
             t.breakout_volume_multiple)
           is_none;
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) -> t.rs_zero_cross)
           (equal_to false);
         field
           (fun (t : Entry_ticket_tags.triple_confirmation) ->
             t.in_base_advance_pct)
           is_none;
       ])

(** A non-positive base floor gives no meaningful denominator. *)
let test_in_base_advance_none_on_non_positive_floor _ =
  assert_that
    (Entry_ticket_tags.triple_confirmation_of_analysis
       (_analysis ~breakout_price:15.0 ~breakdown_price:0.0 ()))
    (field
       (fun (t : Entry_ticket_tags.triple_confirmation) ->
         t.in_base_advance_pct)
       is_none)

(** The book's reference level is 40%; a 50%-advance base with 3x volume and the
    zero-cross is the triple-confirmed cohort. *)
let test_is_triple_confirmed_requires_all_three _ =
  let confirmed =
    Entry_ticket_tags.triple_confirmation_of_analysis
      (_analysis
         ~volume:(_volume_result ~ratio:3.0)
         ~rs:(_rs_result ~trend:Weinstein_types.Bullish_crossover)
         ~breakout_price:15.0 ~breakdown_price:10.0 ())
  in
  (* Same base and volume, but the RS never crossed. *)
  let no_cross =
    Entry_ticket_tags.triple_confirmation_of_analysis
      (_analysis
         ~volume:(_volume_result ~ratio:3.0)
         ~rs:(_rs_result ~trend:Weinstein_types.Positive_rising)
         ~breakout_price:15.0 ~breakdown_price:10.0 ())
  in
  (* All three signals but only a 20% in-base advance — under §4.5's 40%. *)
  let shallow_base =
    Entry_ticket_tags.triple_confirmation_of_analysis
      (_analysis
         ~volume:(_volume_result ~ratio:3.0)
         ~rs:(_rs_result ~trend:Weinstein_types.Bullish_crossover)
         ~breakout_price:12.0 ~breakdown_price:10.0 ())
  in
  assert_that
    (List.map
       [ confirmed; no_cross; shallow_base ]
       ~f:(Entry_ticket_tags.is_triple_confirmed ~strong_volume_threshold:2.0))
    (elements_are [ equal_to true; equal_to false; equal_to false ])

(** The book's ≥40% accumulation signature (§4.5, National Semiconductor /
    Blocker Energy) is the constant the cohort predicate reads. *)
let test_book_min_in_base_advance_pct_is_forty_percent _ =
  assert_that Entry_ticket_tags.book_min_in_base_advance_pct (float_equal 0.40)

(* ------------------------------------------------------------------ *)
(* F1 — freshness basis recovery                                        *)
(* ------------------------------------------------------------------ *)

(** [range_top_freshness = None] is the default [Ma_cross] clock's "no opinion"
    — recovered as [Ma_cross], never as an armed basis. *)
let test_freshness_basis_ma_cross_when_no_opinion _ =
  assert_that
    (Entry_ticket_tags.freshness_basis_of_analysis (_analysis ()))
    (equal_to Entry_freshness.Ma_cross)

(** The armed basis always yields [Some _], INCLUDING [Some false] (setup not
    live). Both must recover as [Range_top_breakout] — recovering only the
    [Some true] case would silently relabel every rejected-but-armed row. *)
let test_freshness_basis_range_top_for_both_armed_verdicts _ =
  assert_that
    (List.map [ Some true; Some false ] ~f:(fun range_top_freshness ->
         Entry_ticket_tags.freshness_basis_of_analysis
           (_analysis ~range_top_freshness ())))
    (elements_are
       [
         equal_to Entry_freshness.Range_top_breakout;
         equal_to Entry_freshness.Range_top_breakout;
       ])

let suite =
  "entry_ticket_tags"
  >::: [
         "triple_confirmation captures all three §4.5 signals"
         >:: test_triple_confirmation_captures_all_three_signals;
         "rs_zero_cross fires only on Bullish_crossover"
         >:: test_triple_confirmation_rs_zero_cross_only_on_bullish_crossover;
         "triple_confirmation is total on missing inputs"
         >:: test_triple_confirmation_is_total_on_missing_inputs;
         "in_base_advance is None on a non-positive floor"
         >:: test_in_base_advance_none_on_non_positive_floor;
         "is_triple_confirmed requires all three"
         >:: test_is_triple_confirmed_requires_all_three;
         "book_min_in_base_advance_pct is 40%"
         >:: test_book_min_in_base_advance_pct_is_forty_percent;
         "freshness basis is Ma_cross when the armed clock has no opinion"
         >:: test_freshness_basis_ma_cross_when_no_opinion;
         "freshness basis is Range_top_breakout for both armed verdicts"
         >:: test_freshness_basis_range_top_for_both_armed_verdicts;
       ]

let () = run_test_tt_main suite
