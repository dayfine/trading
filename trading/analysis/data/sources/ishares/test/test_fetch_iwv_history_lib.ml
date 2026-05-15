open Core
open OUnit2
open Matchers
module Lib = Fetch_iwv_history_lib

let _date y m d = Date.create_exn ~y ~m ~d

(* Cache fixture: each test runs in a fresh tmp dir to keep the
   resume-from-cache state isolated. *)
let _make_tmp_cache () =
  let dir = Filename_unix.temp_dir ~in_dir:"/tmp" "iwv-prc-test-" "" in
  dir

let _write_file path contents =
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc contents)

(* ------------------------------------------------------------------------- *)
(* Cadence parsing                                                           *)
(* ------------------------------------------------------------------------- *)

let test_cadence_of_string_accepts_known_values _ =
  assert_that
    (Lib.cadence_of_string "auto")
    (is_ok_and_holds (equal_to Lib.Auto));
  assert_that
    (Lib.cadence_of_string "DAILY")
    (is_ok_and_holds (equal_to Lib.Daily));
  assert_that
    (Lib.cadence_of_string "monthly")
    (is_ok_and_holds (equal_to Lib.Monthly));
  assert_that
    (Lib.cadence_of_string "  quarterly  ")
    (is_ok_and_holds (equal_to Lib.Quarterly))

let test_cadence_of_string_rejects_unknown _ =
  assert_that (Lib.cadence_of_string "weekly") is_error

(* ------------------------------------------------------------------------- *)
(* Date enumeration                                                          *)
(* ------------------------------------------------------------------------- *)

(* Daily cadence skips weekends — Sat 2020-06-06 and Sun 2020-06-07
   are not in the list. *)
let test_daily_enumeration_skips_weekends _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2020 Month.Jun 5)
      ~until:(_date 2020 Month.Jun 8) Lib.Daily
  in
  assert_that dates
    (elements_are
       [ equal_to (_date 2020 Month.Jun 5); equal_to (_date 2020 Month.Jun 8) ])

let test_monthly_enumeration_picks_month_ends _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2010 Month.Jan 1)
      ~until:(_date 2010 Month.Apr 30) Lib.Monthly
  in
  assert_that dates
    (elements_are
       [
         equal_to (_date 2010 Month.Jan 31);
         equal_to (_date 2010 Month.Feb 28);
         equal_to (_date 2010 Month.Mar 31);
         equal_to (_date 2010 Month.Apr 30);
       ])

let test_quarterly_enumeration_picks_quarter_ends _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2007 Month.Jan 1)
      ~until:(_date 2007 Month.Dec 31) Lib.Quarterly
  in
  assert_that dates
    (elements_are
       [
         equal_to (_date 2007 Month.Mar 31);
         equal_to (_date 2007 Month.Jun 30);
         equal_to (_date 2007 Month.Sep 30);
         equal_to (_date 2007 Month.Dec 31);
       ])

(* Auto cadence pre-2009 ⇒ quarter-ends only. The 2008 calendar year
   crosses one of the explicit Phase 1.4 probe-doc cutoffs (quarterly
   era 2006-09 → 2008-12) so this case pins the lower boundary. *)
let test_auto_enumeration_quarterly_era _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2008 Month.Jan 1)
      ~until:(_date 2008 Month.Dec 31) Lib.Auto
  in
  assert_that dates
    (elements_are
       [
         equal_to (_date 2008 Month.Mar 31);
         equal_to (_date 2008 Month.Jun 30);
         equal_to (_date 2008 Month.Sep 30);
         equal_to (_date 2008 Month.Dec 31);
       ])

(* Auto cadence crossing the 2012-04-30 daily-era boundary: month-ends
   only through 2012-04-29, then every weekday from 2012-04-30 onward.
   Window picked so the verification is byte-stable. *)
let test_auto_enumeration_crosses_daily_cutover _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2012 Month.Mar 1)
      ~until:(_date 2012 Month.May 3) Lib.Auto
  in
  (* Expect: 3/31 (month-end in the monthly era), then daily-era starts
     4/30 (Mon) → 5/1, 5/2, 5/3 (weekdays). 4/30 itself is a month-end
     but appears because the daily era is in effect. April 2012 has no
     other selected day because its month-end (4/30) is past the daily
     cutover and the intervening weekdays were monthly-era non-ends. *)
  assert_that dates
    (elements_are
       [
         equal_to (_date 2012 Month.Mar 31);
         equal_to (_date 2012 Month.Apr 30);
         equal_to (_date 2012 Month.May 1);
         equal_to (_date 2012 Month.May 2);
         equal_to (_date 2012 Month.May 3);
       ])

let test_enumeration_with_inverted_window_is_empty _ =
  let dates =
    Lib.enumerate_dates ~from:(_date 2020 Month.Jun 10)
      ~until:(_date 2020 Month.Jun 5) Lib.Daily
  in
  assert_that dates is_empty

(* ------------------------------------------------------------------------- *)
(* csv_path / sentinel_path                                                  *)
(* ------------------------------------------------------------------------- *)

let test_csv_path_layout _ =
  assert_that
    (Lib.csv_path ~cache_dir:"/tmp/cache" ~as_of:(_date 2012 Month.Apr 30))
    (equal_to "/tmp/cache/2012-04-30.csv")

let test_sentinel_path_layout _ =
  assert_that
    (Lib.sentinel_path ~cache_dir:"/tmp/cache" ~as_of:(_date 2013 Month.Nov 15))
    (equal_to "/tmp/cache/2013-11-15.sentinel")

(* ------------------------------------------------------------------------- *)
(* plan / resume logic                                                       *)
(* ------------------------------------------------------------------------- *)

(* Resume across a mixed cache: one date has a non-empty CSV, one has
   a sentinel marker, three have nothing. All three Skip / Fetch
   actions are exercised. *)
let test_plan_resume_classifies_mixed_cache _ =
  let cache = _make_tmp_cache () in
  let cached = _date 2020 Month.Jun 1 in
  let sentinel_d = _date 2020 Month.Jun 2 in
  let to_fetch_a = _date 2020 Month.Jun 3 in
  let to_fetch_b = _date 2020 Month.Jun 4 in
  let to_fetch_c = _date 2020 Month.Jun 5 in
  _write_file (Lib.csv_path ~cache_dir:cache ~as_of:cached) "row1,row2\n";
  _write_file (Lib.sentinel_path ~cache_dir:cache ~as_of:sentinel_d) "\n";
  let steps =
    Lib.plan ~cache_dir:cache ~resume:true
      [ cached; sentinel_d; to_fetch_a; to_fetch_b; to_fetch_c ]
  in
  assert_that steps
    (elements_are
       [
         equal_to
           ({ as_of = cached; action = Lib.Skip_cached } : Lib.planned_step);
         equal_to
           ({ as_of = sentinel_d; action = Lib.Skip_sentinel }
             : Lib.planned_step);
         equal_to
           ({ as_of = to_fetch_a; action = Lib.Fetch } : Lib.planned_step);
         equal_to
           ({ as_of = to_fetch_b; action = Lib.Fetch } : Lib.planned_step);
         equal_to
           ({ as_of = to_fetch_c; action = Lib.Fetch } : Lib.planned_step);
       ])

(* Zero-byte CSV on disk must NOT count as a hit — that's the partial-
   write state the atomic-rename guard exists to prevent. If a 0-byte
   file survives somehow (e.g. user [touch]-ed the wrong path), the
   resume logic must still re-fetch. *)
let test_plan_resume_treats_empty_csv_as_fetch _ =
  let cache = _make_tmp_cache () in
  let d = _date 2020 Month.Jun 1 in
  _write_file (Lib.csv_path ~cache_dir:cache ~as_of:d) "";
  let steps = Lib.plan ~cache_dir:cache ~resume:true [ d ] in
  assert_that steps
    (elements_are
       [ equal_to ({ as_of = d; action = Lib.Fetch } : Lib.planned_step) ])

let test_plan_no_resume_marks_all_fetch _ =
  let cache = _make_tmp_cache () in
  let cached = _date 2020 Month.Jun 1 in
  let sentinel_d = _date 2020 Month.Jun 2 in
  _write_file (Lib.csv_path ~cache_dir:cache ~as_of:cached) "row1\n";
  _write_file (Lib.sentinel_path ~cache_dir:cache ~as_of:sentinel_d) "\n";
  let steps = Lib.plan ~cache_dir:cache ~resume:false [ cached; sentinel_d ] in
  assert_that steps
    (elements_are
       [
         equal_to ({ as_of = cached; action = Lib.Fetch } : Lib.planned_step);
         equal_to
           ({ as_of = sentinel_d; action = Lib.Fetch } : Lib.planned_step);
       ])

(* ------------------------------------------------------------------------- *)
(* format_plan_summary                                                       *)
(* ------------------------------------------------------------------------- *)

let test_format_plan_summary_counts_and_lists_steps _ =
  let steps : Lib.planned_step list =
    [
      { as_of = _date 2020 Month.Jun 1; action = Lib.Skip_cached };
      { as_of = _date 2020 Month.Jun 2; action = Lib.Skip_sentinel };
      { as_of = _date 2020 Month.Jun 3; action = Lib.Fetch };
    ]
  in
  let out = Lib.format_plan_summary steps in
  assert_that out
    (all_of
       [
         contains_substring "3 dates";
         contains_substring "1 to fetch";
         contains_substring "1 cached";
         contains_substring "1 sentinel";
         contains_substring "2020-06-01 cached";
         contains_substring "2020-06-02 sentinel";
         contains_substring "2020-06-03 fetch";
       ])

(* ------------------------------------------------------------------------- *)
(* Cache I/O                                                                 *)
(* ------------------------------------------------------------------------- *)

let test_ensure_cache_dir_creates_recursively _ =
  let parent = _make_tmp_cache () in
  let nested = Filename.concat parent "a/b/c" in
  let result = Lib.ensure_cache_dir nested in
  assert_that result is_ok;
  assert_that (Sys_unix.is_directory_exn nested) (equal_to true)

(* Sentinel-marker write/read roundtrip: after writing, [plan] must
   classify the same date as [Skip_sentinel] on the next pass. *)
let test_sentinel_marker_roundtrip _ =
  let cache = _make_tmp_cache () in
  let d = _date 2013 Month.Nov 15 in
  let write_result = Lib.write_sentinel_marker ~cache_dir:cache ~as_of:d in
  assert_that write_result is_ok;
  let steps = Lib.plan ~cache_dir:cache ~resume:true [ d ] in
  assert_that steps
    (elements_are
       [
         equal_to ({ as_of = d; action = Lib.Skip_sentinel } : Lib.planned_step);
       ])

(* CSV-body roundtrip: after writing, [plan] must classify the same
   date as [Skip_cached], and the on-disk contents must round-trip
   exactly (no atomic-rename truncation). *)
let test_write_csv_body_roundtrip _ =
  let cache = _make_tmp_cache () in
  let d = _date 2020 Month.Jun 1 in
  let body = "Ticker,Name\nAAPL,APPLE INC\n" in
  let write_result = Lib.write_csv_body ~cache_dir:cache ~as_of:d ~body in
  assert_that write_result is_ok;
  let on_disk = In_channel.read_all (Lib.csv_path ~cache_dir:cache ~as_of:d) in
  assert_that on_disk (equal_to body);
  let steps = Lib.plan ~cache_dir:cache ~resume:true [ d ] in
  assert_that steps
    (elements_are
       [ equal_to ({ as_of = d; action = Lib.Skip_cached } : Lib.planned_step) ])

let suite =
  "fetch_iwv_history_lib_test"
  >::: [
         "cadence_of_string_accepts_known_values"
         >:: test_cadence_of_string_accepts_known_values;
         "cadence_of_string_rejects_unknown"
         >:: test_cadence_of_string_rejects_unknown;
         "daily_enumeration_skips_weekends"
         >:: test_daily_enumeration_skips_weekends;
         "monthly_enumeration_picks_month_ends"
         >:: test_monthly_enumeration_picks_month_ends;
         "quarterly_enumeration_picks_quarter_ends"
         >:: test_quarterly_enumeration_picks_quarter_ends;
         "auto_enumeration_quarterly_era"
         >:: test_auto_enumeration_quarterly_era;
         "auto_enumeration_crosses_daily_cutover"
         >:: test_auto_enumeration_crosses_daily_cutover;
         "enumeration_with_inverted_window_is_empty"
         >:: test_enumeration_with_inverted_window_is_empty;
         "csv_path_layout" >:: test_csv_path_layout;
         "sentinel_path_layout" >:: test_sentinel_path_layout;
         "plan_resume_classifies_mixed_cache"
         >:: test_plan_resume_classifies_mixed_cache;
         "plan_resume_treats_empty_csv_as_fetch"
         >:: test_plan_resume_treats_empty_csv_as_fetch;
         "plan_no_resume_marks_all_fetch"
         >:: test_plan_no_resume_marks_all_fetch;
         "format_plan_summary_counts_and_lists_steps"
         >:: test_format_plan_summary_counts_and_lists_steps;
         "ensure_cache_dir_creates_recursively"
         >:: test_ensure_cache_dir_creates_recursively;
         "sentinel_marker_roundtrip" >:: test_sentinel_marker_roundtrip;
         "write_csv_body_roundtrip" >:: test_write_csv_body_roundtrip;
       ]

let () = run_test_tt_main suite
