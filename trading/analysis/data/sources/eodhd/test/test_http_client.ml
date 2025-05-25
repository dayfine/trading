open Core
open Async
open OUnit2
open Eodhd.Http_client

(* data from /trading/analysis/data/sources/eodhd/test/data/get_historical_price.json *)
let expected_prices =
  [
    {
      Types.Daily_price.date = Date.of_string "2015-11-12";
      open_price = 621.84;
      high_price = 624.59;
      low_price = 612.96;
      close_price = 614.68;
      volume = 29640000;
      adjusted_close = 12.2936;
    };
    {
      Types.Daily_price.date = Date.of_string "2015-11-13";
      open_price = 613.6;
      high_price = 616.25;
      low_price = 592.06;
      close_price = 592.89;
      volume = 60785000;
      adjusted_close = 11.8578;
    };
    {
      Types.Daily_price.date = Date.of_string "2015-11-16";
      open_price = 591.23;
      high_price = 593.85;
      low_price = 583.07;
      close_price = 588.74;
      volume = 41905000;
      adjusted_close = 11.7748;
    };
  ]

let test_get_historical_price _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=2024-01-31&from=2024-01-01&fmt=json&period=d&order=a"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/get_historical_price.json" in
    Deferred.return (Ok test_data)
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
  | Ok prices ->
      assert_equal ~printer:Int.to_string 3 (List.length prices);
      List.iter2_exn prices expected_prices ~f:(fun actual expected ->
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal actual expected))
  | Error err -> assert_failure (Status.show err)

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
  let mock_fetch _uri = Deferred.return (Ok "This is not valid JSON data") in
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
      let msg = Status.show status in
      assert_bool "Error message should mention invalid JSON"
        (String.is_substring msg ~substring:"Invalid JSON")

let test_get_historical_price_no_dates _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let today = Date.today ~zone:Time_float.Zone.utc in
    let expected_uri_str =
      Printf.sprintf
        "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=%s&fmt=json&period=d&order=a"
        (Date.to_string today)
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/get_historical_price.json" in
    Deferred.return (Ok test_data)
  in
  let params : Eodhd.Http_params.historical_price_params =
    { symbol = "AAPL"; start_date = None; end_date = None }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok prices ->
      assert_equal ~printer:Int.to_string 3 (List.length prices);
      List.iter2_exn prices expected_prices ~f:(fun actual expected ->
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal actual expected))
  | Error err -> assert_failure (Status.show err)

let test_get_historical_price_only_start_date _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let today = Date.today ~zone:Time_float.Zone.utc in
    let expected_uri_str =
      Printf.sprintf
        "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=%s&from=2024-01-01&fmt=json&period=d&order=a"
        (Date.to_string today)
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/get_historical_price.json" in
    Deferred.return (Ok test_data)
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
  | Ok prices ->
      assert_equal ~printer:Int.to_string 3 (List.length prices);
      List.iter2_exn prices expected_prices ~f:(fun actual expected ->
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal actual expected))
  | Error err -> assert_failure (Status.show err)

let test_get_historical_price_only_end_date _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=2024-01-31&fmt=json&period=d&order=a"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/get_historical_price.json" in
    Deferred.return (Ok test_data)
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
  | Ok prices ->
      assert_equal ~printer:Int.to_string 3 (List.length prices);
      List.iter2_exn prices expected_prices ~f:(fun actual expected ->
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal actual expected))
  | Error err -> assert_failure (Status.show err)

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
  let mock_fetch _uri = Deferred.return (Ok "This is not valid JSON data") in
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
