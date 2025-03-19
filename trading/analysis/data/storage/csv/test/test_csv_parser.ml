open OUnit2
open Trading.Csv_storage.Types
open Trading.Csv_storage.Parser

let test_parse_line _ =
  let line = "2024-03-15,143.41,144.34,141.13,142.17,141.4998,41025900" in
  match parse_line line with
  | Error msg -> assert_failure ("Expected Ok but got Error: " ^ show_error msg)
  | Ok data ->
      assert_equal 2024 (data.date.tm_year + 1900);
      assert_equal 3 (data.date.tm_mon + 1);
      assert_equal 15 data.date.tm_mday;
      assert_equal 143.41 data.open_;
      assert_equal 144.34 data.high;
      assert_equal 141.13 data.low;
      assert_equal 142.17 data.close;
      assert_equal 141.4998 data.adjusted_close;
      assert_equal 41025900 data.volume

let test_parse_line_invalid_format _ =
  let line = "invalid,data" in
  match parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        (Invalid_csv_format "Expected 7 columns, line: invalid,data")
        msg

let test_parse_line_invalid_date _ =
  let line = "2024-13-15,143.41,144.34,141.13,142.17,141.4998,41025900" in
  match parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        (Invalid_date line)
        msg

let test_parse_line_invalid_number _ =
  let line = "2024-03-15,not_a_number,144.34,141.13,142.17,141.4998,41025900" in
  match parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        (Invalid_number line)
        msg

let test_parse_line_invalid_volume _ =
  let line = "2024-03-15,143.41,144.34,141.13,142.17,141.4998,not_a_number" in
  match parse_line line with
  | Ok data ->
      assert_failure
        (Printf.sprintf "Expected Error but got Ok: %s" (show_price_data data))
  | Error msg ->
      assert_equal
        (Invalid_volume line)
        msg

let test_to_string _ =
  let data = {
    date = Unix.localtime (Unix.time ());
    open_ = 143.41;
    high = 144.34;
    low = 141.13;
    close = 142.17;
    adjusted_close = 141.4998;
    volume = 41025900;
  } in
  let str = to_string data in
  match parse_line str with
  | Error msg -> assert_failure ("Failed to parse generated string: " ^ show_error msg)
  | Ok parsed ->
      assert_equal data.open_ parsed.open_;
      assert_equal data.high parsed.high;
      assert_equal data.low parsed.low;
      assert_equal data.close parsed.close;
      assert_equal data.adjusted_close parsed.adjusted_close;
      assert_equal data.volume parsed.volume

let suite =
  "CSV Parser tests" >::: [
    "test_parse_line" >:: test_parse_line;
    "test_parse_line_invalid_format" >:: test_parse_line_invalid_format;
    "test_parse_line_invalid_date" >:: test_parse_line_invalid_date;
    "test_parse_line_invalid_number" >:: test_parse_line_invalid_number;
    "test_parse_line_invalid_volume" >:: test_parse_line_invalid_volume;
    "test_to_string" >:: test_to_string;
  ]
