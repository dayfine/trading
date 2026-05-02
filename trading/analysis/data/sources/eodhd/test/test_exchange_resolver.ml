open Core
open OUnit2
open Matchers
open Eodhd.Exchange_resolver

(* --- parsing --- *)

let test_parse_us_default _ =
  assert_that (parse "AAPL")
    (is_ok_and_holds
       (equal_to ({ ticker = "AAPL"; exchange = US } : parsed_symbol)))

let test_parse_us_explicit _ =
  assert_that (parse "AAPL.US")
    (is_ok_and_holds
       (equal_to ({ ticker = "AAPL"; exchange = US } : parsed_symbol)))

let test_parse_lse_canonical _ =
  assert_that (parse "BARC.LSE")
    (is_ok_and_holds
       (equal_to ({ ticker = "BARC"; exchange = LSE } : parsed_symbol)))

let test_parse_lse_alias _ =
  assert_that (parse "BARC.L")
    (is_ok_and_holds
       (equal_to ({ ticker = "BARC"; exchange = LSE } : parsed_symbol)))

let test_parse_tse_canonical _ =
  assert_that (parse "7203.TSE")
    (is_ok_and_holds
       (equal_to ({ ticker = "7203"; exchange = TSE } : parsed_symbol)))

let test_parse_tse_alias _ =
  assert_that (parse "7203.T")
    (is_ok_and_holds
       (equal_to ({ ticker = "7203"; exchange = TSE } : parsed_symbol)))

let test_parse_asx_canonical _ =
  assert_that (parse "BHP.AU")
    (is_ok_and_holds
       (equal_to ({ ticker = "BHP"; exchange = ASX } : parsed_symbol)))

let test_parse_asx_alias _ =
  assert_that (parse "BHP.AX")
    (is_ok_and_holds
       (equal_to ({ ticker = "BHP"; exchange = ASX } : parsed_symbol)))

let test_parse_hkex _ =
  assert_that (parse "0700.HK")
    (is_ok_and_holds
       (equal_to ({ ticker = "0700"; exchange = HKEX } : parsed_symbol)))

let test_parse_tsx_canonical _ =
  assert_that (parse "RY.TO")
    (is_ok_and_holds
       (equal_to ({ ticker = "RY"; exchange = TSX } : parsed_symbol)))

let test_parse_tsx_alias _ =
  assert_that (parse "RY.TSX")
    (is_ok_and_holds
       (equal_to ({ ticker = "RY"; exchange = TSX } : parsed_symbol)))

let test_parse_lowercase_suffix _ =
  assert_that (parse "barc.lse")
    (is_ok_and_holds
       (equal_to ({ ticker = "barc"; exchange = LSE } : parsed_symbol)))

let test_parse_unknown_suffix _ =
  assert_that (parse "FOO.XYZ") is_error

let test_parse_empty_string _ =
  assert_that (parse "") is_error

let test_parse_empty_ticker _ =
  assert_that (parse ".US") is_error

(* --- canonical EODHD codes --- *)

let test_to_eodhd_code _ =
  let codes = List.map all ~f:to_eodhd_code in
  assert_that codes
    (elements_are
       [
         equal_to "US";
         equal_to "LSE";
         equal_to "TSE";
         equal_to "AU";
         equal_to "HK";
         equal_to "TO";
       ])

let test_to_eodhd_symbol_round_trip _ =
  let inputs = [ "AAPL.US"; "BARC.LSE"; "7203.TSE"; "BHP.AU"; "0700.HK"; "RY.TO" ] in
  let round_tripped =
    List.map inputs ~f:(fun s ->
        match parse s with
        | Ok ps -> to_eodhd_symbol ps
        | Error err ->
            assert_failure
              (Printf.sprintf "parse failed for %S: %s" s (Status.show err)))
  in
  assert_that round_tripped (elements_are (List.map inputs ~f:equal_to))

let test_to_eodhd_symbol_normalizes_alias _ =
  (* .L and .LSE both round-trip to the canonical .LSE form *)
  let result =
    match parse "BARC.L" with
    | Ok ps -> to_eodhd_symbol ps
    | Error err -> assert_failure (Status.show err)
  in
  assert_that result (equal_to "BARC.LSE")

(* --- currency tagging --- *)

let test_currency_per_exchange _ =
  let pairs = List.map all ~f:(fun ex -> (ex, currency ex)) in
  assert_that pairs
    (elements_are
       [
         equal_to (US, "USD");
         equal_to (LSE, "GBP");
         equal_to (TSE, "JPY");
         equal_to (ASX, "AUD");
         equal_to (HKEX, "HKD");
         equal_to (TSX, "CAD");
       ])

(* --- calendar identifiers --- *)

let test_calendar_per_exchange _ =
  let pairs = List.map all ~f:(fun ex -> (ex, calendar ex)) in
  assert_that pairs
    (elements_are
       [
         equal_to (US, "NYSE");
         equal_to (LSE, "LSE");
         equal_to (TSE, "TSE");
         equal_to (ASX, "ASX");
         equal_to (HKEX, "HKEX");
         equal_to (TSX, "TSX");
       ])

(* --- coverage: every variant in [all] is distinct --- *)

let test_all_distinct _ =
  let codes = List.map all ~f:to_eodhd_code in
  let unique = List.dedup_and_sort codes ~compare:String.compare in
  assert_that (List.length unique) (equal_to (List.length all))

let suite =
  "exchange_resolver_test"
  >::: [
         "parse_us_default" >:: test_parse_us_default;
         "parse_us_explicit" >:: test_parse_us_explicit;
         "parse_lse_canonical" >:: test_parse_lse_canonical;
         "parse_lse_alias" >:: test_parse_lse_alias;
         "parse_tse_canonical" >:: test_parse_tse_canonical;
         "parse_tse_alias" >:: test_parse_tse_alias;
         "parse_asx_canonical" >:: test_parse_asx_canonical;
         "parse_asx_alias" >:: test_parse_asx_alias;
         "parse_hkex" >:: test_parse_hkex;
         "parse_tsx_canonical" >:: test_parse_tsx_canonical;
         "parse_tsx_alias" >:: test_parse_tsx_alias;
         "parse_lowercase_suffix" >:: test_parse_lowercase_suffix;
         "parse_unknown_suffix" >:: test_parse_unknown_suffix;
         "parse_empty_string" >:: test_parse_empty_string;
         "parse_empty_ticker" >:: test_parse_empty_ticker;
         "to_eodhd_code" >:: test_to_eodhd_code;
         "to_eodhd_symbol_round_trip" >:: test_to_eodhd_symbol_round_trip;
         "to_eodhd_symbol_normalizes_alias" >:: test_to_eodhd_symbol_normalizes_alias;
         "currency_per_exchange" >:: test_currency_per_exchange;
         "calendar_per_exchange" >:: test_calendar_per_exchange;
         "all_distinct" >:: test_all_distinct;
       ]

let () = run_test_tt_main suite
