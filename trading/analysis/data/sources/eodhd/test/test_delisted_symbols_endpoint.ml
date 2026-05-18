(** Endpoint test for [Eodhd.Http_client.get_delisted_symbols].

    Stand-alone test file so the test-pattern audit
    (.claude/rules/test-patterns.md) is satisfied at the file level without
    requiring a full refactor of the legacy match-statement tests in
    {!Test_http_client}. *)

open Core
open Async
open OUnit2
open Matchers
open Eodhd.Http_client

let _symbol_with ~code ~asset_type : symbol_metadata matcher =
  all_of
    [
      field (fun m -> m.code) (equal_to code);
      field (fun m -> m.asset_type) (equal_to asset_type);
    ]

let test_get_delisted_symbols _ =
  (* The delisted endpoint reuses the same response schema as the live
     listings endpoint (Code/Name/Exchange/Type fields). The discriminator
     is the [delisted=1] query parameter, which flips the response from
     ~14k currently-listed to ~57k delisted entries. Asserts the URI
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
            _symbol_with ~code:"AAPL" ~asset_type:Eodhd.Asset_type.Common_stock;
            _symbol_with ~code:"SPY" ~asset_type:Eodhd.Asset_type.ETF;
            _symbol_with ~code:"0P000070L2"
              ~asset_type:Eodhd.Asset_type.Mutual_fund;
            _symbol_with ~code:"BABA" ~asset_type:Eodhd.Asset_type.ADR;
            _symbol_with ~code:"GSPC" ~asset_type:Eodhd.Asset_type.Index;
            _symbol_with ~code:"WTF"
              ~asset_type:
                (Eodhd.Asset_type.Other "Brand New Type EODHD Just Invented");
          ]))

let suite =
  "delisted_symbols_endpoint_test"
  >::: [ "get_delisted_symbols" >:: test_get_delisted_symbols ]

let () = run_test_tt_main suite
