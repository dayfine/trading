open Core
open Async
open OUnit2
open Matchers
open Eodhd

let _run_get_dividends ?exchange ~fetch () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Dividends_endpoint.get_dividends ?exchange ~fetch ~token:"test_token"
        ~symbol:"KO" ())

let _stub_fetch ~expected_uri ~body_path : Http_client.fetch_fn =
 fun uri ->
  assert_that (Uri.to_string uri) (equal_to expected_uri);
  Deferred.return (Ok (In_channel.read_all body_path))

let test_get_dividends_happy_path _ =
  let fetch =
    _stub_fetch
      ~expected_uri:
        "https://eodhd.com/api/div/KO.US?api_token=test_token&fmt=json"
      ~body_path:"./data/get_dividends_response.json"
  in
  let result = _run_get_dividends ~fetch () in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            equal_to
              ({ date = Date.of_string "2024-03-15"; amount = 0.485 }
                : Dividends_endpoint.dividend);
            equal_to
              ({ date = Date.of_string "2024-06-14"; amount = 0.485 }
                : Dividends_endpoint.dividend);
            equal_to
              ({ date = Date.of_string "2024-09-13"; amount = 0.485 }
                : Dividends_endpoint.dividend);
          ]))

let test_get_dividends_string_amount _ =
  (* Some endpoints return amounts as strings — must be tolerated. *)
  let body = {|[ { "date": "2024-06-14", "value": "0.485" } ]|} in
  let fetch _uri = Deferred.return (Ok body) in
  let result = _run_get_dividends ~fetch () in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            equal_to
              ({ date = Date.of_string "2024-06-14"; amount = 0.485 }
                : Dividends_endpoint.dividend);
          ]))

let test_get_dividends_empty_response _ =
  let fetch _uri = Deferred.return (Ok "[]") in
  let result = _run_get_dividends ~fetch () in
  assert_that result (is_ok_and_holds (equal_to []))

let test_get_dividends_http_error _ =
  let fetch _uri = Deferred.return (Error (Status.internal_error "5xx")) in
  let result = _run_get_dividends ~fetch () in
  assert_that result (is_error_with Status.Internal)

let test_get_dividends_malformed_json _ =
  let fetch _uri = Deferred.return (Ok "}{") in
  let result = _run_get_dividends ~fetch () in
  assert_that result (is_error_with Status.Invalid_argument)

let test_get_dividends_missing_value_field _ =
  let body = {|[ { "date": "2024-06-14" } ]|} in
  let fetch _uri = Deferred.return (Ok body) in
  let result = _run_get_dividends ~fetch () in
  assert_that result (is_error_with Status.NotFound)

let suite =
  "dividends_endpoint"
  >::: [
         "get_dividends_happy_path" >:: test_get_dividends_happy_path;
         "get_dividends_string_amount" >:: test_get_dividends_string_amount;
         "get_dividends_empty_response" >:: test_get_dividends_empty_response;
         "get_dividends_http_error" >:: test_get_dividends_http_error;
         "get_dividends_malformed_json" >:: test_get_dividends_malformed_json;
         "get_dividends_missing_value_field"
         >:: test_get_dividends_missing_value_field;
       ]

let () = run_test_tt_main suite
