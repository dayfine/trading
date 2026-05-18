open Core
open Async
open OUnit2
open Matchers
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
      active_through = None;
    };
    {
      Types.Daily_price.date = Date.of_string "2015-11-13";
      open_price = 613.6;
      high_price = 616.25;
      low_price = 592.06;
      close_price = 592.89;
      volume = 60785000;
      adjusted_close = 11.8578;
      active_through = None;
    };
    {
      Types.Daily_price.date = Date.of_string "2015-11-16";
      open_price = 591.23;
      high_price = 593.85;
      low_price = 583.07;
      close_price = 588.74;
      volume = 41905000;
      adjusted_close = 11.7748;
      active_through = None;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = None;
      end_date = None;
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = None;
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = None;
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      period = Types.Cadence.Daily;
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
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      period = Types.Cadence.Daily;
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

(* Asserts (code, asset_type) for one symbol_metadata entry. Composed into
   elements_are below. *)
let symbol_with ~code ~asset_type : symbol_metadata matcher =
  all_of
    [
      field (fun m -> m.code) (equal_to code);
      field (fun m -> m.asset_type) (equal_to asset_type);
    ]

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
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            symbol_with ~code:"AAPL" ~asset_type:Eodhd.Asset_type.Common_stock;
            symbol_with ~code:"SPY" ~asset_type:Eodhd.Asset_type.ETF;
            symbol_with ~code:"0P000070L2"
              ~asset_type:Eodhd.Asset_type.Mutual_fund;
            symbol_with ~code:"BABA" ~asset_type:Eodhd.Asset_type.ADR;
            symbol_with ~code:"GSPC" ~asset_type:Eodhd.Asset_type.Index;
            symbol_with ~code:"WTF"
              ~asset_type:
                (Eodhd.Asset_type.Other "Brand New Type EODHD Just Invented");
          ]))

let test_get_delisted_symbols _ =
  (* The delisted endpoint reuses the same response schema as the live
     listings endpoint (Code/Name/Exchange/Type fields). The discriminator
     is the [delisted=1] query parameter, which flips the response from
     ~14k currently-listed to ~57k delisted entries. We assert the URI
     carries that param + that the response parser produces the same
     [symbol_metadata] shape. *)
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/exchange-symbol-list/US?api_token=test_token&fmt=json&delisted=1"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data =
      In_channel.read_all "./data/get_symbol_list_response.json"
    in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_delisted_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            symbol_with ~code:"AAPL" ~asset_type:Eodhd.Asset_type.Common_stock;
            symbol_with ~code:"SPY" ~asset_type:Eodhd.Asset_type.ETF;
            symbol_with ~code:"0P000070L2"
              ~asset_type:Eodhd.Asset_type.Mutual_fund;
            symbol_with ~code:"BABA" ~asset_type:Eodhd.Asset_type.ADR;
            symbol_with ~code:"GSPC" ~asset_type:Eodhd.Asset_type.Index;
            symbol_with ~code:"WTF"
              ~asset_type:
                (Eodhd.Asset_type.Other "Brand New Type EODHD Just Invented");
          ]))

let test_get_symbols_extracts_name_and_exchange _ =
  let mock_fetch _uri =
    let test_data =
      In_channel.read_all "./data/get_symbol_list_response.json"
    in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field (fun m -> m.name) (equal_to "Apple Inc");
                field (fun m -> m.exchange) (equal_to "NASDAQ");
              ];
            all_of
              [
                field (fun m -> m.name) (equal_to "SPDR S&P 500");
                field (fun m -> m.exchange) (equal_to "NYSE ARCA");
              ];
            all_of
              [
                field (fun m -> m.name) (equal_to "Vanguard Total Stock Market");
                field (fun m -> m.exchange) (equal_to "PINK");
              ];
            all_of
              [
                field (fun m -> m.name) (equal_to "Alibaba ADR");
                field (fun m -> m.exchange) (equal_to "NYSE");
              ];
            all_of
              [
                field (fun m -> m.name) (equal_to "S&P 500 Index");
                field (fun m -> m.exchange) (equal_to "INDEX");
              ];
            all_of
              [
                field (fun m -> m.name) (equal_to "Mystery");
                field (fun m -> m.exchange) (equal_to "NASDAQ");
              ];
          ]))

let test_get_symbols_partitions_by_equity_like _ =
  let mock_fetch _uri =
    let test_data =
      In_channel.read_all "./data/get_symbol_list_response.json"
    in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_symbols ~fetch:mock_fetch ~token:"test_token" ())
  in
  let equity_like_codes metadata =
    metadata
    |> List.filter ~f:(fun m -> Eodhd.Asset_type.is_equity_like m.asset_type)
    |> List.map ~f:(fun m -> m.code)
  in
  (* AAPL (Common_stock) and BABA (ADR) are equity-like; SPY (ETF),
     0P000070L2 (Mutual_fund), GSPC (Index) and WTF (Other) are not. *)
  assert_that result
    (is_ok_and_holds
       (field equity_like_codes
          (elements_are [ equal_to "AAPL"; equal_to "BABA" ])))

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

let test_get_bulk_last_day _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod-bulk-last-day/US?api_token=test_token&fmt=json"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/eod_bulk_last_day.json" in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_bulk_last_day ~fetch:mock_fetch ~token:"test_token" ~exchange:"US"
          ())
  in
  match result with
  | Ok prices ->
      let expected_prices =
        [
          ( "AAAZX",
            {
              Types.Daily_price.date = Date.of_string "2025-05-30";
              open_price = 12.3;
              high_price = 12.3;
              low_price = 12.3;
              close_price = 12.3;
              volume = 0;
              adjusted_close = 12.3;
              active_through = None;
            } );
          ( "AABB",
            {
              Types.Daily_price.date = Date.of_string "2025-05-30";
              open_price = 0.029;
              high_price = 0.0304;
              low_price = 0.0281;
              close_price = 0.0304;
              volume = 5158473;
              adjusted_close = 0.0304;
              active_through = None;
            } );
          ( "AABCX",
            {
              Types.Daily_price.date = Date.of_string "2025-05-30";
              open_price = 15.51;
              high_price = 15.51;
              low_price = 15.51;
              close_price = 15.51;
              volume = 0;
              adjusted_close = 15.51;
              active_through = None;
            } );
        ]
      in
      assert_equal ~printer:Int.to_string 3 (List.length prices);
      List.iter2_exn prices expected_prices
        ~f:(fun
            (actual_symbol, actual_price) (expected_symbol, expected_price) ->
          assert_equal ~printer:Fn.id actual_symbol expected_symbol;
          assert_bool "Prices should be equal"
            (Types.Daily_price.equal actual_price expected_price))
  | Error err -> assert_failure (Status.show err)

let test_get_historical_price_weekly _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/eod/AAPL?api_token=test_token&to=2024-01-31&from=2024-01-01&fmt=json&period=w&order=a"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data = In_channel.read_all "./data/get_historical_price.json" in
    Deferred.return (Ok test_data)
  in
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol = "AAPL";
      start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
      end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
      period = Types.Cadence.Weekly;
    }
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_historical_price ~fetch:mock_fetch ~token:"test_token" ~params ())
  in
  match result with
  | Ok prices -> assert_equal ~printer:Int.to_string 3 (List.length prices)
  | Error err -> assert_failure (Status.show err)

let test_get_index_symbols _ =
  let mock_fetch uri =
    let actual_uri_str = Uri.to_string uri in
    let expected_uri_str =
      "https://eodhd.com/api/exchange-symbol-list/GSPC?api_token=test_token&fmt=json"
    in
    assert_equal ~printer:Fn.id actual_uri_str expected_uri_str;
    let test_data =
      In_channel.read_all "./data/get_symbol_list_response.json"
    in
    Deferred.return (Ok test_data)
  in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        get_index_symbols ~fetch:mock_fetch ~token:"test_token" ~index:"GSPC" ())
  in
  match result with
  | Ok symbols -> assert_bool "symbols not empty" (not (List.is_empty symbols))
  | Error err -> assert_failure (Status.show err)

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
         "get_historical_price_weekly" >:: test_get_historical_price_weekly;
         "get_index_symbols" >:: test_get_index_symbols;
         "get_symbols" >:: test_get_symbols;
         "get_delisted_symbols" >:: test_get_delisted_symbols;
         "get_symbols_extracts_name_and_exchange"
         >:: test_get_symbols_extracts_name_and_exchange;
         "get_symbols_partitions_by_equity_like"
         >:: test_get_symbols_partitions_by_equity_like;
         "get_symbols_error" >:: test_get_symbols_error;
         "get_symbols_malformed_data" >:: test_get_symbols_malformed_data;
         "get_bulk_last_day" >:: test_get_bulk_last_day;
       ]

let () = run_test_tt_main suite
