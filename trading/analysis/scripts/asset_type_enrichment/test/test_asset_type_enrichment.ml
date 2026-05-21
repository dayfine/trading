open Core
open OUnit2
open Matchers
open Asset_type_enrichment_lib

(* ---- Fixtures ----

   Top-level builders so that test bodies stay flat: per the nesting linter's
   indentation-as-proxy-for-depth model, an inline record literal nested four
   levels deep inside a [join ~eodhd_listings:[ {...}; {...} ]] expression
   pushes the per-line depth into the [4..8] range. Keeping listing /
   expected-entry builders at module scope flattens the test body's depth
   profile to {1,2}. *)

let _sample_date = Date.create_exn ~y:2026 ~m:May ~d:17

let _make_metadata ~code ~name ~exchange ~asset_type :
    Eodhd.Http_client.symbol_metadata =
  { code; name; exchange; asset_type }

let _make_entry ~symbol ~asset_type ~exchange : entry =
  { symbol; asset_type; exchange }

let _absent_entry symbol =
  _make_entry ~symbol ~asset_type:Not_in_eodhd_listing ~exchange:""

(* Three example EODHD listings — one Common_stock, one Mutual_fund, one ETF.
   The fourth inventory symbol below ("UNKNOWN") is intentionally absent. *)
let _aapl_listing =
  _make_metadata ~code:"AAPL" ~name:"Apple Inc" ~exchange:"NASDAQ"
    ~asset_type:Eodhd.Asset_type.Common_stock

let _vanguard_listing =
  _make_metadata ~code:"0P000070L2" ~name:"Vanguard Total Stock Market"
    ~exchange:"PINK" ~asset_type:Eodhd.Asset_type.Mutual_fund

let _spy_listing =
  _make_metadata ~code:"SPY" ~name:"SPDR S&P 500" ~exchange:"NYSE ARCA"
    ~asset_type:Eodhd.Asset_type.ETF

let _wtf_listing =
  _make_metadata ~code:"WTF" ~name:"Mystery" ~exchange:"NASDAQ"
    ~asset_type:(Eodhd.Asset_type.Other "Brand New Type")

let _eodhd_listings =
  [ _aapl_listing; _vanguard_listing; _spy_listing; _wtf_listing ]

let _inventory_symbols = [ "AAPL"; "0P000070L2"; "UNKNOWN"; "SPY"; "WTF" ]
let _sample_endpoints = [ ("/api/exchange-symbol-list/US", _sample_date) ]

(* Domain-specific join helper — flattens every call to [join] in the tests
   below to one line. Per .claude/rules/test-patterns.md §Test Data Builders. *)
let _join_with_defaults ~inventory_symbols ~eodhd_listings =
  join ~inventory_symbols ~eodhd_listings ~generated_at:_sample_date
    ~source_endpoints:_sample_endpoints

(* ---- Pure join — order preservation ----

   Pin that the output [symbols] list preserves the input [inventory_symbols]
   order and that the result also carries the [generated_at] /
   [source_endpoints] metadata through unchanged. Uses an inventory of
   fully-listed symbols (the absent-symbol contract is exercised by the next
   test). Only the per-entry [symbol] field is checked here so the order
   assertion isn't conflated with full-record marshalling — that's covered by
   the round-trip test. *)

let _symbol_is name = field (fun (e : entry) -> e.symbol) (equal_to name)
let _generated_at_is d = field (fun (t : t) -> t.generated_at) (equal_to d)

let _source_endpoints_match expected =
  field (fun (t : t) -> t.source_endpoints) (elements_are expected)

let _symbols_match per_entry =
  field (fun (t : t) -> t.symbols) (elements_are per_entry)

let test_join_preserves_inventory_order _ =
  let inventory = [ "SPY"; "AAPL"; "WTF"; "0P000070L2" ] in
  let result =
    _join_with_defaults ~inventory_symbols:inventory
      ~eodhd_listings:_eodhd_listings
  in
  assert_that result
    (all_of
       [
         _generated_at_is _sample_date;
         _source_endpoints_match
           [ equal_to ("/api/exchange-symbol-list/US", _sample_date) ];
         _symbols_match (List.map inventory ~f:_symbol_is);
       ])

(* ---- Pure join — absent symbol marking ----

   Pin that symbols present in [inventory_symbols] but absent from
   [eodhd_listings] are emitted with [asset_type = Not_in_eodhd_listing] and
   empty [name] / [exchange] strings, while neighboring symbols that ARE listed
   pass through untouched. *)

let _expected_aapl =
  _make_entry ~symbol:"AAPL" ~asset_type:(Listed Eodhd.Asset_type.Common_stock)
    ~exchange:"NASDAQ"

let _expected_spy =
  _make_entry ~symbol:"SPY" ~asset_type:(Listed Eodhd.Asset_type.ETF)
    ~exchange:"NYSE ARCA"

let test_join_marks_absent_symbols_as_not_in_listing _ =
  let result =
    _join_with_defaults
      ~inventory_symbols:[ "AAPL"; "UNKNOWN"; "SPY" ]
      ~eodhd_listings:_eodhd_listings
  in
  assert_that result
    (_symbols_match
       [
         equal_to _expected_aapl;
         equal_to (_absent_entry "UNKNOWN");
         equal_to _expected_spy;
       ])

(* ---- Empty edge cases ---- *)

let test_join_empty_inventory_yields_empty_entries _ =
  let result =
    _join_with_defaults ~inventory_symbols:[] ~eodhd_listings:_eodhd_listings
  in
  assert_that result (_symbols_match [])

let test_join_empty_listings_marks_everything_absent _ =
  let result =
    _join_with_defaults ~inventory_symbols:[ "AAPL"; "MSFT" ] ~eodhd_listings:[]
  in
  assert_that result
    (_symbols_match
       [ equal_to (_absent_entry "AAPL"); equal_to (_absent_entry "MSFT") ])

(* ---- Duplicate-listing guard ----

   .mli line 67: "If the same symbol appears multiple times in [eodhd_listings],
   the first occurrence wins." Pin that contract here so a future regression
   (e.g. switching [Hashtbl.add] to [Hashtbl.set]) is caught deterministically. *)

let _aapl_first =
  _make_metadata ~code:"AAPL" ~name:"Apple Inc (FIRST)" ~exchange:"NASDAQ"
    ~asset_type:Eodhd.Asset_type.Common_stock

let _aapl_second =
  _make_metadata ~code:"AAPL" ~name:"Apple Inc (SECOND)" ~exchange:"DUPLICATE"
    ~asset_type:Eodhd.Asset_type.Preferred_stock

let _expected_aapl_first =
  _make_entry ~symbol:"AAPL" ~asset_type:(Listed Eodhd.Asset_type.Common_stock)
    ~exchange:"NASDAQ"

let test_join_first_occurrence_wins_on_duplicate _ =
  let result =
    _join_with_defaults ~inventory_symbols:[ "AAPL" ]
      ~eodhd_listings:[ _aapl_first; _aapl_second ]
  in
  assert_that result (_symbols_match [ equal_to _expected_aapl_first ])

(* ---- Round-trip save / load ---- *)

let _with_temp_path ~name ~f =
  let dir = Filename_unix.temp_dir "asset_type_enrich_test" "" in
  let path = Fpath.v Filename.(concat dir name) in
  Exn.protect
    ~f:(fun () -> f path)
    ~finally:(fun () ->
      (try Sys_unix.remove (Fpath.to_string path) with _ -> ());
      try Core_unix.rmdir dir with _ -> ())

let test_round_trip_save_load _ =
  let original =
    _join_with_defaults ~inventory_symbols:_inventory_symbols
      ~eodhd_listings:_eodhd_listings
  in
  let assertion =
    _with_temp_path ~name:"symbol_types.sexp" ~f:(fun path ->
        match save original ~path with
        | Error err -> assert_failure ("save failed: " ^ Status.show err)
        | Ok () -> load ~path)
  in
  assert_that assertion (is_ok_and_holds (equal_to original))

(* ---- Backward-compat: legacy sexp with [name] field still loads ----

   The on-disk shape lost [name] in 2026-05-22. To keep operator workflows
   safe — a stale local copy of [symbol_types.sexp] must still be readable
   by the new code — the parser tolerates an extra [name] pair by ignoring
   it. Pin that contract so a future tightening of [_find_field] (e.g.
   switching to a strict whitelist) is caught here, not on a stranger's
   workstation a month later. *)

let _legacy_sexp_string =
  {|((generated_at 2026-05-17)
 (source_endpoints ((/api/exchange-symbol-list/US 2026-05-17)))
 (symbols
  (((symbol AAPL) (asset_type (Listed "Common Stock"))
    (name "Apple Inc (legacy)") (exchange NASDAQ)))))|}

let _expected_legacy_entry =
  _make_entry ~symbol:"AAPL" ~asset_type:(Listed Eodhd.Asset_type.Common_stock)
    ~exchange:"NASDAQ"

let _load_legacy_sexp () =
  _with_temp_path ~name:"legacy_symbol_types.sexp" ~f:(fun path ->
      Out_channel.write_all (Fpath.to_string path) ~data:_legacy_sexp_string;
      load ~path)

let test_legacy_sexp_with_name_field_still_loads _ =
  assert_that (_load_legacy_sexp ())
    (is_ok_and_holds (_symbols_match [ equal_to _expected_legacy_entry ]))

(* ---- Per-type counts ----

   Build an enriched index with 3 Common_stock, 2 Mutual_fund, 1 ETF, and
   2 absent. Sorted descending by count, then ascending by label. *)

let _stock_listing code =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:Eodhd.Asset_type.Common_stock

let _mutual_fund_listing code =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:Eodhd.Asset_type.Mutual_fund

let _etf_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.ETF

let _per_type_inventory =
  [ "A"; "B"; "C"; "MF1"; "MF2"; "ETF1"; "ABS1"; "ABS2" ]

let _per_type_listings =
  [
    _stock_listing "A";
    _stock_listing "B";
    _stock_listing "C";
    _mutual_fund_listing "MF1";
    _mutual_fund_listing "MF2";
    _etf_listing "ETF1";
  ]

(* Sort: 3 > 2 > 2 > 1; ties broken by label ascending
   ("Mutual Fund" < "Not_in_eodhd_listing"). *)
let _expected_per_type_counts : type_count list =
  [
    { asset_type_label = "Common Stock"; count = 3 };
    { asset_type_label = "Mutual Fund"; count = 2 };
    { asset_type_label = "Not_in_eodhd_listing"; count = 2 };
    { asset_type_label = "ETF"; count = 1 };
  ]

let test_per_type_counts_sorted_by_count_desc _ =
  let t =
    _join_with_defaults ~inventory_symbols:_per_type_inventory
      ~eodhd_listings:_per_type_listings
  in
  assert_that (per_type_counts t)
    (elements_are (List.map _expected_per_type_counts ~f:equal_to))

(* ---- Equity-like filter (Q1 PR3) ----

   Pin that [filter_equity_like_symbols] keeps Common_stock / Preferred_stock /
   ADR / GDR and drops everything else (ETF, Mutual_fund, Fund, Index, Bond,
   Currency, Commodity, Other _, Not_in_eodhd_listing). Order preservation is
   exercised by a separate test. *)

let _adr_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.ADR

let _gdr_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.GDR

let _preferred_listing code =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:Eodhd.Asset_type.Preferred_stock

let _fund_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.Fund

let _index_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.Index

let _bond_listing code =
  _make_metadata ~code ~name:"" ~exchange:"" ~asset_type:Eodhd.Asset_type.Bond

let _currency_listing code =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:Eodhd.Asset_type.Currency

let _commodity_listing code =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:Eodhd.Asset_type.Commodity

let _other_listing code raw =
  _make_metadata ~code ~name:"" ~exchange:""
    ~asset_type:(Eodhd.Asset_type.Other raw)

(* Mixed listings: 4 equity-like (Common, Preferred, ADR, GDR) + 8 non-equity
   (ETF, Mutual_fund, Fund, Index, Bond, Currency, Commodity, Other). *)
let _mixed_listings =
  [
    _stock_listing "AAPL";
    _preferred_listing "BRK-A";
    _adr_listing "BABA";
    _gdr_listing "GAZP";
    _etf_listing "SPY";
    _mutual_fund_listing "0P000070L2";
    _fund_listing "PCEF";
    _index_listing "GSPC";
    _bond_listing "TLT-BOND";
    _currency_listing "EURUSD";
    _commodity_listing "GOLD";
    _other_listing "WTF" "Brand New Type";
  ]

let _mixed_inventory =
  [
    "AAPL";
    "BRK-A";
    "BABA";
    "GAZP";
    "SPY";
    "0P000070L2";
    "PCEF";
    "GSPC";
    "TLT-BOND";
    "EURUSD";
    "GOLD";
    "WTF";
    "MISSING_FROM_INDEX";
  ]

let _mixed_filter_input =
  [
    "AAPL";
    "SPY";
    "BRK-A";
    "0P000070L2";
    "BABA";
    "GSPC";
    "GAZP";
    "WTF";
    "MISSING_FROM_INDEX";
  ]

let _expected_mixed_kept =
  [ equal_to "AAPL"; equal_to "BRK-A"; equal_to "BABA"; equal_to "GAZP" ]

let test_filter_drops_non_equity_like _ =
  let symbol_types =
    _join_with_defaults ~inventory_symbols:_mixed_inventory
      ~eodhd_listings:_mixed_listings
  in
  let kept =
    filter_equity_like_symbols ~symbol_types ~symbols:_mixed_filter_input
  in
  assert_that kept (elements_are _expected_mixed_kept)

(* Order preservation: re-using the same enriched index, ensure the kept
   symbols come back in the input order (not in the [symbol_types] inventory
   order). *)

let _order_listings =
  [ _stock_listing "MSFT"; _stock_listing "AAPL"; _stock_listing "GOOG" ]

let test_filter_preserves_input_order _ =
  let symbol_types =
    _join_with_defaults ~inventory_symbols:[ "AAPL"; "GOOG"; "MSFT" ]
      ~eodhd_listings:_order_listings
  in
  let kept =
    filter_equity_like_symbols ~symbol_types ~symbols:[ "MSFT"; "AAPL"; "GOOG" ]
  in
  assert_that kept
    (elements_are [ equal_to "MSFT"; equal_to "AAPL"; equal_to "GOOG" ])

let suite =
  "asset_type_enrichment_test"
  >::: [
         "join_preserves_inventory_order"
         >:: test_join_preserves_inventory_order;
         "join_marks_absent_symbols_as_not_in_listing"
         >:: test_join_marks_absent_symbols_as_not_in_listing;
         "join_empty_inventory_yields_empty_entries"
         >:: test_join_empty_inventory_yields_empty_entries;
         "join_empty_listings_marks_everything_absent"
         >:: test_join_empty_listings_marks_everything_absent;
         "join_first_occurrence_wins_on_duplicate"
         >:: test_join_first_occurrence_wins_on_duplicate;
         "round_trip_save_load" >:: test_round_trip_save_load;
         "legacy_sexp_with_name_field_still_loads"
         >:: test_legacy_sexp_with_name_field_still_loads;
         "per_type_counts_sorted_by_count_desc"
         >:: test_per_type_counts_sorted_by_count_desc;
         "filter_drops_non_equity_like" >:: test_filter_drops_non_equity_like;
         "filter_preserves_input_order" >:: test_filter_preserves_input_order;
       ]

let () = run_test_tt_main suite
