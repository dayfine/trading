open Core
open OUnit2
open Matchers
open Eodhd_delisted_audit_lib

let _eodhd_fixture_path = "./data/eodhd_delisted_fixture.json"
let _removed_fixture_path = "./data/sp500_removed_fixture.sexp"

let _load_eodhd () =
  match parse_eodhd_fixture (In_channel.read_all _eodhd_fixture_path) with
  | Ok x -> x
  | Error err ->
      assert_failure ("Failed to parse EODHD fixture: " ^ Status.show err)

let _load_removed () =
  match parse_removed_sexp (In_channel.read_all _removed_fixture_path) with
  | Ok x -> x
  | Error err ->
      assert_failure ("Failed to parse removed-sexp fixture: " ^ Status.show err)

let test_parse_eodhd_fixture _ =
  assert_that
    (parse_eodhd_fixture
       {|{"delisted":[{"Code":"LEH"}],"live":[{"Code":"AAPL"}]}|})
    (is_ok_and_holds
       (equal_to ({ delisted = [ "LEH" ]; live = [ "AAPL" ] } : eodhd_fixture)))

let test_parse_eodhd_fixture_rejects_bad_json _ =
  assert_that (parse_eodhd_fixture "{not json") is_error

let _removed_symbol ~symbol ~effective_date : removed_symbol =
  { symbol; effective_date }

let _row ~symbol ~effective_date ~status : row =
  { symbol; effective_date; status }

let test_parse_removed_sexp _ =
  let expected = _removed_symbol ~symbol:"ACE" ~effective_date:"2016-01-11" in
  assert_that
    (parse_removed_sexp {|(((symbol "ACE") (effective_date "2016-01-11")))|})
    (is_ok_and_holds (elements_are [ equal_to expected ]))

(* Pin the .mli "Returns [Error] on structural malformation" guard. *)
let test_parse_removed_sexp_rejects_malformed _ =
  assert_that (parse_removed_sexp "(((not a valid record") is_error

let test_cross_reference_three_statuses _ =
  let removed = _load_removed () in
  let eodhd = _load_eodhd () in
  let expected =
    [
      _row ~symbol:"ACE" ~effective_date:"2016-01-11" ~status:Not_found;
      _row ~symbol:"LEH" ~effective_date:"2008-09-22"
        ~status:Matched_in_eodhd_delisted;
      _row ~symbol:"WB" ~effective_date:"2008-12-22" ~status:Live_on_eodhd;
    ]
  in
  assert_that
    (cross_reference ~removed ~eodhd)
    (elements_are (List.map expected ~f:equal_to))

let _contains needle =
  field
    (fun md -> String.is_substring md ~substring:needle)
    (equal_to true
       ~msg:(Printf.sprintf "expected markdown to contain %S" needle))

let test_render_markdown_contains_summary_and_rows _ =
  let rows =
    cross_reference ~removed:(_load_removed ()) ~eodhd:(_load_eodhd ())
  in
  assert_that (render_markdown rows)
    (all_of
       [
         _contains "Matched: 1 / Live: 1 / Not-found: 1 (total: 3)";
         _contains "| LEH | 2008-09-22 | matched-in-eodhd-delisted |";
         _contains "| WB | 2008-12-22 | live-on-eodhd |";
         _contains "| ACE | 2016-01-11 | not-found |";
       ])

(* Pin the .mli "table sorted by status then symbol" guarantee — substring
   checks above pass with arbitrary row order, so without an index assertion
   the sort contract is unenforced. *)
let _index_of needle md =
  String.substr_index md ~pattern:needle |> Option.value ~default:Int.max_value

let _order_msg ~leh ~wb ~ace =
  Printf.sprintf
    "expected order matched < live < not-found, got LEH=%d WB=%d ACE=%d" leh wb
    ace

let test_render_markdown_sort_status_then_symbol _ =
  let rows =
    cross_reference ~removed:(_load_removed ()) ~eodhd:(_load_eodhd ())
  in
  let md = render_markdown rows in
  let leh = _index_of "| LEH " md in
  let wb = _index_of "| WB " md in
  let ace = _index_of "| ACE " md in
  let in_order = leh < wb && wb < ace in
  assert_that in_order (equal_to true ~msg:(_order_msg ~leh ~wb ~ace))

let () =
  run_test_tt_main
    ("eodhd_delisted_audit"
    >::: [
           "parse_eodhd_fixture" >:: test_parse_eodhd_fixture;
           "parse_eodhd_fixture_rejects_bad_json"
           >:: test_parse_eodhd_fixture_rejects_bad_json;
           "parse_removed_sexp" >:: test_parse_removed_sexp;
           "parse_removed_sexp_rejects_malformed"
           >:: test_parse_removed_sexp_rejects_malformed;
           "cross_reference_three_statuses"
           >:: test_cross_reference_three_statuses;
           "render_markdown_contains_summary_and_rows"
           >:: test_render_markdown_contains_summary_and_rows;
           "render_markdown_sort_status_then_symbol"
           >:: test_render_markdown_sort_status_then_symbol;
         ])
