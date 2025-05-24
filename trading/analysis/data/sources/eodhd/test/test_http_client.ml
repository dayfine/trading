open Core
open Async
open OUnit2
open Eodhd.Http_client

let parse_price_data csv_str =
  let lines = String.split_lines csv_str in
  match lines with
  | _header :: data_lines ->
      List.map data_lines ~f:(fun line ->
          let fields = String.split line ~on:',' in
          match fields with
          | [ date_str; open_str; high_str; low_str; close_str; volume_str ] ->
              {
                Types.Daily_price.date = Date.of_string date_str;
                open_price = Float.of_string open_str;
                high_price = Float.of_string high_str;
                low_price = Float.of_string low_str;
                close_price = Float.of_string close_str;
                volume = int_of_float (Float.of_string volume_str);
                adjusted_close = Float.of_string close_str;
              }
          | _ -> failwith "Invalid CSV format")
  | _ -> []

let test_get_historical_price _ =
  let mock_fetch uri =
    let expected_uri =
      Uri.make ~scheme:"https" ~host:"eodhd.com" ~path:"/api/eod/AAPL"
        ~query:
          [
            ("fmt", [ "csv" ]);
            ("period", [ "d" ]);
            ("order", [ "a" ]);
            ("from", [ "2024-01-01" ]);
            ("to", [ "2024-01-31" ]);
            ("api_token", [ "test_token" ]);
          ]
        ()
    in
    assert_equal ~printer:Uri.to_string expected_uri uri;
    Deferred.return
      (Ok "Date,Open,High,Low,Close,Volume\n2024-01-01,100,101,99,100.5,1000")
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
  | Ok csv_str ->
      let prices = parse_price_data csv_str in
      assert_equal ~printer:Int.to_string 1 (List.length prices);
      let price = List.hd_exn prices in
      assert_equal ~printer:Date.to_string
        (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1)
        price.Types.Daily_price.date;
      assert_equal ~printer:Float.to_string 100.0 price.open_price;
      assert_equal ~printer:Float.to_string 101.0 price.high_price;
      assert_equal ~printer:Float.to_string 99.0 price.low_price;
      assert_equal ~printer:Float.to_string 100.5 price.close_price;
      assert_equal ~printer:string_of_int 1000 price.volume;
      assert_equal ~printer:Float.to_string 100.5 price.adjusted_close
  | Error _ -> assert_failure "Expected Ok result"

let suite =
  "http_client_test"
  >::: [ "get_historical_price" >:: test_get_historical_price ]

let () = run_test_tt_main suite
