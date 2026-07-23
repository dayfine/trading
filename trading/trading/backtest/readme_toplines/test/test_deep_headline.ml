open Core
open OUnit2
open Matchers
module Deep_headline = Readme_toplines.Deep_headline
module Readme_block = Readme_toplines.Readme_block

let promoted : Deep_headline.record =
  {
    label = "Weinstein top-3000 (promoted config)";
    total_return_pct = 8689.0;
    max_drawdown_pct = Some 30.3;
    trades = Some 1170;
    win_rate_pct = Some 38.4;
    period = "2000-01-01 -> 2026-06-26";
    scenario_path = "test_data/backtest_scenarios/staging/top3000.sexp";
    basis_commit = "6a2d9b426 (PR #2047)";
    date = "2026-07-23";
  }

let comparator : Deep_headline.record =
  {
    label = "SPY total return (comparator)";
    total_return_pct = 706.0;
    max_drawdown_pct = None;
    trades = None;
    win_rate_pct = None;
    period = "2000-01-01 -> 2026-06-26";
    scenario_path = "n/a — dividend-adjusted buy & hold";
    basis_commit = "DEEP_RESULTS comparator";
    date = "2026-07-14";
  }

let _has ~substring =
  field (fun x -> String.is_substring x ~substring) (equal_to true)

(* render_markdown formats each record: thousands-grouped signed total return,
   one-decimal percents, thousands-grouped trades, and the DEEP_RESULTS caveat. *)
let test_render_markdown_formats_rows _ =
  let body = Deep_headline.render_markdown [ promoted ] in
  assert_that body
    (all_of
       [
         _has ~substring:"+8,689%";
         _has ~substring:"30.3%";
         _has ~substring:"1,170";
         _has ~substring:"38.4%";
         _has ~substring:"2000-01-01 -> 2026-06-26";
         (* provenance citation with scenario + commit + date *)
         _has ~substring:"6a2d9b426 (PR #2047)";
         _has ~substring:"top3000.sexp";
         (* standing caveat points at DEEP_RESULTS *)
         _has ~substring:"dev/backtest/DEEP_RESULTS.md";
       ])

(* Optional fields (max DD / trades / win rate) render as an em-dash for a
   comparator row that does not carry them. *)
let test_render_markdown_missing_fields_dash _ =
  let body = Deep_headline.render_markdown [ comparator ] in
  assert_that body (all_of [ _has ~substring:"+706%"; _has ~substring:"—" ])

(* render_block wraps the body between the deep-headline markers. *)
let test_render_block_wraps_in_markers _ =
  let block = Deep_headline.render_block [ promoted; comparator ] in
  assert_that block
    (all_of
       [
         field
           (fun s -> String.is_prefix s ~prefix:Deep_headline.start_marker)
           (equal_to true);
         field
           (fun s -> String.is_suffix s ~suffix:Deep_headline.end_marker)
           (equal_to true);
       ])

(* The deep block upserts into a document independently of the light block:
   only the deep marker region is replaced, surrounding lines are preserved. *)
let test_upsert_replaces_deep_region_only _ =
  let old_block =
    Readme_block.render_between ~start_marker:Deep_headline.start_marker
      ~end_marker:Deep_headline.end_marker "OLD DEEP BODY"
  in
  let document =
    String.concat ~sep:"\n"
      [
        "# header";
        "<!-- toplines:start -->";
        "light";
        "<!-- toplines:end -->";
        old_block;
        "tail";
      ]
  in
  let new_block = Deep_headline.render_block [ promoted ] in
  let result =
    Readme_block.upsert_between ~start_marker:Deep_headline.start_marker
      ~end_marker:Deep_headline.end_marker ~document ~block:new_block
  in
  assert_that result
    (all_of
       [
         _has ~substring:"+8,689%";
         field
           (fun s -> String.is_substring s ~substring:"OLD DEEP BODY")
           (equal_to false);
         (* the light block + surrounding lines are untouched *)
         _has ~substring:"<!-- toplines:start -->";
         _has ~substring:"light";
         _has ~substring:"tail";
       ])

(* record_of_sexp parses a single record; omitted optional fields become None. *)
let test_record_of_sexp_optional_omitted _ =
  let sexp =
    Sexp.of_string
      {|((label "A") (total_return_pct 100.0) (period "p")
        (scenario_path "s") (basis_commit "c") (date "d"))|}
  in
  let record = Deep_headline.record_of_sexp sexp in
  assert_that record
    (all_of
       [
         field (fun r -> r.Deep_headline.label) (equal_to "A");
         field (fun r -> r.Deep_headline.max_drawdown_pct) is_none;
         field (fun r -> r.Deep_headline.trades) is_none;
       ])

(* load of an existing, well-formed file round-trips the records. *)
let test_load_roundtrip _ =
  let path = Stdlib.Filename.temp_file "deep_headline" ".sexp" in
  let data =
    [ promoted; comparator ]
    |> List.map ~f:(fun r ->
        Sexp.to_string_hum (Deep_headline.sexp_of_record r))
    |> String.concat ~sep:"\n"
  in
  Out_channel.write_all path ~data;
  let loaded = Deep_headline.load path in
  Stdlib.Sys.remove path;
  assert_that loaded
    (is_some_and
       (elements_are
          [
            field (fun r -> r.Deep_headline.label) (equal_to promoted.label);
            field (fun r -> r.Deep_headline.label) (equal_to comparator.label);
          ]))

(* Missing file => None (skip block), never a crash. *)
let test_load_missing_returns_none _ =
  assert_that (Deep_headline.load "/nonexistent/deep_headline_xyz.sexp") is_none

(* A file that exists but is malformed is a defect => raise, not silently skip. *)
let test_load_malformed_raises _ =
  let path = Stdlib.Filename.temp_file "deep_headline_bad" ".sexp" in
  Out_channel.write_all path ~data:"(((not a record))";
  let raised =
    try
      ignore (Deep_headline.load path : _ option);
      false
    with _ -> true
  in
  Stdlib.Sys.remove path;
  assert_that raised (equal_to true)

let suite =
  "deep_headline"
  >::: [
         "render_markdown_formats_rows" >:: test_render_markdown_formats_rows;
         "render_markdown_missing_fields_dash"
         >:: test_render_markdown_missing_fields_dash;
         "render_block_wraps_in_markers" >:: test_render_block_wraps_in_markers;
         "upsert_replaces_deep_region_only"
         >:: test_upsert_replaces_deep_region_only;
         "record_of_sexp_optional_omitted"
         >:: test_record_of_sexp_optional_omitted;
         "load_roundtrip" >:: test_load_roundtrip;
         "load_missing_returns_none" >:: test_load_missing_returns_none;
         "load_malformed_raises" >:: test_load_malformed_raises;
       ]

let () = run_test_tt_main suite
