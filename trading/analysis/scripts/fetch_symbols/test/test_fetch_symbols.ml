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

let _stored_spy_bar : Types.Daily_price.t =
  {
    date = Date.of_string "2009-06-02";
    open_price = 94.62;
    high_price = 95.62;
    low_price = 94.23;
    close_price = 94.62;
    volume = 1_000_000;
    adjusted_close = 94.62;
    active_through = None;
  }

let _seed_stored ~data_dir symbol bars =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Ok storage -> ignore (Csv.Csv_storage.save storage bars : _ Result.t)
  | Error _ -> ()

let _spy_fetch_body =
  {|[{"date":"2009-06-02","open":94.62,"high":95.62,"low":87.53,"close":94.62,"adjusted_close":94.62,"volume":1000000}]|}

(* Run [fetch_one] for [symbol] and return its result with the [?warn] lines. *)
let _fetch_collecting ~data_dir ~body symbol =
  let warnings = ref [] in
  let warn line = warnings := line :: !warnings in
  let result =
    run_async (fun () ->
        Fetch_symbols_lib.fetch_one ~fetch:(mock_fetch ~body) ~warn
          ~token:"test_token" ~data_dir symbol)
  in
  (result, List.rev !warnings)

let _expected_spy_wick =
  "WICK SPY 2009-06-02 low observed=87.5300 reference=94.2300 (stored) \
   deviation=7.11%"

(* #3028 end to end: the stored copy must be read BEFORE the fetched bars
   overwrite it. A stored SPY bar with low 94.23 and a fetch of the same date
   with low 87.53 must reach [?warn] as one wick line; if the check ran after
   the save it would compare the bars with themselves and stay silent. *)
let test_fetch_one_warns_against_stored_copy _ =
  let data_dir = Fpath.v (Filename_unix.temp_dir "fetch_symbols_test_" "") in
  _seed_stored ~data_dir "SPY" [ _stored_spy_bar ];
  assert_that
    (_fetch_collecting ~data_dir ~body:_spy_fetch_body "SPY")
    (equal_to ((Ok "SPY" : (string, string) Result.t), [ _expected_spy_wick ]))

let suite =
  "fetch_symbols"
  >::: [
         "fetch_one returns Error on empty bar list without raising"
         >:: test_fetch_one_empty_bars;
         "fetch_one returns Ok on non-empty bar list"
         >:: test_fetch_one_non_empty_bars;
         "fetch_one warns against the stored copy (#3028)"
         >:: test_fetch_one_warns_against_stored_copy;
       ]

let () = run_test_tt_main suite
