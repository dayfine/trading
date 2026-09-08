(** The warehouse exceptions file is parsed ONCE, strictly, into a record with
    two optional sections; [Build_runner.load_tail_exceptions] and
    [load_splice_exceptions] are views of it (#2672 class ii).

    Two properties are in tension and both must hold. {b Optional}: either
    section may be absent, so the pre-class-ii file (only [keep_tail]) and a
    splice-only file both load. {b Strict}: no other field is admitted, so a
    mistyped section name fails the load instead of silently yielding an empty
    veto list — the fatal load path exists precisely because degrading to "no
    exceptions" would edit the symbols a reviewer vetoed. *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Series_splice = Snapshot_pipeline.Series_splice

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_exceptions" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

(* Both loaders against one on-disk file, so a case states what each section
   sees from the same bytes. *)
let _load contents =
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "warehouse_exceptions.sexp" in
      Out_channel.write_all path ~data:contents;
      ( Build_runner.load_tail_exceptions (Some path),
        Build_runner.load_splice_exceptions (Some path) ))

let _tail_mem symbol expected =
  is_ok_and_holds
    (field (fun t -> Series_tail.Exceptions.mem t ~symbol) (equal_to expected))

let _tail_has symbol = _tail_mem symbol true
let _tail_lacks symbol = _tail_mem symbol false

let _splice_rule symbol rule =
  is_ok_and_holds
    (field
       (fun t -> Series_splice.Exceptions.find t ~symbol)
       (is_some_and (equal_to ~cmp:Series_splice.Exceptions.equal_rule rule)))

let _splice_silent symbol =
  is_ok_and_holds
    (field (fun t -> Series_splice.Exceptions.find t ~symbol) is_none)

(* The pre-#2672-class-ii shape. The splice section is absent, not empty. *)
let test_tail_only_file_loads_for_both_sections _ =
  assert_that
    (_load "((keep_tail (STMP WDR)))")
    (pair (_tail_has "STMP") (_splice_silent "ICT"))

(* The direction the old two-parser design got wrong: [keep_tail] absent used
   to be a hard parse failure, so a splice-only file could not be written. *)
let test_splice_only_file_loads_for_both_sections _ =
  assert_that
    (_load "((splice ((drop ICT))))")
    (pair (_tail_lacks "STMP")
       (_splice_rule "ICT" (Series_splice.Exceptions.Drop "ICT")))

(* One file, both sections, three rule shapes — the operator-facing contract. *)
let test_both_sections_load _ =
  assert_that
    (_load
       "((keep_tail (STMP))\n\
       \ (splice ((keep AGR) (drop ICT) (cut_at CHS 2004-12-20))))")
    (pair (_tail_has "STMP")
       (_splice_rule "CHS"
          (Series_splice.Exceptions.Cut_at ("CHS", Date.of_string "2004-12-20"))))

(* The guard the strict record buys back: a section name one letter wrong is a
   veto silently lost. Both loaders must refuse the file, not just the one
   whose section was misspelt. *)
let test_mistyped_section_name_is_an_error _ =
  assert_that
    (_load "((keep_tail ()) (splcie ((drop ICT))))")
    (pair is_error is_error)

let test_mistyped_tail_section_name_is_an_error _ =
  assert_that (_load "((keep_tal (STMP)))") (pair is_error is_error)

(* A rule spelling the file does not define is equally fatal — the strictness
   reaches inside the splice section, not just its name. *)
let test_unknown_splice_rule_is_an_error _ =
  assert_that (_load "((splice ((trim ICT))))") (pair is_error is_error)

(* Walk the cwd up to the source tree: [dune runtest]'s cwd is under [_build].
   Mirrors [Walk_forward] test_spec.ml's fixture locator. *)
let _committed_exceptions_path () =
  let target = "trading/test_data/warehouse_exceptions.sexp" in
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate = Filename.concat dir target in
      if try Stdlib.Sys.file_exists candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _load_path path =
  ( Build_runner.load_tail_exceptions path,
    Build_runner.load_splice_exceptions path )

let _committed_exceptions_path_exn () =
  match _committed_exceptions_path () with
  | Some path -> path
  | None ->
      assert_failure
        (Printf.sprintf "could not locate warehouse_exceptions.sexp from cwd %s"
           (Stdlib.Sys.getcwd ()))

(* The committed file a reviewer edits by hand must load under the strict
   record — the parse is part of its contract, and it is the only file the
   builders are ever pointed at. *)
let test_committed_exceptions_file_loads _ =
  assert_that
    (_load_path (Some (_committed_exceptions_path_exn ())))
    (pair (_tail_lacks "STMP") (_splice_silent "CHS"))

let test_no_path_is_empty_on_both_sides _ =
  assert_that (_load_path None)
    (pair (_tail_lacks "STMP") (_splice_silent "CHS"))

let suite =
  "build_runner_exceptions"
  >::: [
         "tail_only_file_loads_for_both_sections"
         >:: test_tail_only_file_loads_for_both_sections;
         "splice_only_file_loads_for_both_sections"
         >:: test_splice_only_file_loads_for_both_sections;
         "both_sections_load" >:: test_both_sections_load;
         "mistyped_section_name_is_an_error"
         >:: test_mistyped_section_name_is_an_error;
         "mistyped_tail_section_name_is_an_error"
         >:: test_mistyped_tail_section_name_is_an_error;
         "unknown_splice_rule_is_an_error"
         >:: test_unknown_splice_rule_is_an_error;
         "committed_exceptions_file_loads"
         >:: test_committed_exceptions_file_loads;
         "no_path_is_empty_on_both_sides"
         >:: test_no_path_is_empty_on_both_sides;
       ]

let () = run_test_tt_main suite
