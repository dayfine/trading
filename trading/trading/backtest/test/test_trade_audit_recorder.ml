(** Tests for {!Backtest.Trade_audit_recorder} — the strategy-event ->
    [Trade_audit] projection.

    This module had no test at all before 2026-08-06. That gap was load-bearing
    rather than cosmetic: [of_collector]'s [record_entry] is the {b last} hop
    between an [Audit_recorder.entry_event] and the [trade_audit.sexp] a
    walk-forward run reads, so a field dropped here is invisible in every other
    suite. It was found by mutating [_entry_decision_of_event] to hardcode
    [split_safe_basis = Flag_off]: the full-repo [dune runtest] stayed at exit 0
    while every audit row in a [split_safe_floors true] arm would have read
    [Flag_off], making the inert fraction evaluate 0/0.

    The tests below pin the projection for the fields whose {e value} (not mere
    presence) the audit consumer depends on. They deliberately drive non-default
    enum values — a fixture that only exercises the default cannot tell
    "projected" from "constant". *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module AR = Weinstein_strategy.Audit_recorder

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s
let _current_date = _date "2024-06-14"

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis : Stock_analysis.t =
  {
    ticker = "ZZZZ";
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    local_range_top = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission = false;
    current_close = None;
    as_of_date = _current_date;
  }

let _candidate : Screener.scored_candidate =
  {
    ticker = "ZZZZ";
    analysis = _stock_analysis;
    sector =
      {
        sector_name = "Test";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
      };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 100.0;
    suggested_stop = 92.0;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _macro : Macro.result =
  {
    index_stage = _stage_result;
    indicators = [];
    trend = Weinstein_types.Bullish;
    confidence = 0.8;
    regime_changed = false;
    rationale = [ "fixture" ];
  }

let _entry_event ~split_safe_basis ~stop_floor_kind : AR.entry_event =
  {
    position_id = "ZZZZ-wein-1";
    candidate = _candidate;
    macro = _macro;
    current_date = _current_date;
    installed_stop = 92.0;
    stop_floor_kind;
    split_safe_basis;
    shares = 100;
    initial_position_value = 10_000.0;
    initial_risk_dollars = 800.0;
    alternatives = [];
  }

(** Drive one [entry_event] through the real recorder bundle and read back the
    single [entry_decision] the collector holds. Goes through [of_collector] /
    [record_entry] rather than calling the private projection directly, so the
    wiring inside the bundle is exercised too. *)
let _recorded_entry ~split_safe_basis ~stop_floor_kind =
  let trade_audit = TA.create () in
  let recorder =
    Backtest.Trade_audit_recorder.of_collector ~trade_audit
      ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
  in
  recorder.record_entry (_entry_event ~split_safe_basis ~stop_floor_kind);
  match TA.get_audit_records trade_audit with
  | [ r ] -> r.TA.entry
  | records ->
      OUnit2.assert_failure
        (Printf.sprintf "expected exactly 1 audit record, got %d"
           (List.length records))

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** B1 sink-hop pin (hop 2 of 2). Each [AR.split_safe_basis] must project to its
    [TA] counterpart. Driving all three constructors — not just the [Flag_off]
    default — is what makes hardcoding any single value at this hop fail. *)
let test_split_safe_basis_projects_all_three_states _ =
  let projected =
    [ AR.Flag_off; AR.Adjusted; AR.Raw_fallback ]
    |> List.map ~f:(fun split_safe_basis ->
        (_recorded_entry ~split_safe_basis ~stop_floor_kind:AR.Buffer_fallback)
          .TA.split_safe_basis)
  in
  assert_that projected
    (elements_are
       [
         equal_to (TA.Flag_off : TA.split_safe_basis);
         equal_to (TA.Adjusted : TA.split_safe_basis);
         equal_to (TA.Raw_fallback : TA.split_safe_basis);
       ])

(** The sibling tag on the same hop, pinned for the same reason: both
    constructors, both directions. *)
let test_stop_floor_kind_projects_both_states _ =
  let projected =
    [ AR.Support_floor; AR.Buffer_fallback ]
    |> List.map ~f:(fun stop_floor_kind ->
        (_recorded_entry ~split_safe_basis:AR.Flag_off ~stop_floor_kind)
          .TA.stop_floor_kind)
  in
  assert_that projected
    (elements_are
       [
         equal_to (TA.Support_floor : TA.stop_floor_kind);
         equal_to (TA.Buffer_fallback : TA.stop_floor_kind);
       ])

(** Sanity pin on the rest of the projection so the two enum tests above are not
    the module's only coverage: the identifying + dollar fields the audit
    consumer keys off must survive the hop unchanged. *)
let test_entry_projection_carries_identifying_fields _ =
  assert_that
    (_recorded_entry ~split_safe_basis:AR.Adjusted
       ~stop_floor_kind:AR.Support_floor)
    (all_of
       [
         field (fun (e : TA.entry_decision) -> e.symbol) (equal_to "ZZZZ");
         field
           (fun (e : TA.entry_decision) -> e.position_id)
           (equal_to "ZZZZ-wein-1");
         field
           (fun (e : TA.entry_decision) -> e.entry_date)
           (equal_to _current_date);
         field
           (fun (e : TA.entry_decision) -> e.installed_stop)
           (float_equal 92.0);
         field
           (fun (e : TA.entry_decision) -> e.initial_risk_dollars)
           (float_equal 800.0);
       ])

let suite =
  "Trade_audit_recorder"
  >::: [
         "split_safe_basis projects all three states"
         >:: test_split_safe_basis_projects_all_three_states;
         "stop_floor_kind projects both states"
         >:: test_stop_floor_kind_projects_both_states;
         "entry projection carries identifying fields"
         >:: test_entry_projection_carries_identifying_fields;
       ]

let () = run_test_tt_main suite
