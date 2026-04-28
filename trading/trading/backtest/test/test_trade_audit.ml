(** Unit tests for [Backtest.Trade_audit].

    Covers:
    - sexp round-trip on every record type
    - collector accumulates correctly across record_entry / record_exit
    - exits are dropped when no matching entry was recorded
    - get_audit_records returns position-id-sorted output
    - empty collector returns [] *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit

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
    ?(risk_pct = 0.08) ?(initial_position_value = 75_000.0)
    ?(initial_risk_dollars = 6_000.0) ?(alternatives_considered = []) () :
    TA.entry_decision =
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

let _alt ~symbol ~score ~grade ~reason : TA.alternative_candidate =
  {
    symbol;
    side = Trading_base.Types.Long;
    score;
    grade;
    reason_skipped = reason;
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

let test_alternative_candidate_sexp_round_trip _ =
  let alt =
    _alt ~symbol:"MSFT" ~score:62 ~grade:Weinstein_types.B
      ~reason:TA.Insufficient_cash
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
            ~reason:TA.Insufficient_cash;
          _alt ~symbol:"NVDA" ~score:55 ~grade:Weinstein_types.B
            ~reason:TA.Sized_to_zero;
        ]
      ()
  in
  let parsed = TA.entry_decision_of_sexp (TA.sexp_of_entry_decision entry) in
  assert_that parsed (equal_to entry)

let test_exit_decision_sexp_round_trip _ =
  let exit_ = make_exit () in
  let parsed = TA.exit_decision_of_sexp (TA.sexp_of_exit_decision exit_) in
  assert_that parsed (equal_to exit_)

let test_audit_record_sexp_round_trip _ =
  let record : TA.audit_record =
    { entry = make_entry (); exit_ = Some (make_exit ()) }
  in
  let parsed = TA.audit_record_of_sexp (TA.sexp_of_audit_record record) in
  assert_that parsed (equal_to record)

let test_audit_records_sexp_round_trip_through_top_level_codec _ =
  let records : TA.audit_record list =
    [
      { entry = make_entry (); exit_ = Some (make_exit ()) };
      {
        entry =
          make_entry ~symbol:"MSFT" ~position_id:"MSFT-wein-1"
            ~entry_date:(_date "2024-02-01") ();
        exit_ = None;
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
             ~reason:TA.Top_n_cutoff;
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
         "alternative_candidate sexp round-trip"
         >:: test_alternative_candidate_sexp_round_trip;
         "entry_decision sexp round-trip"
         >:: test_entry_decision_sexp_round_trip;
         "exit_decision sexp round-trip" >:: test_exit_decision_sexp_round_trip;
         "audit_record sexp round-trip" >:: test_audit_record_sexp_round_trip;
         "audit_records list sexp round-trip"
         >:: test_audit_records_sexp_round_trip_through_top_level_codec;
         "empty collector returns []" >:: test_empty_collector_returns_empty;
         "record_entry appears in audit" >:: test_record_entry_appears_in_audit;
         "record_exit attaches to existing entry"
         >:: test_record_exit_attaches_to_existing_entry;
         "record_exit without entry is dropped"
         >:: test_record_exit_without_entry_is_dropped;
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
