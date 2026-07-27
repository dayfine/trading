(** Tests for {!Snapshot_validator} — issue #2122 v1 invariants. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _date = Date.of_string "2026-07-24"

let _candidate ?(symbol = "TEST") ?(entry = 100.0) ?(stop = 90.0)
    ?(sized_shares = 0) ?(sized_risk_amount = 0.0)
    ?(reconciliation = Entry_reconciliation.Not_reconciled) () :
    Weekly_snapshot.candidate =
  {
    symbol;
    score = 80.0;
    grade = "A";
    entry;
    stop;
    sector = "XLK";
    rationale = "r";
    rs_vs_spy = None;
    resistance_grade = None;
    sized_shares;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount;
    sizing_note = None;
    stop_is_structural = true;
    data_suspect = false;
    reconciliation;
  }

let _snapshot ?(longs = []) ?(shorts = []) () : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "test";
    date = _date;
    macro = { regime = "Bullish"; score = 1.0 };
    sectors_strong = [];
    sectors_weak = [];
    long_candidates = longs;
    short_candidates = shorts;
    held_positions = [];
    warnings = [];
  }

let _checks findings =
  List.map findings ~f:(fun (f : Snapshot_validator.finding) -> f.check)

(* ------- Clean artifacts produce no findings ------- *)

let test_clean_snapshot_has_no_findings _ =
  let longs =
    [
      _candidate ();
      _candidate ~symbol:"THRU"
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3 })
        ~sized_shares:57 ~sized_risk_amount:986.1 ();
    ]
  in
  assert_that
    (Snapshot_validator.validate (_snapshot ~longs ()))
    (equal_to ([] : Snapshot_validator.finding list))

(* ------- Reconciliation invariants ------- *)

let test_wrong_class_for_overshoot_is_an_error _ =
  (* Overshoot 7.3% is inside (band 1.0, max 15.0] — calling it Extended is a
     class error. *)
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Extended { close = 107.3; overshoot_pct = 7.3 })
        ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "reconciliation_class" ])

let test_stored_overshoot_must_match_close_vs_entry _ =
  (* close 107.3 vs entry 100 is +7.3%, not the stored +2%. *)
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 2.0 })
        ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "reconciliation_overshoot" ])

let test_extended_with_a_sized_ticket_is_an_error _ =
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Extended { close = 134.5; overshoot_pct = 34.5 })
        ~sized_shares:10 ~sized_risk_amount:445.0 ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "extended_not_suppressed"; "risk_consistency" ])

(* ------- Sizing invariants ------- *)

let test_risk_arithmetic_must_agree _ =
  (* 57 shares x |107.3 - 90| = 986.10; a stored 500 is inconsistent. *)
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3 })
        ~sized_shares:57 ~sized_risk_amount:500.0 ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "risk_consistency" ])

let test_risk_budget_excess_is_a_warning _ =
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3 })
        ~sized_shares:57 ~sized_risk_amount:986.1 ();
    ]
  in
  let findings =
    Snapshot_validator.validate ~risk_budget:900.0 (_snapshot ~longs ())
  in
  assert_that findings
    (elements_are
       [
         all_of
           [
             field
               (fun (f : Snapshot_validator.finding) -> f.check)
               (equal_to "risk_budget");
             field
               (fun (f : Snapshot_validator.finding) -> f.level)
               (equal_to Snapshot_validator.Warning);
           ];
       ])

(* ------- Price / side invariants ------- *)

let test_long_stop_above_fill_is_an_error _ =
  let longs = [ _candidate ~entry:100.0 ~stop:105.0 () ] in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "stop_side" ])

let test_short_stop_below_fill_is_an_error _ =
  (* Shorts are protected ABOVE the fill; a stop below it is wrong-side. *)
  let shorts = [ _candidate ~entry:100.0 ~stop:90.0 () ] in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~shorts ())))
    (equal_to [ "stop_side" ])

let test_duplicate_symbol_is_an_error _ =
  let longs = [ _candidate (); _candidate () ] in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "duplicate_symbol" ])

(* ------- Bar-dependent checks ------- *)

let _bar ~day ~close ~adjusted : Types.Daily_price.t =
  Types.Daily_price.make
    ~date:(Date.add_days _date (day - 10))
    ~open_price:close ~high_price:close ~low_price:close ~close_price:close
    ~volume:100 ~adjusted_close:adjusted ()

let test_split_in_window_is_flagged _ =
  (* raw 100 (adj 25) then raw 25 (adj 25): the raw/adjusted ratio steps 4x. *)
  let bars_for ~symbol:_ =
    [
      _bar ~day:0 ~close:100.0 ~adjusted:25.0;
      _bar ~day:1 ~close:25.0 ~adjusted:25.0;
    ]
  in
  assert_that
    (_checks
       (Snapshot_validator.validate ~bars_for
          (_snapshot ~longs:[ _candidate () ] ())))
    (equal_to [ "split_in_window" ])

let test_sparse_bars_flag_chart_coverage _ =
  let bars_for ~symbol:_ = [] in
  assert_that
    (_checks
       (Snapshot_validator.validate ~bars_for
          (_snapshot ~longs:[ _candidate () ] ())))
    (equal_to [ "chart_coverage" ])

let test_dividend_scale_ratio_drift_is_not_a_split _ =
  (* A gentle adjusted/raw drift (dividends) never crosses the step
     threshold. *)
  let bars_for ~symbol:_ =
    [
      _bar ~day:0 ~close:100.0 ~adjusted:98.0;
      _bar ~day:1 ~close:100.0 ~adjusted:99.0;
      _bar ~day:2 ~close:100.0 ~adjusted:100.0;
    ]
  in
  assert_that
    (Snapshot_validator.validate ~bars_for
       (_snapshot ~longs:[ _candidate () ] ()))
    (equal_to ([] : Snapshot_validator.finding list))

(* ------- Report / exit-code helpers ------- *)

let test_has_errors_distinguishes_levels _ =
  let err =
    Snapshot_validator.
      { level = Error; symbol = None; check = "c"; detail = "d" }
  in
  let warn = Snapshot_validator.{ err with level = Warning } in
  assert_that
    [
      Snapshot_validator.has_errors [ warn ];
      Snapshot_validator.has_errors [ warn; err ];
      Snapshot_validator.has_errors [];
    ]
    (equal_to [ false; true; false ])

let suite =
  "snapshot_validator"
  >::: [
         "clean_snapshot_has_no_findings"
         >:: test_clean_snapshot_has_no_findings;
         "wrong_class_for_overshoot_is_an_error"
         >:: test_wrong_class_for_overshoot_is_an_error;
         "stored_overshoot_must_match_close_vs_entry"
         >:: test_stored_overshoot_must_match_close_vs_entry;
         "extended_with_a_sized_ticket_is_an_error"
         >:: test_extended_with_a_sized_ticket_is_an_error;
         "risk_arithmetic_must_agree" >:: test_risk_arithmetic_must_agree;
         "risk_budget_excess_is_a_warning"
         >:: test_risk_budget_excess_is_a_warning;
         "long_stop_above_fill_is_an_error"
         >:: test_long_stop_above_fill_is_an_error;
         "short_stop_below_fill_is_an_error"
         >:: test_short_stop_below_fill_is_an_error;
         "duplicate_symbol_is_an_error" >:: test_duplicate_symbol_is_an_error;
         "split_in_window_is_flagged" >:: test_split_in_window_is_flagged;
         "sparse_bars_flag_chart_coverage"
         >:: test_sparse_bars_flag_chart_coverage;
         "dividend_scale_ratio_drift_is_not_a_split"
         >:: test_dividend_scale_ratio_drift_is_not_a_split;
         "has_errors_distinguishes_levels"
         >:: test_has_errors_distinguishes_levels;
       ]

let () = run_test_tt_main suite
