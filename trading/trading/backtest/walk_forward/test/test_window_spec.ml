(** Unit tests for {!Walk_forward.Window_spec}. Pure date-arithmetic checks — no
    backtest invocation. *)

open OUnit2
open Core
open Matchers
module WS = Walk_forward.Window_spec
module Scenario = Scenario_lib.Scenario

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* ---------- Validation ---------- *)

let test_negative_train_days_raises _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 12 31;
      train_days = -1;
      test_days = 30;
      step_days = 30;
    }
  in
  assert_raises (Failure "WindowSpec.generate: train_days must be >= 0, got -1")
    (fun () -> WS.generate spec)

let test_zero_test_days_raises _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 12 31;
      train_days = 30;
      test_days = 0;
      step_days = 30;
    }
  in
  assert_raises (Failure "WindowSpec.generate: test_days must be > 0, got 0")
    (fun () -> WS.generate spec)

let test_zero_step_days_raises _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 12 31;
      train_days = 30;
      test_days = 30;
      step_days = 0;
    }
  in
  assert_raises (Failure "WindowSpec.generate: step_days must be > 0, got 0")
    (fun () -> WS.generate spec)

(* ---------- Empty-range cases ---------- *)

let test_start_after_end_yields_empty _ =
  let spec : WS.t =
    {
      start_date = _date 2020 12 31;
      end_date = _date 2020 1 1;
      train_days = 0;
      test_days = 30;
      step_days = 30;
    }
  in
  assert_that (WS.generate spec) (size_is 0)

let test_no_fold_fits_yields_empty _ =
  (* Window is 60 days (0 + 60) but available range is 30 days. *)
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 1 30;
      train_days = 0;
      test_days = 60;
      step_days = 60;
    }
  in
  assert_that (WS.generate spec) (size_is 0)

(* ---------- Train-period None when train_days = 0 ---------- *)

let test_train_days_zero_yields_no_train_period _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 6 30;
      train_days = 0;
      test_days = 30;
      step_days = 30;
    }
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         all_of
           [
             field (fun (f : WS.fold) -> f.train_period) is_none;
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 1 30));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 31));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 2 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 3 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 3 30));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 3 31));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 4 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 4 30));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 5 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 5 30));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 6 28));
           ];
       ])

(* ---------- Train + test back-to-back ---------- *)

let test_train_followed_by_test _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 12 31;
      train_days = 60;
      test_days = 30;
      step_days = 90;
    }
  in
  let folds = WS.generate spec in
  (* First fold: train 01-01..03-01 (60d), test 03-01..03-30 (30d). *)
  let first = List.hd_exn folds in
  assert_that first
    (all_of
       [
         field (fun (f : WS.fold) -> f.index) (equal_to 0);
         field (fun (f : WS.fold) -> f.name) (equal_to "fold-000");
         field
           (fun (f : WS.fold) ->
             match f.train_period with
             | Some p -> p.start_date
             | None -> _date 1900 1 1)
           (equal_to (_date 2020 1 1));
         field
           (fun (f : WS.fold) ->
             match f.train_period with
             | Some p -> p.end_date
             | None -> _date 1900 1 1)
           (equal_to (_date 2020 2 29));
         field
           (fun (f : WS.fold) -> f.test_period.start_date)
           (equal_to (_date 2020 3 1));
         field
           (fun (f : WS.fold) -> f.test_period.end_date)
           (equal_to (_date 2020 3 30));
       ])

(* ---------- Step < test = overlapping rolling folds ---------- *)

let test_overlapping_step_yields_overlapping_test_windows _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 4 30;
      train_days = 0;
      test_days = 60;
      step_days = 30;
    }
  in
  let folds = WS.generate spec in
  let test_starts =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.start_date)
  in
  let test_ends =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.end_date)
  in
  assert_that test_starts
    (elements_are
       [
         equal_to (_date 2020 1 1);
         equal_to (_date 2020 1 31);
         equal_to (_date 2020 3 1);
       ]);
  assert_that test_ends
    (elements_are
       [
         equal_to (_date 2020 2 29);
         equal_to (_date 2020 3 30);
         equal_to (_date 2020 4 29);
       ])

(* ---------- Drop folds extending past end_date ---------- *)

let test_drops_folds_past_end_date _ =
  (* start=01-01, end=01-31, test_days=30, step=15. Possible test windows:
     [01-01..01-30] (ok), [01-16..02-14] (PAST end), drop. *)
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 1 31;
      train_days = 0;
      test_days = 30;
      step_days = 15;
    }
  in
  let folds = WS.generate spec in
  assert_that folds (size_is 1)

(* ---------- Index + name shape ---------- *)

let test_fold_names_zero_padded _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 4 30;
      train_days = 0;
      test_days = 30;
      step_days = 30;
    }
  in
  let folds = WS.generate spec in
  let names = List.map folds ~f:(fun (f : WS.fold) -> f.name) in
  assert_that names
    (elements_are
       [
         equal_to "fold-000";
         equal_to "fold-001";
         equal_to "fold-002";
         equal_to "fold-003";
       ])

(* ---------- Sexp round-trip ---------- *)

let test_sexp_round_trip _ =
  let spec : WS.t =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2024 12 31;
      train_days = 365;
      test_days = 182;
      step_days = 91;
    }
  in
  let parsed = WS.t_of_sexp (WS.sexp_of_t spec) in
  assert_that parsed
    (all_of
       [
         field (fun (s : WS.t) -> s.start_date) (equal_to spec.start_date);
         field (fun (s : WS.t) -> s.end_date) (equal_to spec.end_date);
         field (fun (s : WS.t) -> s.train_days) (equal_to spec.train_days);
         field (fun (s : WS.t) -> s.test_days) (equal_to spec.test_days);
         field (fun (s : WS.t) -> s.step_days) (equal_to spec.step_days);
       ])

let suite =
  "Window_spec"
  >::: [
         "negative train_days raises" >:: test_negative_train_days_raises;
         "zero test_days raises" >:: test_zero_test_days_raises;
         "zero step_days raises" >:: test_zero_step_days_raises;
         "start after end yields empty" >:: test_start_after_end_yields_empty;
         "no fold fits yields empty" >:: test_no_fold_fits_yields_empty;
         "train_days=0 yields no train_period"
         >:: test_train_days_zero_yields_no_train_period;
         "train followed by test back-to-back" >:: test_train_followed_by_test;
         "overlapping step yields overlapping test windows"
         >:: test_overlapping_step_yields_overlapping_test_windows;
         "drops folds past end_date" >:: test_drops_folds_past_end_date;
         "fold names zero-padded" >:: test_fold_names_zero_padded;
         "sexp round-trip" >:: test_sexp_round_trip;
       ]

let () = run_test_tt_main suite
