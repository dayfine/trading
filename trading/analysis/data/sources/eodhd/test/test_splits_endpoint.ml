open Core
open Async
open OUnit2
open Matchers
open Eodhd

(* Driver: synchronous wrapper around the async endpoint, with an injectable
   stub fetcher. Keeps each test compact. *)
let _run_get_splits ?exchange ~fetch () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Splits_endpoint.get_splits ?exchange ~fetch ~token:"test_token"
        ~symbol:"AAPL" ())

(* Build a stub fetch_fn that asserts the URI matches what the endpoint should
   produce, then returns a fixture-backed JSON body. *)
let _stub_fetch ~expected_uri ~body_path : Http_client.fetch_fn =
 fun uri ->
  assert_that (Uri.to_string uri) (equal_to expected_uri);
  Deferred.return (Ok (In_channel.read_all body_path))

let test_get_splits_happy_path _ =
  let fetch =
    _stub_fetch
      ~expected_uri:
        "https://eodhd.com/api/splits/AAPL.US?api_token=test_token&fmt=json"
      ~body_path:"./data/get_splits_response.json"
  in
  let result = _run_get_splits ~fetch () in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            equal_to
              ({ date = Date.of_string "2014-06-09"; factor = 7.0 }
                : Splits_endpoint.split);
            equal_to
              ({ date = Date.of_string "2020-08-31"; factor = 4.0 }
                : Splits_endpoint.split);
          ]))

let test_get_splits_uses_custom_exchange _ =
  let fetch =
    _stub_fetch
      ~expected_uri:
        "https://eodhd.com/api/splits/AAPL.NASDAQ?api_token=test_token&fmt=json"
      ~body_path:"./data/get_splits_response.json"
  in
  let result = _run_get_splits ~exchange:"NASDAQ" ~fetch () in
  assert_that result (is_ok_and_holds (size_is 2))

let test_get_splits_empty_response _ =
  let fetch _uri = Deferred.return (Ok "[]") in
  let result = _run_get_splits ~fetch () in
  assert_that result (is_ok_and_holds (equal_to []))

let test_get_splits_http_error _ =
  let fetch _uri =
    Deferred.return (Error (Status.internal_error "API rate limit exceeded"))
  in
  let result = _run_get_splits ~fetch () in
  assert_that result (is_error_with Status.Internal)

let test_get_splits_malformed_json _ =
  let fetch _uri = Deferred.return (Ok "not json at all (") in
  let result = _run_get_splits ~fetch () in
  assert_that result (is_error_with Status.Invalid_argument)

let test_get_splits_missing_field _ =
  (* Row missing the "split" field: must surface an Invalid_argument. *)
  let body = {|[ { "date": "2020-08-31" } ]|} in
  let fetch _uri = Deferred.return (Ok body) in
  let result = _run_get_splits ~fetch () in
  assert_that result (is_error_with Status.NotFound)

let test_get_splits_zero_denominator _ =
  let body = {|[ { "date": "2020-08-31", "split": "4.0/0.0" } ]|} in
  let fetch _uri = Deferred.return (Ok body) in
  let result = _run_get_splits ~fetch () in
  assert_that result (is_error_with Status.Invalid_argument)

let suite =
  "splits_endpoint"
  >::: [
         "get_splits_happy_path" >:: test_get_splits_happy_path;
         "get_splits_uses_custom_exchange"
         >:: test_get_splits_uses_custom_exchange;
         "get_splits_empty_response" >:: test_get_splits_empty_response;
         "get_splits_http_error" >:: test_get_splits_http_error;
         "get_splits_malformed_json" >:: test_get_splits_malformed_json;
         "get_splits_missing_field" >:: test_get_splits_missing_field;
         "get_splits_zero_denominator" >:: test_get_splits_zero_denominator;
       ]

let () = run_test_tt_main suite
