(** Unit tests for [Backtest.Trade_audit].

    Covers:
    - sexp round-trip on every record type
    - collector accumulates correctly across record_entry / record_exit
    - exits are dropped when no matching entry was recorded
    - get_audit_records returns position-id-sorted output
    - empty collector returns []
    - [record_transitions] (issue #2076): reason-only [external_exit] capture
      for [TriggerExit]s that never go through the strategy's own [record_exit]
      path (margin exits, and other [StrategySignal] exits) — enriched [exit_]
      always wins, no-entry transitions are dropped, and only [TriggerExit] (not
      [TriggerPartialExit]) is handled. *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module Position = Trading_strategy.Position

(* Builders --------------------------------------------------------------- *)

let _date d = Date.of_string d

(** Minimal but realistic [entry_decision] for round-trip + collector tests.

    Optional parameters allow per-test overrides without forcing every test to
    write a 30-field literal — keeps the assertions focused on the field(s) each
    test actually cares about. *)
let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(macro_trend = Weinstein_types.Bullish) ?(macro_confidence = 0.72)
    ?(macro_indicators = [])
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(ma_direction = Weinstein_types.Rising) ?(ma_slope_pct = 0.018)
    ?(rs_trend = Some Weinstein_types.Positive_rising) ?(rs_value = Some 1.05)
    ?(volume_quality = Some (Weinstein_types.Strong 2.4))
    ?(volume_ratio = Some 2.4)
    ?(resistance_quality = Some Weinstein_types.Clean)
    ?(support_quality = Some Weinstein_types.Clean)
    ?(sector_name = "Information Technology") ?(sector_rating = Screener.Strong)
    ?(cascade_score = 75) ?(cascade_grade = Weinstein_types.A)
    ?(cascade_score_components =
      [
        ("stage2_breakout", 30);
        ("strong_volume", 20);
        ("positive_rs", 20);
        ("clean_resistance", 15);
        ("sector_strong", 10);
      ]) ?(cascade_rationale = [ "Stage2 breakout"; "RS positive rising" ])
    ?(suggested_entry = 150.50) ?(suggested_stop = 138.46)
    ?(installed_stop = 138.46) ?(stop_floor_kind = TA.Buffer_fallback)
    ?(split_safe_basis = TA.Flag_off) ?(risk_pct = 0.08)
    ?(initial_position_value = 75_000.0) ?(initial_risk_dollars = 6_000.0)
    ?(alternatives_considered = []) () : TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend;
    macro_confidence;
    macro_indicators;
    stage;
    ma_direction;
    ma_slope_pct;
    rs_trend;
    rs_value;
    volume_quality;
    volume_ratio;
    resistance_quality;
    support_quality;
    sector_name;
    sector_rating;
    cascade_score;
    cascade_grade;
    cascade_score_components;
    cascade_rationale;
    side;
    suggested_entry;
    suggested_stop;
    installed_stop;
    stop_floor_kind;
    split_safe_basis;
    risk_pct;
    initial_position_value;
    initial_risk_dollars;
    alternatives_considered;
  }

let make_exit ?(symbol = "AAPL") ?(exit_date = _date "2024-04-20")
    ?(position_id = "AAPL-wein-1")
    ?(exit_trigger =
      Backtest.Stop_log.Stop_loss { stop_price = 138.46; actual_price = 137.20 })
    ?(macro_trend_at_exit = Weinstein_types.Neutral)
    ?(macro_confidence_at_exit = 0.45)
    ?(stage_at_exit = Weinstein_types.Stage3 { weeks_topping = 2 })
    ?(rs_trend_at_exit = Some Weinstein_types.Positive_flat)
    ?(distance_from_ma_pct = -0.025) ?(max_favorable_excursion_pct = 0.082)
    ?(max_adverse_excursion_pct = -0.085) ?(weeks_macro_was_bearish = 0)
    ?(weeks_stage_left_2 = 1) () : TA.exit_decision =
  {
    symbol;
    exit_date;
    position_id;
    exit_trigger;
    macro_trend_at_exit;
    macro_confidence_at_exit;
    stage_at_exit;
    rs_trend_at_exit;
    distance_from_ma_pct;
    max_favorable_excursion_pct;
    max_adverse_excursion_pct;
    weeks_macro_was_bearish;
    weeks_stage_left_2;
  }

let _alt ~symbol ~score ~grade ~reason
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false })
    ?(weeks_advancing = Some 3) ?(rs_value = Some 1.02)
    ?(volume_ratio = Some 1.8) ?(sector_name = "Information Technology")
    ?(score_components = []) () : TA.alternative_candidate =
  {
    symbol;
    side = Trading_base.Types.Long;
    score;
    grade;
    reason_skipped = reason;
    stage;
    weeks_advancing;
    rs_value;
    volume_ratio;
    sector_name;
    score_components;
  }

(** A [TriggerExit] transition carrying a [StrategySignal] exit reason — what
    margin exits ([margin_call] / [buyin_stress] / [maintenance_reduce]) and the
    other externally-generated [StrategySignal] exits ([stage3_force_exit],
    [laggard_rotation], ...) look like on the [Position.transition] list
    [record_transitions] observes. *)
let _strategy_signal_trigger_exit ?(position_id = "AAPL-wein-1")
    ?(date = _date "2024-04-20") ?(label = "margin_call") ?(detail = None)
    ?(exit_price = 137.20) () : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.TriggerExit
        { exit_reason = Position.StrategySignal { label; detail }; exit_price };
  }

(** A [TriggerPartialExit] transition carrying a [StrategySignal] exit reason —
    what a partial trim (e.g. [harvest_rotate]) looks like on the
    [Position.transition] list [record_transitions] observes. Structurally
    adjacent to {!_strategy_signal_trigger_exit} (same [exit_reason] shape)
    except for [kind], so it genuinely discriminates [record_transitions]'s
    "only [TriggerExit], not [TriggerPartialExit]" behavior — unlike
    [UpdateRiskParams], which has no [exit_reason] field at all. *)
let _strategy_signal_trigger_partial_exit ?(position_id = "AAPL-wein-1")
    ?(date = _date "2024-04-20") ?(label = "harvest_rotate") ?(detail = None)
    ?(exit_price = 137.20) ?(target_quantity = 50.0) () : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.TriggerPartialExit
        {
          exit_reason = Position.StrategySignal { label; detail };
          exit_price;
          target_quantity;
        };
  }

(* Sexp round-trip ------------------------------------------------------- *)

let test_skip_reason_sexp_round_trip _ =
  let all : TA.skip_reason list =
    [
      Insufficient_cash;
      Already_held;
      Below_min_grade;
      Sized_to_zero;
      Sector_concentration;
      Top_n_cutoff;
    ]
  in
  let parsed =
    List.map all ~f:(fun r -> TA.skip_reason_of_sexp (TA.sexp_of_skip_reason r))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

let test_stop_floor_kind_sexp_round_trip _ =
  let all : TA.stop_floor_kind list = [ Support_floor; Buffer_fallback ] in
  let parsed =
    List.map all ~f:(fun k ->
        TA.stop_floor_kind_of_sexp (TA.sexp_of_stop_floor_kind k))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

let test_split_safe_basis_sexp_round_trip _ =
  let all : TA.split_safe_basis list = [ Flag_off; Adjusted; Raw_fallback ] in
  let parsed =
    List.map all ~f:(fun b ->
        TA.split_safe_basis_of_sexp (TA.sexp_of_split_safe_basis b))
  in
  assert_that parsed (elements_are (List.map all ~f:equal_to))

(* [split_safe_basis] is [\[@sexp.default Flag_off\]] so that [trade_audit.sexp]
   files written before the field existed stay readable — they are read back by
   [Optimal_run_artefacts], [Validator_report] and [Trade_audit_report]. Drop the
   field from a serialized row and the parse must still succeed, defaulting to
   [Flag_off] (which is the truth for any run predating the field). *)
let test_entry_decision_sexp_tolerates_missing_split_safe_basis _ =
  let entry = make_entry ~split_safe_basis:TA.Raw_fallback () in
  let stripped =
    match TA.sexp_of_entry_decision entry with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "split_safe_basis" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (TA.entry_decision_of_sexp stripped)
    (equal_to (make_entry ~split_safe_basis:TA.Flag_off () : TA.entry_decision))

let test_alternative_candidate_sexp_round_trip _ =
  (* Exercise the enriched decision-time fields (stage / weeks_advancing /
     rs_value / volume_ratio / sector_name / score_components) through the
     codec, not just the score+grade+reason base. *)
  let alt =
    _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
      ~reason:TA.Insufficient_cash
      ~stage:(Weinstein_types.Stage2 { weeks_advancing = 6; late = true })
      ~weeks_advancing:(Some 6) ~rs_value:(Some 0.94) ~volume_ratio:(Some 2.1)
      ~sector_name:"Health Care"
      ~score_components:[ ("stage2_breakout", 30); ("strong_volume", 20) ]
      ()
  in
  let parsed =
    TA.alternative_candidate_of_sexp (TA.sexp_of_alternative_candidate alt)
  in
  assert_that parsed (equal_to alt)

let test_entry_decision_sexp_round_trip _ =
  let entry =
    make_entry
      ~alternatives_considered:
        [
          _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
            ~reason:TA.Insufficient_cash ();
          _alt ~symbol:"NVDA" ~score:55 ~grade:Weinstein_types.B
            ~reason:TA.Sized_to_zero ();
        ]
      ()
  in
  let parsed = TA.entry_decision_of_sexp (TA.sexp_of_entry_decision entry) in
  assert_that parsed (equal_to entry)

let test_exit_decision_sexp_round_trip _ =
  let exit_ = make_exit () in
  let parsed = TA.exit_decision_of_sexp (TA.sexp_of_exit_decision exit_) in
  assert_that parsed (equal_to exit_)

let test_external_exit_decision_sexp_round_trip _ =
  let ext : TA.external_exit_decision =
    {
      symbol = "AAPL";
      exit_date = _date "2024-04-20";
      position_id = "AAPL-wein-1";
      exit_trigger =
        Backtest.Stop_log.Strategy_signal
          { label = "margin_call"; detail = Some "avg_cost=50.00" };
    }
  in
  let parsed =
    TA.external_exit_decision_of_sexp (TA.sexp_of_external_exit_decision ext)
  in
  assert_that parsed (equal_to ext)

let test_audit_record_sexp_round_trip _ =
  let record : TA.audit_record =
    {
      entry = make_entry ();
      exit_ = Some (make_exit ());
      external_exit = None;
      execution = None;
    }
  in
  let parsed = TA.audit_record_of_sexp (TA.sexp_of_audit_record record) in
  assert_that parsed (equal_to record)

let test_audit_records_sexp_round_trip_through_top_level_codec _ =
  let records : TA.audit_record list =
    [
      {
        entry = make_entry ();
        exit_ = Some (make_exit ());
        external_exit = None;
        execution = None;
      };
      {
        entry =
          make_entry ~symbol:"MSFT" ~position_id:"MSFT-wein-1"
            ~entry_date:(_date "2024-02-01") ();
        exit_ = None;
        external_exit = None;
        execution = None;
      };
    ]
  in
  let sexp = TA.sexp_of_audit_records records in
  let parsed = TA.audit_records_of_sexp sexp in
  assert_that parsed (elements_are (List.map records ~f:equal_to))

(* Collector behaviour --------------------------------------------------- *)

let test_empty_collector_returns_empty _ =
  let t = TA.create () in
  assert_that (TA.get_audit_records t) is_empty

let test_record_entry_appears_in_audit _ =
  let t = TA.create () in
  let entry = make_entry () in
  TA.record_entry t entry;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field (fun (r : TA.audit_record) -> r.entry) (equal_to entry);
             field (fun (r : TA.audit_record) -> r.exit_) is_none;
           ];
       ])

let test_record_exit_attaches_to_existing_entry _ =
  let t = TA.create () in
  let entry = make_entry () in
  let exit_ = make_exit () in
  TA.record_entry t entry;
  TA.record_exit t exit_;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field (fun (r : TA.audit_record) -> r.entry) (equal_to entry);
             field
               (fun (r : TA.audit_record) -> r.exit_)
               (is_some_and (equal_to exit_));
           ];
       ])

let test_record_exit_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_exit t (make_exit ~position_id:"ORPHAN-1" ());
  assert_that (TA.get_audit_records t) is_empty

(* record_transitions (#2076) --------------------------------------------- *)

let _external_exit_of t ~position_id =
  TA.get_audit_records t
  |> List.find ~f:(fun (r : TA.audit_record) ->
      String.equal r.entry.position_id position_id)
  |> Option.bind ~f:(fun (r : TA.audit_record) -> r.external_exit)

let test_record_transitions_captures_margin_call_as_external_exit _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [
      _strategy_signal_trigger_exit ~label:"margin_call"
        ~detail:(Some "avg_cost=50.00") ~date:(_date "2024-05-01")
        ~exit_price:65.0 ();
    ];
  assert_that
    (_external_exit_of t ~position_id:"AAPL-wein-1")
    (is_some_and
       (all_of
          [
            field
              (fun (e : TA.external_exit_decision) -> e.symbol)
              (equal_to "AAPL");
            field
              (fun (e : TA.external_exit_decision) -> e.exit_date)
              (equal_to (_date "2024-05-01"));
            field
              (fun (e : TA.external_exit_decision) -> e.position_id)
              (equal_to "AAPL-wein-1");
            field
              (fun (e : TA.external_exit_decision) -> e.exit_trigger)
              (equal_to
                 (Backtest.Stop_log.Strategy_signal
                    { label = "margin_call"; detail = Some "avg_cost=50.00" }));
          ]));
  (* No enriched exit_ was ever recorded — this position's exit is
     reason-only. *)
  assert_that (TA.get_audit_records t)
    (elements_are [ field (fun (r : TA.audit_record) -> r.exit_) is_none ])

(* Extra credit (#2076): the SAME generic path also fixes the other
   [StrategySignal] exit sources that never routed through
   [Weinstein_strategy.Exit_audit_capture] — no per-label special-casing was
   needed to cover [stage3_force_exit] alongside [margin_call]. *)
let test_record_transitions_captures_any_strategy_signal_label _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [ _strategy_signal_trigger_exit ~label:"stage3_force_exit" ~detail:None () ];
  assert_that
    (_external_exit_of t ~position_id:"AAPL-wein-1")
    (is_some_and
       (field
          (fun (e : TA.external_exit_decision) -> e.exit_trigger)
          (equal_to
             (Backtest.Stop_log.Strategy_signal
                { label = "stage3_force_exit"; detail = None }))))

let test_record_transitions_enriched_exit_wins_no_overwrite _ =
  let t = TA.create () in
  let enriched_exit = make_exit () in
  TA.record_entry t (make_entry ());
  TA.record_exit t enriched_exit;
  (* A same-position TriggerExit arriving afterwards (as [on_transitions]
     would, one step later than the strategy's own enriched-path recording)
     must NOT touch [exit_] or populate [external_exit] — enriched always
     wins. *)
  TA.record_transitions t [ _strategy_signal_trigger_exit () ];
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TA.audit_record) -> r.exit_)
               (is_some_and (equal_to enriched_exit));
             field (fun (r : TA.audit_record) -> r.external_exit) is_none;
           ];
       ])

let test_record_transitions_without_entry_is_dropped _ =
  let t = TA.create () in
  TA.record_transitions t
    [ _strategy_signal_trigger_exit ~position_id:"ORPHAN-1" () ];
  assert_that (TA.get_audit_records t) is_empty

let test_record_transitions_ignores_non_trigger_exit_kinds _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  let update_risk_params : Position.transition =
    {
      position_id = "AAPL-wein-1";
      date = _date "2024-04-20";
      kind =
        Position.UpdateRiskParams
          {
            new_risk_params =
              {
                stop_loss_price = Some 145.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  TA.record_transitions t [ update_risk_params ];
  assert_that (_external_exit_of t ~position_id:"AAPL-wein-1") is_none

let test_record_transitions_ignores_partial_exit _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_transitions t
    [
      _strategy_signal_trigger_partial_exit ~label:"harvest_rotate"
        ~target_quantity:50.0 ();
    ];
  (* A partial trim does not close the position, so [record_transitions]
     must not synthesize an [external_exit] for it — confirmed against the
     wildcard match arm in [_process_transition_for_external_exit]. *)
  assert_that (_external_exit_of t ~position_id:"AAPL-wein-1") is_none;
  assert_that (TA.get_audit_records t)
    (elements_are [ field (fun (r : TA.audit_record) -> r.exit_) is_none ])

let test_record_entry_overwrites_same_position_id _ =
  let t = TA.create () in
  let first = make_entry ~cascade_score:50 () in
  let second = make_entry ~cascade_score:80 () in
  TA.record_entry t first;
  TA.record_entry t second;
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.entry.cascade_score)
           (equal_to 80);
       ])

let test_get_audit_records_sorts_by_position_id _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ~position_id:"ZZZ-wein-1" ~symbol:"ZZZ" ());
  TA.record_entry t (make_entry ~position_id:"AAA-wein-1" ~symbol:"AAA" ());
  TA.record_entry t (make_entry ~position_id:"MMM-wein-1" ~symbol:"MMM" ());
  assert_that (TA.get_audit_records t)
    (elements_are
       [
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "AAA-wein-1");
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "MMM-wein-1");
         field
           (fun (r : TA.audit_record) -> r.entry.position_id)
           (equal_to "ZZZ-wein-1");
       ])

let test_collector_round_trips_through_sexp _ =
  let t = TA.create () in
  TA.record_entry t
    (make_entry
       ~alternatives_considered:
         [
           _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
             ~reason:TA.Top_n_cutoff ();
         ]
       ());
  TA.record_exit t (make_exit ());
  TA.record_entry t (make_entry ~symbol:"NVDA" ~position_id:"NVDA-wein-1" ());
  let original = TA.get_audit_records t in
  let parsed = TA.audit_records_of_sexp (TA.sexp_of_audit_records original) in
  assert_that parsed (elements_are (List.map original ~f:equal_to))

(* Cascade summary builders + tests --------------------------------------- *)

(** Minimal but realistic [cascade_summary] builder. Defaults model a typical
    Bullish-macro Friday with modest long-side activity and one entry. *)
let make_cascade_summary ?(date = _date "2024-01-19") ?(total_stocks = 20)
    ?(candidates_after_held = 18) ?(macro_trend = Weinstein_types.Bullish)
    ?(long_macro_admitted = 18) ?(long_breakout_admitted = 5)
    ?(long_sector_admitted = 5) ?(long_grade_admitted = 3)
    ?(long_top_n_admitted = 3) ?(short_macro_admitted = 18)
    ?(short_breakdown_admitted = 0) ?(short_sector_admitted = 0)
    ?(short_rs_hard_gate_admitted = 0) ?(short_grade_admitted = 0)
    ?(short_top_n_admitted = 0) ?(entered = 1) () : TA.cascade_summary =
  {
    date;
    total_stocks;
    candidates_after_held;
    macro_trend;
    long_macro_admitted;
    long_breakout_admitted;
    long_sector_admitted;
    long_grade_admitted;
    long_top_n_admitted;
    short_macro_admitted;
    short_breakdown_admitted;
    short_sector_admitted;
    short_rs_hard_gate_admitted;
    short_grade_admitted;
    short_top_n_admitted;
    entered;
  }

let test_cascade_summary_sexp_round_trip _ =
  let s = make_cascade_summary () in
  let parsed = TA.cascade_summary_of_sexp (TA.sexp_of_cascade_summary s) in
  assert_that parsed (equal_to s)

let test_record_cascade_summary_appears_in_collector _ =
  let t = TA.create () in
  let s = make_cascade_summary () in
  TA.record_cascade_summary t s;
  assert_that (TA.get_cascade_summaries t) (elements_are [ equal_to s ])

let test_get_cascade_summaries_sorts_by_date _ =
  let t = TA.create () in
  let s1 = make_cascade_summary ~date:(_date "2024-03-15") () in
  let s2 = make_cascade_summary ~date:(_date "2024-01-19") () in
  let s3 = make_cascade_summary ~date:(_date "2024-02-09") () in
  TA.record_cascade_summary t s1;
  TA.record_cascade_summary t s2;
  TA.record_cascade_summary t s3;
  assert_that
    (TA.get_cascade_summaries t)
    (elements_are
       [
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-01-19");
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-02-09");
         field
           (fun (s : TA.cascade_summary) -> Date.to_string s.date)
           (equal_to "2024-03-15");
       ])

let test_audit_blob_round_trip _ =
  let t = TA.create () in
  TA.record_entry t (make_entry ());
  TA.record_exit t (make_exit ());
  TA.record_cascade_summary t (make_cascade_summary ());
  TA.record_cascade_summary t
    (make_cascade_summary ~date:(_date "2024-01-26")
       ~macro_trend:Weinstein_types.Bearish ~long_macro_admitted:0
       ~long_breakout_admitted:0 ~long_sector_admitted:0 ~long_grade_admitted:0
       ~long_top_n_admitted:0 ~entered:0 ());
  let blob = TA.get_audit_blob t in
  let parsed = TA.audit_blob_of_sexp (TA.sexp_of_audit_blob blob) in
  assert_that parsed (equal_to blob)

let test_empty_collector_returns_empty_blob _ =
  let t = TA.create () in
  let blob = TA.get_audit_blob t in
  assert_that blob
    (all_of
       [
         field (fun (b : TA.audit_blob) -> b.audit_records) is_empty;
         field (fun (b : TA.audit_blob) -> b.cascade_summaries) is_empty;
       ])

let suite =
  "Trade_audit"
  >::: [
         "skip_reason sexp round-trip" >:: test_skip_reason_sexp_round_trip;
         "stop_floor_kind sexp round-trip"
         >:: test_stop_floor_kind_sexp_round_trip;
         "split_safe_basis sexp round-trip"
         >:: test_split_safe_basis_sexp_round_trip;
         "entry_decision sexp tolerates a missing split_safe_basis"
         >:: test_entry_decision_sexp_tolerates_missing_split_safe_basis;
         "alternative_candidate sexp round-trip"
         >:: test_alternative_candidate_sexp_round_trip;
         "entry_decision sexp round-trip"
         >:: test_entry_decision_sexp_round_trip;
         "exit_decision sexp round-trip" >:: test_exit_decision_sexp_round_trip;
         "external_exit_decision sexp round-trip"
         >:: test_external_exit_decision_sexp_round_trip;
         "audit_record sexp round-trip" >:: test_audit_record_sexp_round_trip;
         "audit_records list sexp round-trip"
         >:: test_audit_records_sexp_round_trip_through_top_level_codec;
         "empty collector returns []" >:: test_empty_collector_returns_empty;
         "record_entry appears in audit" >:: test_record_entry_appears_in_audit;
         "record_exit attaches to existing entry"
         >:: test_record_exit_attaches_to_existing_entry;
         "record_exit without entry is dropped"
         >:: test_record_exit_without_entry_is_dropped;
         "record_transitions captures margin_call as external_exit"
         >:: test_record_transitions_captures_margin_call_as_external_exit;
         "record_transitions captures any StrategySignal label"
         >:: test_record_transitions_captures_any_strategy_signal_label;
         "record_transitions: enriched exit wins, no overwrite"
         >:: test_record_transitions_enriched_exit_wins_no_overwrite;
         "record_transitions without entry is dropped"
         >:: test_record_transitions_without_entry_is_dropped;
         "record_transitions ignores non-TriggerExit transition kinds"
         >:: test_record_transitions_ignores_non_trigger_exit_kinds;
         "record_transitions ignores TriggerPartialExit"
         >:: test_record_transitions_ignores_partial_exit;
         "record_entry overwrites same position_id"
         >:: test_record_entry_overwrites_same_position_id;
         "get_audit_records sorts by position_id"
         >:: test_get_audit_records_sorts_by_position_id;
         "collector round-trips through sexp"
         >:: test_collector_round_trips_through_sexp;
         "cascade_summary sexp round-trip"
         >:: test_cascade_summary_sexp_round_trip;
         "record_cascade_summary appears in collector"
         >:: test_record_cascade_summary_appears_in_collector;
         "get_cascade_summaries sorts by date"
         >:: test_get_cascade_summaries_sorts_by_date;
         "audit_blob round-trips through sexp" >:: test_audit_blob_round_trip;
         "empty collector returns empty audit_blob"
         >:: test_empty_collector_returns_empty_blob;
       ]

let () = run_test_tt_main suite
