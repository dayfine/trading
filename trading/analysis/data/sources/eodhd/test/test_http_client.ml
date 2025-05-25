open Core
open Async
open OUnit2
open Eodhd.Http_client
open Csv.Parser

let test_get_historical_price _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=2024-01-31&from=2024-01-01&fmt=csv&period=d&order=a"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    Deferred.return
      (Ok
         {|Date,Open,High,Low,Close,Adjusted Close,Volume
2024-01-01,100.0,101.0,99.0,100.5,100.5,1000|})
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok csv_str -> (
      let lines = String.split_lines csv_str in
      match parse_lines lines with
      | Ok prices ->
          assert_equal ~printer:Int.to_string 1 (List.length prices);
          let expected_price =
            {
              Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
              open_price = 100.0;
              high_price = 101.0;
              low_price = 99.0;
              close_price = 100.5;
              volume = 1000;
              adjusted_close = 100.5;
            }
          in
          let actual_price = List.hd_exn prices in
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal expected_price actual_price)
      | Error err -> assert_failure (Status.show err))
  | Error _ -> assert_failure "Expected Ok result"

let test_get_historical_price_error _ =
  let mock_fetch _uri =
    Deferred.return (Error (Status.internal_error "API rate limit exceeded"))
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok _ -> assert_failure "Expected Error result"
  | Error status ->
      assert_equal ~printer:Status.show
        (Status.internal_error "API rate limit exceeded")
        status

let test_get_historical_price_malformed_data _ =
  let mock_fetch _uri =
    Deferred.return (Ok {|Invalid,CSV,Format
No,Proper,Headers|})
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok csv_str -> (
      let lines = String.split_lines csv_str in
      match parse_lines lines with
      | Ok _ -> assert_failure "Expected parse_lines to fail on malformed data"
      | Error err ->
          let msg = Status.show err in
          assert_bool "Error message should mention columns"
            (String.is_substring msg ~substring:"columns"))
  | Error _ -> assert_failure "Expected Ok result with malformed data"

let test_get_historical_price_no_dates _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let today = Date.today ~zone:Time_float.Zone.utc in
    let expected_uri_str =
      Printf.sprintf
        "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=%s&fmt=csv&period=d&order=a"
        (Date.to_string today)
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    Deferred.return
      (Ok
         {|Date,Open,High,Low,Close,Adjusted Close,Volume
2024-01-01,100.0,101.0,99.0,100.5,100.5,1000|})
  in
  let params : Eodhd.Http_params.historical_price_params =
    { symbol = "AAPL"; start_date = None; end_date = None }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok csv_str -> (
      let lines = String.split_lines csv_str in
      match parse_lines lines with
      | Ok prices ->
          assert_equal ~printer:Int.to_string 1 (List.length prices);
          let expected_price =
            {
              Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
              open_price = 100.0;
              high_price = 101.0;
              low_price = 99.0;
              close_price = 100.5;
              volume = 1000;
              adjusted_close = 100.5;
            }
          in
          let actual_price = List.hd_exn prices in
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal expected_price actual_price)
      | Error err -> assert_failure (Status.show err))
  | Error _ -> assert_failure "Expected Ok result"

let test_get_historical_price_only_start_date _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let today = Date.today ~zone:Time_float.Zone.utc in
    let expected_uri_str =
      Printf.sprintf
        "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=%s&from=2024-01-01&fmt=csv&period=d&order=a"
        (Date.to_string today)
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    Deferred.return
      (Ok
         {|Date,Open,High,Low,Close,Adjusted Close,Volume
2024-01-01,100.0,101.0,99.0,100.5,100.5,1000|})
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = None;
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok csv_str -> (
      let lines = String.split_lines csv_str in
      match parse_lines lines with
      | Ok prices ->
          assert_equal ~printer:Int.to_string 1 (List.length prices);
          let expected_price =
            {
              Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
              open_price = 100.0;
              high_price = 101.0;
              low_price = 99.0;
              close_price = 100.5;
              volume = 1000;
              adjusted_close = 100.5;
            }
          in
          let actual_price = List.hd_exn prices in
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal expected_price actual_price)
      | Error err -> assert_failure (Status.show err))
  | Error _ -> assert_failure "Expected Ok result"

let test_get_historical_price_only_end_date _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=2024-01-31&fmt=csv&period=d&order=a"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    Deferred.return
      (Ok
         {|Date,Open,High,Low,Close,Adjusted Close,Volume
2024-01-01,100.0,101.0,99.0,100.5,100.5,1000|})
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = None;
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok csv_str -> (
      let lines = String.split_lines csv_str in
      match parse_lines lines with
      | Ok prices ->
          assert_equal ~printer:Int.to_string 1 (List.length prices);
          let expected_price =
            {
              Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
              open_price = 100.0;
              high_price = 101.0;
              low_price = 99.0;
              close_price = 100.5;
              volume = 1000;
              adjusted_close = 100.5;
            }
          in
          let actual_price = List.hd_exn prices in
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal expected_price actual_price)
      | Error err -> assert_failure (Status.show err))
  | Error _ -> assert_failure "Expected Ok result"

let test_get_historical_price_invalid_date_range _ =
  let mock_fetch _uri =
    Deferred.return
      (Error
         (Status.invalid_argument_error
            "start_date must be before or equal to end_date"))
  in
  let params : Eodhd.Http_params.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok _ -> assert_failure "Expected Error result"
  | Error status ->
      assert_equal ~printer:Status.show
        (Status.invalid_argument_error
           "start_date must be before or equal to end_date")
        status

let test_get_symbols _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/exchange-symbol-list/US?api_token=test_token&fmt=json"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data =
      In_channel.read_all "./data/get_symbol_list_response.json"
    in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  match result with
  | Ok symbols ->
      let expected_symbols =
        [ "0P000070L2"; "0P0000A2WI"; "ZZHGY"; "ZZZ"; "ZZZOF" ]
      in
      assert_equal
        ~printer:(fun xs -> String.concat ~sep:"," xs)
        expected_symbols symbols
  | Error err -> assert_failure (Status.show err)

let test_get_symbols_error _ =
  let mock_fetch _uri =
    Deferred.return (Error (Status.internal_error "API rate limit exceeded"))
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  match result with
  | Ok _ -> assert_failure "Expected Error result"
  | Error status ->
      assert_equal ~printer:Status.show
        (Status.internal_error "API rate limit exceeded")
        status

let test_get_symbols_malformed_data _ =
  let mock_fetch _uri =
    Deferred.return (Ok "This is not valid JSON data")
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  match result with
  | Ok _ -> assert_failure "Expected Error result"
  | Error status ->
      let msg = Status.show status in
      assert_bool "Error message should mention invalid JSON"
        (String.is_substring msg ~substring:"Invalid JSON")

let suite =
  "http_client_test"
  >::: [
         "get_historical_price" >:: test_get_historical_price;
         "get_historical_price_error" >:: test_get_historical_price_error;
         "get_historical_price_malformed_data"
         >:: test_get_historical_price_malformed_data;
         "get_historical_price_no_dates" >:: test_get_historical_price_no_dates;
         "get_historical_price_only_start_date"
         >:: test_get_historical_price_only_start_date;
         "get_historical_price_only_end_date"
         >:: test_get_historical_price_only_end_date;
         "get_historical_price_invalid_date_range"
         >:: test_get_historical_price_invalid_date_range;
         "get_symbols" >:: test_get_symbols;
         "get_symbols_error" >:: test_get_symbols_error;
         "get_symbols_malformed_data" >:: test_get_symbols_malformed_data;
       ]

let () = run_test_tt_main suite
