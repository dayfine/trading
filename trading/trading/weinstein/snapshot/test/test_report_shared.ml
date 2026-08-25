(** Tests for the pure {!Report_shared} helpers added for the weekly-report
    improvements: the per-candidate {b weakness line} and the
    {b score breakdown}. Both are format-agnostic (the Markdown and HTML
    renderers call them), so pinning them here pins both reports at once. *)

open OUnit2
open Matchers
open Weinstein_snapshot

(* A candidate with the fields the weakness / breakdown helpers read exposed as
   optional params; the rest are fixed. The defaults describe a CLEAN long setup
   — strong volume, structural stop, tight 8% risk, strong sector, not
   reconciled — so [weakness_line] is [None] unless a param introduces a weak
   link. *)
let _cand ?(rationale = "Strong volume; Strong sector")
    ?(stop_is_structural = true) ?(entry = 100.0) ?(stop = 92.0)
    ?(reconciliation = Entry_reconciliation.Not_reconciled)
    ?(score_components = []) () : Weekly_snapshot.candidate =
  {
    symbol = "TEST";
    score = 70.0;
    grade = "A";
    entry;
    stop;
    sector = "XLK";
    rationale;
    rs_vs_spy = None;
    resistance_grade = None;
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
    stop_is_structural;
    data_suspect = false;
    reconciliation;
    score_components;
  }

let test_clean_setup_has_no_weakness _ =
  assert_that (Report_shared.weakness_line (_cand ())) is_none

let test_adequate_volume_is_a_weakness _ =
  (* "Strong sector" in the rationale suppresses the sector weakness so only the
     volume weakness is left. *)
  assert_that
    (Report_shared.weaknesses
       (_cand ~rationale:"Adequate volume; Strong sector" ()))
    (elements_are [ equal_to "adequate (not strong) volume" ])

let test_fallback_stop_is_a_weakness _ =
  assert_that
    (Report_shared.weaknesses (_cand ~stop_is_structural:false ()))
    (elements_are [ equal_to "fallback stop (no structural floor)" ])

let test_wide_risk_is_a_weakness _ =
  (* (100 - 80) / 100 = 20% > the 15% wide-risk threshold. *)
  assert_that
    (Report_shared.weaknesses (_cand ~entry:100.0 ~stop:80.0 ()))
    (elements_are [ equal_to "wide risk 20.0%" ])

let test_through_entry_is_a_weakness _ =
  assert_that
    (Report_shared.weaknesses
       (_cand
          ~reconciliation:
            (Entry_reconciliation.Through_entry
               { close = 104.7; overshoot_pct = 4.7; cap = 0.0 })
          ()))
    (elements_are [ equal_to "paying up +4.7% through entry" ])

let test_extended_is_a_weakness _ =
  assert_that
    (Report_shared.weaknesses
       (_cand
          ~reconciliation:
            (Entry_reconciliation.Extended
               { close = 112.3; overshoot_pct = 12.3; cap = 0.0 })
          ()))
    (elements_are [ equal_to "+12.3% past cap, will not fill" ])

let test_sector_not_strong_is_a_long_weakness _ =
  (* A long setup (stop below entry) whose rationale lacks "Strong sector". *)
  assert_that
    (Report_shared.weaknesses (_cand ~rationale:"Strong volume" ()))
    (elements_are [ equal_to "sector not strong" ])

let test_short_setup_does_not_flag_sector_strength _ =
  (* A short (stop ABOVE entry) is not judged on long-side sector strength, so
     the exact list carries only its volume caveat — no "sector not strong". *)
  assert_that
    (Report_shared.weaknesses
       (_cand ~rationale:"Adequate breakdown volume" ~entry:50.0 ~stop:55.0 ()))
    (elements_are [ equal_to "adequate (not strong) volume" ])

let test_weaknesses_compose_in_one_line _ =
  (* Adequate volume AND fallback stop AND (long, no Strong sector) → three
     caveats joined in weakness order [volume; stop; …; sector]. *)
  assert_that
    (Report_shared.weakness_line
       (_cand ~rationale:"Adequate volume" ~stop_is_structural:false ()))
    (is_some_and
       (equal_to
          "adequate (not strong) volume; fallback stop (no structural floor); \
           sector not strong"))

let test_score_breakdown_compact_and_detail _ =
  let c =
    _cand
      ~score_components:
        [ ("Stage1→Stage2 breakout", 30); ("Strong volume", 20) ]
      ()
  in
  assert_that
    (Report_shared.score_breakdown c)
    (is_some_and (equal_to "50 = 30 + 20"));
  assert_that
    (Report_shared.score_breakdown_detail c)
    (is_some_and (equal_to "30 Stage1→Stage2 breakout · 20 Strong volume"))

let test_score_breakdown_empty_is_none _ =
  assert_that (Report_shared.score_breakdown (_cand ())) is_none;
  assert_that (Report_shared.score_breakdown_detail (_cand ())) is_none

let suite =
  "report_shared"
  >::: [
         "clean_setup_has_no_weakness" >:: test_clean_setup_has_no_weakness;
         "adequate_volume_is_a_weakness" >:: test_adequate_volume_is_a_weakness;
         "fallback_stop_is_a_weakness" >:: test_fallback_stop_is_a_weakness;
         "wide_risk_is_a_weakness" >:: test_wide_risk_is_a_weakness;
         "through_entry_is_a_weakness" >:: test_through_entry_is_a_weakness;
         "extended_is_a_weakness" >:: test_extended_is_a_weakness;
         "sector_not_strong_is_a_long_weakness"
         >:: test_sector_not_strong_is_a_long_weakness;
         "short_setup_does_not_flag_sector_strength"
         >:: test_short_setup_does_not_flag_sector_strength;
         "weaknesses_compose_in_one_line"
         >:: test_weaknesses_compose_in_one_line;
         "score_breakdown_compact_and_detail"
         >:: test_score_breakdown_compact_and_detail;
         "score_breakdown_empty_is_none" >:: test_score_breakdown_empty_is_none;
       ]

let () = run_test_tt_main suite
