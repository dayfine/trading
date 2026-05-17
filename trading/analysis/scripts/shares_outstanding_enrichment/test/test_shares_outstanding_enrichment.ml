open Core
open OUnit2
open Matchers
open Shares_outstanding_enrichment_lib

(* ---- Fixtures ----

   Top-level builders keep the test bodies flat (per the nesting linter's
   indentation-as-depth heuristic) and let the matcher assertions read at
   depth {1,2}. *)

let _sample_date = Date.create_exn ~y:2026 ~m:May ~d:17

let _make_fundamentals ~symbol ~shares_outstanding :
    Eodhd.Fundamentals_endpoint.fundamentals =
  {
    symbol;
    name = symbol ^ " Inc";
    sector = "Technology";
    industry = "Software";
    market_cap = 0.0;
    exchange = "NASDAQ";
    shares_outstanding;
  }

let _make_entry ~symbol ~shares_outstanding : entry =
  { symbol; shares_outstanding }

let _sample_endpoints =
  [ ("/api/fundamentals/{symbol}?filter=General,SharesStats", _sample_date) ]

let _join_with_defaults fundamentals =
  join ~fundamentals ~generated_at:_sample_date
    ~source_endpoints:_sample_endpoints

(* Matcher helpers — single [field] extractors composed via [all_of]. *)

let _generated_at_is d = field (fun (t : t) -> t.generated_at) (equal_to d)

let _source_endpoints_match expected =
  field (fun (t : t) -> t.source_endpoints) (elements_are expected)

let _entries_match per_entry =
  field (fun (t : t) -> t.entries) (elements_are per_entry)

(* ---- Pure join — sorts entries by symbol ascending ---- *)

(* Unsorted input fixtures, top-level to keep the test body flat. *)
let _unsorted_three_fundamentals =
  [
    _make_fundamentals ~symbol:"MSFT" ~shares_outstanding:7_500_000_000.0;
    _make_fundamentals ~symbol:"AAPL" ~shares_outstanding:14_687_356_000.0;
    _make_fundamentals ~symbol:"GOOG" ~shares_outstanding:12_300_000_000.0;
  ]

let _expected_sorted_entries =
  [
    equal_to (_make_entry ~symbol:"AAPL" ~shares_outstanding:14_687_356_000.0);
    equal_to (_make_entry ~symbol:"GOOG" ~shares_outstanding:12_300_000_000.0);
    equal_to (_make_entry ~symbol:"MSFT" ~shares_outstanding:7_500_000_000.0);
  ]

let _expected_endpoints =
  [
    equal_to
      ("/api/fundamentals/{symbol}?filter=General,SharesStats", _sample_date);
  ]

let test_join_sorts_entries_by_symbol_ascending _ =
  let result = _join_with_defaults _unsorted_three_fundamentals in
  assert_that result
    (all_of
       [
         _generated_at_is _sample_date;
         _source_endpoints_match _expected_endpoints;
         _entries_match _expected_sorted_entries;
       ])

(* ---- Pure join — drops symbols with zero or negative shares ----

   The .mli contract: shares_outstanding = 0.0 is the "no fundamentals data"
   sentinel emitted by [Fundamentals_endpoint.get_fundamentals] when the
   [SharesStats] section is absent. Such entries must NOT appear in the
   output. *)

let _mixed_shares_fundamentals =
  [
    _make_fundamentals ~symbol:"AAPL" ~shares_outstanding:14_687_356_000.0;
    _make_fundamentals ~symbol:"NOSHARES" ~shares_outstanding:0.0;
    _make_fundamentals ~symbol:"MSFT" ~shares_outstanding:7_500_000_000.0;
    _make_fundamentals ~symbol:"NEGSHARES" ~shares_outstanding:(-1.0);
  ]

let _expected_positive_entries =
  [
    equal_to (_make_entry ~symbol:"AAPL" ~shares_outstanding:14_687_356_000.0);
    equal_to (_make_entry ~symbol:"MSFT" ~shares_outstanding:7_500_000_000.0);
  ]

let test_join_drops_zero_shares_entries _ =
  let result = _join_with_defaults _mixed_shares_fundamentals in
  assert_that result (_entries_match _expected_positive_entries)

(* ---- Empty input ---- *)

let test_join_empty_input_yields_empty_entries _ =
  let result = _join_with_defaults [] in
  assert_that result (_entries_match [])

(* ---- Duplicate-symbol guard ----

   .mli line: "If the same symbol appears multiple times in [fundamentals],
   the first occurrence wins." Pin so a future regression (e.g. switching to
   "last wins") is caught deterministically. *)

let test_join_first_occurrence_wins_on_duplicate _ =
  let result =
    _join_with_defaults
      [
        _make_fundamentals ~symbol:"AAPL" ~shares_outstanding:1_000.0;
        _make_fundamentals ~symbol:"AAPL" ~shares_outstanding:2_000.0;
      ]
  in
  assert_that result
    (_entries_match
       [ equal_to (_make_entry ~symbol:"AAPL" ~shares_outstanding:1_000.0) ])

(* ---- Round-trip save / load ---- *)

let _with_temp_path ~name ~f =
  let dir = Filename_unix.temp_dir "shares_outstanding_test" "" in
  let path = Fpath.v Filename.(concat dir name) in
  Exn.protect
    ~f:(fun () -> f path)
    ~finally:(fun () ->
      (try Sys_unix.remove (Fpath.to_string path) with _ -> ());
      try Core_unix.rmdir dir with _ -> ())

let test_round_trip_save_load _ =
  let original =
    _join_with_defaults
      [
        _make_fundamentals ~symbol:"AAPL" ~shares_outstanding:14_687_356_000.0;
        _make_fundamentals ~symbol:"MSFT" ~shares_outstanding:7_500_000_000.0;
        _make_fundamentals ~symbol:"GOOG" ~shares_outstanding:12_300_000_000.0;
      ]
  in
  let assertion =
    _with_temp_path ~name:"shares_outstanding.sexp" ~f:(fun path ->
        match save original ~path with
        | Error err -> assert_failure ("save failed: " ^ Status.show err)
        | Ok () -> load ~path)
  in
  assert_that assertion (is_ok_and_holds (equal_to original))

let suite =
  "shares_outstanding_enrichment_test"
  >::: [
         "join_sorts_entries_by_symbol_ascending"
         >:: test_join_sorts_entries_by_symbol_ascending;
         "join_drops_zero_shares_entries"
         >:: test_join_drops_zero_shares_entries;
         "join_empty_input_yields_empty_entries"
         >:: test_join_empty_input_yields_empty_entries;
         "join_first_occurrence_wins_on_duplicate"
         >:: test_join_first_occurrence_wins_on_duplicate;
         "round_trip_save_load" >:: test_round_trip_save_load;
       ]

let () = run_test_tt_main suite
