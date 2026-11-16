(** Tests for {!Public_summary}: the price-free public summary committed as
    [dev/weekly-picks/<system-version>/<date>-picks.md]. Pins the table rows,
    the empty-list [(none)] case, the beyond-cap counts and the short-list note,
    and that no price-bearing snapshot value reaches the output. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

(* Every price- or size-bearing field carries a distinctive value, so the
   leakage test can search the output for it. *)
let _cand ~symbol ~score ~grade ~sector : Weekly_snapshot.candidate =
  {
    symbol;
    score;
    grade;
    entry = 123.45;
    stop = 98.76;
    sector;
    rationale = "Stage2 breakout 31.37% above the base";
    rs_vs_spy = Some 1.2345;
    resistance_grade = Some "Moderate_resistance (7.89)";
    sized_shares = 4242;
    sized_position_value = 51234.5;
    sized_position_pct = 0.1234;
    sized_risk_amount = 1066.1;
    sizing_note = Some "sized on 55.55";
    stop_is_structural = true;
    data_suspect = false;
    reconciliation = Entry_reconciliation.Not_reconciled;
    score_components = [ ("Strong volume", 20) ];
  }

let _held : Weekly_snapshot.held_position =
  {
    symbol = "HELDCO";
    entered = Date.of_string "2026-06-05";
    stop = 66.66;
    status = "Holding";
    shares = 3131;
    entry_price = 77.77;
    current_price = 88.88;
    unrealized_pct = 14.29;
    recommended_stop = Some 69.69;
  }

let _snapshot ?(longs = []) ?(shorts = []) ?(strong = []) ?(weak = [])
    ?(long_beyond = 0) ?(short_beyond = 0) () : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "abc123def";
    date = Date.of_string "2026-11-20";
    macro = { regime = "Neutral"; score = 0.5 };
    sectors_strong = strong;
    sectors_weak = weak;
    long_candidates = longs;
    short_candidates = shorts;
    long_eligible_beyond_cap = long_beyond;
    short_eligible_beyond_cap = short_beyond;
    held_positions = [ _held ];
    warnings = [ "SPARSE: ZZZZ closed at 11.11" ];
  }

let _longs =
  [
    _cand ~symbol:"ARLP" ~score:120.0 ~grade:"A+" ~sector:"Energy";
    _cand ~symbol:"LECO" ~score:87.5 ~grade:"A" ~sector:"Information Technology";
  ]

let _shorts n =
  List.init n ~f:(fun i ->
      _cand ~symbol:(sprintf "SHT%d" i) ~score:90.0 ~grade:"A+"
        ~sector:"Utilities")

let _header =
  "# Weekly picks — 2026-11-20 (public summary)\n\n\
   System version: `abc123def`. Generated with \
   `dev/weekly-picks/record-config-overrides.sexp` (README, \"Weekly \
   cadence\"). Price-free summary: the full record (entries, stops, tickets, \
   charts, validation) is in the private `dayfine/trading-results` repo under \
   the same path.\n\n"

let test_full_summary_pins_every_section _ =
  let snap =
    _snapshot ~longs:_longs ~shorts:(_shorts 2)
      ~strong:[ "Energy"; "Health Care" ]
      ~weak:[ "Utilities" ] ~long_beyond:134 ~short_beyond:7 ()
  in
  assert_that
    (Public_summary.render snap)
    (equal_to
       (_header
      ^ "## Macro\n\n\
         **Neutral** (score 0.5)\n\n\
         ## Strong sectors\n\n\
         - Energy\n\
         - Health Care\n\n\
         ## Weak sectors\n\n\
         - Utilities\n\n\
         ## Long candidates (2, 134 more eligible beyond the cap)\n\n\
         | Rank | Symbol | Grade | Score | Sector |\n\
         |---|---|---|---|---|\n\
         | 1 | ARLP | A+ | 120 | Energy |\n\
         | 2 | LECO | A | 87.5 | Information Technology |\n\n\
         ## Short candidates (2, 7 more eligible beyond the cap)\n\n\
         | Rank | Symbol | Grade | Score | Sector |\n\
         |---|---|---|---|---|\n\
         | 1 | SHT0 | A+ | 90 | Utilities |\n\
         | 2 | SHT1 | A+ | 90 | Utilities |\n\n\
         _Shorts are report-only: the record config sets enable_short_side \
         false._\n"))

let test_empty_lists_print_none _ =
  assert_that
    (Public_summary.render (_snapshot ()))
    (equal_to
       (_header
      ^ "## Macro\n\n\
         **Neutral** (score 0.5)\n\n\
         ## Strong sectors\n\n\
         (none)\n\n\
         ## Weak sectors\n\n\
         (none)\n\n\
         ## Long candidates (0, 0 more eligible beyond the cap)\n\n\
         (none)\n\n\
         ## Short candidates (0, 0 more eligible beyond the cap)\n\n\
         (none)\n\n"))

(* The short heading names the report's own display cap only when the list is
   longer than it; the beyond-cap count stays whatever the snapshot carries. *)
let test_short_note_appears_only_beyond_the_display_cap _ =
  let heading n =
    Public_summary.render (_snapshot ~shorts:(_shorts n) ~short_beyond:119 ())
    |> String.split_lines
    |> List.find ~f:(String.is_prefix ~prefix:"## Short candidates")
  in
  assert_that
    (heading Report_renderer.default_short_display_limit)
    (is_some_and
       (equal_to "## Short candidates (5, 119 more eligible beyond the cap)"));
  assert_that
    (heading (Report_renderer.default_short_display_limit + 1))
    (is_some_and
       (equal_to
          "## Short candidates (6, 119 more eligible beyond the cap; the \
           rendered report shows the top 5)"))

let test_config_path_names_the_overrides_file _ =
  assert_that
    (Public_summary.render ~config_path:"cfg/other.sexp" (_snapshot ())
    |> String.is_substring ~substring:"Generated with `cfg/other.sexp`")
    (equal_to true)

(* The summary is committed to a public repo: no price-, size- or
   position-bearing value of the snapshot may appear in it, in any of the
   spellings the renderers use. *)
let test_no_price_bearing_value_reaches_the_output _ =
  let snap =
    _snapshot ~longs:_longs ~shorts:(_shorts 6) ~strong:[ "Energy" ]
      ~long_beyond:3 ~short_beyond:4 ()
  in
  let out = Public_summary.render snap in
  let spellings x =
    [ Float.to_string x; sprintf "%.2f" x; sprintf "%.1f" x; sprintf "%g" x ]
  in
  let forbidden =
    List.concat_map
      [
        123.45; 98.76; 51234.5; 1066.1; 77.77; 88.88; 66.66; 69.69; 55.55; 11.11;
      ]
      ~f:spellings
    @ [ "4242"; "3131"; "HELDCO"; "ZZZZ"; "Stage2 breakout"; "Moderate" ]
  in
  assert_that
    (List.filter forbidden ~f:(fun s -> String.is_substring out ~substring:s))
    is_empty

let suite =
  "public_summary"
  >::: [
         "full_summary_pins_every_section"
         >:: test_full_summary_pins_every_section;
         "empty_lists_print_none" >:: test_empty_lists_print_none;
         "short_note_appears_only_beyond_the_display_cap"
         >:: test_short_note_appears_only_beyond_the_display_cap;
         "config_path_names_the_overrides_file"
         >:: test_config_path_names_the_overrides_file;
         "no_price_bearing_value_reaches_the_output"
         >:: test_no_price_bearing_value_reaches_the_output;
       ]

let () = run_test_tt_main suite
