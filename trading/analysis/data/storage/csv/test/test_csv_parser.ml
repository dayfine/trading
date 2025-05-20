open OUnit2
open Core
open Csv
open Status

let parse_line line =
  Parser.parse_lines [ ""; line ]
  |> Result.map_error ~f:(fun status -> status.message)

let test_parse_line_valid _ =
  let result =
    parse_line "2024-03-19,100.0,105.0,98.0,103.0,103.0,1000"
    |> Result.ok |> Option.value_exn |> List.hd_exn
  in
  assert_equal ~printer:Types.Daily_price.show result
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
      open_price = 100.0;
      high_price = 105.0;
      low_price = 98.0;
      close_price = 103.0;
      adjusted_close = 103.0;
      volume = 1000;
    }

let test_parse_line_invalid_date _ =
  let result =
    parse_line "invalid,100.0,105.0,98.0,103.0,103.0,1000" |> Result.error
  in
  assert_equal result (Option.some "Invalid date format, expected YYYY-MM-DD")

let test_parse_line_invalid_number _ =
  let result =
    parse_line "2024-03-19,invalid,105.0,98.0,103.0,103.0,1000" |> Result.error
  in
  assert_equal result
    (Option.some
       "Invalid number in line: 2024-03-19,invalid,105.0,98.0,103.0,103.0,1000")

let test_parse_line_invalid_volume _ =
  let result =
    parse_line "2024-03-19,100.0,105.0,98.0,103.0,103.0,invalid" |> Result.error
  in
  assert_equal result
    (Option.some
       "Invalid number in line: 2024-03-19,100.0,105.0,98.0,103.0,103.0,invalid")

let test_parse_line_invalid_format _ =
  let result = parse_line "not,enough,columns" |> Result.error in
  assert_equal result
    (Option.some "Expected 7 columns, line: not,enough,columns")

let test_parse_lines_with_empty_list _ =
  let result = Parser.parse_lines [] in
  assert_equal result (Error (Status.invalid_argument_error "Empty file"))

let test_parse_lines_with_empty_lines _ =
  let result = Parser.parse_lines [ ""; "" ] in
  assert_equal result
    (Error (Status.invalid_argument_error "Expected 7 columns, line: "))

let test_parse_lines_with_invalid_line _ =
  let result = Parser.parse_lines [ ""; "not,enough,columns" ] in
  assert_equal result
    (Error
       (Status.invalid_argument_error
          "Expected 7 columns, line: not,enough,columns"))

let test_read_test_data_file _ =
  let prices =
    In_channel.read_lines "./data/test_data.csv"
    |> Parser.parse_lines |> Result.ok |> Option.value_exn
  in
  assert_equal (List.length prices) 250;
  let first_price = List.hd_exn prices in
  assert_equal ~printer:Types.Daily_price.show first_price
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:12;
      open_price = 138.25;
      high_price = 140.28;
      low_price = 138.21;
      close_price = 139.62;
      adjusted_close = 138.9618;
      volume = 19019700;
    };
  let last_price = List.last_exn prices in
  assert_equal ~printer:Types.Daily_price.show last_price
    {
      Types.Daily_price.date = Date.create_exn ~y:2025 ~m:Month.Mar ~d:11;
      open_price = 166.68;
      high_price = 168.655;
      low_price = 163.24;
      close_price = 165.98;
      adjusted_close = 165.98;
      volume = 23682500;
    }

let suite =
  "CSV Parser tests"
  >::: [
         "test_parse_line_valid" >:: test_parse_line_valid;
         "test_parse_line_invalid_date" >:: test_parse_line_invalid_date;
         "test_parse_line_invalid_number" >:: test_parse_line_invalid_number;
         "test_parse_line_invalid_volume" >:: test_parse_line_invalid_volume;
         "test_parse_line_invalid_format" >:: test_parse_line_invalid_format;
         "test_parse_lines_with_empty_list" >:: test_parse_lines_with_empty_list;
         "test_parse_lines_with_empty_lines"
         >:: test_parse_lines_with_empty_lines;
         "test_parse_lines_with_invalid_line"
         >:: test_parse_lines_with_invalid_line;
         "test_read_test_data_file" >:: test_read_test_data_file;
       ]

let () = run_test_tt_main suite
