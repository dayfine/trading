open Core
open Async
open OUnit2
open Matchers

(* Mock fetch function for the EODHD client that returns a fixed JSON body
   regardless of the requested URI. *)
let mock_fetch ~body _uri = Deferred.return (Ok body)

(* Run a Deferred computation synchronously for test assertions. *)
let run_async f = Async.Thread_safe.block_on_async_exn f

let test_fetch_one_empty_bars _ =
  (* EODHD returns an empty JSON array when the symbol has no bars (observed
     with indices like UKX.INDX on certain date ranges). The fetch script
     must not raise — it should return [Error symbol] and continue. *)
  let fetch = mock_fetch ~body:"[]" in
  let data_dir = Fpath.v (Filename_unix.temp_dir "fetch_symbols_test_" "") in
  let result =
    run_async (fun () ->
        Fetch_symbols_lib.fetch_one ~fetch ~token:"test_token" ~data_dir
          "UKX.INDX")
  in
  assert_that result (equal_to (Error "UKX.INDX"))

let test_fetch_one_non_empty_bars _ =
  (* Sanity check: with a non-empty response, the fetch succeeds and
     returns [Ok symbol]. Uses the same JSON fixture as the EODHD client
     tests. *)
  let body =
    {|[{"date":"2024-01-02","open":100.0,"high":101.0,"low":99.0,"close":100.5,"adjusted_close":100.5,"volume":1000000}]|}
  in
  let fetch = mock_fetch ~body in
  let data_dir = Fpath.v (Filename_unix.temp_dir "fetch_symbols_test_" "") in
  let result =
    run_async (fun () ->
        Fetch_symbols_lib.fetch_one ~fetch ~token:"test_token" ~data_dir "AAPL")
  in
  assert_that result (equal_to (Ok "AAPL"))

let suite =
  "fetch_symbols"
  >::: [
         "fetch_one returns Error on empty bar list without raising"
         >:: test_fetch_one_empty_bars;
         "fetch_one returns Ok on non-empty bar list"
         >:: test_fetch_one_non_empty_bars;
       ]

let () = run_test_tt_main suite
