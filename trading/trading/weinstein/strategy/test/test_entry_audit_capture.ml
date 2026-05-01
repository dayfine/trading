(** Pin the G14-fix-B contract for [Entry_audit_capture]: when the screener's
    [cand.suggested_entry] differs from the most recent close in [bar_reader] at
    [current_date], the produced [Position.CreateEntering] and [entry_event] use
    the realised entry (current close), while the audit row's [candidate] field
    still carries the screener's pre-fill intent verbatim.

    See [dev/notes/g14-deep-dive-2026-05-01.md] for the bug + fix shape. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _ticker = "ZZZZ"

(** Build a one-symbol [Bar_reader.t] whose most recent (and only) bar has
    [close_price = current_close]. The bar reader's [daily_bars_for] returns a
    list with this bar; [_effective_entry_price] reads its [close_price] as the
    realised entry. *)
let _bar_reader_with_current_close ~current_date ~current_close : Bar_reader.t =
  let symbol_index =
    match Symbol_index.create ~universe:[ _ticker ] with
    | Ok t -> t
    | Error err ->
        OUnit2.assert_failure ("Symbol_index.create: " ^ err.Status.message)
  in
  let calendar = [| current_date |] in
  let ohlcv = Ohlcv_panels.create symbol_index ~n_days:1 in
  (match Symbol_index.to_row symbol_index _ticker with
  | None -> OUnit2.assert_failure "to_row failed"
  | Some row ->
      Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day:0
        {
          Types.Daily_price.date = current_date;
          open_price = current_close;
          high_price = current_close *. 1.01;
          low_price = current_close *. 0.99;
          close_price = current_close;
          adjusted_close = current_close;
          volume = 1_000_000;
        });
  let panels =
    match Bar_panels.create ~ohlcv ~calendar with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure ("Bar_panels.create: " ^ err.Status.message)
  in
  Bar_reader.of_panels panels

(** Construct a minimal [Stage.result] for the analysis bundle. The fields are
    required by [scored_candidate] but [make_entry_transition] doesn't read them
    — only [suggested_entry] / [suggested_stop] / [side] flow through. *)
let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis ~ticker ~as_of_date : Stock_analysis.t =
  {
    ticker;
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    prior_stage = None;
    as_of_date;
  }

let _sector_context : Screener.sector_context =
  {
    sector_name = "Test";
    rating = Neutral;
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
  }

(** Build a long [scored_candidate] whose [suggested_entry] is divorced from
    [bar_reader]'s current close. This is the configuration that exposes the G14
    bug pre-fix. *)
let _long_candidate ~ticker ~suggested_entry ~suggested_stop ~as_of_date :
    Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker ~as_of_date;
    sector = _sector_context;
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry;
    suggested_stop;
    risk_pct = (suggested_entry -. suggested_stop) /. suggested_entry;
    swing_target = None;
    rationale = [ "test breakout"; "test volume confirm" ];
  }

let _portfolio_risk_config : Portfolio_risk.config =
  Portfolio_risk.default_config

let _stops_config : Weinstein_stops.config = Weinstein_stops.default_config

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** With [suggested_entry = $130] and bar_reader returning current close $110,
    [make_entry_transition] must produce a [CreateEntering] whose
    [entry_price = $110] — the realised price the broker will fill at — and
    sizing keys off this realised price too. *)
let test_effective_entry_overrides_suggested_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:110.0
  in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun ((trans : Position.transition), _) ->
                match trans.kind with
                | Position.CreateEntering e -> e.entry_price
                | _ -> Float.nan)
              (float_equal 110.0);
            field
              (fun (_, (m : Entry_audit_capture.entry_meta)) ->
                m.effective_entry_price)
              (float_equal 110.0);
          ]))

(** [build_entry_event] must compute [initial_position_value] and
    [initial_risk_dollars] off [meta.effective_entry_price] (realised entry),
    not the screener's pre-fill [candidate.suggested_entry]. The candidate field
    on the audit row keeps [suggested_entry] verbatim so audit consumers can
    reconcile screener intent vs realised entry. *)
let test_entry_event_audit_dollars_use_effective_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:110.0
  in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let trans_and_meta =
    match
      Entry_audit_capture.make_entry_transition
        ~portfolio_risk_config:_portfolio_risk_config
        ~stops_config:_stops_config ~initial_stop_buffer:0.92 ~stop_states
        ~bar_reader ~portfolio_value:100_000.0 ~current_date cand
    with
    | Some pair -> pair
    | None -> OUnit2.assert_failure "make_entry_transition returned None"
  in
  let _, meta = trans_and_meta in
  let macro : Macro.result =
    {
      index_stage = _stage_result;
      indicators = [];
      trend = Weinstein_types.Bullish;
      confidence = 0.80;
      regime_changed = false;
      rationale = [ "fixture" ];
    }
  in
  let event =
    Entry_audit_capture.build_entry_event ~macro ~current_date ~candidate:cand
      ~meta ~alternatives:[]
  in
  let expected_position_value =
    Float.of_int meta.shares *. meta.effective_entry_price
  in
  let expected_risk_dollars =
    Float.of_int meta.shares
    *. Float.abs (meta.effective_entry_price -. meta.installed_stop)
  in
  assert_that event
    (all_of
       [
         (* Realised-entry-anchored dollar fields. *)
         field
           (fun e -> e.Audit_recorder.initial_position_value)
           (float_equal expected_position_value);
         field
           (fun e -> e.Audit_recorder.initial_risk_dollars)
           (float_equal expected_risk_dollars);
         (* Candidate is passed through verbatim — screener intent preserved. *)
         field
           (fun e -> e.Audit_recorder.candidate.Screener.suggested_entry)
           (float_equal 130.0);
         (* Position-state shares + stop come from [meta]. *)
         field (fun e -> e.Audit_recorder.shares) (equal_to meta.shares);
         field
           (fun e -> e.Audit_recorder.installed_stop)
           (float_equal meta.installed_stop);
       ])

(** When [bar_reader] has no bars for the candidate's ticker (e.g., a test
    fixture that didn't pre-populate a panel for it), [_effective_entry_price]
    falls back to [cand.suggested_entry]. The fallback path must keep the
    pre-G14 behaviour bit-equivalent so tests / synthetic fixtures that don't
    seed bars still drive deterministic entry construction. *)
let test_empty_bar_reader_falls_back_to_suggested_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader = Bar_reader.empty () in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) ->
            m.effective_entry_price)
          (float_equal 130.0)))

let () =
  run_test_tt_main
    ("entry_audit_capture"
    >::: [
           "G14: effective_entry overrides cand.suggested_entry"
           >:: test_effective_entry_overrides_suggested_entry;
           "G14: build_entry_event audit dollars use effective_entry"
           >:: test_entry_event_audit_dollars_use_effective_entry;
           "G14: empty bar_reader falls back to suggested_entry"
           >:: test_empty_bar_reader_falls_back_to_suggested_entry;
         ])
