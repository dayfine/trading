open OUnit2
open Core
open Matchers
open Time_period

(* Helper: ISO date constructor. *)
let d ~y ~m ~day = Date.create_exn ~y ~m ~d:day

(* Tuple-valued items so the tests prove [bucket_weekly] is generic over 'a. *)
type tagged = Date.t * int [@@deriving show, eq]

let tagged_get_date (d, _) = d

let tagged_sum (rev : tagged list) : tagged =
  let date, _ = List.hd_exn rev in
  let total = List.sum (module Int) rev ~f:snd in
  (date, total)

let test_empty_input _ =
  let result =
    Week_bucketing.bucket_weekly ~get_date:tagged_get_date ~aggregate:tagged_sum
      []
  in
  assert_that result (elements_are [])

let test_single_element _ =
  let item = (d ~y:2024 ~m:Month.Mar ~day:12, 7) in
  let result =
    Week_bucketing.bucket_weekly ~get_date:tagged_get_date ~aggregate:tagged_sum
      [ item ]
  in
  assert_that result
    (elements_are [ equal_to ((d ~y:2024 ~m:Month.Mar ~day:12, 7) : tagged) ])

let test_multi_week_preserves_order _ =
  (* Two ISO weeks with several weekdays each. *)
  let items =
    [
      (d ~y:2024 ~m:Month.Mar ~day:11, 1);
      (* Mon, week 11 *)
      (d ~y:2024 ~m:Month.Mar ~day:13, 2);
      (* Wed *)
      (d ~y:2024 ~m:Month.Mar ~day:15, 3);
      (* Fri *)
      (d ~y:2024 ~m:Month.Mar ~day:18, 4);
      (* Mon, week 12 *)
      (d ~y:2024 ~m:Month.Mar ~day:20, 5);
      (* Wed *)
      (d ~y:2024 ~m:Month.Mar ~day:22, 6);
      (* Fri *)
    ]
  in
  let result =
    Week_bucketing.bucket_weekly ~get_date:tagged_get_date ~aggregate:tagged_sum
      items
  in
  assert_that result
    (elements_are
       [
         equal_to ((d ~y:2024 ~m:Month.Mar ~day:15, 1 + 2 + 3) : tagged);
         equal_to ((d ~y:2024 ~m:Month.Mar ~day:22, 4 + 5 + 6) : tagged);
       ])

let test_partial_head_and_tail_weeks_emitted _ =
  (* Head week starts on Wed; tail week ends on Tue.  Both are partial and
     should still produce one bucket each. *)
  let items =
    [
      (d ~y:2024 ~m:Month.Mar ~day:13, 10);
      (* Wed, week 11 — partial head *)
      (d ~y:2024 ~m:Month.Mar ~day:15, 20);
      (* Fri, week 11 *)
      (d ~y:2024 ~m:Month.Mar ~day:18, 30);
      (* Mon, week 12 — full middle *)
      (d ~y:2024 ~m:Month.Mar ~day:22, 40);
      (* Fri, week 12 *)
      (d ~y:2024 ~m:Month.Mar ~day:25, 50);
      (* Mon, week 13 — partial tail *)
      (d ~y:2024 ~m:Month.Mar ~day:26, 60);
      (* Tue, week 13 *)
    ]
  in
  let result =
    Week_bucketing.bucket_weekly ~get_date:tagged_get_date ~aggregate:tagged_sum
      items
  in
  assert_that result
    (elements_are
       [
         equal_to ((d ~y:2024 ~m:Month.Mar ~day:15, 10 + 20) : tagged);
         equal_to ((d ~y:2024 ~m:Month.Mar ~day:22, 30 + 40) : tagged);
         equal_to ((d ~y:2024 ~m:Month.Mar ~day:26, 50 + 60) : tagged);
       ])

let test_unsorted_input_raises _ =
  let items =
    [ (d ~y:2024 ~m:Month.Mar ~day:15, 1); (d ~y:2024 ~m:Month.Mar ~day:12, 2) ]
  in
  assert_raises
    (Invalid_argument
       "Data must be sorted chronologically by date with no duplicates")
    (fun () ->
      Week_bucketing.bucket_weekly ~get_date:tagged_get_date
        ~aggregate:tagged_sum items)

let test_duplicate_date_raises _ =
  let items =
    [ (d ~y:2024 ~m:Month.Mar ~day:15, 1); (d ~y:2024 ~m:Month.Mar ~day:15, 2) ]
  in
  assert_raises
    (Invalid_argument
       "Data must be sorted chronologically by date with no duplicates")
    (fun () ->
      Week_bucketing.bucket_weekly ~get_date:tagged_get_date
        ~aggregate:tagged_sum items)

(* Sanity check: the helper is generic over the item type — exercise it on a
   record-flavoured input to confirm the API isn't accidentally constrained to
   tuples or to the [Daily_price] type. *)
type observation = { obs_date : Date.t; value : float } [@@deriving show, eq]

let test_record_input _ =
  let items =
    [
      { obs_date = d ~y:2024 ~m:Month.Mar ~day:11; value = 1.5 };
      { obs_date = d ~y:2024 ~m:Month.Mar ~day:13; value = 2.5 };
      { obs_date = d ~y:2024 ~m:Month.Mar ~day:18; value = 4.0 };
    ]
  in
  let result =
    Week_bucketing.bucket_weekly
      ~get_date:(fun o -> o.obs_date)
      ~aggregate:(fun rev ->
        let last = List.hd_exn rev in
        {
          obs_date = last.obs_date;
          value = List.sum (module Float) rev ~f:(fun o -> o.value);
        })
      items
  in
  assert_that result
    (elements_are
       [
         equal_to
           ({ obs_date = d ~y:2024 ~m:Month.Mar ~day:13; value = 4.0 }
             : observation);
         equal_to
           ({ obs_date = d ~y:2024 ~m:Month.Mar ~day:18; value = 4.0 }
             : observation);
       ])

let suite =
  "Week_bucketing tests"
  >::: [
         "test_empty_input" >:: test_empty_input;
         "test_single_element" >:: test_single_element;
         "test_multi_week_preserves_order" >:: test_multi_week_preserves_order;
         "test_partial_head_and_tail_weeks_emitted"
         >:: test_partial_head_and_tail_weeks_emitted;
         "test_unsorted_input_raises" >:: test_unsorted_input_raises;
         "test_duplicate_date_raises" >:: test_duplicate_date_raises;
         "test_record_input" >:: test_record_input;
       ]

let () = run_test_tt_main suite
