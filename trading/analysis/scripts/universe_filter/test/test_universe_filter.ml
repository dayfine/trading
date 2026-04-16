open Core
open OUnit2
open Matchers
module U = Universe_filter_lib

(* --- Helpers ------------------------------------------------------------- *)

let row ?(name = "") ?(exchange = "") symbol sector : U.row =
  { symbol; sector; name; exchange }

let cfg_of_string s = s |> Sexp.of_string |> U.config_of_sexp

(* --- filter tests -------------------------------------------------------- *)

let test_empty_config_is_noop _ctx =
  let cfg : U.config = { rules = [] } in
  let rows = [ row "AAPL" "Information Technology"; row "JPM" "Financials" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are (List.map rows ~f:equal_to));
         field (fun r -> r.U.dropped) (elements_are []);
         field (fun r -> r.U.rule_stats) (elements_are []);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

let test_symbol_pattern_drops_matches _ctx =
  let cfg : U.config =
    { rules = [ U.Symbol_pattern { name = "units"; pattern = "\\.U$" } ] }
  in
  let rows =
    [ row "AAPL" "IT"; row "FOO.U" "Financials"; row "BAR.U" "Financials" ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are [ equal_to (row "AAPL" "IT") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to (row "FOO.U" "Financials");
                equal_to (row "BAR.U" "Financials");
              ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to ({ rule_name = "units"; drop_count = 2 } : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

let test_name_pattern_drops_etf_fund_etc _ctx =
  (* Case-sensitive match of "ETF" / "Fund" / "Trust" / "Notes" at word
     boundaries. A common stock ("Apple Inc") must survive. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Name_pattern
            {
              name = "etf_fund_trust_notes";
              pattern = "(\\bETF\\b|\\bFund\\b|\\bTrust\\b|\\bNotes\\b)";
            };
        ];
    }
  in
  let rows =
    [
      row ~name:"Apple Inc" "AAPL" "IT";
      row ~name:"SPDR S&P 500 ETF Trust" "SPY" "Financials";
      row ~name:"Vanguard Total Stock Market Index Fund" "VTSAX" "Financials";
      row ~name:"ProShares Trust II" "UCO" "Energy";
      row ~name:"BlackRock Senior Floating Rate Notes" "XYZ" "Financials";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.U.kept)
           (elements_are [ equal_to (row ~name:"Apple Inc" "AAPL" "IT") ]);
         field (fun r -> r.U.dropped) (size_is 4);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "etf_fund_trust_notes"; drop_count = 4 }
                    : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

let test_name_pattern_case_insensitive _ctx =
  (* [(?i)…] flag in the regex makes it case-insensitive — lowercase "etf"
     should match uppercase "ETF" in the name and vice versa. *)
  let cfg : U.config =
    {
      rules = [ U.Name_pattern { name = "etf_ci"; pattern = "(?i)\\bETF\\b" } ];
    }
  in
  let rows =
    [
      row ~name:"SPDR S&P 500 ETF Trust" "SPY" "Financials";
      row ~name:"iShares Core S&P 500 etf" "IVV" "Financials";
      row ~name:"Apple Inc" "AAPL" "IT";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (size_is 1);
         field (fun r -> r.U.dropped) (size_is 2);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "etf_ci"; drop_count = 2 } : U.rule_stat);
              ]);
       ])

let test_exchange_equals_drops_nyse_arca _ctx =
  (* Exchange_equals is exact-match; "NYSE ARCA" should drop only rows whose
     exchange is exactly "NYSE ARCA", not NASDAQ / NYSE / NYSEARCA (one-word). *)
  let cfg : U.config =
    {
      rules =
        [ U.Exchange_equals { name = "nyse_arca"; exchange = "NYSE ARCA" } ];
    }
  in
  let rows =
    [
      row ~exchange:"NYSE ARCA" "XLK" "IT";
      row ~exchange:"NYSE ARCA" "XLF" "Financials";
      row ~exchange:"NASDAQ" "AAPL" "IT";
      row ~exchange:"NYSE" "JPM" "Financials";
      row ~exchange:"NYSEARCA" "BAR" "Financials";
      (* one-word variant — should NOT drop *)
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (size_is 3);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to (row ~exchange:"NYSE ARCA" "XLK" "IT");
                equal_to (row ~exchange:"NYSE ARCA" "XLF" "Financials");
              ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "nyse_arca"; drop_count = 2 } : U.rule_stat);
              ]);
       ])

let test_allowlist_rescues_match _ctx =
  (* The regex matches 'SPY', but the allow-list should preserve it.
     A different symbol 'ZZPY' that matches the same regex should still
     be dropped. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Symbol_pattern { name = "ends_py"; pattern = "PY$" };
          U.Keep_allowlist { name = "broad"; symbols = [ "SPY" ] };
        ];
    }
  in
  let rows = [ row "SPY" "Financials"; row "ZZPY" "Financials" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.U.kept)
           (elements_are [ equal_to (row "SPY" "Financials") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are [ equal_to (row "ZZPY" "Financials") ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "ends_py"; drop_count = 2 } : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 1);
       ])

let test_allowlist_rescues_from_exchange_rule _ctx =
  (* SPY is listed on NYSE ARCA; an Exchange_equals "NYSE ARCA" rule would
     drop it. The allow-list must rescue SPY regardless. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Keep_allowlist { name = "broad"; symbols = [ "SPY" ] };
          U.Exchange_equals { name = "nyse_arca"; exchange = "NYSE ARCA" };
        ];
    }
  in
  let rows =
    [
      row ~exchange:"NYSE ARCA" "SPY" "Financials";
      row ~exchange:"NYSE ARCA" "AAAA" "Financials";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.U.kept)
           (elements_are
              [ equal_to (row ~exchange:"NYSE ARCA" "SPY" "Financials") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [ equal_to (row ~exchange:"NYSE ARCA" "AAAA" "Financials") ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 1);
       ])

let test_multiple_rules_independent_counts _ctx =
  (* A row matching two drop rules counts once in each rule's stat; the row
     is still dropped once (appears in [dropped] exactly once). *)
  let cfg : U.config =
    {
      rules =
        [
          U.Symbol_pattern { name = "ends_W"; pattern = "W$" };
          U.Symbol_pattern { name = "starts_A"; pattern = "^A" };
        ];
    }
  in
  (* AW matches both; AB matches starts_A; BW matches ends_W; ZZ matches neither. *)
  let rows = [ row "AW" ""; row "AB" ""; row "BW" ""; row "ZZ" "" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are [ equal_to (row "ZZ" "") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to (row "AW" "");
                equal_to (row "AB" "");
                equal_to (row "BW" "");
              ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "ends_W"; drop_count = 2 } : U.rule_stat);
                equal_to
                  ({ rule_name = "starts_A"; drop_count = 2 } : U.rule_stat);
              ]);
       ])

let test_stats_zero_for_nonmatching_rule _ctx =
  (* A rule that matches nothing still shows up with count 0, so the
     operator sees that the rule is present but inert. *)
  let cfg : U.config =
    { rules = [ U.Symbol_pattern { name = "inert"; pattern = "ZZZZ$" } ] }
  in
  let rows = [ row "AAPL" ""; row "MSFT" "" ] in
  let result = U.filter cfg rows in
  assert_that result
    (field
       (fun r -> r.U.rule_stats)
       (elements_are
          [ equal_to ({ rule_name = "inert"; drop_count = 0 } : U.rule_stat) ]))

(* --- load_config tests --------------------------------------------------- *)

let _write_tmp ?(suffix = ".sexp") contents =
  let tmp = Stdlib.Filename.temp_file "universe_filter_test" suffix in
  Stdlib.Out_channel.with_open_text tmp (fun oc ->
      Stdlib.Out_channel.output_string oc contents);
  tmp

(* load_config returns (config, string) Result.t — not Status.status_or — so
   we pattern-match instead of using is_ok_and_holds / is_error matchers. *)
let test_load_config_ok _ctx =
  let tmp =
    _write_tmp
      {|((rules (
  (Symbol_pattern (name "u") (pattern "\\.U$"))
  (Name_pattern (name "etf") (pattern "\\bETF\\b"))
  (Exchange_equals (name "arca") (exchange "NYSE ARCA"))
  (Keep_allowlist (name "broad") (symbols (SPY QQQ))))))|}
  in
  let result = U.load_config tmp in
  Stdlib.Sys.remove tmp;
  match result with
  | Error e -> assert_failure ("expected Ok, got Error: " ^ e)
  | Ok cfg ->
      assert_that cfg (field (fun c -> List.length c.U.rules) (equal_to 4))

let test_load_config_missing_file _ctx =
  let result = U.load_config "/nonexistent/does-not-exist.sexp" in
  match result with
  | Ok _ -> assert_failure "expected Error for missing file, got Ok"
  | Error _ -> ()

let test_load_config_malformed _ctx =
  let tmp = _write_tmp "(this is (not a valid config))" in
  let result = U.load_config tmp in
  Stdlib.Sys.remove tmp;
  match result with
  | Ok _ -> assert_failure "expected Error for malformed sexp, got Ok"
  | Error _ -> ()

(* --- default.sexp smoke test --------------------------------------------- *)

(* The default sexp that ships under dev/config/universe_filter is not
   directly addressable from the test cwd, so we exercise its content by
   inlining the same shape. This guards against syntax drift in the
   shipped default. *)
let test_default_shape_parses _ctx =
  (* Mirrors the exact shape of dev/config/universe_filter/default.sexp,
     including the Item 4.1 Keep_if_sector rule added for REIT rescue. *)
  let sample =
    {|((rules (
        (Keep_allowlist (name "broad") (symbols (SPY QQQ)))
        (Keep_if_sector (name "reit_royalty_rescue")
                        (sectors ("Real Estate" "Energy" "Materials")))
        (Name_pattern (name "fund_etf") (pattern "(?i)(\\bETF\\b|\\bFund\\b|\\bTrust\\b|\\bNotes\\b)"))
        (Exchange_equals (name "nyse_arca") (exchange "NYSE ARCA")))))|}
  in
  let cfg = cfg_of_string sample in
  assert_that cfg (field (fun c -> List.length c.U.rules) (equal_to 4))

(* --- CSV roundtrip ------------------------------------------------------- *)

let test_csv_roundtrip _ctx =
  let tmp_dir = Stdlib.Filename.temp_dir "universe_filter_csv" "" in
  let path = tmp_dir ^ "/test.csv" in
  (* CSV only stores symbol + sector; enriched fields ([name], [exchange])
     round-trip as empty strings. *)
  let rows = [ row "AAPL" "IT"; row "JPM" "Financials" ] in
  (match U.write_csv path rows with
  | Ok () -> ()
  | Error e -> assert_failure ("write failed: " ^ e));
  let loaded =
    match U.read_csv path with
    | Ok r -> r
    | Error e -> assert_failure ("read failed: " ^ e)
  in
  Stdlib.Sys.remove path;
  Stdlib.Sys.rmdir tmp_dir;
  assert_that loaded (elements_are (List.map rows ~f:equal_to))

(* --- load_rows_with_universe (join) ------------------------------------- *)

let test_join_enriches_rows _ctx =
  let tmp_dir = Stdlib.Filename.temp_dir "universe_filter_join" "" in
  let csv = tmp_dir ^ "/sectors.csv" in
  let sexp = tmp_dir ^ "/universe.sexp" in
  Stdlib.Out_channel.with_open_text csv (fun oc ->
      Stdlib.Out_channel.output_string oc
        "symbol,sector\nAAPL,IT\nSPY,Financials\n");
  Stdlib.Out_channel.with_open_text sexp (fun oc ->
      Stdlib.Out_channel.output_string oc
        {|(
  ((symbol AAPL) (name "Apple Inc") (sector IT) (industry "") (market_cap 0) (exchange NASDAQ))
  ((symbol SPY) (name "SPDR S&P 500 ETF Trust") (sector Financials) (industry "") (market_cap 0) (exchange "NYSE ARCA"))
)|});
  let result = U.load_rows_with_universe ~sectors_csv:csv ~universe_sexp:sexp in
  Stdlib.Sys.remove csv;
  Stdlib.Sys.remove sexp;
  Stdlib.Sys.rmdir tmp_dir;
  match result with
  | Error e -> assert_failure ("join failed: " ^ e)
  | Ok rows ->
      assert_that rows
        (elements_are
           [
             equal_to
               ({
                  symbol = "AAPL";
                  sector = "IT";
                  name = "Apple Inc";
                  exchange = "NASDAQ";
                }
                 : U.row);
             equal_to
               ({
                  symbol = "SPY";
                  sector = "Financials";
                  name = "SPDR S&P 500 ETF Trust";
                  exchange = "NYSE ARCA";
                }
                 : U.row);
           ])

let test_join_handles_missing_universe_symbols _ctx =
  (* Rows whose symbol is absent from universe.sexp keep empty name/exchange —
     no crash, no data loss. *)
  let tmp_dir = Stdlib.Filename.temp_dir "universe_filter_join_missing" "" in
  let csv = tmp_dir ^ "/sectors.csv" in
  let sexp = tmp_dir ^ "/universe.sexp" in
  Stdlib.Out_channel.with_open_text csv (fun oc ->
      Stdlib.Out_channel.output_string oc
        "symbol,sector\nAAPL,IT\nUNKNOWN,Financials\n");
  Stdlib.Out_channel.with_open_text sexp (fun oc ->
      Stdlib.Out_channel.output_string oc
        {|(
  ((symbol AAPL) (name "Apple Inc") (sector IT) (industry "") (market_cap 0) (exchange NASDAQ))
)|});
  let result = U.load_rows_with_universe ~sectors_csv:csv ~universe_sexp:sexp in
  Stdlib.Sys.remove csv;
  Stdlib.Sys.remove sexp;
  Stdlib.Sys.rmdir tmp_dir;
  match result with
  | Error e -> assert_failure ("join failed: " ^ e)
  | Ok rows ->
      assert_that rows
        (elements_are
           [
             equal_to
               ({
                  symbol = "AAPL";
                  sector = "IT";
                  name = "Apple Inc";
                  exchange = "NASDAQ";
                }
                 : U.row);
             equal_to
               ({
                  symbol = "UNKNOWN";
                  sector = "Financials";
                  name = "";
                  exchange = "";
                }
                 : U.row);
           ])

(* --- Keep_if_sector tests ------------------------------------------------ *)

(* The default rule-set has a Name_pattern that catches "Trust" and would
   drop REITs like "American Assets Trust" (AAT).  A Keep_if_sector rule
   placed before or after the drop rule rescues them by sector. *)
let test_keep_if_sector_rescues_reits _ctx =
  (* Mirrors the real default.sexp pattern: allow-list + name-pattern +
     sector-rescue.  AAT has "Trust" in its name → would be dropped by the
     name_pattern, but Keep_if_sector("Real Estate") rescues it. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Keep_allowlist
            { name = "broad"; symbols = [ "SPY"; "QQQ" ] };
          U.Keep_if_sector
            { name = "reit_rescue"; sectors = [ "Real Estate" ] };
          U.Name_pattern
            {
              name = "etf_fund_trust_notes";
              pattern = "(?i)(\\bETF\\b|\\bFund\\b|\\bTrust\\b|\\bNotes\\b)";
            };
        ];
    }
  in
  let rows =
    [
      (* REIT: name contains "Trust", sector "Real Estate" — must be kept *)
      row ~name:"American Assets Trust Inc" ~exchange:"NYSE" "AAT"
        "Real Estate";
      (* ETF: name contains "ETF", sector "Financials" — must be dropped *)
      row
        ~name:"Amplius Aggressive Asset Allocation ETF"
        ~exchange:"NYSE" "AAAA" "Financials";
      (* Allow-listed ETF: rescued by Keep_allowlist, not Keep_if_sector *)
      row ~name:"SPDR S&P 500 ETF Trust" ~exchange:"NYSE ARCA" "SPY"
        "Financials";
      (* Plain common stock: not matching any rule — kept *)
      row ~name:"Apple Inc" ~exchange:"NASDAQ" "AAPL"
        "Information Technology";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.U.kept)
           (elements_are
              [
                equal_to
                  (row ~name:"American Assets Trust Inc" ~exchange:"NYSE"
                     "AAT" "Real Estate");
                equal_to
                  (row ~name:"SPDR S&P 500 ETF Trust" ~exchange:"NYSE ARCA"
                     "SPY" "Financials");
                equal_to
                  (row ~name:"Apple Inc" ~exchange:"NASDAQ" "AAPL"
                     "Information Technology");
              ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to
                  (row
                     ~name:"Amplius Aggressive Asset Allocation ETF"
                     ~exchange:"NYSE" "AAAA" "Financials");
              ]);
         (* AAT + SPY both rescued; drop_count is raw (before rescue) *)
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "etf_fund_trust_notes"; drop_count = 3 }
                    : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 2);
       ])

let test_keep_if_sector_multiple_sectors _ctx =
  (* Passing multiple sectors extends the rescue to all of them. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Keep_if_sector
            {
              name = "reit_energy_rescue";
              sectors = [ "Real Estate"; "Energy"; "Materials" ];
            };
          U.Name_pattern
            {
              name = "trust_notes";
              pattern = "(?i)(\\bTrust\\b|\\bNotes\\b)";
            };
        ];
    }
  in
  let rows =
    [
      (* Real Estate REIT — rescued *)
      row ~name:"Arbor Realty Trust" ~exchange:"NYSE" "ABR" "Real Estate";
      (* Energy royalty trust — rescued *)
      row ~name:"Permian Basin Royalty Trust" ~exchange:"NYSE" "PBT" "Energy";
      (* Materials trust — rescued *)
      row ~name:"Mesabi Trust" ~exchange:"NYSE" "MSB" "Materials";
      (* Finance trust — NOT rescued (not in sector list), dropped *)
      row ~name:"XYZ Credit Trust" ~exchange:"NYSE" "XYZCT" "Financials";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (size_is 3);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to
                  (row ~name:"XYZ Credit Trust" ~exchange:"NYSE" "XYZCT"
                     "Financials");
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 3);
       ])

let test_keep_if_sector_no_match_does_not_rescue _ctx =
  (* A symbol in a sector NOT listed in Keep_if_sector is not rescued. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Keep_if_sector
            { name = "reit_only"; sectors = [ "Real Estate" ] };
          U.Name_pattern
            { name = "trust"; pattern = "(?i)\\bTrust\\b" };
        ];
    }
  in
  let rows =
    [
      (* Financials trust — not in rescue sectors, dropped *)
      row ~name:"ABC Investment Trust" ~exchange:"NASDAQ" "ABCT" "Financials";
    ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are []);
         field (fun r -> r.U.dropped) (size_is 1);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

(* --- Test runner --------------------------------------------------------- *)

let () =
  run_test_tt_main
    ("universe_filter"
    >::: [
           "filter"
           >::: [
                  "empty config is no-op" >:: test_empty_config_is_noop;
                  "symbol pattern drops matches"
                  >:: test_symbol_pattern_drops_matches;
                  "name pattern drops ETF/Fund/Trust/Notes"
                  >:: test_name_pattern_drops_etf_fund_etc;
                  "name pattern is case-insensitive with (?i) flag"
                  >:: test_name_pattern_case_insensitive;
                  "exchange_equals drops NYSE ARCA only"
                  >:: test_exchange_equals_drops_nyse_arca;
                  "allowlist rescues match" >:: test_allowlist_rescues_match;
                  "allowlist rescues even when exchange rule fires"
                  >:: test_allowlist_rescues_from_exchange_rule;
                  "multiple rules independent counts"
                  >:: test_multiple_rules_independent_counts;
                  "stats show zero for nonmatching rule"
                  >:: test_stats_zero_for_nonmatching_rule;
                  "Keep_if_sector rescues REITs (AAT kept, AAAA dropped, SPY kept)"
                  >:: test_keep_if_sector_rescues_reits;
                  "Keep_if_sector rescues multiple sectors"
                  >:: test_keep_if_sector_multiple_sectors;
                  "Keep_if_sector does not rescue unmatched sectors"
                  >:: test_keep_if_sector_no_match_does_not_rescue;
                ];
           "load_config"
           >::: [
                  "parses valid file" >:: test_load_config_ok;
                  "missing file is error" >:: test_load_config_missing_file;
                  "malformed sexp is error" >:: test_load_config_malformed;
                  "default-sexp shape parses" >:: test_default_shape_parses;
                ];
           "csv_io" >::: [ "roundtrip" >:: test_csv_roundtrip ];
           "universe_join"
           >::: [
                  "enriches rows with name + exchange"
                  >:: test_join_enriches_rows;
                  "missing universe symbols use empty fields"
                  >:: test_join_handles_missing_universe_symbols;
                ];
         ])
