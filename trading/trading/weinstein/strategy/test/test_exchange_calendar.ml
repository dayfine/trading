(** Pins {!Weinstein_strategy.Exchange_calendar} (#3139): which weekdays the
    exchange is closed all day, and which weekday ends a trading week.

    Every case is a date whose status is public record. The Friday cases are the
    ones that matter to the screening cadence (a closed Friday moves the weekly
    review to Thursday); the Monday/Thursday cases and the weekend-shift rules
    pin the calendar's other branches so a rule change cannot hide behind the
    Friday set. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _d = Date.of_string

(* Dates on which [f] disagrees with the expected answer. An empty list is a
   pass and a failure names the offending dates. *)
let _disagreements f cases =
  List.filter_map cases ~f:(fun (date, expected) ->
      if Bool.equal (f (_d date)) expected then None else Some date)

let test_good_friday_is_closed _ =
  assert_that
    (_disagreements Exchange_calendar.is_closed
       [
         ("2000-04-21", true);
         ("2016-03-25", true);
         ("2019-04-19", true);
         ("2024-03-29", true);
         ("2025-04-18", true);
         ("2025-04-11", false);
       ])
    is_empty

let test_friday_fixed_date_holidays _ =
  assert_that
    (_disagreements Exchange_calendar.is_closed
       [
         (* 4 July on a Friday, and observed on Friday when it is a Saturday *)
         ("2025-07-04", true);
         ("2020-07-03", true);
         ("2026-07-03", true);
         (* Christmas on a Friday, and observed on Friday when a Saturday *)
         ("2026-12-25", true);
         ("2021-12-24", true);
         (* 1 January on a Friday closes; on a Saturday it is NOT observed *)
         ("2010-01-01", true);
         ("2010-12-31", false);
         (* Juneteenth: from 2022 only; Friday 2026, Sunday-shifted 2022 *)
         ("2026-06-19", true);
         ("2021-06-18", false);
         ("2022-06-20", true);
       ])
    is_empty

let test_non_friday_holidays _ =
  assert_that
    (_disagreements Exchange_calendar.is_closed
       [
         ("2025-01-20", true);
         ("2025-02-17", true);
         ("2025-05-26", true);
         ("2025-09-01", true);
         ("2025-11-27", true);
         (* Sunday 1 January 2023 and Sunday Christmas 2022 shift to Monday *)
         ("2023-01-02", true);
         ("2022-12-26", true);
       ])
    is_empty

let test_unscheduled_closures_and_weekends _ =
  assert_that
    (_disagreements Exchange_calendar.is_closed
       [
         ("2001-09-11", true);
         ("2001-09-14", true);
         ("2001-09-10", false);
         ("2001-09-17", false);
         ("2004-06-11", true);
         (* weekends are not "closed weekdays" *)
         ("2025-04-19", false);
         ("2025-04-20", false);
       ])
    is_empty

let test_last_trading_day_of_week _ =
  assert_that
    (_disagreements Exchange_calendar.is_last_trading_day_of_week
       [
         (* ordinary week: only Friday ends it *)
         ("2025-04-11", true);
         ("2025-04-10", false);
         (* Good Friday week: Thursday ends it, the holiday itself does not *)
         ("2025-04-17", true);
         ("2025-04-18", false);
         ("2019-04-18", true);
         ("2025-07-03", true);
         (* a closed Monday does not move the end of its week *)
         ("2025-09-05", true);
         ("2025-09-01", false);
         (* 11-14 Sep 2001 emptied the rest of the week: Monday ends it *)
         ("2001-09-10", true);
         ("2001-09-06", false);
         (* weekends end nothing *)
         ("2025-04-19", false);
       ])
    is_empty

let suite =
  "exchange_calendar"
  >::: [
         "Good Friday is closed" >:: test_good_friday_is_closed;
         "Friday fixed-date holidays and weekend shifts"
         >:: test_friday_fixed_date_holidays;
         "non-Friday holidays are closed" >:: test_non_friday_holidays;
         "unscheduled closures and weekends"
         >:: test_unscheduled_closures_and_weekends;
         "last trading day of the week" >:: test_last_trading_day_of_week;
       ]

let () = run_test_tt_main suite
