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
    score_components = [];
  }

let _snapshot ?(longs = []) ?(shorts = [])
    ?(macro : Weekly_snapshot.macro_context =
      { regime = "Bullish"; score = 1.0 }) () : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "test";
    date = _date;
    macro;
    sectors_strong = [];
    sectors_weak = [];
    long_candidates = longs;
    short_candidates = shorts;
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
    held_positions = [];
    warnings = [];
  }

let _checks findings =
  List.map findings ~f:(fun (f : Snapshot_validator.finding) -> f.check)

(* Matcher combinators for a single finding, so a test can pin which candidate
   raised which check without unpacking the record. *)
let _check_is name =
  field (fun (f : Snapshot_validator.finding) -> f.check) (equal_to name)

let _symbol_is symbol =
  field
    (fun (f : Snapshot_validator.finding) -> f.symbol)
    (equal_to (symbol : string option))

let _no_findings = equal_to ([] : Snapshot_validator.finding list)

(* ------- Clean artifacts produce no findings ------- *)

let test_clean_snapshot_has_no_findings _ =
  let longs =
    [
      _candidate ();
      _candidate ~symbol:"THRU"
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
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
          (Entry_reconciliation.Extended
             { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
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
             { close = 107.3; overshoot_pct = 2.0; cap = 0.0 })
        ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "reconciliation_overshoot" ])

(* Both class boundaries fall to the LOWER class, mirroring
   [Entry_reconciliation._class_of]. If the two conventions ever drift apart,
   the validator would report a spurious [reconciliation_class] error on a
   legitimate boundary artifact — so the convention is pinned on both edges. *)

let test_overshoot_exactly_at_the_band_is_valid_stop _ =
  (* close 101 vs entry 100 is +1.0%, exactly the default through_band_pct. *)
  let longs =
    [
      _candidate ~entry:100.0
        ~reconciliation:
          (Entry_reconciliation.Valid_stop
             { close = 101.0; overshoot_pct = 1.0; cap = 0.0 })
        ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~longs ())) _no_findings

let test_overshoot_exactly_at_the_extension_cap_is_through_entry _ =
  (* close 115 vs entry 100 is +15.0%, exactly the default extension_max_pct. *)
  let longs =
    [
      _candidate ~entry:100.0
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 115.0; overshoot_pct = 15.0; cap = 0.0 })
        ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~longs ())) _no_findings

(* Issue #2404: an EXTENDED candidate carries a normal sized ticket — its order
   simply will not fill at the current price — so a consistent one is clean.
   Sized on the cap $115.00: 10 x |115.00 - 90.00| = 250.00. The old
   [extended_not_suppressed] check, which required exactly the opposite, is
   gone. *)
let test_extended_with_a_consistent_sized_ticket_is_clean _ =
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Extended
             { close = 134.5; overshoot_pct = 34.5; cap = 115.0 })
        ~sized_shares:10 ~sized_risk_amount:250.0 ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~longs ())) _no_findings

(* And the risk identity still binds on that ticket: a stored 445.00 against the
   same 250.00 basis is an inconsistency the validator must catch. *)
let test_extended_with_inconsistent_risk_is_an_error _ =
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Extended
             { close = 134.5; overshoot_pct = 34.5; cap = 115.0 })
        ~sized_shares:10 ~sized_risk_amount:445.0 ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "risk_consistency" ])

(* ------- Sizing invariants ------- *)

let test_risk_arithmetic_must_agree _ =
  (* 57 shares x |107.3 - 90| = 986.10; a stored 500 is inconsistent. *)
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
        ~sized_shares:57 ~sized_risk_amount:500.0 ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "risk_consistency" ])

(* Issue #2158: the risk identity is checked against the do-not-chase CAP (the
   worst admissible fill), not the expected fill. A candidate carrying a $115.00
   cap sized 40 sh with sized_risk_amount 40 x |115.00 - 90.00| = 1000.0 is
   consistent — nothing fires. *)
let test_risk_consistency_on_the_cap_passes _ =
  let longs =
    [
      _candidate ~entry:100.0 ~stop:90.0
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 115.0 })
        ~sized_shares:40 ~sized_risk_amount:1000.0 ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~longs ())) _no_findings

(* The other direction: sizing the SAME candidate on the expected fill ($107.30)
   — 40 x |107.30 - 90.00| = 692.0 — is now a [risk_consistency] ERROR, because
   the identity moved off the expected fill onto the cap. Pins that the basis
   genuinely changed (under the pre-#2158 code this row was consistent). *)
let test_risk_consistency_on_the_expected_fill_now_fails _ =
  let longs =
    [
      _candidate ~entry:100.0 ~stop:90.0
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 115.0 })
        ~sized_shares:40 ~sized_risk_amount:692.0 ();
    ]
  in
  assert_that
    (_checks (Snapshot_validator.validate (_snapshot ~longs ())))
    (equal_to [ "risk_consistency" ])

(* Backward-compat: a pre-#2158 snapshot carries no cap ([cap = 0.0]), so the
   basis falls back to the expected fill and the row validates exactly as it did
   before this feature — 57 sh x |107.30 - 90.00| = 986.10. *)
let test_legacy_no_cap_validates_on_the_expected_fill _ =
  let longs =
    [
      _candidate ~entry:100.0 ~stop:90.0
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
        ~sized_shares:57 ~sized_risk_amount:986.1 ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~longs ())) _no_findings

let test_risk_budget_excess_is_a_warning _ =
  let longs =
    [
      _candidate
        ~reconciliation:
          (Entry_reconciliation.Through_entry
             { close = 107.3; overshoot_pct = 7.3; cap = 0.0 })
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

let test_short_risk_is_the_absolute_fill_to_stop_distance _ =
  (* A short is protected ABOVE its fill (weinstein-book-reference.md §6.3), so
     [fill - stop] is negative and only the absolute distance is the risk:
     50 x |100 - 110| = 500. Without the absolute value the identity would
     report -500 and raise a spurious [risk_consistency] error. *)
  let shorts =
    [
      _candidate ~entry:100.0 ~stop:110.0 ~sized_shares:50
        ~sized_risk_amount:500.0 ();
    ]
  in
  assert_that (Snapshot_validator.validate (_snapshot ~shorts ())) _no_findings

(* ------- Price / side invariants ------- *)

let test_non_positive_or_nan_prices_are_errors _ =
  (* Neither candidate is wrong-side (a zero stop sits below its long fill, and
     every NaN comparison is false), so [positive_prices] is the only finding
     each raises. *)
  let longs =
    [
      _candidate ~symbol:"ZEROSTOP" ~entry:100.0 ~stop:0.0 ();
      _candidate ~symbol:"NANENTRY" ~entry:Float.nan ~stop:90.0 ();
    ]
  in
  assert_that
    (Snapshot_validator.validate (_snapshot ~longs ()))
    (elements_are
       [
         all_of [ _check_is "positive_prices"; _symbol_is (Some "ZEROSTOP") ];
         all_of [ _check_is "positive_prices"; _symbol_is (Some "NANENTRY") ];
       ])

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

let test_empty_macro_regime_is_an_error _ =
  (* Snapshot-level finding: no symbol, and it fires even with no candidates. *)
  assert_that
    (Snapshot_validator.validate
       (_snapshot ~macro:{ regime = ""; score = 0.0 } ()))
    (elements_are
       [
         all_of
           [
             _check_is "macro_regime";
             _symbol_is None;
             field
               (fun (f : Snapshot_validator.finding) -> f.level)
               (equal_to Snapshot_validator.Error);
           ];
       ])

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
         "overshoot_exactly_at_the_band_is_valid_stop"
         >:: test_overshoot_exactly_at_the_band_is_valid_stop;
         "overshoot_exactly_at_the_extension_cap_is_through_entry"
         >:: test_overshoot_exactly_at_the_extension_cap_is_through_entry;
         "extended_with_a_consistent_sized_ticket_is_clean"
         >:: test_extended_with_a_consistent_sized_ticket_is_clean;
         "extended_with_inconsistent_risk_is_an_error"
         >:: test_extended_with_inconsistent_risk_is_an_error;
         "risk_arithmetic_must_agree" >:: test_risk_arithmetic_must_agree;
         "risk_consistency_on_the_cap_passes"
         >:: test_risk_consistency_on_the_cap_passes;
         "risk_consistency_on_the_expected_fill_now_fails"
         >:: test_risk_consistency_on_the_expected_fill_now_fails;
         "legacy_no_cap_validates_on_the_expected_fill"
         >:: test_legacy_no_cap_validates_on_the_expected_fill;
         "risk_budget_excess_is_a_warning"
         >:: test_risk_budget_excess_is_a_warning;
         "short_risk_is_the_absolute_fill_to_stop_distance"
         >:: test_short_risk_is_the_absolute_fill_to_stop_distance;
         "non_positive_or_nan_prices_are_errors"
         >:: test_non_positive_or_nan_prices_are_errors;
         "long_stop_above_fill_is_an_error"
         >:: test_long_stop_above_fill_is_an_error;
         "short_stop_below_fill_is_an_error"
         >:: test_short_stop_below_fill_is_an_error;
         "duplicate_symbol_is_an_error" >:: test_duplicate_symbol_is_an_error;
         "empty_macro_regime_is_an_error"
         >:: test_empty_macro_regime_is_an_error;
         "split_in_window_is_flagged" >:: test_split_in_window_is_flagged;
         "sparse_bars_flag_chart_coverage"
         >:: test_sparse_bars_flag_chart_coverage;
         "dividend_scale_ratio_drift_is_not_a_split"
         >:: test_dividend_scale_ratio_drift_is_not_a_split;
         "has_errors_distinguishes_levels"
         >:: test_has_errors_distinguishes_levels;
       ]

let () = run_test_tt_main suite
