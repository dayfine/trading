open OUnit2
open Weinstein_types
open Matchers

let test_stage_eq _ =
  let s2_early = (Stage2 { weeks_advancing = 3; late = false } : stage) in
  let s2_late = (Stage2 { weeks_advancing = 3; late = true } : stage) in
  assert_that s2_early (equal_to s2_early);
  assert_that s2_early (not_ (equal_to s2_late));
  assert_that
    (Stage1 { weeks_in_base = 4 } : stage)
    (not_ (equal_to (Stage3 { weeks_topping = 4 } : stage)))

let test_ma_direction_eq _ =
  assert_that (Rising : ma_direction) (equal_to Rising);
  assert_that (Rising : ma_direction) (not_ (equal_to Declining))

(* GICS canonical spellings must parse. *)
let test_gics_of_string_canonical _ =
  assert_that
    (gics_sector_of_string_opt "Information Technology")
    (is_some_and (equal_to Information_technology));
  assert_that
    (gics_sector_of_string_opt "Health Care")
    (is_some_and (equal_to Health_care));
  assert_that
    (gics_sector_of_string_opt "COMMUNICATION SERVICES")
    (is_some_and (equal_to Communication_services))

(* All 11 Finviz sector display labels (verified against
   finviz.com/groups.ashx?g=sector) must map to a GICS variant. If
   Finviz ever renames one, this test fails loudly. *)
let test_gics_of_string_all_finviz_labels _ =
  let finviz_to_gics =
    [
      ("Basic Materials", Materials);
      ("Communication Services", Communication_services);
      ("Consumer Cyclical", Consumer_discretionary);
      ("Consumer Defensive", Consumer_staples);
      ("Energy", Energy);
      ("Financial", Financials);
      ("Financial Services", Financials);
      ("Healthcare", Health_care);
      ("Industrials", Industrials);
      ("Real Estate", Real_estate);
      ("Technology", Information_technology);
      ("Utilities", Utilities);
    ]
  in
  List.iter
    (fun (label, expected) ->
      assert_that
        (gics_sector_of_string_opt label)
        (is_some_and (equal_to expected)))
    finviz_to_gics

let test_gics_of_string_unknown _ =
  assert_that (gics_sector_of_string_opt "Bogus") is_none;
  assert_that (gics_sector_of_string_opt "") is_none

(* normalize_sector_name returns the canonical GICS spelling for known
   names, passes unknowns through unchanged. *)
let test_normalize_sector_name _ =
  assert_that
    (normalize_sector_name "Technology")
    (equal_to "Information Technology");
  assert_that (normalize_sector_name "Financial") (equal_to "Financials");
  assert_that (normalize_sector_name "Healthcare") (equal_to "Health Care");
  assert_that
    (normalize_sector_name "Information Technology")
    (equal_to "Information Technology");
  assert_that (normalize_sector_name "Bogus") (equal_to "Bogus")

let suite =
  "weinstein_types"
  >::: [
         "stage_eq" >:: test_stage_eq;
         "ma_direction_eq" >:: test_ma_direction_eq;
         "gics_of_string canonical" >:: test_gics_of_string_canonical;
         "gics_of_string all finviz labels"
         >:: test_gics_of_string_all_finviz_labels;
         "gics_of_string unknown" >:: test_gics_of_string_unknown;
         "normalize_sector_name" >:: test_normalize_sector_name;
       ]

let () = run_test_tt_main suite
