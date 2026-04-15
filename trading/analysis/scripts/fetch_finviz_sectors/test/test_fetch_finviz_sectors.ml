open Core
open OUnit2
open Matchers

(* --- Sample HTML fragments ----------------------------------------------- *)

let _sample_html_aapl =
  {|<html><body>
<table class="snapshot-table2">
<tr>
<td class="snapshot-td2-cp" width="7%"><b>Index</b></td>
<td class="snapshot-td2" width="7%"><b><a href="screener.ashx?v=111&amp;f=idx_sp500" class="tab-link">S&amp;P 500</a></b></td>
<td class="snapshot-td2-cp" width="7%"><b>P/E</b></td>
<td class="snapshot-td2" width="7%"><b>33.22</b></td>
</tr>
<tr>
<td class="snapshot-td2-cp"><b>Sector</b></td>
<td class="snapshot-td2"><b><a href="screener.ashx?v=111&amp;f=sec_technology" class="tab-link">Technology</a></b></td>
<td class="snapshot-td2-cp"><b>EPS (ttm)</b></td>
<td class="snapshot-td2"><b>6.30</b></td>
</tr>
<tr>
<td class="snapshot-td2-cp"><b>Industry</b></td>
<td class="snapshot-td2"><b><a href="screener.ashx?v=111&amp;f=ind_consumerelectronics" class="tab-link">Consumer Electronics</a></b></td>
</tr>
</table>
</body></html>|}

let _sample_html_jpm =
  {|<table>
<tr>
<td class="snapshot-td2-cp"><b>Sector</b></td>
<td class="snapshot-td2"><b><a href="screener.ashx?v=111&amp;f=sec_financialservices" class="tab-link">Financial Services</a></b></td>
</tr>
</table>|}

let _sample_html_no_sector =
  {|<html><body>
<table class="snapshot-table2">
<tr>
<td class="snapshot-td2-cp"><b>P/E</b></td>
<td class="snapshot-td2"><b>15.00</b></td>
</tr>
</table>
</body></html>|}

(* --- parse_sector tests -------------------------------------------------- *)

(* parse_sector normalizes Finviz labels to canonical GICS spellings. *)
let test_parse_sector_aapl _ctx =
  assert_that
    (Fetch_finviz_sectors_lib.parse_sector _sample_html_aapl)
    (is_some_and (equal_to "Information Technology"))

let test_parse_sector_jpm _ctx =
  assert_that
    (Fetch_finviz_sectors_lib.parse_sector _sample_html_jpm)
    (is_some_and (equal_to "Financials"))

let test_parse_sector_missing _ctx =
  assert_that
    (Fetch_finviz_sectors_lib.parse_sector _sample_html_no_sector)
    is_none

let test_parse_sector_empty _ctx =
  assert_that (Fetch_finviz_sectors_lib.parse_sector "") is_none

(* --- filter_common_stocks tests ------------------------------------------ *)

let _make_info ?(exchange = "NYSE") symbol : Types.Instrument_info.t =
  { symbol; name = ""; sector = ""; industry = ""; market_cap = 0.0; exchange }

let test_filter_common_stocks _ctx =
  let instruments =
    [
      _make_info "AAPL";
      _make_info "GSPC.INDX";
      _make_info ~exchange:"INDEX" "DJI";
      _make_info "ABCW";
      _make_info "XYZ-PA";
      _make_info "MSFT";
      _make_info "TEST.U";
    ]
  in
  let result = Fetch_finviz_sectors_lib.filter_common_stocks instruments in
  assert_that result (elements_are [ equal_to "AAPL"; equal_to "MSFT" ])

(* --- CSV I/O tests ------------------------------------------------------- *)

let test_write_and_load_csv _ctx =
  let tmp_dir = Stdlib.Filename.temp_dir "finviz_test" "" in
  let rows =
    [
      ("AAPL", "Technology");
      ("JPM", "Financial Services");
      ("MSFT", "Technology");
    ]
  in
  (match Fetch_finviz_sectors_lib.write_sectors_csv ~data_dir:tmp_dir rows with
  | Ok () -> ()
  | Error e -> assert_failure ("write failed: " ^ e));
  let loaded =
    Fetch_finviz_sectors_lib.load_existing_sectors (tmp_dir ^ "/sectors.csv")
  in
  assert_that (Hashtbl.length loaded) (equal_to 3);
  assert_that (Hashtbl.find loaded "AAPL") (is_some_and (equal_to "Technology"));
  assert_that
    (Hashtbl.find loaded "JPM")
    (is_some_and (equal_to "Financial Services"));
  Stdlib.Sys.remove (tmp_dir ^ "/sectors.csv");
  Stdlib.Sys.rmdir tmp_dir

(* --- Manifest tests ------------------------------------------------------ *)

let test_manifest_roundtrip _ctx =
  let tmp = Stdlib.Filename.temp_file "manifest" ".sexp" in
  let m : Fetch_finviz_sectors_lib.manifest =
    {
      fetched_at = "2026-04-14 12:00:00Z";
      source = "finviz";
      row_count = 100;
      rate_limit_rps = 1.0;
      errors = [ "BADTICKER" ];
    }
  in
  Fetch_finviz_sectors_lib.save_manifest tmp m;
  let loaded = Fetch_finviz_sectors_lib.load_manifest tmp in
  assert_that loaded
    (is_some_and
       (all_of
          [
            field
              (fun (m : Fetch_finviz_sectors_lib.manifest) -> m.source)
              (equal_to "finviz");
            field
              (fun (m : Fetch_finviz_sectors_lib.manifest) -> m.row_count)
              (equal_to 100);
            field
              (fun (m : Fetch_finviz_sectors_lib.manifest) -> m.errors)
              (elements_are [ equal_to "BADTICKER" ]);
          ]));
  Stdlib.Sys.remove tmp

let test_manifest_missing _ctx =
  let result =
    Fetch_finviz_sectors_lib.load_manifest "/nonexistent/manifest.sexp"
  in
  assert_that result is_none

let test_manifest_fresh _ctx =
  let now = Time_float_unix.to_string_utc (Time_float_unix.now ()) in
  let m : Fetch_finviz_sectors_lib.manifest =
    {
      fetched_at = now;
      source = "finviz";
      row_count = 50;
      rate_limit_rps = 1.0;
      errors = [];
    }
  in
  assert_that
    (Fetch_finviz_sectors_lib.manifest_is_fresh m ~max_age_days:30)
    (equal_to true)

let test_manifest_stale _ctx =
  let m : Fetch_finviz_sectors_lib.manifest =
    {
      fetched_at = "2020-01-01 00:00:00Z";
      source = "finviz";
      row_count = 50;
      rate_limit_rps = 1.0;
      errors = [];
    }
  in
  assert_that
    (Fetch_finviz_sectors_lib.manifest_is_fresh m ~max_age_days:30)
    (equal_to false)

(* --- Test runner --------------------------------------------------------- *)

let () =
  run_test_tt_main
    ("fetch_finviz_sectors"
    >::: [
           "parse_sector"
           >::: [
                  "AAPL" >:: test_parse_sector_aapl;
                  "JPM" >:: test_parse_sector_jpm;
                  "missing" >:: test_parse_sector_missing;
                  "empty" >:: test_parse_sector_empty;
                ];
           "filter" >::: [ "common stocks" >:: test_filter_common_stocks ];
           "csv_io" >::: [ "write and load" >:: test_write_and_load_csv ];
           "manifest"
           >::: [
                  "roundtrip" >:: test_manifest_roundtrip;
                  "missing file" >:: test_manifest_missing;
                  "fresh" >:: test_manifest_fresh;
                  "stale" >:: test_manifest_stale;
                ];
         ])
