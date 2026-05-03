open Core
open OUnit2
open Matchers
open Wiki_sp500.Changes_parser

(* Pinned snapshot of [<table id="changes">] from
   [https://en.wikipedia.org/wiki/List_of_S%26P_500_companies] on
   2026-05-03 (curl + awk extract, verbatim). 394 data rows at capture;
   threshold 390 leaves room for small Wikipedia editorial drift. *)
let _pinned_html_path = "./data/changes_table_2026-05-03.html"
let _min_expected_events = 390
let _load_pinned_html () = In_channel.read_all _pinned_html_path

let _parse_pinned_exn () =
  match parse (_load_pinned_html ()) with
  | Ok events -> events
  | Error err ->
      assert_failure ("Failed to parse pinned HTML: " ^ Status.show err)

let _find_event_on events ~y ~m ~d =
  let target = Date.create_exn ~y ~m ~d in
  List.filter events ~f:(fun e -> Date.equal e.effective_date target)

let test_parses_pinned_snapshot _ =
  let events = _parse_pinned_exn () in
  assert_that (List.length events) (ge (module Int_ord) _min_expected_events)

let test_returns_error_on_missing_table _ =
  assert_that (parse "<html><body>no table here</body></html>") is_error

(* 2026-04-09: CASY (Casey's) added, HOLX (Hologic) removed. *)
let test_known_event_2026_04_09 _ =
  let matches =
    _find_event_on (_parse_pinned_exn ()) ~y:2026 ~m:Month.Apr ~d:9
  in
  assert_that matches
    (elements_are
       [
         all_of
           [
             field
               (fun e -> e.added)
               (is_some_and
                  (equal_to
                     ({ symbol = "CASY"; security_name = "Casey's" }
                       : ticker_id)));
             field
               (fun e -> e.removed)
               (is_some_and
                  (equal_to
                     ({ symbol = "HOLX"; security_name = "Hologic" }
                       : ticker_id)));
           ];
       ])

(* 2008-09-12: two events — CRM/FRE and FAST/FNM. The plan's original
   2009-09-21/CRM-IR anchor doesn't appear in the pinned table; we use
   the verifiable rows instead. *)
let test_known_event_2008_09_12 _ =
  let matches =
    _find_event_on (_parse_pinned_exn ()) ~y:2008 ~m:Month.Sep ~d:12
  in
  assert_that matches
    (elements_are
       [
         all_of
           [
             field
               (fun e -> e.added)
               (is_some_and (field (fun a -> a.symbol) (equal_to "CRM")));
             field
               (fun e -> e.removed)
               (is_some_and (field (fun r -> r.symbol) (equal_to "FRE")));
           ];
         all_of
           [
             field
               (fun e -> e.added)
               (is_some_and (field (fun a -> a.symbol) (equal_to "FAST")));
             field
               (fun e -> e.removed)
               (is_some_and (field (fun r -> r.symbol) (equal_to "FNM")));
           ];
       ])

(* 1999-04-12: ACT (Actavis) added, no removal. *)
let test_handles_empty_removed _ =
  let matches =
    _find_event_on (_parse_pinned_exn ()) ~y:1999 ~m:Month.Apr ~d:12
  in
  assert_that matches
    (elements_are
       [
         all_of
           [
             field
               (fun e -> e.added)
               (is_some_and
                  (equal_to
                     ({ symbol = "ACT"; security_name = "Actavis" } : ticker_id)));
             field (fun e -> e.removed) is_none;
           ];
       ])

(* Multiple rows in the pinned table have empty Added cells (e.g.
   2025-11-04 EMN removal). Verify at least one is preserved as None. *)
let test_handles_empty_added _ =
  let events = _parse_pinned_exn () in
  let with_empty_added =
    List.filter events ~f:(fun e -> Option.is_none e.added)
  in
  assert_that (List.length with_empty_added) (gt (module Int_ord) 0)

(* Reason text must be free of any HTML markup, including [<sup>] footnote
   markers (which carry [cite_ref...] anchors inside). *)
let test_strips_sup_footnotes _ =
  let events = _parse_pinned_exn () in
  let bad =
    List.filter events ~f:(fun e ->
        String.is_substring e.reason_text ~substring:"<sup"
        || String.is_substring e.reason_text ~substring:"</sup>"
        || String.is_substring e.reason_text ~substring:"<a "
        || String.is_substring e.reason_text ~substring:"cite_ref")
  in
  assert_that bad (size_is 0)

(* HTML entities (e.g. [&amp;] in "S&P 500") must be decoded. *)
let test_decodes_entities_in_reason _ =
  let events = _parse_pinned_exn () in
  let with_amp_entity =
    List.filter events ~f:(fun e ->
        String.is_substring e.reason_text ~substring:"&amp;")
  in
  assert_that with_amp_entity (size_is 0)

(* The Casey's row uses [&#39;] for the apostrophe; verify decode. *)
let test_preserves_security_name_with_special_chars _ =
  let matches =
    _find_event_on (_parse_pinned_exn ()) ~y:2026 ~m:Month.Apr ~d:9
  in
  assert_that matches
    (elements_are
       [
         field
           (fun e -> e.added)
           (is_some_and (field (fun a -> a.security_name) (equal_to "Casey's")));
       ])

let suite =
  "changes_parser_test"
  >::: [
         "parses_pinned_snapshot" >:: test_parses_pinned_snapshot;
         "returns_error_on_missing_table"
         >:: test_returns_error_on_missing_table;
         "known_event_2026_04_09" >:: test_known_event_2026_04_09;
         "known_event_2008_09_12" >:: test_known_event_2008_09_12;
         "handles_empty_removed" >:: test_handles_empty_removed;
         "handles_empty_added" >:: test_handles_empty_added;
         "strips_sup_footnotes" >:: test_strips_sup_footnotes;
         "decodes_entities_in_reason" >:: test_decodes_entities_in_reason;
         "preserves_security_name_with_special_chars"
         >:: test_preserves_security_name_with_special_chars;
       ]

let () = run_test_tt_main suite
