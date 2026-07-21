open OUnit2
open Core
open Matchers
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "weekly_sidetable_test_" ".weekly"

let _entry ~day_seed ~mid ~high : Weekly_sidetable.entry =
  {
    week_end_date = Date.add_days (Date.of_string "2010-01-08") (day_seed * 7);
    mid;
    high;
  }

(* Distinct per-entry mids/highs, including a negative and a large value, so the
   round-trip exercises float64 bit-identity rather than trivial equality. *)
let _entries n =
  List.init n ~f:(fun i ->
      _entry ~day_seed:i
        ~mid:(Float.of_int ((i * 100) + 1) +. 0.25)
        ~high:(Float.of_int ((i * 100) + 51) -. (0.5 *. Float.of_int (i - 3))))

let _round_trip entries =
  Weekly_sidetable.decode (Weekly_sidetable.encode entries)

(* ----- codec round-trip ----- *)

let test_round_trip_1_entry _ =
  let entries = _entries 1 in
  assert_that (_round_trip entries)
    (is_ok_and_holds (elements_are (List.map entries ~f:equal_to)))

let test_round_trip_520_entries _ =
  let entries = _entries 520 in
  assert_that (_round_trip entries)
    (is_ok_and_holds (elements_are (List.map entries ~f:equal_to)))

(* Deep-fed history stretches past the 520 trailing-week horizon. *)
let test_round_trip_deep_fed_over_520 _ =
  let entries = _entries 640 in
  assert_that (_round_trip entries)
    (is_ok_and_holds (elements_are (List.map entries ~f:equal_to)))

let test_round_trip_empty _ =
  assert_that (_round_trip []) (is_ok_and_holds (size_is 0))

(* ----- file IO round-trip ----- *)

let test_write_read_file _ =
  let path = _tmp_path () in
  let entries = _entries 37 in
  let result =
    Result.bind (Weekly_sidetable.write_file ~path entries) ~f:(fun () ->
        Weekly_sidetable.read_file ~path)
  in
  assert_that result
    (is_ok_and_holds (elements_are (List.map entries ~f:equal_to)))

(* ----- loud decode failures ----- *)

let test_bad_magic_rejected _ =
  let b = Weekly_sidetable.encode (_entries 3) in
  Stdlib.Bytes.set b 0 'X';
  assert_that (Weekly_sidetable.decode b) is_error

let test_truncated_rejected _ =
  let b = Weekly_sidetable.encode (_entries 4) in
  let short = Stdlib.Bytes.sub b 0 (Bytes.length b - 5) in
  assert_that (Weekly_sidetable.decode short) is_error

let test_short_of_header_rejected _ =
  assert_that (Weekly_sidetable.decode (Stdlib.Bytes.create 4)) is_error

(* ----- format hash: pinned literal guards a version bump ----- *)

let test_format_hash_pinned _ =
  assert_that Weekly_sidetable.format_hash
    (equal_to "90f2e86aef383e4da1cd4117ce360833")

let suite =
  "weekly_sidetable"
  >::: [
         "round trip 1 entry" >:: test_round_trip_1_entry;
         "round trip 520 entries" >:: test_round_trip_520_entries;
         "round trip deep-fed over 520" >:: test_round_trip_deep_fed_over_520;
         "round trip empty" >:: test_round_trip_empty;
         "write then read file" >:: test_write_read_file;
         "bad magic rejected" >:: test_bad_magic_rejected;
         "truncated rejected" >:: test_truncated_rejected;
         "shorter than header rejected" >:: test_short_of_header_rejected;
         "format hash pinned" >:: test_format_hash_pinned;
       ]

let () = run_test_tt_main suite
