open Core
open OUnit2
open Matchers
open Shiller.Shiller_client

(* The pinned sample fixture covers four distinct eras of the Shiller series:
   - 1871 head (the start of the dataset; populated fundamentals)
   - 2000 / 2020 mid-stream rows (both eras have populated fundamentals)
   - 2026 tail (three months at the head of the series with sentinel-0
     fundamentals, reflecting Shiller's typical 1-3 month release lag)

   The fixture is small enough to keep in-repo but exercises both the
   populated-fundamental and sentinel-handling branches of [parse]. *)
let _fixture_path = "./data/shiller_sample.csv"
let _read () = In_channel.read_all _fixture_path

let _parsed_or_fail body =
  match parse body with
  | Ok series -> series
  | Error err -> failwith ("Shiller parse failed: " ^ Status.show err)

let _date y m d = Date.create_exn ~y ~m ~d

let test_parse_returns_eight_observations _ =
  let series = _parsed_or_fail (_read ()) in
  assert_that series.observations (size_is 8)

let test_first_observation_is_jan_1871 _ =
  let series = _parsed_or_fail (_read ()) in
  match series.observations with
  | first :: _ ->
      assert_that first
        (all_of
           [
             field (fun o -> o.period) (equal_to (_date 1871 Month.Jan 1));
             field (fun o -> o.sp_price) (float_equal 4.44);
             field (fun o -> o.dividend) (is_some_and (float_equal 0.26));
             field (fun o -> o.earnings) (is_some_and (float_equal 0.4));
             field (fun o -> o.cpi) (is_some_and (float_equal 12.46));
             field (fun o -> o.long_rate) (is_some_and (float_equal 5.32));
           ])
  | [] -> assert_failure "Expected non-empty observations list"

let test_y2k_observation_has_populated_fundamentals _ =
  let series = _parsed_or_fail (_read ()) in
  let y2k =
    List.find series.observations ~f:(fun o ->
        Date.equal o.period (_date 2000 Month.Jan 1))
  in
  assert_that y2k
    (is_some_and
       (all_of
          [
            field (fun o -> o.sp_price) (float_equal 1425.59);
            field (fun o -> o.dividend) (is_some_and (float_equal 16.27));
            field (fun o -> o.earnings) (is_some_and (float_equal 49.34));
            field (fun o -> o.cpi) (is_some_and (float_equal 169.3));
            field (fun o -> o.long_rate) (is_some_and (float_equal 6.66));
          ]))

(* The covid-era March 2020 row exercises a mid-stream observation where the
   long-rate dropped to a sub-1.0 figure (0.87) but is still a real value,
   not a sentinel. Asserting it as [Some 0.87] guards against accidental
   sentinel widening that would silently drop the data. *)
let test_covid_observation_long_rate_below_one_not_sentinelled _ =
  let series = _parsed_or_fail (_read ()) in
  let covid =
    List.find series.observations ~f:(fun o ->
        Date.equal o.period (_date 2020 Month.Mar 1))
  in
  assert_that covid
    (is_some_and
       (all_of
          [
            field (fun o -> o.sp_price) (float_equal 2652.39);
            field (fun o -> o.long_rate) (is_some_and (float_equal 0.87));
          ]))

let test_recent_observations_sentinel_to_none _ =
  let series = _parsed_or_fail (_read ()) in
  let recent =
    List.find series.observations ~f:(fun o ->
        Date.equal o.period (_date 2026 Month.Mar 1))
  in
  assert_that recent
    (is_some_and
       (all_of
          [
            field (fun o -> o.sp_price) (float_equal 6654.42);
            field (fun o -> o.dividend) is_none;
            field (fun o -> o.earnings) is_none;
            field (fun o -> o.cpi) is_none;
            field (fun o -> o.long_rate) is_none;
          ]))

let test_last_observation_is_may_2026 _ =
  let series = _parsed_or_fail (_read ()) in
  let last = List.last series.observations in
  assert_that last
    (is_some_and
       (all_of
          [
            field (fun o -> o.period) (equal_to (_date 2026 Month.May 1));
            field (fun o -> o.sp_price) (float_equal 7215.43);
          ]))

let test_observations_in_source_order _ =
  let series = _parsed_or_fail (_read ()) in
  let dates = List.map series.observations ~f:(fun o -> o.period) in
  assert_that dates
    (elements_are
       [
         equal_to (_date 1871 Month.Jan 1);
         equal_to (_date 1871 Month.Feb 1);
         equal_to (_date 1871 Month.Mar 1);
         equal_to (_date 2000 Month.Jan 1);
         equal_to (_date 2020 Month.Mar 1);
         equal_to (_date 2026 Month.Mar 1);
         equal_to (_date 2026 Month.Apr 1);
         equal_to (_date 2026 Month.May 1);
       ])

let test_header_drift_is_error _ =
  let body =
    "Date,SP500,Dividend,Earnings,Consumer Price Index,WRONG_HEADER,Real \
     Price,Real Dividend,Real Earnings,PE10\n\
     1871-01-01,4.44,0.26,0.4,12.46,5.32,109.05,6.39,9.82,0.0\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_empty_body_is_error _ =
  assert_that (parse "") (is_error_with Status.Invalid_argument)

let test_whitespace_only_body_is_error _ =
  assert_that (parse "\n  \n\n") (is_error_with Status.Invalid_argument)

let test_unparseable_date_is_error _ =
  let body =
    "Date,SP500,Dividend,Earnings,Consumer Price Index,Long Interest Rate,Real \
     Price,Real Dividend,Real Earnings,PE10\n\
     not-a-date,4.44,0.26,0.4,12.46,5.32,109.05,6.39,9.82,0.0\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_wrong_column_count_is_error _ =
  let body =
    "Date,SP500,Dividend,Earnings,Consumer Price Index,Long Interest Rate,Real \
     Price,Real Dividend,Real Earnings,PE10\n\
     1871-01-01,4.44,0.26\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_unparseable_numeric_is_error _ =
  let body =
    "Date,SP500,Dividend,Earnings,Consumer Price Index,Long Interest Rate,Real \
     Price,Real Dividend,Real Earnings,PE10\n\
     1871-01-01,NOT_A_NUMBER,0.26,0.4,12.46,5.32,109.05,6.39,9.82,0.0\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

(* UTF-8 BOM tolerance — some HTTP intermediaries / file editors prepend a
   BOM. The parser must strip it transparently so we don't false-fail on a
   mid-pipeline transcoding artifact. *)
let test_utf8_bom_is_tolerated _ =
  let body = "\xEF\xBB\xBF" ^ _read () in
  let series = _parsed_or_fail body in
  assert_that series.observations (size_is 8)

let test_source_uri_is_https_github_raw _ =
  let uri_str = Uri.to_string source_uri in
  assert_that uri_str
    (all_of
       [
         contains_substring "https://raw.githubusercontent.com/";
         contains_substring "datasets/s-and-p-500";
         contains_substring "data/data.csv";
       ])

let suite =
  "shiller_client"
  >::: [
         "test_parse_returns_eight_observations"
         >:: test_parse_returns_eight_observations;
         "test_first_observation_is_jan_1871"
         >:: test_first_observation_is_jan_1871;
         "test_y2k_observation_has_populated_fundamentals"
         >:: test_y2k_observation_has_populated_fundamentals;
         "test_covid_observation_long_rate_below_one_not_sentinelled"
         >:: test_covid_observation_long_rate_below_one_not_sentinelled;
         "test_recent_observations_sentinel_to_none"
         >:: test_recent_observations_sentinel_to_none;
         "test_last_observation_is_may_2026"
         >:: test_last_observation_is_may_2026;
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
         "test_source_uri_is_https_github_raw"
         >:: test_source_uri_is_https_github_raw;
       ]

let () = run_test_tt_main suite
