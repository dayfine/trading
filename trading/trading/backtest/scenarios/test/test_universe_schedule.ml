(** Dated point-in-time universe membership — {!Scenario_lib.Universe_schedule}.

    Pins the step-function window semantics (D1/D2 of
    [dev/plans/pit-universe-migration-2026-09-14.md] §Step 3a), the union sector
    map a scheduled run stages (D6), the load-time validation, and the loud
    rejection every non-scenario-runner consumer performs. *)

open OUnit2
open Core
open Matchers
module Universe_schedule = Scenario_lib.Universe_schedule

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Two tiny universes written into a fresh temp fixtures root. [early] holds
   AAPL + JPM; [late] drops JPM, keeps AAPL (with a DIFFERENT sector, so
   first-occurrence-wins is observable) and adds MSFT. *)
let _write_fixtures () =
  let root =
    Core_unix.mkdtemp (Filename.concat Filename.temp_dir_name "uschedule")
  in
  Out_channel.write_all
    (Filename.concat root "early.sexp")
    ~data:
      {|(Pinned (((symbol AAPL) (sector "Information Technology"))
                 ((symbol JPM)  (sector Financials))))|};
  Out_channel.write_all
    (Filename.concat root "late.sexp")
    ~data:
      {|(Pinned (((symbol AAPL) (sector "Sector Renamed Later"))
                 ((symbol MSFT) (sector "Information Technology"))))|};
  Out_channel.write_all
    (Filename.concat root "broad.sexp")
    ~data:"Full_sector_map";
  root

let _load_two_list_schedule () =
  let root = _write_fixtures () in
  Universe_schedule.load ~fixtures_root:root
    [ (_ymd 2020 6 1, "late.sexp"); (_ymd 2020 1 1, "early.sexp") ]

let _members_on date =
  field (fun s -> Set.to_list (Universe_schedule.members_at s date))

(* The entries above are deliberately given NEWEST-FIRST; a schedule that is
   not sorted on load would answer [late]'s membership for every date. *)
let test_unsorted_input_is_sorted_on_load _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (field
          (fun s -> Universe_schedule.is_member s "JPM" (_ymd 2020 3 1))
          (equal_to true)))

(* D2: the first entry governs every date BEFORE it. *)
let test_before_first_entry_uses_first_list _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (_members_on (_ymd 2015 1 1)
          (elements_are [ equal_to "AAPL"; equal_to "JPM" ])))

(* D1: the window is half-open — an entry governs its own date. *)
let test_on_entry_date_uses_that_list _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (_members_on (_ymd 2020 6 1)
          (elements_are [ equal_to "AAPL"; equal_to "MSFT" ])))

(* D1: the day before the next entry still belongs to the earlier list. *)
let test_between_entries_uses_earlier_list _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (_members_on (_ymd 2020 5 31)
          (elements_are [ equal_to "AAPL"; equal_to "JPM" ])))

(* D2: the last entry governs every date after it. *)
let test_after_last_entry_uses_last_list _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (_members_on (_ymd 2030 1 1)
          (elements_are [ equal_to "AAPL"; equal_to "MSFT" ])))

(* A name that appears only in the second list is not a member before that
   list's date, and is a member from it on. *)
let test_member_of_second_list_only _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (all_of
          [
            field
              (fun s -> Universe_schedule.is_member s "MSFT" (_ymd 2020 3 1))
              (equal_to false);
            field
              (fun s -> Universe_schedule.is_member s "MSFT" (_ymd 2020 7 1))
              (equal_to true);
          ]))

(* D6: the union spans every list, and a symbol in several lists keeps the
   sector from its FIRST occurrence in schedule order. *)
let test_union_sector_map_first_occurrence_wins _ =
  assert_that
    (_load_two_list_schedule ())
    (is_ok_and_holds
       (field
          (fun s ->
            Universe_schedule.union_sector_map s
            |> Hashtbl.to_alist
            |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b))
          (elements_are
             [
               equal_to ("AAPL", "Information Technology");
               equal_to ("JPM", "Financials");
               equal_to ("MSFT", "Information Technology");
             ])))

let test_duplicate_dates_rejected _ =
  let root = _write_fixtures () in
  assert_that
    (Universe_schedule.load ~fixtures_root:root
       [ (_ymd 2020 1 1, "early.sexp"); (_ymd 2020 1 1, "late.sexp") ])
    (is_error_with Status.Invalid_argument)

let test_empty_schedule_rejected _ =
  let root = _write_fixtures () in
  assert_that
    (Universe_schedule.load ~fixtures_root:root [])
    (is_error_with Status.Invalid_argument)

(* [Full_sector_map] carries no explicit membership list, so it cannot say who
   is a member on a given date. *)
let test_full_sector_map_entry_rejected _ =
  let root = _write_fixtures () in
  assert_that
    (Universe_schedule.load ~fixtures_root:root
       [ (_ymd 2020 1 1, "broad.sexp") ])
    (is_error_with Status.Failed_precondition)

let test_reject_if_present_allows_empty _ =
  assert_that
    (Universe_schedule.reject_if_present ~runner_name:"Walk_forward_executor" [])
    is_ok

(* The loud failure every non-scenario-runner consumer performs: the message
   must name both the field and the runner so the operator can act on it. *)
let test_reject_if_present_names_field_and_runner _ =
  assert_that
    (Universe_schedule.reject_if_present ~runner_name:"Walk_forward_executor"
       [ (_ymd 2020 1 1, "early.sexp") ])
    (all_of
       [
         is_error_with Status.Unimplemented;
         field
           (fun r ->
             Result.error r
             |> Option.value_map ~default:"<no error>" ~f:(fun (e : Status.t) ->
                 e.message))
           (all_of
              [
                contains_substring "universe_schedule";
                contains_substring "Walk_forward_executor";
              ]);
       ])

(* [raise_if_present] carries the same message as an exception, for the call
   sites that resolve a universe inside a non-[Result] pipeline. *)
let _raise_if_present_outcome schedule =
  Or_error.try_with (fun () ->
      Universe_schedule.raise_if_present ~runner_name:"Barbell_scenario"
        schedule)
  |> Result.error
  |> Option.value_map ~default:"<no exception>" ~f:Error.to_string_hum

let test_raise_if_present_raises_on_non_empty _ =
  assert_that
    (_raise_if_present_outcome [ (_ymd 2020 1 1, "early.sexp") ])
    (all_of
       [
         contains_substring "universe_schedule";
         contains_substring "Barbell_scenario";
       ])

let test_raise_if_present_is_noop_on_empty _ =
  assert_that (_raise_if_present_outcome []) (equal_to "<no exception>")

let suite =
  "universe_schedule_tests"
  >::: [
         "unsorted input is sorted on load"
         >:: test_unsorted_input_is_sorted_on_load;
         "before first entry => first list"
         >:: test_before_first_entry_uses_first_list;
         "on an entry date => that list" >:: test_on_entry_date_uses_that_list;
         "between entries => earlier list"
         >:: test_between_entries_uses_earlier_list;
         "after last entry => last list"
         >:: test_after_last_entry_uses_last_list;
         "name present only in list 2" >:: test_member_of_second_list_only;
         "union sector map: first occurrence wins"
         >:: test_union_sector_map_first_occurrence_wins;
         "duplicate dates rejected" >:: test_duplicate_dates_rejected;
         "empty schedule rejected" >:: test_empty_schedule_rejected;
         "Full_sector_map entry rejected"
         >:: test_full_sector_map_entry_rejected;
         "reject_if_present allows empty"
         >:: test_reject_if_present_allows_empty;
         "reject_if_present names field and runner"
         >:: test_reject_if_present_names_field_and_runner;
         "raise_if_present raises on non-empty"
         >:: test_raise_if_present_raises_on_non_empty;
         "raise_if_present is a no-op on empty"
         >:: test_raise_if_present_is_noop_on_empty;
       ]

let () = run_test_tt_main suite
