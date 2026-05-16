open Core
open OUnit2
open Matchers
open Stooq.Stooq_client

(* Pinned fixture: 8 rows from Stooq's AAPL.US daily series. Five 2020-Q1
   rows + three 2026-05 tail rows. The tail row 2026-05-15 is the same
   trading day as the HTML probe captured during the verification probe
   (open=297.9, high=303.2, low=296.52, close=300.23, volume=54862836)
   so any drift between this fixture and a live re-fetch would surface
   loudly. *)
let _fixture_path = "./data/stooq_aapl_sample.csv"
let _read () = In_channel.read_all _fixture_path

let _parsed_or_fail body =
  match parse body with
  | Ok series -> series
  | Error err -> failwith ("Stooq parse failed: " ^ Status.show err)

let _date y m d = Date.create_exn ~y ~m ~d

let test_parse_returns_eight_observations _ =
  let series = _parsed_or_fail (_read ()) in
  assert_that series.observations (size_is 8)

let test_first_observation_jan_2_2020 _ =
  let series = _parsed_or_fail (_read ()) in
  match series.observations with
  | first :: _ ->
      assert_that first
        (equal_to
           ({
              date = _date 2020 Month.Jan 2;
              open_ = 74.06;
              high = 75.15;
              low = 73.7975;
              close = 75.0875;
              volume = 135480400;
            }
             : daily_observation))
  | [] -> assert_failure "Expected non-empty observations list"

let test_last_observation_may_15_2026 _ =
  let series = _parsed_or_fail (_read ()) in
  let last = List.last series.observations in
  assert_that last
    (is_some_and
       (equal_to
          ({
             date = _date 2026 Month.May 15;
             open_ = 297.9;
             high = 303.2;
             low = 296.52;
             close = 300.23;
             volume = 54862836;
           }
            : daily_observation)))

let test_observations_in_source_order _ =
  let series = _parsed_or_fail (_read ()) in
  let dates = List.map series.observations ~f:(fun o -> o.date) in
  assert_that dates
    (elements_are
       [
         equal_to (_date 2020 Month.Jan 2);
         equal_to (_date 2020 Month.Jan 3);
         equal_to (_date 2020 Month.Jan 6);
         equal_to (_date 2020 Month.Jan 7);
         equal_to (_date 2020 Month.Jan 8);
         equal_to (_date 2026 Month.May 13);
         equal_to (_date 2026 Month.May 14);
         equal_to (_date 2026 Month.May 15);
       ])

let test_header_drift_is_error _ =
  let body =
    "Date,Open,High,Low,CloseWRONG,Volume\n\
     2020-01-02,74.06,75.15,73.7975,75.0875,135480400\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_empty_body_is_error _ =
  assert_that (parse "") (is_error_with Status.Invalid_argument)

let test_whitespace_only_body_is_error _ =
  assert_that (parse "\n  \n\n") (is_error_with Status.Invalid_argument)

let test_unparseable_date_is_error _ =
  let body =
    "Date,Open,High,Low,Close,Volume\n\
     not-a-date,74.06,75.15,73.7975,75.0875,135480400\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_wrong_column_count_is_error _ =
  let body = "Date,Open,High,Low,Close,Volume\n2020-01-02,74.06,75.15\n" in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_unparseable_numeric_is_error _ =
  let body =
    "Date,Open,High,Low,Close,Volume\n\
     2020-01-02,NOT_A_NUMBER,75.15,73.7975,75.0875,135480400\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

(* UTF-8 BOM tolerance — some HTTP intermediaries / file editors prepend a
   BOM. The parser must strip it transparently. *)
let test_utf8_bom_is_tolerated _ =
  let body = "\xEF\xBB\xBF" ^ _read () in
  let series = _parsed_or_fail body in
  assert_that series.observations (size_is 8)

let test_build_uri_default_no_apikey _ =
  let uri_str = Uri.to_string (build_uri ~symbol:"AAPL" ()) in
  assert_that uri_str
    (all_of
       [
         contains_substring "https://stooq.com/q/d/l/";
         contains_substring "s=aapl.us";
         contains_substring "i=d";
       ])

let test_build_uri_lowercases_symbol _ =
  let uri_str = Uri.to_string (build_uri ~symbol:"AAPL" ()) in
  assert_that uri_str (contains_substring "s=aapl.us")

let test_build_uri_appends_us_suffix _ =
  let uri_str = Uri.to_string (build_uri ~symbol:"msft" ()) in
  assert_that uri_str (contains_substring "s=msft.us")

let test_build_uri_with_apikey _ =
  let uri_str =
    Uri.to_string (build_uri ~apikey:"TESTKEY123" ~symbol:"AAPL" ())
  in
  assert_that uri_str
    (all_of
       [
         contains_substring "s=aapl.us"; contains_substring "apikey=TESTKEY123";
       ])

(* The apikey-error sentinel verbatim from the 2026-05-17 probe. *)
let _apikey_error_body =
  "Get your apikey:\n\n\
   1. Open https://stooq.com/q/d/?s=aapl.us&get_apikey\n\
   2. Enter the captcha code.\n\
   3. Copy the CSV download link at the bottom of the page - it will contain \
   the <apikey> variable.\n\
   4. Append the <apikey> variable with its value to your requests, e.g.\n\
  \   \
   https://stooq.com/q/d/l/?s=aapl.us&i=d&apikey=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n"

let test_apikey_error_body_detected _ =
  assert_that (is_apikey_error_body _apikey_error_body) (equal_to true)

let test_real_csv_body_is_not_apikey_error _ =
  assert_that (is_apikey_error_body (_read ())) (equal_to false)

let suite =
  "stooq_client"
  >::: [
         "test_parse_returns_eight_observations"
         >:: test_parse_returns_eight_observations;
         "test_first_observation_jan_2_2020"
         >:: test_first_observation_jan_2_2020;
         "test_last_observation_may_15_2026"
         >:: test_last_observation_may_15_2026;
         "test_observations_in_source_order"
         >:: test_observations_in_source_order;
         "test_header_drift_is_error" >:: test_header_drift_is_error;
         "test_empty_body_is_error" >:: test_empty_body_is_error;
         "test_whitespace_only_body_is_error"
         >:: test_whitespace_only_body_is_error;
         "test_unparseable_date_is_error" >:: test_unparseable_date_is_error;
         "test_wrong_column_count_is_error" >:: test_wrong_column_count_is_error;
         "test_unparseable_numeric_is_error"
         >:: test_unparseable_numeric_is_error;
         "test_utf8_bom_is_tolerated" >:: test_utf8_bom_is_tolerated;
         "test_build_uri_default_no_apikey" >:: test_build_uri_default_no_apikey;
         "test_build_uri_lowercases_symbol" >:: test_build_uri_lowercases_symbol;
         "test_build_uri_appends_us_suffix" >:: test_build_uri_appends_us_suffix;
         "test_build_uri_with_apikey" >:: test_build_uri_with_apikey;
         "test_apikey_error_body_detected" >:: test_apikey_error_body_detected;
         "test_real_csv_body_is_not_apikey_error"
         >:: test_real_csv_body_is_not_apikey_error;
       ]

let () = run_test_tt_main suite
