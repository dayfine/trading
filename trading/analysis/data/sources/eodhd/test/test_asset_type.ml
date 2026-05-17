open Core
open OUnit2
open Matchers
open Eodhd

let test_of_eodhd_string_common_stock _ =
  assert_that
    (Asset_type.of_eodhd_string "Common Stock")
    (equal_to Asset_type.Common_stock)

let test_of_eodhd_string_preferred_stock _ =
  assert_that
    (Asset_type.of_eodhd_string "Preferred Stock")
    (equal_to Asset_type.Preferred_stock)

let test_of_eodhd_string_etf _ =
  assert_that (Asset_type.of_eodhd_string "ETF") (equal_to Asset_type.ETF)

let test_of_eodhd_string_mutual_fund _ =
  assert_that
    (Asset_type.of_eodhd_string "Mutual Fund")
    (equal_to Asset_type.Mutual_fund)

let test_of_eodhd_string_fund_variants _ =
  (* All three legacy EODHD spellings collapse to [Fund]. *)
  assert_that
    (List.map
       [ "FUND"; "Fund"; "Closed-End Fund" ]
       ~f:Asset_type.of_eodhd_string)
    (elements_are
       [
         equal_to Asset_type.Fund;
         equal_to Asset_type.Fund;
         equal_to Asset_type.Fund;
       ])

let test_of_eodhd_string_adr _ =
  assert_that (Asset_type.of_eodhd_string "ADR") (equal_to Asset_type.ADR)

let test_of_eodhd_string_gdr _ =
  assert_that (Asset_type.of_eodhd_string "GDR") (equal_to Asset_type.GDR)

let test_of_eodhd_string_index_variants _ =
  assert_that
    (List.map [ "INDEX"; "Index" ] ~f:Asset_type.of_eodhd_string)
    (elements_are [ equal_to Asset_type.Index; equal_to Asset_type.Index ])

let test_of_eodhd_string_unknown_preserves_raw _ =
  assert_that
    (Asset_type.of_eodhd_string "Brand New Type EODHD Just Invented")
    (equal_to (Asset_type.Other "Brand New Type EODHD Just Invented"))

let test_of_eodhd_string_empty _ =
  assert_that (Asset_type.of_eodhd_string "") (equal_to (Asset_type.Other ""))

let test_of_eodhd_string_whitespace _ =
  (* Whitespace-only collapses to [Other ""] after the [String.strip]. *)
  assert_that
    (Asset_type.of_eodhd_string "   ")
    (equal_to (Asset_type.Other ""))

(* Per the [.mli] contract: [Common_stock; Preferred_stock; ADR; GDR] are
   equity-like; everything else (including [Other _]) is not. *)

let test_is_equity_like_true_cases _ =
  let inputs =
    [
      Asset_type.Common_stock;
      Asset_type.Preferred_stock;
      Asset_type.ADR;
      Asset_type.GDR;
    ]
  in
  assert_that
    (List.count inputs ~f:Asset_type.is_equity_like)
    (equal_to (List.length inputs))

let test_is_equity_like_false_cases _ =
  let inputs =
    [
      Asset_type.ETF;
      Asset_type.Mutual_fund;
      Asset_type.Fund;
      Asset_type.Bond;
      Asset_type.Index;
      Asset_type.Currency;
      Asset_type.Commodity;
      Asset_type.Other "anything";
    ]
  in
  assert_that (List.count inputs ~f:Asset_type.is_equity_like) (equal_to 0)

let suite =
  "asset_type_test"
  >::: [
         "of_eodhd_string_common_stock" >:: test_of_eodhd_string_common_stock;
         "of_eodhd_string_preferred_stock"
         >:: test_of_eodhd_string_preferred_stock;
         "of_eodhd_string_etf" >:: test_of_eodhd_string_etf;
         "of_eodhd_string_mutual_fund" >:: test_of_eodhd_string_mutual_fund;
         "of_eodhd_string_fund_variants" >:: test_of_eodhd_string_fund_variants;
         "of_eodhd_string_adr" >:: test_of_eodhd_string_adr;
         "of_eodhd_string_gdr" >:: test_of_eodhd_string_gdr;
         "of_eodhd_string_index_variants"
         >:: test_of_eodhd_string_index_variants;
         "of_eodhd_string_unknown_preserves_raw"
         >:: test_of_eodhd_string_unknown_preserves_raw;
         "of_eodhd_string_empty" >:: test_of_eodhd_string_empty;
         "of_eodhd_string_whitespace" >:: test_of_eodhd_string_whitespace;
         "is_equity_like_true_cases" >:: test_is_equity_like_true_cases;
         "is_equity_like_false_cases" >:: test_is_equity_like_false_cases;
       ]

let () = run_test_tt_main suite
