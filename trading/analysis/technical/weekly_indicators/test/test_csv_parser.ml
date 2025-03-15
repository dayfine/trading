open OUnit2
open Weekly_indicators.Types

let test_parse_line _ =
  let line = "2024-03-15,143.41,144.34,141.13,142.17,141.4998,41025900" in
  match Weekly_indicators.Csv_parser.parse_line line with
  | Error msg -> assert_failure ("Expected Ok but got Error: " ^ msg)
  | Ok data ->
      assert_equal 2024 (Date.year data.date);
      assert_equal 3 (Date.month data.date);
      assert_equal 15 (Date.day data.date);
      assert_equal 143.41 data.open_price;
      assert_equal 144.34 data.high;
      assert_equal 141.13 data.low;
      assert_equal 142.17 data.close;
      assert_equal 141.4998 data.adjusted_close;
      assert_equal 41025900 data.volume

let test_parse_line_invalid_format _ =
  let line = "invalid,data" in
  match Weekly_indicators.Csv_parser.parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        "Invalid CSV format: expected 7 columns, line: invalid,data"
        msg

let test_parse_line_invalid_date _ =
  let line = "2024-13-15,143.41,144.34,141.13,142.17,141.4998,41025900" in
  match Weekly_indicators.Csv_parser.parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        "Error parsing line '2024-13-15,143.41,144.34,141.13,142.17,141.4998,41025900': Invalid date format, expected YYYY-MM-DD"
        msg

let test_parse_line_invalid_number _ =
  let line = "2024-03-15,not_a_number,144.34,141.13,142.17,141.4998,41025900" in
  match Weekly_indicators.Csv_parser.parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_bool "Should contain float_of_string error"
        (String.contains msg "float_of_string")

let test_to_string _ =
  let data = {
    date = Date.create ~year:2024 ~month:3 ~day:15;
    open_price = 143.41;
    high = 144.34;
    low = 141.13;
    close = 142.17;
    adjusted_close = 141.4998;
    volume = 41025900;
  } in
  assert_equal
    "2024-03-15,143.41,144.34,141.13,142.17,141.50,41025900"
    (Weekly_indicators.Csv_parser.to_string data)

let suite =
  "CSV Parser tests" >::: [
    "test_parse_line" >:: test_parse_line;
    "test_parse_line_invalid_format" >:: test_parse_line_invalid_format;
    "test_parse_line_invalid_date" >:: test_parse_line_invalid_date;
    "test_parse_line_invalid_number" >:: test_parse_line_invalid_number;
    "test_to_string" >:: test_to_string;
  ]
