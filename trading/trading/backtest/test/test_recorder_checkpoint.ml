(** Checkpoint capture/restore of the four backtest recorders (#3477 PR 5).

    Each recorder is fed events up to a pause and captured. The live recorder
    then takes the rest; so does one restored in memory and one restored through
    sexp text. All three must observe the same output, which also fails if a
    snapshot shares mutable state with the live recorder. *)

open OUnit2
open Core
open Matchers
module SL = Backtest.Stop_log
module TA = Backtest.Trade_audit
module FL = Backtest.Force_liquidation_log
module CL = Backtest.Candidate_log
module Position = Trading_strategy.Position

let _date = Date.of_string

(* Runs [head], captures, then [tail] on the live recorder, on an in-memory
   restore, and on a restore of the snapshot's sexp text (taken last, so a
   restore that mutated the snapshot shows too). Returns the live recorder and
   the three observations. *)
let _resume ~create ~capture ~restore ~sexp_of ~of_sexp ~head ~tail ~observe =
  let live = create () in
  head live;
  let snap = capture live in
  tail live;
  let in_memory = restore snap in
  tail in_memory;
  let from_text =
    restore (of_sexp (Sexp.of_string (Sexp.to_string (sexp_of snap))))
  in
  tail from_text;
  (live, (observe live, observe in_memory, observe from_text))

let _same_as_live (obs : Sexp.t * Sexp.t * Sexp.t) =
  let live, _, _ = obs in
  equal_to (live, live, live)

(* Stop_log --------------------------------------------------------------- *)

let _tr position_id kind : Position.transition =
  { position_id; date = _date "2024-01-15"; kind }

let _stop level : Position.risk_params =
  {
    stop_loss_price = Some level;
    take_profit_price = None;
    max_hold_days = None;
  }

let _raise_to level =
  _tr "AAA-wein-1" (UpdateRiskParams { new_risk_params = _stop level })

let _stop_head log =
  SL.record_transitions log
    [
      _tr "AAA-wein-1"
        (CreateEntering
           {
             symbol = "AAA";
             side = Trading_base.Types.Long;
             target_quantity = 10.0;
             entry_price = 100.0;
             reasoning = ManualDecision { description = "test" };
           });
      _tr "AAA-wein-1" (EntryComplete { risk_params = _stop 90.0 });
      _raise_to 92.0;
    ]

let _stop_tail log =
  SL.record_transitions log
    [
      _raise_to 95.0;
      _raise_to 97.0;
      _tr "AAA-wein-1"
        (TriggerExit
           {
             exit_reason =
               StopLoss
                 { stop_price = 97.0; actual_price = 96.0; loss_percent = -4.0 };
             exit_price = 96.0;
           });
    ]

let test_stop_log _ =
  let live, obs =
    _resume ~create:SL.create ~capture:SL.capture ~restore:SL.restore
      ~sexp_of:SL.sexp_of_snapshot ~of_sexp:SL.snapshot_of_sexp ~head:_stop_head
      ~tail:_stop_tail ~observe:(fun l ->
        [%sexp_of: SL.stop_info list] (SL.get_stop_infos l))
  in
  assert_that obs (_same_as_live obs);
  assert_that (SL.get_stop_infos live)
    (elements_are
       [
         all_of
           [
             field
               (fun (i : SL.stop_info) -> i.max_stop)
               (is_some_and (float_equal 97.0));
             field (fun (i : SL.stop_info) -> i.n_stop_raises) (equal_to 3);
             field
               (fun (i : SL.stop_info) -> i.exit_trigger)
               (is_some_and (fun _ -> ()));
           ];
       ])

(* Trade_audit ------------------------------------------------------------ *)

let _entry position_id symbol : TA.entry_decision =
  {
    symbol;
    entry_date = _date "2024-01-05";
    position_id;
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.7;
    macro_indicators = [];
    stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false };
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.02;
    rs_trend = None;
    rs_value = Some 1.05;
    volume_quality = None;
    volume_ratio = Some 2.4;
    resistance_quality = None;
    support_quality = None;
    sector_name = "Tech";
    sector_rating = Screener.Strong;
    cascade_score = 75;
    cascade_grade = Weinstein_types.A;
    cascade_score_components = [ ("stage2", 30) ];
    cascade_rationale = [ "breakout" ];
    side = Trading_base.Types.Long;
    suggested_entry = 150.5;
    close_at_decision = None;
    adjusted_close_at_decision = None;
    ma_value = None;
    local_range_top = None;
    screener_proxy_stop = 138.0;
    installed_stop = 138.0;
    stop_floor_kind = TA.Buffer_fallback;
    split_safe_basis = TA.Flag_off;
    risk_pct = 0.08;
    initial_position_value = 75_000.0;
    initial_risk_dollars = 6_000.0;
    ticket_lifecycle = None;
    alternatives_considered = [];
  }

let _summary date entered : TA.cascade_summary =
  {
    date = _date date;
    total_stocks = 20;
    candidates_after_held = 18;
    macro_trend = Weinstein_types.Bullish;
    breadth_state = Weinstein_types.Neutral_breadth;
    long_macro_admitted = 18;
    long_breakout_admitted = 5;
    long_sector_admitted = 5;
    long_grade_admitted = 3;
    long_top_n_admitted = 3;
    short_macro_admitted = 0;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
    entered;
    decisions = [];
  }

let _decision date position_id ~before ~after : Weinstein_stops.Stop_decision.t
    =
  {
    date = _date date;
    position_id;
    state_before = Trailing;
    state_after = Trailing;
    stop_before = before;
    stop_after = after;
    candidate = Some after;
    correction_count_before = 0;
    correction_count = 1;
    last_trend_extreme = None;
    last_correction_extreme = None;
    ma_value = 120.0;
    reason = Raised;
    tighten_trigger = None;
  }

let _audit_head t =
  TA.record_entry t (_entry "AAA-wein-1" "AAA");
  TA.record_entry t (_entry "BBB-wein-2" "BBB");
  TA.record_cascade_summary t (_summary "2024-01-05" 2);
  TA.record_cascade_summary t (_summary "2024-01-05" 1);
  TA.record_stop_decision t
    (_decision "2024-01-12" "AAA-wein-1" ~before:138.0 ~after:140.0)

let _audit_tail t =
  TA.record_stop_decision t
    (_decision "2024-01-19" "AAA-wein-1" ~before:140.0 ~after:145.0);
  TA.record_cascade_summary t (_summary "2024-01-05" 0);
  TA.record_transitions t
    [
      _tr "AAA-wein-1"
        (TriggerExit
           {
             exit_reason =
               StrategySignal { label = "margin_call"; detail = None };
             exit_price = 130.0;
           });
      _tr "BBB-wein-2" (CancelEntry { reason = "entry_ticket_ttl_expired" });
    ];
  ignore
    (TA.record_reissue t ~position_id:"BBB-wein-3"
       ~original_position_id:"BBB-wein-2" ~reissue_date:(_date "2024-02-02")
      : TA.entry_decision option)

let test_trade_audit _ =
  let live, obs =
    _resume ~create:TA.create ~capture:TA.capture ~restore:TA.restore
      ~sexp_of:TA.sexp_of_snapshot ~of_sexp:TA.snapshot_of_sexp
      ~head:_audit_head ~tail:_audit_tail ~observe:(fun t ->
        TA.sexp_of_audit_blob (TA.get_audit_blob t))
  in
  assert_that obs (_same_as_live obs);
  assert_that (TA.get_audit_blob live)
    (all_of
       [
         field (fun (b : TA.audit_blob) -> b.audit_records) (size_is 3);
         field
           (fun (b : TA.audit_blob) ->
             List.map b.cascade_summaries ~f:(fun s -> s.entered))
           (equal_to [ 2; 1; 0 ]);
       ])

(* Force_liquidation_log -------------------------------------------------- *)

let _fl_event date price : Portfolio_risk.Force_liquidation.event =
  {
    symbol = "AAA";
    position_id = "AAA-wein-1";
    date = _date date;
    side = Trading_base.Types.Long;
    entry_price = 100.0;
    current_price = price;
    quantity = 10.0;
    cost_basis = 1000.0;
    unrealized_pnl = (price -. 100.0) *. 10.0;
    unrealized_pnl_pct = (price -. 100.0) /. 100.0;
    reason = Per_position;
  }

let test_force_liquidation_log _ =
  let live, obs =
    _resume ~create:FL.create ~capture:FL.capture ~restore:FL.restore
      ~sexp_of:FL.sexp_of_snapshot ~of_sexp:FL.snapshot_of_sexp
      ~head:(fun l ->
        FL.record l (_fl_event "2024-01-10" 60.0);
        FL.record l (_fl_event "2024-01-11" 50.0);
        FL.record l (_fl_event "2024-01-11" 45.0))
      ~tail:(fun l -> FL.record l (_fl_event "2024-01-11" 40.0))
      ~observe:(fun l ->
        [%sexp_of: Portfolio_risk.Force_liquidation.event list] (FL.events l))
  in
  assert_that obs (_same_as_live obs);
  assert_that (FL.events live)
    (elements_are
       (List.map [ 60.0; 50.0; 45.0; 40.0 ] ~f:(fun p ->
            field
              (fun (e : Portfolio_risk.Force_liquidation.event) ->
                e.current_price)
              (float_equal p))))

(* Candidate_log ---------------------------------------------------------- *)

let _week date : CL.week =
  {
    date = _date date;
    candidates =
      [
        {
          symbol = "AAA";
          side = Trading_base.Types.Long;
          outcome = CL.Admitted;
          breakout_gate = None;
          signals =
            {
              score = 70;
              grade = Weinstein_types.B;
              stage =
                Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
              weeks_advancing = Some 3;
              rs_value = None;
              volume_ratio = None;
              sector_name = "Tech";
            };
        };
      ];
  }

let test_candidate_log _ =
  let live, obs =
    _resume ~create:CL.create ~capture:CL.capture ~restore:CL.restore
      ~sexp_of:CL.sexp_of_snapshot ~of_sexp:CL.snapshot_of_sexp
      ~head:(fun c ->
        CL.record c (_week "2024-01-05");
        CL.record c (_week "2024-01-12"))
      ~tail:(fun c -> CL.record c (_week "2024-01-19"))
      ~observe:(fun c -> [%sexp_of: CL.week list] (CL.weeks c))
  in
  assert_that obs (_same_as_live obs);
  assert_that (CL.weeks live)
    (elements_are
       (List.map [ "2024-01-05"; "2024-01-12"; "2024-01-19" ] ~f:(fun d ->
            field (fun (w : CL.week) -> w.date) (equal_to (_date d)))))

let suite =
  "recorder_checkpoint"
  >::: [
         "stop_log" >:: test_stop_log;
         "trade_audit" >:: test_trade_audit;
         "force_liquidation_log" >:: test_force_liquidation_log;
         "candidate_log" >:: test_candidate_log;
       ]

let () = run_test_tt_main suite
