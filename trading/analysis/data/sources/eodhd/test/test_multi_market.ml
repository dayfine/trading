(** Stubbed multi-market integration test for the M7.0 Track 2 EODHD expansion
    (LSE, TSE, ASX, HKEX, TSX).

    Each case parses a market-suffixed symbol via {!Exchange_resolver}, drives
    {!Http_client.get_historical_price} with the canonical EODHD symbol, and
    asserts:

    - the request URL embeds the canonical [TICKER.SUFFIX];
    - the parsed price bars round-trip cleanly (3 rows, plausible OHLC);
    - the currency tag from the resolver matches expectations.

    No network is involved — the fetch function is a fixture stub that reads the
    same shared price JSON used by [test_http_client.ml]. *)

open Core
open Async
open OUnit2
open Matchers
open Eodhd

let _make_stub ~expected_symbol_suffix =
 fun uri ->
  let uri_str = Uri.to_string uri in
  assert_bool
    (Printf.sprintf "URI should embed %S, got %S" expected_symbol_suffix uri_str)
    (String.is_substring uri_str ~substring:expected_symbol_suffix);
  let body = In_channel.read_all "./data/get_historical_price.json" in
  Deferred.return (Ok body)

let _params_for symbol : Http_client.historical_price_params =
  {
    symbol;
    start_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:1);
    end_date = Some (Date.create_exn ~y:2024 ~m:Month.Jan ~d:31);
    period = Types.Cadence.Daily;
  }

let _fetch_for_market input_symbol =
  let parsed =
    match Exchange_resolver.parse input_symbol with
    | Ok p -> p
    | Error err ->
        assert_failure
          (Printf.sprintf "resolver failed on %S: %s" input_symbol
             (Status.show err))
  in
  let canonical = Exchange_resolver.to_eodhd_symbol parsed in
  let stub = _make_stub ~expected_symbol_suffix:canonical in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Http_client.get_historical_price ~fetch:stub ~token:"test_token"
          ~params:(_params_for canonical) ())
  in
  (parsed, result)

(* Each fetched bar should have OHLC > 0 and high >= low. The fixture
   data are AAPL split-adjusted prices in the hundreds, so this is a
   loose plausibility gate; per-market specific assertions live above. *)
let _bar_is_plausible : Types.Daily_price.t matcher =
 fun bar ->
  assert_that bar
    (all_of
       [
         field
           (fun (b : Types.Daily_price.t) -> b.open_price)
           (gt (module Float_ord) 0.0);
         field
           (fun (b : Types.Daily_price.t) -> b.high_price)
           (gt (module Float_ord) 0.0);
         field
           (fun (b : Types.Daily_price.t) -> b.low_price)
           (gt (module Float_ord) 0.0);
         field
           (fun (b : Types.Daily_price.t) -> b.close_price)
           (gt (module Float_ord) 0.0);
         field
           (fun (b : Types.Daily_price.t) -> b.high_price -. b.low_price)
           (ge (module Float_ord) 0.0);
       ])

let _check_market ~input_symbol ~expected_exchange ~expected_currency =
  let parsed, result = _fetch_for_market input_symbol in
  assert_that parsed.exchange (equal_to expected_exchange);
  assert_that
    (Exchange_resolver.currency parsed.exchange)
    (equal_to expected_currency);
  assert_that result
    (is_ok_and_holds (all_of [ size_is 3; each _bar_is_plausible ]))

let test_lse _ =
  _check_market ~input_symbol:"BARC.LSE"
    ~expected_exchange:Exchange_resolver.LSE ~expected_currency:"GBP"

let test_tse _ =
  _check_market ~input_symbol:"7203.T" ~expected_exchange:Exchange_resolver.TSE
    ~expected_currency:"JPY"

let test_asx _ =
  _check_market ~input_symbol:"BHP.AU" ~expected_exchange:Exchange_resolver.ASX
    ~expected_currency:"AUD"

let test_hkex _ =
  _check_market ~input_symbol:"0700.HK"
    ~expected_exchange:Exchange_resolver.HKEX ~expected_currency:"HKD"

let test_tsx _ =
  _check_market ~input_symbol:"RY.TO" ~expected_exchange:Exchange_resolver.TSX
    ~expected_currency:"CAD"

let suite =
  "multi_market_test"
  >::: [
         "lse_barclays" >:: test_lse;
         "tse_toyota" >:: test_tse;
         "asx_bhp" >:: test_asx;
         "hkex_tencent" >:: test_hkex;
         "tsx_royal_bank" >:: test_tsx;
       ]

let () = run_test_tt_main suite
