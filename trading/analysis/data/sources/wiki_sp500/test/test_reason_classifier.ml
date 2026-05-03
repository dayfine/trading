open OUnit2
open Matchers
open Wiki_sp500.Reason_classifier

(* Free-text examples below are taken verbatim from the pinned changes
   table snapshot to keep the classifier tests grounded in real wording. *)

let test_acquired _ =
  assert_that
    (classify "Blackstone Inc. and TPG Inc. acquired Hologic.")
    (equal_to M_and_A)

let test_purchased _ =
  assert_that (classify "ConAgra purchased Pinnacle Foods.") (equal_to M_and_A)

let test_merged_with _ =
  assert_that (classify "Wyeth merged with Pfizer.") (equal_to M_and_A)

let test_acquisition_keyword _ =
  assert_that
    (classify "Pending acquisition by Berkshire Hathaway.")
    (equal_to M_and_A)

let test_bankruptcy _ =
  assert_that
    (classify "Lehman Brothers filed for bankruptcy.")
    (equal_to Bankruptcy)

let test_filed_for _ =
  assert_that
    (classify "Company X filed for chapter 11 protection.")
    (equal_to Bankruptcy)

let test_market_capitalization _ =
  assert_that (classify "Market capitalization change.") (equal_to Mcap_change)

let test_market_cap_short _ =
  assert_that (classify "Market cap below threshold.") (equal_to Mcap_change)

let test_spinoff _ =
  assert_that (classify "Spinoff from parent company.") (equal_to Spinoff)

let test_spun_off _ =
  assert_that
    (classify
       "S&P 500 constituent Honeywell International Inc. spun off Solstice \
        Advanced Materials.")
    (equal_to Spinoff)

let test_split_off _ =
  assert_that (classify "Subsidiary split off from parent.") (equal_to Spinoff)

let test_other_fallback _ =
  assert_that (classify "Major restructuring of S&P 500.") (equal_to Other)

(* Precedence: M_and_A keywords win over Mcap_change. The "acquisition due
   to market capitalization" wording is plausibly produced by re-paraphrased
   reason text and the dominant business event is the acquisition. *)
let test_acquisition_overrides_mcap _ =
  assert_that
    (classify "Acquisition due to market capitalization decline.")
    (equal_to M_and_A)

(* Precedence: Bankruptcy keywords win over Mcap_change. *)
let test_bankruptcy_overrides_mcap _ =
  assert_that
    (classify "Bankruptcy following market cap collapse.")
    (equal_to Bankruptcy)

(* Case-insensitive matching: real Wiki text varies in capitalization. *)
let test_case_insensitive _ =
  assert_that (classify "MARKET CAPITALIZATION CHANGE.") (equal_to Mcap_change)

let suite =
  "reason_classifier_test"
  >::: [
         "acquired" >:: test_acquired;
         "purchased" >:: test_purchased;
         "merged_with" >:: test_merged_with;
         "acquisition_keyword" >:: test_acquisition_keyword;
         "bankruptcy" >:: test_bankruptcy;
         "filed_for" >:: test_filed_for;
         "market_capitalization" >:: test_market_capitalization;
         "market_cap_short" >:: test_market_cap_short;
         "spinoff" >:: test_spinoff;
         "spun_off" >:: test_spun_off;
         "split_off" >:: test_split_off;
         "other_fallback" >:: test_other_fallback;
         "acquisition_overrides_mcap" >:: test_acquisition_overrides_mcap;
         "bankruptcy_overrides_mcap" >:: test_bankruptcy_overrides_mcap;
         "case_insensitive" >:: test_case_insensitive;
       ]

let () = run_test_tt_main suite
