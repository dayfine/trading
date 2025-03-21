open OUnit2
open Core
open Csv_storage

let test_parse_line_valid _ =
  match Parser.parse_line "2024-03-19;100.0;105.0;98.0;103.0;103.0;1000" with
  | Ok data ->
      let expected =
        {
          Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
          open_price = 100.0;
          high_price = 105.0;
          low_price = 98.0;
          close_price = 103.0;
          adjusted_close = 103.0;
          volume = 1000;
        }
      in
      assert_equal ~printer:Types.Daily_price.show expected data
  | Error msg -> assert_failure ("Expected Ok but got Error: " ^ msg)

let test_parse_line_invalid_date _ =
  match Parser.parse_line "invalid;100.0;105.0;98.0;103.0;103.0;1000" with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error msg -> assert_equal "Invalid date format, expected YYYY-MM-DD" msg

let test_parse_line_invalid_number _ =
  match Parser.parse_line "2024-03-19;invalid;105.0;98.0;103.0;103.0;1000" with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error msg ->
      assert_equal
        "Invalid number in line: 2024-03-19;invalid;105.0;98.0;103.0;103.0;1000"
        msg

let test_parse_line_invalid_volume _ =
  match Parser.parse_line "2024-03-19;100.0;105.0;98.0;103.0;103.0;invalid" with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error msg ->
      assert_equal
        "Invalid number in line: \
         2024-03-19;100.0;105.0;98.0;103.0;103.0;invalid"
        msg

let test_parse_line_invalid_format _ =
  match Parser.parse_line "not;enough;columns" with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error msg -> assert_equal "Expected 7 columns, line: not;enough;columns" msg

let suite =
  "CSV Parser tests"
  >::: [
         "test_parse_line_valid" >:: test_parse_line_valid;
         "test_parse_line_invalid_date" >:: test_parse_line_invalid_date;
         "test_parse_line_invalid_number" >:: test_parse_line_invalid_number;
         "test_parse_line_invalid_volume" >:: test_parse_line_invalid_volume;
         "test_parse_line_invalid_format" >:: test_parse_line_invalid_format;
       ]

let () = run_test_tt_main suite
