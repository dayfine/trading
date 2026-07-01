(** Unit tests for [Decision_audit.Screen_record].

    Covers grouping entry decisions by screen date, the funded / near-miss
    projection, near-miss dedup + score-desc ordering, and the summary (min/max
    score + inversion flag) — all on synthetic [audit_record] lists. *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module SR = Decision_audit.Screen_record

let _date d = Date.of_string d

let _alt ?(side = Trading_base.Types.Long)
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false })
    ?(weeks_advancing = Some 3) ?(rs_value = Some 1.0)
    ?(volume_ratio = Some 1.5) ?(sector_name = "Tech") ?(score_components = [])
    ~symbol ~score ~grade ~reason () : TA.alternative_candidate =
  {
    symbol;
    side;
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

(** Minimal [entry_decision] carrying the fields [Screen_record] projects, plus
    an [alternatives_considered] list. Non-projected fields get inert defaults.
*)
let _entry ?(entry_date = _date "2024-03-01") ?(symbol = "AAPL")
    ?(position_id = "AAPL-1") ?(score = 80) ?(grade = Weinstein_types.A)
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 2; late = false })
    ?(rs_value = Some 1.1) ?(volume_ratio = Some 2.0) ?(sector_name = "Tech")
    ?(alternatives = []) () : TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.7;
    macro_indicators = [];
    stage;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    rs_trend = None;
    rs_value;
    volume_quality = None;
    volume_ratio;
    resistance_quality = None;
    support_quality = None;
    sector_name;
    sector_rating = Screener.Neutral;
    cascade_score = score;
    cascade_grade = grade;
    cascade_score_components = [];
    cascade_rationale = [];
    side = Trading_base.Types.Long;
    suggested_entry = 100.0;
    suggested_stop = 92.0;
    installed_stop = 92.0;
    stop_floor_kind = TA.Buffer_fallback;
    risk_pct = 0.08;
    initial_position_value = 10_000.0;
    initial_risk_dollars = 800.0;
    alternatives_considered = alternatives;
  }

let _record entry : TA.audit_record = { entry; exit_ = None }

(* Grouping -------------------------------------------------------------- *)

let test_groups_by_screen_date _ =
  let records =
    [
      _record
        (_entry ~entry_date:(_date "2024-03-08") ~symbol:"MSFT"
           ~position_id:"MSFT-1" ());
      _record (_entry ~entry_date:(_date "2024-03-01") ~symbol:"AAPL" ());
      _record
        (_entry ~entry_date:(_date "2024-03-01") ~symbol:"NVDA"
           ~position_id:"NVDA-1" ());
    ]
  in
  assert_that
    (SR.of_audit_records records)
    (elements_are
       [
         all_of
           [
             field
               (fun (s : SR.t) -> Date.to_string s.screen_date)
               (equal_to "2024-03-01");
             field (fun (s : SR.t) -> s.summary.n_funded) (equal_to 2);
           ];
         all_of
           [
             field
               (fun (s : SR.t) -> Date.to_string s.screen_date)
               (equal_to "2024-03-08");
             field (fun (s : SR.t) -> s.summary.n_funded) (equal_to 1);
           ];
       ])

let test_funded_projection_carries_features _ =
  let records =
    [
      _record
        (_entry ~symbol:"AAPL" ~score:78 ~grade:Weinstein_types.A
           ~stage:(Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
           ~rs_value:(Some 1.2) ~volume_ratio:(Some 2.3) ~sector_name:"Health"
           ());
    ]
  in
  assert_that
    (SR.of_audit_records records)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.funded)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (e : SR.funded_entry) -> e.symbol)
                      (equal_to "AAPL");
                    field (fun (e : SR.funded_entry) -> e.score) (equal_to 78);
                    field
                      (fun (e : SR.funded_entry) -> e.weeks_advancing)
                      (is_some_and (equal_to 4));
                    field
                      (fun (e : SR.funded_entry) -> e.rs_value)
                      (is_some_and (float_equal 1.2));
                    field
                      (fun (e : SR.funded_entry) -> e.sector_name)
                      (equal_to "Health");
                  ];
              ]);
       ])

(* Near-misses ----------------------------------------------------------- *)

let test_near_misses_union_dedup_and_sorted _ =
  (* Two entries on the same screen share the near-miss ADBE; it must dedup to
     one, and near-misses must sort score-desc. *)
  let alts_a =
    [
      _alt ~symbol:"ADBE" ~score:75 ~grade:Weinstein_types.A
        ~reason:TA.Insufficient_cash ();
      _alt ~symbol:"AMD" ~score:70 ~grade:Weinstein_types.B
        ~reason:TA.Insufficient_cash ();
    ]
  in
  let alts_b =
    [
      _alt ~symbol:"ADBE" ~score:75 ~grade:Weinstein_types.A
        ~reason:TA.Insufficient_cash ();
      _alt ~symbol:"CRM" ~score:72 ~grade:Weinstein_types.B
        ~reason:TA.Sized_to_zero ();
    ]
  in
  let records =
    [
      _record (_entry ~symbol:"AAPL" ~alternatives:alts_a ());
      _record
        (_entry ~symbol:"MSFT" ~position_id:"MSFT-1" ~alternatives:alts_b ());
    ]
  in
  assert_that
    (SR.of_audit_records records)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.near_misses)
           (elements_are
              [
                field (fun (n : SR.near_miss) -> n.symbol) (equal_to "ADBE");
                field (fun (n : SR.near_miss) -> n.symbol) (equal_to "CRM");
                field (fun (n : SR.near_miss) -> n.symbol) (equal_to "AMD");
              ]);
       ])

(* Summary + inversion --------------------------------------------------- *)

let test_summary_scores_and_no_inversion _ =
  (* Funded min score 80; near-misses all below → no inversion. *)
  let alts =
    [
      _alt ~symbol:"AMD" ~score:70 ~grade:Weinstein_types.B
        ~reason:TA.Insufficient_cash ();
    ]
  in
  let records =
    [ _record (_entry ~symbol:"AAPL" ~score:80 ~alternatives:alts ()) ]
  in
  assert_that
    (SR.of_audit_records records)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.summary)
           (all_of
              [
                field
                  (fun (m : SR.summary) -> m.min_funded_score)
                  (is_some_and (equal_to 80));
                field
                  (fun (m : SR.summary) -> m.max_nearmiss_score)
                  (is_some_and (equal_to 70));
                field (fun (m : SR.summary) -> m.inversion) (equal_to false);
              ]);
       ])

let test_inversion_flagged_when_near_miss_outscores_funded _ =
  (* A near-miss scored 90 > funded min 80 → inversion. *)
  let alts =
    [
      _alt ~symbol:"NVDA" ~score:90 ~grade:Weinstein_types.A_plus
        ~reason:TA.Sector_exposure_cap ();
    ]
  in
  let records =
    [ _record (_entry ~symbol:"AAPL" ~score:80 ~alternatives:alts ()) ]
  in
  assert_that
    (SR.of_audit_records records)
    (elements_are
       [ field (fun (s : SR.t) -> s.summary.inversion) (equal_to true) ])

let test_empty_input_yields_no_screens _ =
  assert_that (SR.of_audit_records []) is_empty

let suite =
  "Decision_audit.Screen_record"
  >::: [
         "groups by screen date" >:: test_groups_by_screen_date;
         "funded projection carries features"
         >:: test_funded_projection_carries_features;
         "near-misses union / dedup / sorted"
         >:: test_near_misses_union_dedup_and_sorted;
         "summary scores + no inversion"
         >:: test_summary_scores_and_no_inversion;
         "inversion flagged when near-miss outscores funded"
         >:: test_inversion_flagged_when_near_miss_outscores_funded;
         "empty input yields no screens" >:: test_empty_input_yields_no_screens;
       ]

let () = run_test_tt_main suite
