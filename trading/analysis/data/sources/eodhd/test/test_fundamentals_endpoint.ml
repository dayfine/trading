open Core
open Async
open OUnit2
open Matchers
open Eodhd

(* Driver: synchronous wrapper around the async endpoint, with an injectable
   stub fetcher. *)
let _run_get_fundamentals ~fetch ~symbol () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Fundamentals_endpoint.get_fundamentals ~fetch ~token:"test_token" ~symbol
        ())

let _fixture_fetch ~expected_uri ~body_path : Http_client.fetch_fn =
 fun uri ->
  assert_that (Uri.to_string uri) (equal_to expected_uri);
  Deferred.return (Ok (In_channel.read_all body_path))

let test_get_fundamentals _ =
  let fetch =
    _fixture_fetch
      ~expected_uri:
        "https://eodhd.com/api/fundamentals/AAPL?api_token=test_token&filter=General%2CSharesStats&fmt=json"
      ~body_path:"./data/get_fundamentals_response.json"
  in
  let result = _run_get_fundamentals ~fetch ~symbol:"AAPL" () in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.symbol)
              (equal_to "AAPL");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.name)
              (equal_to "Apple Inc");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.sector)
              (equal_to "Technology");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.industry)
              (equal_to "Consumer Electronics");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.exchange)
              (equal_to "NASDAQ");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.market_cap)
              (float_equal 2800000000000.0);
            field
              (fun (f : Fundamentals_endpoint.fundamentals) ->
                f.shares_outstanding)
              (float_equal 14687356000.0);
          ]))

(* When the response omits the [SharesStats] section entirely (some
   thinly-covered listings on EODHD), [shares_outstanding] falls back to
   [0.0]. Downstream consumers (e.g. shares_outstanding_enrichment) treat
   0.0 as a sentinel for "no fundamentals data" and skip the symbol. *)
let test_get_fundamentals_missing_shares_stats _ =
  let fetch _uri =
    Deferred.return
      (Ok
         (In_channel.read_all
            "./data/get_fundamentals_response_no_shares_stats.json"))
  in
  let result = _run_get_fundamentals ~fetch ~symbol:"OBSC" () in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.symbol)
              (equal_to "OBSC");
            field
              (fun (f : Fundamentals_endpoint.fundamentals) ->
                f.shares_outstanding)
              (float_equal 0.0);
            field
              (fun (f : Fundamentals_endpoint.fundamentals) -> f.market_cap)
              (float_equal 0.0);
          ]))

let test_get_fundamentals_error _ =
  let fetch _uri =
    Deferred.return (Error (Status.internal_error "API rate limit exceeded"))
  in
  let result = _run_get_fundamentals ~fetch ~symbol:"AAPL" () in
  assert_that result is_error

let suite =
  "fundamentals_endpoint_test"
  >::: [
         "get_fundamentals" >:: test_get_fundamentals;
         "get_fundamentals_missing_shares_stats"
         >:: test_get_fundamentals_missing_shares_stats;
         "get_fundamentals_error" >:: test_get_fundamentals_error;
       ]

let () = run_test_tt_main suite
