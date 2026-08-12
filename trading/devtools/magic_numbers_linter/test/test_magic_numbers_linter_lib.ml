(* Regression suite for Magic_numbers_linter_lib -- pins the detection
   equivalence with the removed shell linter (linter_magic_numbers.sh) that
   PR #2272's qc-behavioral rework found undocumented: without a durable
   pinned test, a future edit that makes the linter detect LESS would pass
   every other committed check (build, fmt, the linter's own dogfooding on
   this codebase). See magic_numbers_linter_lib.mli's "exempt surface"
   section for the full rule enumeration these tests pin.

   Every value under test gets exactly one [assert_that] call, per
   .claude/rules/test-patterns.md. *)

open OUnit2
open Matchers
open Magic_numbers_linter_lib

(* ------------------------------------------------------------------ *)
(* Exempt literals -- the five gaps named in the PR #2272 CP2 rework:   *)
(* 1.0 and 0.5 were previously unpinned.                                *)
(* ------------------------------------------------------------------ *)

let test_exempt_literal_0_0 _ =
  assert_that (is_exempt_literal "0.0") (equal_to true)

let test_exempt_literal_1_0 _ =
  assert_that (is_exempt_literal "1.0") (equal_to true)

let test_exempt_literal_0_5 _ =
  assert_that (is_exempt_literal "0.5") (equal_to true)

let test_exempt_literal_2_0 _ =
  assert_that (is_exempt_literal "2.0") (equal_to true)

let test_exempt_literal_100_0 _ =
  assert_that (is_exempt_literal "100.0") (equal_to true)

let test_non_exempt_literal _ =
  assert_that (is_exempt_literal "42") (equal_to false)

(* End-to-end: an exempt literal never produces a violation even on an
   otherwise fully-scanned line. *)
let test_exempt_literal_1_0_end_to_end_no_violation _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "unit_price 1.0 dollars" ])
    (equal_to [])

let test_exempt_literal_0_5_end_to_end_no_violation _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "half_max 0.5 factor" ])
    (equal_to [])

(* ------------------------------------------------------------------ *)
(* Skip rules -- one test per rule folded into should_skip_line, in the *)
(* order documented in the .mli. The "e.g." rule is listed first below *)
(* per the rework instruction: it is the highest-priority gap, since it *)
(* exists specifically because of the #409 incident and was previously *)
(* pinned nowhere.                                                      *)
(* ------------------------------------------------------------------ *)

let test_skip_rule_eg _ =
  assert_that
    (should_skip_line "helper_use e.g. 42 as an example value")
    (equal_to true)

let test_skip_rule_eg_end_to_end_no_violation _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "helper_use e.g. 42 as an example value" ])
    (equal_to [])

let test_skip_rule_comment_marker _ =
  assert_that (should_skip_line "(* 42 is a magic number *)") (equal_to true)

let test_skip_rule_trailing_backslash _ =
  assert_that (should_skip_line "wrap_call 42 \\") (equal_to true)

let test_skip_rule_odd_quote_count _ =
  assert_that (should_skip_line "broken \"quote start 42") (equal_to true)

let test_skip_rule_eq_digit_default _ =
  assert_that (should_skip_line "threshold_default = 42") (equal_to true)

let test_skip_rule_eq_digit_default_negative _ =
  assert_that (should_skip_line "y = -42") (equal_to true)

let test_skip_rule_let_binding _ =
  assert_that (should_skip_line "let max_len = 42") (equal_to true)

let test_skip_rule_config _ =
  assert_that (should_skip_line "config.threshold 42") (equal_to true)

let test_skip_rule_arrow _ =
  assert_that (should_skip_line "Stage1 _ -> 42") (equal_to true)

let test_skip_rule_labeled_arg_len _ =
  assert_that (should_skip_line "foo ~len:42 bar") (equal_to true)

(* ~f: and ~pos: -- the other two of the five CP2 gaps (~len: was already
   pinned previously). *)
let test_skip_rule_labeled_arg_f _ =
  assert_that (should_skip_line "foo ~f:42 bar") (equal_to true)

let test_skip_rule_labeled_arg_pos _ =
  assert_that (should_skip_line "foo ~pos:42 bar") (equal_to true)

let test_not_skipped_plain_line _ =
  assert_that (should_skip_line "foo bar 42 baz") (equal_to false)

(* ------------------------------------------------------------------ *)
(* has_let_binding / has_eq_digit_default -- exposed separately from    *)
(* should_skip_line for targeted testing, per the rework instruction.   *)
(* ------------------------------------------------------------------ *)

let test_has_let_binding_true _ =
  assert_that (has_let_binding "let max_len = 42") (equal_to true)

let test_has_let_binding_false _ =
  assert_that (has_let_binding "foo bar 42 baz") (equal_to false)

let test_has_eq_digit_default_true _ =
  assert_that (has_eq_digit_default "threshold_default = 42") (equal_to true)

let test_has_eq_digit_default_negative _ =
  assert_that (has_eq_digit_default "y = -42") (equal_to true)

let test_has_eq_digit_default_false _ =
  assert_that (has_eq_digit_default "foo bar 42 baz") (equal_to false)

(* ------------------------------------------------------------------ *)
(* extract_candidates -- basic positive cases, grounding the negatives  *)
(* below.                                                                *)
(* ------------------------------------------------------------------ *)

let test_extract_basic_integer _ =
  assert_that (extract_candidates "foo bar 42 baz") (equal_to [ "42" ])

let test_extract_basic_float _ =
  assert_that (extract_candidates "compute 3.14 tail") (equal_to [ "3.14" ])

let test_extract_multiple_candidates_per_line _ =
  assert_that
    (extract_candidates "Array.make 42 0.0")
    (equal_to [ "42"; "0.0" ])

let test_extract_single_digit_never_a_candidate _ =
  (* Dead-arm note (also in the .mli): the integer branch of extraction
     requires a 2+ digit run, so a bare single digit is never a candidate --
     is_exempt_literal's "0"/"1" arms are consequently unreachable. *)
  assert_that (extract_candidates "value 7") (equal_to [])

let test_extract_glued_to_identifier_not_recognized _ =
  assert_that (extract_candidates "identifier42value okay") (equal_to [])

(* ------------------------------------------------------------------ *)
(* extract_candidates -- adversarial extraction edge cases (this is a   *)
(* character-level scan, not a real numeric-literal parser; none of     *)
(* these valid-OCaml-syntax or plausible-looking numbers are recognized *)
(* as candidates -- pinned here so a future "improvement" to the        *)
(* extraction regex is a deliberate, reviewed decision, not a silent    *)
(* side effect).                                                        *)
(* ------------------------------------------------------------------ *)

let test_extract_scientific_notation_not_recognized _ =
  assert_that (extract_candidates "value 1e5 here") (equal_to [])

let test_extract_hex_not_recognized _ =
  assert_that (extract_candidates "value 0x2A here") (equal_to [])

let test_extract_trailing_dot_not_recognized _ =
  assert_that (extract_candidates "value 12. done") (equal_to [])

let test_extract_leading_dot_not_recognized _ =
  assert_that (extract_candidates "value .55 here") (equal_to [])

let test_extract_underscore_separator_not_recognized _ =
  assert_that (extract_candidates "value 42_000 here") (equal_to [])

let test_extract_multi_dot_not_recognized _ =
  assert_that (extract_candidates "value 12.34.56 here") (equal_to [])

let test_extract_dotted_version_not_recognized _ =
  assert_that (extract_candidates "version v1.2.3 here") (equal_to [])

(* ------------------------------------------------------------------ *)
(* strip_quoted_segments / quoted-string handling.                      *)
(* ------------------------------------------------------------------ *)

let test_strip_quoted_segments_removes_quoted_span _ =
  assert_that
    (strip_quoted_segments "log_msg \"value is 42 today\"")
    (equal_to "log_msg ")

let test_number_inside_quotes_not_flagged _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "log_msg \"value is 42 today\"" ])
    (equal_to [])

let test_number_outside_quotes_flagged _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "compute_value 42 label \"some text\"" ])
    (equal_to [ "f.ml: 42 in: compute_value 42 label \"some text\"" ])

(* ------------------------------------------------------------------ *)
(* Comment-depth tracking, including a nested (* (* *) *) marker.       *)
(* ------------------------------------------------------------------ *)

(* A single-line nested comment nets opens == closes (2 each), so depth
   returns to 0 and does not suppress the following line. *)
let test_comment_depth_nested_single_line_does_not_leak _ =
  assert_that
    (scan_file_lines ~path:"f.ml" [ "(* (* *) *)"; "real_call 99" ])
    (equal_to [ "f.ml: 99 in: real_call 99" ])

(* A nested comment spanning multiple lines: depth goes 0 -> 2 (two opens
   on line 1) -> 1 (one close on line 3) -> 0 (the other close on line 5).
   Both "42"s inside the still-open comment are suppressed; only the line
   after the comment fully closes is scanned. *)
let test_comment_depth_nested_multiline _ =
  assert_that
    (scan_file_lines ~path:"f.ml"
       [
         "(* outer start (* inner";
         "   42 still inside";
         "   inner *)";
         "   42 still inside outer";
         "outer *)";
         "real_call 42";
       ])
    (equal_to [ "f.ml: 42 in: real_call 42" ])

(* ------------------------------------------------------------------ *)
(* End-to-end scan_file_lines on an inline string list -- the shape the  *)
(* rework asked for: no fixture files, no temp dirs, no subprocess.      *)
(* ------------------------------------------------------------------ *)

let test_scan_file_lines_end_to_end _ =
  assert_that
    (scan_file_lines ~path:"fixture.ml"
       [
         "foo bar 42 baz";
         "process_batch 250";
         "value 7";
         "compute 3.14 tail";
         "apply 100.0 percent";
         "Array.make 42 0.0";
       ])
    (equal_to
       [
         "fixture.ml: 42 in: foo bar 42 baz";
         "fixture.ml: 250 in: process_batch 250";
         "fixture.ml: 3.14 in: compute 3.14 tail";
         "fixture.ml: 42 in: Array.make 42 0.0";
       ])

let () =
  run_test_tt_main
    ("magic_numbers_linter_lib_tests"
    >::: [
           "exempt literal 0.0" >:: test_exempt_literal_0_0;
           "exempt literal 1.0" >:: test_exempt_literal_1_0;
           "exempt literal 0.5" >:: test_exempt_literal_0_5;
           "exempt literal 2.0" >:: test_exempt_literal_2_0;
           "exempt literal 100.0" >:: test_exempt_literal_100_0;
           "non-exempt literal 42" >:: test_non_exempt_literal;
           "exempt 1.0 end-to-end no violation"
           >:: test_exempt_literal_1_0_end_to_end_no_violation;
           "exempt 0.5 end-to-end no violation"
           >:: test_exempt_literal_0_5_end_to_end_no_violation;
           "skip rule: e.g." >:: test_skip_rule_eg;
           "skip rule: e.g. end-to-end no violation"
           >:: test_skip_rule_eg_end_to_end_no_violation;
           "skip rule: comment marker" >:: test_skip_rule_comment_marker;
           "skip rule: trailing backslash" >:: test_skip_rule_trailing_backslash;
           "skip rule: odd quote count" >:: test_skip_rule_odd_quote_count;
           "skip rule: = <digit> default" >:: test_skip_rule_eq_digit_default;
           "skip rule: = -<digit> negative default"
           >:: test_skip_rule_eq_digit_default_negative;
           "skip rule: let binding" >:: test_skip_rule_let_binding;
           "skip rule: config." >:: test_skip_rule_config;
           "skip rule: ->" >:: test_skip_rule_arrow;
           "skip rule: ~len:" >:: test_skip_rule_labeled_arg_len;
           "skip rule: ~f:" >:: test_skip_rule_labeled_arg_f;
           "skip rule: ~pos:" >:: test_skip_rule_labeled_arg_pos;
           "plain line is not skipped" >:: test_not_skipped_plain_line;
           "has_let_binding: true case" >:: test_has_let_binding_true;
           "has_let_binding: false case" >:: test_has_let_binding_false;
           "has_eq_digit_default: true case" >:: test_has_eq_digit_default_true;
           "has_eq_digit_default: negative case"
           >:: test_has_eq_digit_default_negative;
           "has_eq_digit_default: false case"
           >:: test_has_eq_digit_default_false;
           "extract: basic integer" >:: test_extract_basic_integer;
           "extract: basic float" >:: test_extract_basic_float;
           "extract: multiple candidates per line"
           >:: test_extract_multiple_candidates_per_line;
           "extract: single digit never a candidate"
           >:: test_extract_single_digit_never_a_candidate;
           "extract: glued to identifier not recognized"
           >:: test_extract_glued_to_identifier_not_recognized;
           "extract: scientific notation not recognized"
           >:: test_extract_scientific_notation_not_recognized;
           "extract: hex literal not recognized"
           >:: test_extract_hex_not_recognized;
           "extract: trailing dot not recognized"
           >:: test_extract_trailing_dot_not_recognized;
           "extract: leading dot not recognized"
           >:: test_extract_leading_dot_not_recognized;
           "extract: underscore separator not recognized"
           >:: test_extract_underscore_separator_not_recognized;
           "extract: multi-dot not recognized"
           >:: test_extract_multi_dot_not_recognized;
           "extract: dotted version not recognized"
           >:: test_extract_dotted_version_not_recognized;
           "strip_quoted_segments removes quoted span"
           >:: test_strip_quoted_segments_removes_quoted_span;
           "number inside quotes not flagged"
           >:: test_number_inside_quotes_not_flagged;
           "number outside quotes flagged"
           >:: test_number_outside_quotes_flagged;
           "comment depth: nested single line does not leak"
           >:: test_comment_depth_nested_single_line_does_not_leak;
           "comment depth: nested multiline"
           >:: test_comment_depth_nested_multiline;
           "scan_file_lines end-to-end" >:: test_scan_file_lines_end_to_end;
         ])
