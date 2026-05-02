(** Unit tests for {!Scenario_lib.Smoke_catalog} — pins window dates, names, and
    ordering so [backtest_runner --smoke] always exercises the same macro
    regimes. *)

open OUnit2
open Core
open Matchers
module Smoke_catalog = Scenario_lib.Smoke_catalog

let test_all_returns_three_windows _ = assert_that Smoke_catalog.all (size_is 3)

let test_all_in_bull_crash_recovery_order _ =
  assert_that Smoke_catalog.all
    (elements_are
       [
         field (fun (w : Smoke_catalog.window) -> w.name) (equal_to "bull");
         field (fun (w : Smoke_catalog.window) -> w.name) (equal_to "crash");
         field (fun (w : Smoke_catalog.window) -> w.name) (equal_to "recovery");
       ])

let test_bull_window_dates _ =
  assert_that Smoke_catalog.bull
    (all_of
       [
         field
           (fun (w : Smoke_catalog.window) -> w.start_date)
           (equal_to (Date.create_exn ~y:2019 ~m:Month.Jun ~d:1));
         field
           (fun (w : Smoke_catalog.window) -> w.end_date)
           (equal_to (Date.create_exn ~y:2019 ~m:Month.Dec ~d:31));
       ])

let test_crash_window_dates _ =
  assert_that Smoke_catalog.crash
    (all_of
       [
         field
           (fun (w : Smoke_catalog.window) -> w.start_date)
           (equal_to (Date.create_exn ~y:2020 ~m:Month.Jan ~d:2));
         field
           (fun (w : Smoke_catalog.window) -> w.end_date)
           (equal_to (Date.create_exn ~y:2020 ~m:Month.Jun ~d:30));
       ])

let test_recovery_window_dates _ =
  assert_that Smoke_catalog.recovery
    (all_of
       [
         field
           (fun (w : Smoke_catalog.window) -> w.start_date)
           (equal_to (Date.create_exn ~y:2023 ~m:Month.Jan ~d:2));
         field
           (fun (w : Smoke_catalog.window) -> w.end_date)
           (equal_to (Date.create_exn ~y:2023 ~m:Month.Dec ~d:31));
       ])

let test_each_window_has_nonempty_description _ =
  let descriptions =
    List.map Smoke_catalog.all ~f:(fun (w : Smoke_catalog.window) ->
        w.description)
  in
  assert_that descriptions
    (elements_are
       [
         field String.length (gt (module Int_ord) 0);
         field String.length (gt (module Int_ord) 0);
         field String.length (gt (module Int_ord) 0);
       ])

let test_each_window_has_start_before_end _ =
  let pairs =
    List.map Smoke_catalog.all ~f:(fun (w : Smoke_catalog.window) ->
        (Date.( < ) w.start_date w.end_date, w.name))
  in
  assert_that pairs
    (elements_are
       [
         equal_to (true, "bull");
         equal_to (true, "crash");
         equal_to (true, "recovery");
       ])

(* Pin the default universe path on every window. The smoke catalog must NOT
   default to the full sector-map (~10K symbols) — that OOMs the 8 GB dev
   container at panel-load time and defeats the "fast iteration" purpose of
   smoke. sp500 (~491 symbols) keeps each window under the memory budget. *)
let test_every_window_uses_sp500_universe _ =
  let paths =
    List.map Smoke_catalog.all ~f:(fun (w : Smoke_catalog.window) ->
        w.universe_path)
  in
  assert_that paths
    (elements_are
       [
         equal_to "universes/sp500.sexp";
         equal_to "universes/sp500.sexp";
         equal_to "universes/sp500.sexp";
       ])

let suite =
  "Scenario_lib.Smoke_catalog"
  >::: [
         "all returns three windows" >:: test_all_returns_three_windows;
         "windows are in bull/crash/recovery order"
         >:: test_all_in_bull_crash_recovery_order;
         "bull window dates" >:: test_bull_window_dates;
         "crash window dates" >:: test_crash_window_dates;
         "recovery window dates" >:: test_recovery_window_dates;
         "each window has non-empty description"
         >:: test_each_window_has_nonempty_description;
         "each window has start < end" >:: test_each_window_has_start_before_end;
         "every window uses sp500 universe by default"
         >:: test_every_window_uses_sp500_universe;
       ]

let () = run_test_tt_main suite
