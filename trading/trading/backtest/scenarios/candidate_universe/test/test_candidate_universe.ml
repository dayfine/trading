open Core
open OUnit2
open Matchers
module Universe_file = Scenario_lib.Universe_file

(* A trimmed all-eligible header: the real one carries 19 columns, but the
   parser locates 'symbol' by name, so the test asserts that property rather
   than reproducing the full width. *)
let _header = "signal_date,symbol,side,entry_price,return_pct"
let _csv rows = String.concat ~sep:"\n" (_header :: rows)

let test_extracts_distinct_symbols _ =
  let contents =
    _csv
      [
        "2019-01-04,AAPL,LONG,100.0,5.0";
        "2019-02-01,MSFT,LONG,200.0,3.0";
        "2019-03-01,AAPL,LONG,110.0,-2.0";
      ]
  in
  assert_that
    (Candidate_universe.symbols_of_all_eligible_csv ~contents |> Set.to_list)
    (elements_are [ equal_to "AAPL"; equal_to "MSFT" ])

let test_header_only_file_is_empty _ =
  assert_that
    (Candidate_universe.symbols_of_all_eligible_csv ~contents:_header
    |> Set.to_list)
    (size_is 0)

(* The column is found by name, not position — a capture whose columns were
   reordered upstream must still read the symbol, because a positional parser
   would silently return entry prices as symbols. *)
let test_symbol_column_located_by_name _ =
  let contents =
    String.concat ~sep:"\n"
      [ "side,return_pct,symbol,signal_date"; "LONG,5.0,NVDA,2019-01-04" ]
  in
  assert_that
    (Candidate_universe.symbols_of_all_eligible_csv ~contents |> Set.to_list)
    (elements_are [ equal_to "NVDA" ])

let test_missing_symbol_column_raises _ =
  assert_raises
    (Failure
       "candidate_universe: all-eligible CSV header has no 'symbol' column — \
        input is not an all-eligible capture") (fun () ->
      Candidate_universe.symbols_of_all_eligible_csv
        ~contents:"signal_date,side,entry_price")

let test_short_and_blank_rows_are_skipped _ =
  let contents =
    _csv [ "2019-01-04,AAPL,LONG,100.0,5.0"; ""; "2019-02-01"; "  " ]
  in
  assert_that
    (Candidate_universe.symbols_of_all_eligible_csv ~contents |> Set.to_list)
    (elements_are [ equal_to "AAPL" ])

(* The context instruments are the reason a capture-derived universe is safe to
   shrink: they are read by the macro gate and the sector scoring but never
   appear as candidates, so they can only enter via this union. *)
let test_context_symbols_are_unioned_in _ =
  let entries =
    Candidate_universe.build ~include_context:true
      ~candidate_symbols:(String.Set.of_list [ "AAPL" ])
      ~sector_of:(fun _ -> Some "Information Technology")
      ~default_sector:"Unknown" ()
  in
  let symbols = List.map entries ~f:(fun e -> e.Universe_file.symbol) in
  assert_that symbols
    (all_of
       [
         field (fun s -> List.mem s "AAPL" ~equal:String.equal) (equal_to true);
         field (fun s -> List.mem s "GSPC" ~equal:String.equal) (equal_to true);
         field (fun s -> List.mem s "SPY" ~equal:String.equal) (equal_to true);
         field (fun s -> List.mem s "XLK" ~equal:String.equal) (equal_to true);
       ])

let test_entries_are_sorted_and_deduped _ =
  let entries =
    Candidate_universe.build ~include_context:true
      ~candidate_symbols:(String.Set.of_list [ "ZTS"; "AAPL"; "SPY" ])
      ~sector_of:(fun _ -> Some "S")
      ~default_sector:"Unknown" ()
  in
  let symbols = List.map entries ~f:(fun e -> e.Universe_file.symbol) in
  assert_that symbols
    (all_of
       [
         (* sorted: a fixture that reorders per build produces noise diffs *)
         field
           (fun s ->
             List.equal String.equal s (List.sort s ~compare:String.compare))
           (equal_to true);
         (* SPY supplied both as a candidate and as a context symbol appears once *)
         field (fun s -> List.count s ~f:(String.equal "SPY")) (equal_to 1);
       ])

let test_default_sector_fills_unknown_symbols _ =
  let entries =
    Candidate_universe.build ~include_context:true
      ~candidate_symbols:(String.Set.of_list [ "AAPL" ])
      ~sector_of:(fun s ->
        if String.equal s "AAPL" then Some "Information Technology" else None)
      ~default_sector:"Unknown" ()
  in
  let sector_of_spy =
    List.find entries ~f:(fun e -> String.equal e.Universe_file.symbol "SPY")
  in
  assert_that sector_of_spy
    (is_some_and (field (fun e -> e.Universe_file.sector) (equal_to "Unknown")))

let test_unresolved_sectors_reports_the_gaps _ =
  assert_that
    (Candidate_universe.unresolved_sectors
       ~candidate_symbols:(String.Set.of_list [ "AAPL"; "ZZZZ" ])
       ~sector_of:(fun s ->
         if String.equal s "AAPL" then Some "Information Technology" else None)
       ())
    (field (fun l -> List.mem l "ZZZZ" ~equal:String.equal) (equal_to true))

(* THE DEFAULT IS NO CONTEXT SYMBOLS. A universe file governs candidate
   membership, and the ETFs are tradeable — injecting them into a fixture
   derived from an equities-only universe (small.sexp has 302 equities and zero
   ETFs) adds symbols that can become candidates and change the very trade list
   the fixture must reproduce. An earlier draft defaulted this on. *)
let test_context_symbols_excluded_by_default _ =
  let entries =
    Candidate_universe.build
      ~candidate_symbols:(String.Set.of_list [ "AAPL" ])
      ~sector_of:(fun _ -> Some "Information Technology")
      ~default_sector:"Unknown" ()
  in
  let symbols = List.map entries ~f:(fun e -> e.Universe_file.symbol) in
  assert_that symbols (elements_are [ equal_to "AAPL" ])

(* The source universe is the authoritative sector source for a derived subset:
   it is what the full run used. Preferring sectors.csv instead collapsed 297 of
   304 symbols to the fallback in the first real run, which would have disabled
   the sector filter in the fixture. *)
let test_sector_inherited_from_source_universe _ =
  let source =
    Universe_file.Pinned
      [
        { Universe_file.symbol = "AAPL"; sector = "Information Technology" };
        { Universe_file.symbol = "JPM"; sector = "Financials" };
      ]
  in
  let lookup = Candidate_universe.sector_of_universe source in
  assert_that
    [ lookup "AAPL"; lookup "JPM"; lookup "NOPE" ]
    (elements_are
       [
         is_some_and (equal_to "Information Technology");
         is_some_and (equal_to "Financials");
         is_none;
       ])

let test_full_sector_map_source_resolves_nothing _ =
  assert_that
    (Candidate_universe.sector_of_universe Universe_file.Full_sector_map "AAPL")
    is_none

(* Chain order is the point: source universe first, sectors.csv only for
   symbols it lacks (typically the context ETFs). *)
let test_first_available_prefers_earlier_lookup _ =
  let from_universe s =
    if String.equal s "AAPL" then Some "FromUniverse" else None
  in
  let from_csv s =
    if String.equal s "AAPL" then Some "FromCsv"
    else if String.equal s "SPY" then Some "CsvOnly"
    else None
  in
  assert_that
    [
      Candidate_universe.first_available [ from_universe; from_csv ] "AAPL";
      Candidate_universe.first_available [ from_universe; from_csv ] "SPY";
      Candidate_universe.first_available [ from_universe; from_csv ] "ZZZZ";
    ]
    (elements_are
       [
         is_some_and (equal_to "FromUniverse");
         is_some_and (equal_to "CsvOnly");
         is_none;
       ])

(* A derived fixture whose provenance is missing is unverifiable in practice —
   the 2026-08-13 nearfloor review turned on exactly that. *)
let test_render_carries_provenance_and_parses _ =
  let text =
    Candidate_universe.render
      ~entries:
        [ { Universe_file.symbol = "AAPL"; sector = "Information Technology" } ]
      ~provenance:[ "window 2018-2023"; "min_grade F" ]
  in
  assert_that text
    (all_of
       [
         field
           (fun t -> String.is_substring t ~substring:";; window 2018-2023")
           (equal_to true);
         field
           (fun t -> String.is_substring t ~substring:";; min_grade F")
           (equal_to true);
       ]);
  (* and the emitted text must round-trip through the real parser *)
  let parsed =
    Universe_file.t_of_sexp
      (Sexp.of_string
         (String.strip
            (List.last_exn
               (String.split_lines text
               |> List.filter ~f:(fun l ->
                   not (String.is_prefix l ~prefix:";;"))
               |> List.filter ~f:(fun l ->
                   not (String.is_empty (String.strip l)))))))
  in
  assert_that (Universe_file.symbol_count parsed) (is_some_and (equal_to 1))

let suite =
  "Candidate_universe"
  >::: [
         "extracts distinct symbols" >:: test_extracts_distinct_symbols;
         "header-only file is empty" >:: test_header_only_file_is_empty;
         "symbol column located by name" >:: test_symbol_column_located_by_name;
         "missing symbol column raises" >:: test_missing_symbol_column_raises;
         "short and blank rows skipped"
         >:: test_short_and_blank_rows_are_skipped;
         "context symbols unioned in" >:: test_context_symbols_are_unioned_in;
         "context symbols excluded by default"
         >:: test_context_symbols_excluded_by_default;
         "entries sorted and deduped" >:: test_entries_are_sorted_and_deduped;
         "default sector fills unknown"
         >:: test_default_sector_fills_unknown_symbols;
         "unresolved sectors reported"
         >:: test_unresolved_sectors_reports_the_gaps;
         "sector inherited from source universe"
         >:: test_sector_inherited_from_source_universe;
         "Full_sector_map source resolves nothing"
         >:: test_full_sector_map_source_resolves_nothing;
         "first_available prefers earlier lookup"
         >:: test_first_available_prefers_earlier_lookup;
         "render carries provenance"
         >:: test_render_carries_provenance_and_parses;
       ]

let () = run_test_tt_main suite
