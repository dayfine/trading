(** Direct unit pin for {!Twin_pass.run}'s survivor guard (#2730 rework).

    {!Twin_pass}'s docstring promises that "a symbol whose CSV is missing,
    unreadable, or empty in-window contributes no series and therefore can never
    be matched or dropped — it simply survives". That branch cannot be pinned
    through {!Build_runner}: the builder leaves a symbol out of the manifest
    both when the twin pass drops it {e and} when there is no source CSV to
    snapshot, so a manifest assertion cannot tell the two apart.
    {!Twin_pass.run} is public and returns the survivor/dropped pair directly,
    so it is asserted here instead.

    The guard is not hypothetical: the vintage rebuild this pass exists to arm
    hands the builder a ~3,015-symbol superset against a store that resolves
    ~2,999 of them, so the first armed production run takes this branch for
    every unresolved ticker. A regression (e.g. [Csv_storage.get] raising rather
    than returning [Error]) would abort a multi-hour rebuild. *)

open Core
open OUnit2
open Matchers

(* Same fixture shape as [test_build_runner_twins.ml]: the twin criterion needs
   at least [Config.default.min_overlap_days] (100) shared dates, so each leg
   carries 130 consecutive daily bars. *)
let _bars_per_series = 130
let _late_end = Date.of_string "2021-12-31"

(* The dropped leg ends one week earlier, which is what makes the survivor
   deterministic: {!Twin_detector} keeps the latest-[data_end] leg. *)
let _early_end = Date.add_days _late_end (-7)
let _survivor = "TWINB"
let _dropped = "TWINA"
let _control = "OTHER"

(* Never written to disk — [Csv_storage.create] finds no file for it. *)
let _missing = "NOCSV"

(* Written, but every bar of it falls before the windowed builds' [start_date],
   so [Bar_window.filter] returns [] for it. *)
let _out_of_window = "OLDONLY"
let _window_start = Date.of_string "2021-01-01"
let _out_of_window_end = Date.of_string "2015-06-30"
let _armed_config = { Twin_detector.Config.default with enabled = true }

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_twin_pass" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* Flat series: the two twin legs carry the SAME closes on their shared dates
   (that is the twin criterion); the control trades at a different level
   entirely, so it can never match either. *)
let _series ~last ~close =
  List.init _bars_per_series ~f:(fun i ->
      _bar (Date.add_days last (i - (_bars_per_series - 1))) close)

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

(* Runs the armed pass over [symbols] in a fresh temp dir, after writing a CSV
   for each [(symbol, bars)] in [fixtures]. Any symbol in [symbols] absent from
   [fixtures] therefore has no file on disk. *)
let _run_armed ~fixtures ~symbols ~start_date dir =
  let data_dir = Filename.concat dir "csv" in
  let output_dir = Filename.concat dir "snap" in
  Core_unix.mkdir_p data_dir;
  List.iter fixtures ~f:(fun (symbol, bars) ->
      _write_csv ~data_dir ~symbol bars);
  Twin_pass.run _armed_config ~data_dir:(Fpath.v data_dir) ~start_date
    ~end_date:None ~output_dir symbols

(** A symbol with no CSV at all survives the armed pass in input order, and its
    presence changes neither the detected twin group nor the dropped set. *)
let test_symbol_without_a_csv_survives_the_armed_pass _ =
  assert_that
    (_with_temp_dir
       (_run_armed
          ~fixtures:
            [
              (_dropped, _series ~last:_early_end ~close:50.0);
              (_survivor, _series ~last:_late_end ~close:50.0);
              (_control, _series ~last:_late_end ~close:20.0);
            ]
          ~symbols:[ _dropped; _survivor; _control; _missing ]
          ~start_date:None))
    (pair
       (elements_are
          [ equal_to _survivor; equal_to _control; equal_to _missing ])
       (elements_are [ equal_to _dropped ]))

(** Same guard, second half of the docstring's sentence: a symbol whose CSV
    exists but whose bars all fall outside the requested window is windowed down
    to no series, so it too survives untouched. *)
let test_symbol_empty_in_window_survives_the_armed_pass _ =
  assert_that
    (_with_temp_dir
       (_run_armed
          ~fixtures:
            [
              (_dropped, _series ~last:_early_end ~close:50.0);
              (_survivor, _series ~last:_late_end ~close:50.0);
              (_control, _series ~last:_late_end ~close:20.0);
              (_out_of_window, _series ~last:_out_of_window_end ~close:50.0);
            ]
          ~symbols:[ _dropped; _survivor; _control; _out_of_window ]
          ~start_date:(Some _window_start)))
    (pair
       (elements_are
          [ equal_to _survivor; equal_to _control; equal_to _out_of_window ])
       (elements_are [ equal_to _dropped ]))

let () =
  run_test_tt_main
    ("twin_pass"
    >::: [
           "a symbol with no CSV survives the armed pass"
           >:: test_symbol_without_a_csv_survives_the_armed_pass;
           "a symbol empty in-window survives the armed pass"
           >:: test_symbol_empty_in_window_survives_the_armed_pass;
         ])
