open Core
open Async
open OUnit2
open Matchers
module Lib = Fetch_corporate_actions_lib
module CA = Corporate_actions

let _run_async f = Thread_safe.block_on_async_exn f
let _fresh_dir () = Fpath.v (Filename_unix.temp_dir "fetch_corp_act_" "")
let _d = Date.of_string

(* Stub HTTP layer keyed on the request path: AAPL has two dividends and a
   split, XYZ has none, ERR fails at the transport. Records every path. *)
let _stub_fetch ~requested uri =
  let path = Uri.path uri in
  requested := path :: !requested;
  let body =
    match path with
    | "/api/div/AAPL.US" ->
        Ok
          {|[{"date":"2024-02-09","value":0.24,"unadjustedValue":0.96},{"date":"2024-05-10","value":0.25}]|}
    | "/api/splits/AAPL.US" ->
        Ok {|[{"date":"2020-08-31","split":"4.000000/1.000000"}]|}
    | "/api/div/XYZ.US" | "/api/splits/XYZ.US" -> Ok "[]"
    | _ -> Error (Status.internal_error ("stub: no route for " ^ path))
  in
  return body

let _config data_dir : Lib.config =
  { data_dir; refresh = false; sleep_ms = 0; parallel = 1 }

let test_eodhd_ticker _ =
  assert_that
    (List.map [ "AAPL"; "APC_old"; "GSPC.INDX"; "BRK.B" ] ~f:Lib.eodhd_ticker)
    (equal_to
       [ ("AAPL", "US"); ("APC_old", "US"); ("GSPC", "INDX"); ("BRK", "B") ])

let test_fetch_symbol_with_events _ =
  let data_dir = _fresh_dir () in
  let requested = ref [] in
  let outcome =
    _run_async (fun () ->
        Lib.fetch_symbol ~fetch:(_stub_fetch ~requested) ~token:"t" ~data_dir
          "AAPL")
  in
  assert_that
    ( outcome,
      CA.read_dividends ~data_dir "AAPL",
      CA.read_splits ~data_dir "AAPL" )
    (all_of
       [
         field
           (fun (o, _, _) -> o)
           (equal_to (Lib.Fetched { dividends = 2; splits = 1 }));
         field
           (fun (_, d, _) -> d)
           (is_ok_and_holds
              (elements_are
                 [
                   equal_to
                     ({
                        ex_date = _d "2024-02-09";
                        unadjusted_amount = Some 0.96;
                        adjusted_amount = 0.24;
                      }
                       : CA.dividend);
                   equal_to
                     ({
                        ex_date = _d "2024-05-10";
                        unadjusted_amount = None;
                        adjusted_amount = 0.25;
                      }
                       : CA.dividend);
                 ]));
         field
           (fun (_, _, s) -> s)
           (is_ok_and_holds
              (elements_are
                 [
                   equal_to
                     ({ date = _d "2020-08-31"; factor = 4.0 } : CA.split);
                 ]));
       ])

let test_fetch_symbol_empty _ =
  let data_dir = _fresh_dir () in
  let requested = ref [] in
  let outcome =
    _run_async (fun () ->
        Lib.fetch_symbol ~fetch:(_stub_fetch ~requested) ~token:"t" ~data_dir
          "XYZ")
  in
  assert_that
    (outcome, CA.read_dividends ~data_dir "XYZ", CA.read_splits ~data_dir "XYZ")
    (all_of
       [
         field (fun (o, _, _) -> o) (equal_to Lib.Empty);
         field (fun (_, d, _) -> d) (is_ok_and_holds (size_is 0));
         field (fun (_, _, s) -> s) (is_ok_and_holds (size_is 0));
       ])

let test_fetch_symbol_error_writes_nothing _ =
  let data_dir = _fresh_dir () in
  let requested = ref [] in
  let outcome =
    _run_async (fun () ->
        Lib.fetch_symbol ~fetch:(_stub_fetch ~requested) ~token:"t" ~data_dir
          "ERR")
  in
  assert_that
    (outcome, CA.has_both_files ~data_dir "ERR")
    (pair
       (matching ~msg:"Expected Failed"
          (function Lib.Failed msg -> Some msg | _ -> None)
          (contains_substring "dividends"))
       (equal_to false))

let test_run_counts_and_skips _ =
  let data_dir = _fresh_dir () in
  let requested = ref [] in
  let fetch = _stub_fetch ~requested in
  let symbols = [ "AAPL"; "XYZ"; "ERR" ] in
  let log _ = () in
  let first =
    _run_async (fun () ->
        Lib.run ~fetch ~log ~token:"t" (_config data_dir) symbols)
  in
  requested := [];
  let second =
    _run_async (fun () ->
        Lib.run ~fetch ~log ~token:"t" (_config data_dir) symbols)
  in
  assert_that
    (first, second, List.rev !requested)
    (all_of
       [
         field
           (fun (f, _, _) -> f)
           (equal_to
              ({ ok = 1; empty = 1; error = 1; skipped = 0 } : Lib.summary));
         field
           (fun (_, s, _) -> s)
           (equal_to
              ({ ok = 0; empty = 0; error = 1; skipped = 2 } : Lib.summary));
         field
           (fun (_, _, r) -> r)
           (equal_to [ "/api/div/ERR.US"; "/api/splits/ERR.US" ]);
       ])

let test_run_refresh_refetches _ =
  let data_dir = _fresh_dir () in
  let requested = ref [] in
  let fetch = _stub_fetch ~requested in
  let log _ = () in
  let config = { (_config data_dir) with refresh = true } in
  let _first : Lib.summary =
    _run_async (fun () -> Lib.run ~fetch ~log ~token:"t" config [ "AAPL" ])
  in
  let second =
    _run_async (fun () -> Lib.run ~fetch ~log ~token:"t" config [ "AAPL" ])
  in
  assert_that second
    (equal_to ({ ok = 1; empty = 0; error = 0; skipped = 0 } : Lib.summary))

let test_parse_symbols _ =
  assert_that
    (Lib.parse_symbols "AAPL\n\n# comment\n  MSFT  \nAPC_old\n")
    (equal_to [ "AAPL"; "MSFT"; "APC_old" ])

let _touch path =
  Core_unix.mkdir_p (Fpath.to_string (Fpath.parent path));
  Out_channel.write_all (Fpath.to_string path) ~data:""

let test_symbols_in_data_dir _ =
  let data_dir = _fresh_dir () in
  _touch Fpath.(data_dir / "A" / "L" / "AAPL" / "data.csv");
  _touch Fpath.(data_dir / "A" / "d" / "APC_old" / "data.csv");
  _touch Fpath.(data_dir / "M" / "T" / "MSFT" / "data.metadata.sexp");
  _touch Fpath.(data_dir / "A" / "L" / "manifest.sexp");
  assert_that
    (Lib.symbols_in_data_dir data_dir)
    (equal_to [ "AAPL"; "APC_old" ])

let test_render_summary _ =
  assert_that
    (Lib.render_summary { ok = 3; empty = 2; error = 1; skipped = 4 })
    (all_of
       [
         contains_substring "ok (events)     : 3";
         contains_substring "empty (none)    : 2";
         contains_substring "error           : 1";
         contains_substring "skipped (cached): 4";
         contains_substring "total           : 10";
       ])

let suite =
  "fetch_corporate_actions"
  >::: [
         "eodhd_ticker" >:: test_eodhd_ticker;
         "fetch_symbol_with_events" >:: test_fetch_symbol_with_events;
         "fetch_symbol_empty" >:: test_fetch_symbol_empty;
         "fetch_symbol_error_writes_nothing"
         >:: test_fetch_symbol_error_writes_nothing;
         "run_counts_and_skips" >:: test_run_counts_and_skips;
         "run_refresh_refetches" >:: test_run_refresh_refetches;
         "parse_symbols" >:: test_parse_symbols;
         "symbols_in_data_dir" >:: test_symbols_in_data_dir;
         "render_summary" >:: test_render_summary;
       ]

let () = run_test_tt_main suite
