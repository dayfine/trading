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
module TL = Backtest.Ticket_lifecycle
module AR = Weinstein_strategy.Audit_recorder

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s
let _current_date = _date "2024-06-14"

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    (* Distinct from every other price in the fixture ([suggested_entry] =
       100.0, [close_at_decision] = 99.0, [installed_stop] = 92.0) so a
       mis-wire of [entry_decision.ma_value] to any of them fails the pin. *)
    ma_value = 97.5;
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
    range_top_freshness = None;
    require_breakout_volume = true;
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

let _no_triple_confirmation :
    Weinstein_strategy.Entry_ticket_tags.triple_confirmation =
  {
    breakout_volume_multiple = None;
    rs_zero_cross = false;
    in_base_advance_pct = None;
  }

let _entry_event ?(candidate = _candidate) ?(sized_down_wide_stop = false)
    ?(freshness_basis = Weinstein_strategy.Entry_freshness.Ma_cross)
    ?(triple_confirmation = _no_triple_confirmation) ~split_safe_basis
    ~stop_floor_kind () : AR.entry_event =
  {
    position_id = "ZZZZ-wein-1";
    candidate;
    macro = _macro;
    current_date = _current_date;
    close_at_decision = Some 99.0;
    installed_stop = 92.0;
    stop_floor_kind;
    split_safe_basis;
    shares = 100;
    initial_position_value = 10_000.0;
    initial_risk_dollars = 800.0;
    sized_down_wide_stop;
    freshness_basis;
    triple_confirmation;
    alternatives = [];
  }

(** Drive one [entry_event] through the real recorder bundle and read back the
    single [entry_decision] the collector holds. Goes through [of_collector] /
    [record_entry] rather than calling the private projection directly, so the
    wiring inside the bundle is exercised too. *)
let _recorded_entry_of (event : AR.entry_event) =
  let trade_audit = TA.create () in
  let recorder =
    Backtest.Trade_audit_recorder.of_collector ~trade_audit
      ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
  in
  recorder.record_entry event;
  match TA.get_audit_records trade_audit with
  | [ r ] -> r.TA.entry
  | records ->
      OUnit2.assert_failure
        (Printf.sprintf "expected exactly 1 audit record, got %d"
           (List.length records))

let _recorded_entry ~split_safe_basis ~stop_floor_kind =
  _recorded_entry_of (_entry_event ~split_safe_basis ~stop_floor_kind ())

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** B1 sink-hop pin (hop 2 of 2). Each [AR.split_safe_basis] must project to its
    [TA] counterpart. Driving all three constructors — not just the [Flag_off]
    default — is what makes hardcoding any single value at this hop fail. *)
let test_split_safe_basis_projects_all_three_states _ =
  let projected =
    [ AR.Flag_off; AR.Adjusted; AR.Raw_fallback; AR.Empty_window ]
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
         equal_to (TA.Empty_window : TA.split_safe_basis);
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

(** E-provenance fields (entry-ticket right-basis plan 2026-08-08):
    [close_at_decision] must pass through from the event verbatim, [ma_value]
    must be read off the candidate's stage analysis (the fixture's
    [_stage_result.ma_value = 97.5], distinct from every other fixture price so
    a mis-wire cannot pass), and [local_range_top] mirrors the candidate's
    analysis field — [None] here because the fixture leaves the local-anchor
    knob off. Non-default values, same reason as the enum pins: a hardcoded
    [None]/constant at this hop must fail. *)
let test_entry_projection_carries_e_provenance_fields _ =
  assert_that
    (_recorded_entry ~split_safe_basis:AR.Flag_off
       ~stop_floor_kind:AR.Buffer_fallback)
    (all_of
       [
         field
           (fun (e : TA.entry_decision) -> e.close_at_decision)
           (is_some_and (float_equal 99.0));
         field
           (fun (e : TA.entry_decision) -> e.ma_value)
           (is_some_and (float_equal 97.5));
         field (fun (e : TA.entry_decision) -> e.local_range_top) is_none;
       ])

(** When the candidate's analysis carries an armed [local_range_top], the
    projection must surface it — pins the [Some] side of the mirror the test
    above pins the [None] side of. *)
let test_entry_projection_carries_armed_local_range_top _ =
  let candidate =
    {
      _candidate with
      analysis = { _stock_analysis with local_range_top = Some 105.0 };
    }
  in
  assert_that
    (_recorded_entry_of
       (_entry_event ~candidate ~split_safe_basis:AR.Flag_off
          ~stop_floor_kind:AR.Buffer_fallback ()))
    (field
       (fun (e : TA.entry_decision) -> e.local_range_top)
       (is_some_and (float_equal 105.0)))

(* PR-5 ticket-lifecycle projection -------------------------------------- *)

(** The placement-time half of the lifecycle: the placement date is the tick the
    event was captured on, the F3 tag and the F1 basis pass through, and the F6
    §4.5 measurements are copied field-for-field. All three resolution fields
    are [None] on a freshly-recorded row — they are merged in later, not
    fabricated here. *)
let test_entry_projection_carries_placement_time_lifecycle _ =
  assert_that
    (_recorded_entry_of
       (_entry_event ~sized_down_wide_stop:true
          ~freshness_basis:Weinstein_strategy.Entry_freshness.Range_top_breakout
          ~triple_confirmation:
            {
              breakout_volume_multiple = Some 3.1;
              rs_zero_cross = true;
              in_base_advance_pct = Some 0.62;
            }
          ~split_safe_basis:AR.Flag_off ~stop_floor_kind:AR.Buffer_fallback ()))
    (field
       (fun (e : TA.entry_decision) -> e.ticket_lifecycle)
       (is_some_and
          (all_of
             [
               field
                 (fun (l : TL.t) -> l.placement_date)
                 (equal_to _current_date);
               field (fun (l : TL.t) -> l.sized_down_wide_stop) (equal_to true);
               field
                 (fun (l : TL.t) -> l.freshness_basis)
                 (equal_to (TL.Range_top_breakout : TL.entry_freshness_basis));
               field
                 (fun (l : TL.t) -> l.triple_confirmation)
                 (equal_to
                    ({
                       breakout_volume_multiple = Some 3.1;
                       rs_zero_cross = true;
                       in_base_advance_pct = Some 0.62;
                     }
                      : TL.triple_confirmation));
               field (fun (l : TL.t) -> l.fill_volume) is_none;
               field (fun (l : TL.t) -> l.ticket_age_weeks_at_cancel) is_none;
               field (fun (l : TL.t) -> l.ticket_age_weeks_at_fill) is_none;
             ])))

(** The default no-op shape: an unarmed run records [Ma_cross] and an untagged
    stop. Driving both basis constructors is what makes hardcoding either at
    this hop fail. *)
let test_entry_projection_defaults_to_ma_cross_and_untagged _ =
  assert_that
    (_recorded_entry_of
       (_entry_event ~split_safe_basis:AR.Flag_off
          ~stop_floor_kind:AR.Buffer_fallback ()))
    (field
       (fun (e : TA.entry_decision) -> e.ticket_lifecycle)
       (is_some_and
          (all_of
             [
               field
                 (fun (l : TL.t) -> l.freshness_basis)
                 (equal_to (TL.Ma_cross : TL.entry_freshness_basis));
               field (fun (l : TL.t) -> l.sized_down_wide_stop) (equal_to false);
             ])))

(** Sink-hop pin for the F5 record: every {!Volume.breakout_confirmation}
    constructor — plus the [None] no-verdict case — and every
    {!AR.fill_volume_outcome} must reach its [TA] counterpart. A value dropped
    here is invisible in [trade_audit.sexp]. Each row pairs a distinct verdict
    with a distinct outcome, so a hop that mixed the two up (or hardcoded
    either) fails. *)
let test_fill_volume_projects_every_verdict_class _ =
  let recorded (confirmation, outcome) =
    let trade_audit = TA.create () in
    let recorder =
      Backtest.Trade_audit_recorder.of_collector ~trade_audit
        ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
    in
    recorder.record_entry
      (_entry_event ~split_safe_basis:AR.Flag_off
         ~stop_floor_kind:AR.Buffer_fallback ());
    recorder.record_fill_volume
      { AR.position_id = "ZZZZ-wein-1"; confirmation; outcome };
    match TA.get_audit_records trade_audit with
    | [ r ] ->
        Option.bind r.TA.entry.ticket_lifecycle ~f:(fun l -> l.fill_volume)
    | records ->
        OUnit2.assert_failure
          (Printf.sprintf "expected exactly 1 audit record, got %d"
             (List.length records))
  in
  let check verdict outcome : TL.fill_volume_check = { verdict; outcome } in
  assert_that
    (List.map ~f:recorded
       [
         (Some (Volume.Spike 3.4), AR.Held);
         (Some (Volume.Buildup 2.2), AR.Held);
         ( Some
             (Volume.Unconfirmed
                { spike_ratio = Some 1.1; buildup_multiple = None }),
           AR.Ejected );
         ( Some
             (Volume.Unconfirmed
                { spike_ratio = None; buildup_multiple = Some 1.2 }),
           AR.Skipped_other_exit );
         (None, AR.Held);
       ])
    (elements_are
       [
         is_some_and (equal_to (check (TL.Confirmed_spike 3.4) TL.Held));
         is_some_and (equal_to (check (TL.Confirmed_buildup 2.2) TL.Held));
         is_some_and
           (equal_to
              (check
                 (TL.Unconfirmed
                    { spike_ratio = Some 1.1; buildup_multiple = None })
                 TL.Ejected));
         is_some_and
           (equal_to
              (check
                 (TL.Unconfirmed
                    { spike_ratio = None; buildup_multiple = Some 1.2 })
                 TL.Skipped_other_exit));
         is_some_and (equal_to (check TL.No_verdict TL.Held));
       ])

let suite =
  "Trade_audit_recorder"
  >::: [
         "entry projection carries the placement-time lifecycle"
         >:: test_entry_projection_carries_placement_time_lifecycle;
         "entry projection defaults to Ma_cross and untagged"
         >:: test_entry_projection_defaults_to_ma_cross_and_untagged;
         "fill_volume projects every verdict class"
         >:: test_fill_volume_projects_every_verdict_class;
         "split_safe_basis projects all three states"
         >:: test_split_safe_basis_projects_all_three_states;
         "stop_floor_kind projects both states"
         >:: test_stop_floor_kind_projects_both_states;
         "entry projection carries identifying fields"
         >:: test_entry_projection_carries_identifying_fields;
         "entry projection carries E-provenance fields"
         >:: test_entry_projection_carries_e_provenance_fields;
         "entry projection carries armed local_range_top"
         >:: test_entry_projection_carries_armed_local_range_top;
       ]

let () = run_test_tt_main suite
