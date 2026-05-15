open Core
open OUnit2
open Matchers
open Ishares.Ishares_holdings_client

(* Pinned fixtures truncated from the iShares Russell 3000 holdings CSV.
   Each fixture preserves the verbatim 15-column schema, the 9-line preamble,
   and the era-specific row quirks called out in
   dev/notes/phase1.4-iwv-url-probe-2026-05-16.md. *)
let _quarterly_fixture = "./data/iwv_holdings_2007-09-28.csv"
let _monthly_fixture = "./data/iwv_holdings_2012-04-30.csv"
let _daily_fixture = "./data/iwv_holdings_2020-06-01.csv"
let _sentinel_fixture = "./data/iwv_holdings_sentinel.csv"
let _read fixture = In_channel.read_all fixture

(* Test setup helper: unwrap a successful [Parsed] outcome for the fixture
   under test, mirroring the documented "Extract values from Ok results in
   test setup" pattern in [.claude/rules/test-patterns.md]. Used only for
   PASS-path fixtures; sentinel and error fixtures are asserted directly via
   matchers. *)
let _parsed_or_fail body =
  match parse body with
  | Ok (Parsed snap) -> snap
  | Ok No_data_sentinel ->
      failwith "Expected Parsed snapshot, got No_data_sentinel"
  | Error err -> failwith ("Parse failed: " ^ Status.show err)

let _find_holding snap ~ticker =
  List.find snap.holdings ~f:(fun h -> String.equal h.ticker ticker)

(* Pre-2012 era: sectors are unpopulated ("-"), rows ascend by market value,
   includes cross-listings (LSE / XETRA) and un-tickered positions. *)
let test_parses_quarterly_era _ =
  let snap = _parsed_or_fail (_read _quarterly_fixture) in
  assert_that snap
    (all_of
       [
         field
           (fun s -> s.as_of)
           (equal_to (Date.create_exn ~y:2007 ~m:Month.Sep ~d:28));
         field (fun s -> List.length s.holdings) (equal_to 9);
       ])

let test_quarterly_era_has_empty_sectors _ =
  let snap = _parsed_or_fail (_read _quarterly_fixture) in
  let populated =
    List.filter snap.holdings ~f:(fun h -> not (String.equal h.sector "-"))
  in
  assert_that populated (size_is 0)

(* The parser must preserve era-specific quirks verbatim: synthetic
   cross-listing tickers ("0R01" for Citigroup on LSE) and the "-" ticker
   for un-tickered positions. *)
let test_quarterly_era_preserves_era_quirks _ =
  let snap = _parsed_or_fail (_read _quarterly_fixture) in
  assert_that
    (_find_holding snap ~ticker:"0R01")
    (is_some_and
       (all_of
          [
            field (fun h -> h.location) (equal_to "United Kingdom");
            field (fun h -> h.exchange) (equal_to "LSE");
            field (fun h -> h.currency) (equal_to "GBP");
          ]));
  assert_that
    (_find_holding snap ~ticker:"-")
    (is_some_and
       (field (fun h -> h.name) (equal_to "UNTICKERED ESCROW POSITION")))

(* 2012-04-30 is the first daily-available date per the URL probe. Sectors are
   populated; market-currency is "USD"; futures / cash rows appear at the end
   of the data region. *)
let test_parses_daily_cutover _ =
  let snap = _parsed_or_fail (_read _monthly_fixture) in
  assert_that snap
    (all_of
       [
         field
           (fun s -> s.as_of)
           (equal_to (Date.create_exn ~y:2012 ~m:Month.Apr ~d:30));
         field (fun s -> List.length s.holdings) (equal_to 9);
       ])

let test_daily_cutover_has_populated_sectors _ =
  let snap = _parsed_or_fail (_read _monthly_fixture) in
  let aapl = _find_holding snap ~ticker:"AAPL" in
  assert_that aapl
    (is_some_and
       (all_of
          [
            field (fun h -> h.sector) (equal_to "Information Technology");
            field (fun h -> h.asset_class) (equal_to "Equity");
            field (fun h -> h.market_currency) (equal_to "USD");
          ]))

let test_daily_cutover_preserves_non_equity_rows _ =
  let snap = _parsed_or_fail (_read _monthly_fixture) in
  let futures = _find_holding snap ~ticker:"ESM2" in
  let cash = _find_holding snap ~ticker:"USD" in
  assert_that futures
    (is_some_and (field (fun h -> h.asset_class) (equal_to "Futures")));
  assert_that cash
    (is_some_and (field (fun h -> h.asset_class) (equal_to "Cash")))

(* Modern era: full 15-column parse including the load-bearing numeric fields. *)
let test_parses_modern_daily_era _ =
  let snap = _parsed_or_fail (_read _daily_fixture) in
  assert_that snap
    (all_of
       [
         field
           (fun s -> s.as_of)
           (equal_to (Date.create_exn ~y:2020 ~m:Month.Jun ~d:1));
         field (fun s -> List.length s.holdings) (equal_to 9);
       ])

let test_modern_era_parses_all_columns _ =
  let snap = _parsed_or_fail (_read _daily_fixture) in
  let msft = _find_holding snap ~ticker:"MSFT" in
  assert_that msft
    (is_some_and
       (all_of
          [
            field (fun h -> h.name) (equal_to "MICROSOFT CORP");
            field (fun h -> h.sector) (equal_to "Information Technology");
            field (fun h -> h.asset_class) (equal_to "Equity");
            field (fun h -> h.weight_pct) (float_equal 4.85);
            field (fun h -> h.quantity) (float_equal 1280000.0);
            field (fun h -> h.price) (float_equal 183.25);
            field (fun h -> h.location) (equal_to "United States");
            field (fun h -> h.exchange) (equal_to "NASDAQ");
            field (fun h -> h.currency) (equal_to "USD");
            field (fun h -> h.fx_rate) (float_equal 1.0);
          ]))

(* Source order must be preserved — parser does not sort. Modern era is
   descending by market value; the top row in the fixture is MSFT. *)
let test_parser_preserves_source_order _ =
  let snap = _parsed_or_fail (_read _daily_fixture) in
  let tickers = List.map snap.holdings ~f:(fun h -> h.ticker) in
  let first_three = List.take tickers 3 in
  assert_that first_three
    (elements_are [ equal_to "MSFT"; equal_to "AAPL"; equal_to "AMZN" ])

let test_detects_sentinel _ =
  let result = parse (_read _sentinel_fixture) in
  assert_that result (is_ok_and_holds (equal_to No_data_sentinel))

(* Header drift is the schema-migration alarm: if iShares changes a column
   name post-2026, the parser must fail loudly rather than silently mis-map
   columns. *)
let test_rejects_drifted_header _ =
  let body =
    "\xEF\xBB\xBFiShares Russell 3000 ETF\n\
     Fund Holdings as of,\"Jun 01, 2020\"\n\n\
     Inception Date,\"May 22, 2000\"\n\n\
     Ticker,Symbol,Sector,Asset Class,Market Value,Weight (%),Notional \
     Value,Quantity,Price,Location,Exchange,Currency,FX Rate,Market \
     Currency,Accrual Date\n\
     \"AAPL\",\"APPLE INC\",\"Information \
     Technology\",\"Equity\",\"100\",\"1.0\",\"100\",\"1\",\"100\",\"United \
     States\",\"NASDAQ\",\"USD\",\"1.0\",\"USD\",\"-\"\n"
  in
  assert_that (parse body) is_error

let test_rejects_empty_input _ = assert_that (parse "") is_error

let test_rejects_missing_header _ =
  let body =
    "iShares Russell 3000 ETF\n\
     Fund Holdings as of,\"Jun 01, 2020\"\n\n\
     no header row anywhere\n"
  in
  assert_that (parse body) is_error

(* The URL pattern is the Phase 1.4 verified shape. The load-bearing checks
   are: host, product id, file name, and zero-padded YYYYMMDD asOfDate. *)
let test_build_uri_shape _ =
  let uri = build_uri ~as_of:(Date.create_exn ~y:2006 ~m:Month.Sep ~d:29) in
  assert_that uri
    (all_of
       [
         field Uri.host (is_some_and (equal_to "www.ishares.com"));
         field
           (fun u -> Uri.get_query_param u "fileName")
           (is_some_and (equal_to "IWV_holdings"));
         field
           (fun u -> Uri.get_query_param u "asOfDate")
           (is_some_and (equal_to "20060929"));
       ])

let suite =
  "ishares_holdings_client_test"
  >::: [
         "parses_quarterly_era" >:: test_parses_quarterly_era;
         "quarterly_era_has_empty_sectors"
         >:: test_quarterly_era_has_empty_sectors;
         "quarterly_era_preserves_era_quirks"
         >:: test_quarterly_era_preserves_era_quirks;
         "parses_daily_cutover" >:: test_parses_daily_cutover;
         "daily_cutover_has_populated_sectors"
         >:: test_daily_cutover_has_populated_sectors;
         "daily_cutover_preserves_non_equity_rows"
         >:: test_daily_cutover_preserves_non_equity_rows;
         "parses_modern_daily_era" >:: test_parses_modern_daily_era;
         "modern_era_parses_all_columns" >:: test_modern_era_parses_all_columns;
         "parser_preserves_source_order" >:: test_parser_preserves_source_order;
         "detects_sentinel" >:: test_detects_sentinel;
         "rejects_drifted_header" >:: test_rejects_drifted_header;
         "rejects_empty_input" >:: test_rejects_empty_input;
         "rejects_missing_header" >:: test_rejects_missing_header;
         "build_uri_shape" >:: test_build_uri_shape;
       ]

let () = run_test_tt_main suite
