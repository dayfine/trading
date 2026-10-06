open Core
open OUnit2
open Matchers
module CA = Corporate_actions

let _fresh_dir () =
  Fpath.v (Filename_unix.temp_dir "corporate_actions_test_" "")

let _d = Date.of_string

let _div ?unadjusted date adjusted : CA.dividend =
  {
    ex_date = _d date;
    unadjusted_amount = unadjusted;
    adjusted_amount = adjusted;
  }

(* Out of date order; one row with no unadjusted amount; one long float. *)
let _dividends =
  [
    _div "2024-05-10" ~unadjusted:0.25 0.25;
    _div "2024-02-09" 0.24;
    _div "1987-05-11" ~unadjusted:0.12096 0.1234567890123;
  ]

let _splits : CA.split list =
  [
    { date = _d "2020-08-31"; factor = 4.0 };
    { date = _d "2014-06-09"; factor = 7.0 };
    { date = _d "2023-01-03"; factor = 0.2 };
  ]

let _read_file path = In_channel.read_all (Fpath.to_string path)

let test_dividends_round_trip _ =
  let data_dir = _fresh_dir () in
  let read =
    Result.bind (CA.write_dividends ~data_dir "AAPL" _dividends) ~f:(fun () ->
        CA.read_dividends ~data_dir "AAPL")
  in
  assert_that read
    (is_ok_and_holds
       (elements_are
          [
            equal_to (_div "1987-05-11" ~unadjusted:0.12096 0.1234567890123);
            equal_to (_div "2024-02-09" 0.24);
            equal_to (_div "2024-05-10" ~unadjusted:0.25 0.25);
          ]))

let test_dividends_file_layout _ =
  let data_dir = _fresh_dir () in
  let text =
    Result.map (CA.write_dividends ~data_dir "AAPL" _dividends) ~f:(fun () ->
        _read_file (CA.dividends_path ~data_dir "AAPL"))
  in
  assert_that text
    (is_ok_and_holds
       (equal_to
          "ex_date,unadjusted_amount,adjusted_amount\n\
           1987-05-11,0.12096,0.1234567890123\n\
           2024-02-09,,0.24\n\
           2024-05-10,0.25,0.25\n"))

let test_splits_round_trip _ =
  let data_dir = _fresh_dir () in
  let read =
    Result.bind (CA.write_splits ~data_dir "AAPL" _splits) ~f:(fun () ->
        CA.read_splits ~data_dir "AAPL")
  in
  assert_that read
    (is_ok_and_holds
       (elements_are
          [
            equal_to ({ date = _d "2014-06-09"; factor = 7.0 } : CA.split);
            equal_to ({ date = _d "2020-08-31"; factor = 4.0 } : CA.split);
            equal_to ({ date = _d "2023-01-03"; factor = 0.2 } : CA.split);
          ]))

(* Files sit next to data.csv under the <L1>/<L2>/<SYM> sharding rule. *)
let test_paths_follow_symbol_dir _ =
  let data_dir = Fpath.v "/data" in
  assert_that
    ( Fpath.to_string (CA.dividends_path ~data_dir "AAPL"),
      Fpath.to_string (CA.splits_path ~data_dir "APC_old") )
    (equal_to ("/data/A/L/AAPL/dividends.csv", "/data/A/d/APC_old/splits.csv"))

let test_empty_writes_header_only _ =
  let data_dir = _fresh_dir () in
  let read =
    Result.bind (CA.write_dividends ~data_dir "XYZ" []) ~f:(fun () ->
        CA.read_dividends ~data_dir "XYZ")
  in
  assert_that
    (read, _read_file (CA.dividends_path ~data_dir "XYZ"))
    (all_of
       [
         field fst (is_ok_and_holds (size_is 0));
         field snd (equal_to "ex_date,unadjusted_amount,adjusted_amount\n");
       ])

let test_rewrite_is_byte_identical _ =
  let data_dir = _fresh_dir () in
  let write_and_read () =
    Result.map (CA.write_splits ~data_dir "AAPL" _splits) ~f:(fun () ->
        _read_file (CA.splits_path ~data_dir "AAPL"))
  in
  let expected =
    "date,factor\n2014-06-09,7.\n2020-08-31,4.\n2023-01-03,0.2\n"
  in
  let first = write_and_read () in
  let second = write_and_read () in
  assert_that (first, second)
    (pair
       (is_ok_and_holds (equal_to expected))
       (is_ok_and_holds (equal_to expected)))

let test_missing_file_is_not_found _ =
  let data_dir = _fresh_dir () in
  assert_that (CA.read_splits ~data_dir "NOPE") (is_error_with Status.NotFound)

let test_bad_header_is_invalid _ =
  let data_dir = _fresh_dir () in
  let path = CA.dividends_path ~data_dir "BAD" in
  Core_unix.mkdir_p (Fpath.to_string (Fpath.parent path));
  Out_channel.write_all (Fpath.to_string path) ~data:"date,value\n";
  assert_that
    (CA.read_dividends ~data_dir "BAD")
    (is_error_with Status.Invalid_argument)

let test_malformed_row_is_invalid _ =
  let data_dir = _fresh_dir () in
  let path = CA.splits_path ~data_dir "BAD" in
  Core_unix.mkdir_p (Fpath.to_string (Fpath.parent path));
  Out_channel.write_all (Fpath.to_string path)
    ~data:"date,factor\n2020-01-01,abc\n";
  assert_that
    (CA.read_splits ~data_dir "BAD")
    (is_error_with Status.Invalid_argument)

let test_has_both_files _ =
  let data_dir = _fresh_dir () in
  let after_divs =
    Result.map (CA.write_dividends ~data_dir "AAPL" []) ~f:(fun () ->
        CA.has_both_files ~data_dir "AAPL")
  in
  let after_both =
    Result.map (CA.write_splits ~data_dir "AAPL" []) ~f:(fun () ->
        CA.has_both_files ~data_dir "AAPL")
  in
  assert_that (after_divs, after_both)
    (pair (is_ok_and_holds (equal_to false)) (is_ok_and_holds (equal_to true)))

let suite =
  "corporate_actions"
  >::: [
         "dividends_round_trip" >:: test_dividends_round_trip;
         "dividends_file_layout" >:: test_dividends_file_layout;
         "splits_round_trip" >:: test_splits_round_trip;
         "paths_follow_symbol_dir" >:: test_paths_follow_symbol_dir;
         "empty_writes_header_only" >:: test_empty_writes_header_only;
         "rewrite_is_byte_identical" >:: test_rewrite_is_byte_identical;
         "missing_file_is_not_found" >:: test_missing_file_is_not_found;
         "bad_header_is_invalid" >:: test_bad_header_is_invalid;
         "malformed_row_is_invalid" >:: test_malformed_row_is_invalid;
         "has_both_files" >:: test_has_both_files;
       ]

let () = run_test_tt_main suite
