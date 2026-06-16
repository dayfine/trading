open Core
open OUnit2
open Matchers
module Readme_block = Readme_toplines.Readme_block

let block_a = Readme_block.render "BODY A"
let block_b = Readme_block.render "BODY B"

(* When the document has no markers, the block is appended. *)
let test_upsert_appends_when_absent _ =
  let document = "# trading\n\nsome text\n" in
  let result = Readme_block.upsert ~document ~block:block_a in
  assert_that result
    (all_of
       [
         field (fun s -> String.is_prefix s ~prefix:"# trading") (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"BODY A")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:Readme_block.start_marker)
           (equal_to true);
       ])

(* When the markers exist, only the region between them is replaced. *)
let test_upsert_replaces_region _ =
  let document =
    String.concat ~sep:"\n" [ "# header"; "before"; block_a; "after"; "tail" ]
  in
  let result = Readme_block.upsert ~document ~block:block_b in
  assert_that result
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:"BODY B")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"BODY A")
           (equal_to false);
         (* surrounding content preserved *)
         field
           (fun s -> String.is_substring s ~substring:"before")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"after")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"tail")
           (equal_to true);
       ])

(* Regenerating with the same block twice is a no-op. *)
let test_upsert_idempotent _ =
  let document = "# header\n\nbody\n" in
  let once = Readme_block.upsert ~document ~block:block_a in
  let twice = Readme_block.upsert ~document:once ~block:block_a in
  assert_that twice (equal_to once)

(* An unterminated marker block must raise, never silently corrupt. *)
let test_upsert_raises_on_unterminated _ =
  let document =
    String.concat ~sep:"\n" [ "# header"; Readme_block.start_marker; "body" ]
  in
  assert_raises
    (Invalid_argument
       "Readme_block.upsert: start marker has no matching end marker")
    (fun () -> Readme_block.upsert ~document ~block:block_a)

let test_render_wraps_in_markers _ =
  assert_that block_a
    (all_of
       [
         field
           (fun s -> String.is_prefix s ~prefix:Readme_block.start_marker)
           (equal_to true);
         field
           (fun s -> String.is_suffix s ~suffix:Readme_block.end_marker)
           (equal_to true);
       ])

let suite =
  "readme_block"
  >::: [
         "upsert_appends_when_absent" >:: test_upsert_appends_when_absent;
         "upsert_replaces_region" >:: test_upsert_replaces_region;
         "upsert_idempotent" >:: test_upsert_idempotent;
         "upsert_raises_on_unterminated" >:: test_upsert_raises_on_unterminated;
         "render_wraps_in_markers" >:: test_render_wraps_in_markers;
       ]

let () = run_test_tt_main suite
