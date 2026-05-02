(** Split replay test — drives {!Round_trip_verifier.verify_split_round_trip}
    against a fixture-backed historical scenario.

    Scope: AAPL 2020-08-31 4:1 split (PR-1) + TSLA 2020-08-31 5:1 split (PR-2).
    Follow-up PRs add GOOG, NVDA, KO. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

(* --------- Fixture loading --------- *)

let _fixture_dir name = Filename.concat (Filename.concat "fixtures" name) ""

let _read_snapshot path =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      assert_failure
        (Printf.sprintf "Failed to read snapshot %s: %s" path (Status.show err))

(* Parse a single CSV line into a [Daily_price.t]. The fixture format matches
   [analysis/data/storage/csv/lib/parser.ml]: 7 columns,
   date,open,high,low,close,adjusted_close,volume. We re-implement here to
   avoid pulling [csv_storage] into this test. *)
let _parse_bar_line line =
  match String.split line ~on:',' with
  | [ d; o; h; l; c; ac; v ] ->
      ({
         date = Date.of_string d;
         open_price = Float.of_string o;
         high_price = Float.of_string h;
         low_price = Float.of_string l;
         close_price = Float.of_string c;
         adjusted_close = Float.of_string ac;
         volume = Int.of_string v;
       }
        : Types.Daily_price.t)
  | _ -> assert_failure (Printf.sprintf "Malformed bar line: %s" line)

let _read_bars path =
  match In_channel.read_lines path with
  | [] -> assert_failure (Printf.sprintf "Empty bars file: %s" path)
  | _ :: rest -> List.map rest ~f:_parse_bar_line

(* --------- AAPL 2020-08-31 scenario --------- *)

(* Entry price from the pre-split snapshot's candidate entry ($502.13).
   Cost-basis check then becomes 100 * 502.13 = 400 * 125.5325. *)
let _aapl_pre_lot : Round_trip_verifier.held_lot =
  { symbol = "AAPL"; quantity = 100.0; entry_price = 502.13 }

let _aapl_split_factor = 4.0
let _aapl_split_date = Date.of_string "2020-08-31"

let _load_aapl_scenario () =
  let dir = _fixture_dir "aapl-2020-split" in
  let bars = _read_bars (Filename.concat dir "bars.csv") in
  let pick_pre = _read_snapshot (Filename.concat dir "pre_split.sexp") in
  let pick_post = _read_snapshot (Filename.concat dir "post_split.sexp") in
  (bars, pick_pre, pick_post)

let test_aapl_2020_split_all_checks_pass _ =
  let bars, pick_pre, pick_post = _load_aapl_scenario () in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"AAPL"
      ~split_date:_aapl_split_date ~factor:_aapl_split_factor ~bars
      ~pre_split_lot:_aapl_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:pick_post ()
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Round_trip_verifier.Round_trip_result.t) -> r.checks)
           (elements_are
              [
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "adjusted_close_continuity");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "position_carryover");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "cost_basis_preserved");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "no_phantom_picks");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "stop_adjusted");
              ]);
         field
           (fun (r : Round_trip_verifier.Round_trip_result.t) ->
             Round_trip_verifier.Round_trip_result.failures r)
           (equal_to []);
       ])

(* Negative test: tampered post-split snapshot with the wrong stop must fail
   the [position_carryover] and [stop_adjusted] checks. Pins the verifier
   actually catches a regression — silence on FAIL would be a critical bug. *)

let _tampered_post_split (snapshot : Weekly_snapshot.t) =
  let held' =
    List.map snapshot.held_positions ~f:(fun h ->
        if String.equal h.symbol "AAPL" then { h with stop = 999.99 } else h)
  in
  { snapshot with held_positions = held' }

let test_aapl_2020_split_tampered_stop_fails _ =
  let bars, pick_pre, pick_post = _load_aapl_scenario () in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"AAPL"
      ~split_date:_aapl_split_date ~factor:_aapl_split_factor ~bars
      ~pre_split_lot:_aapl_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:(_tampered_post_split pick_post)
      ()
  in
  let failure_names =
    Round_trip_verifier.Round_trip_result.failures result
    |> List.map ~f:(fun (c : Round_trip_verifier.check) -> c.name)
  in
  assert_that failure_names
    (elements_are [ equal_to "position_carryover"; equal_to "stop_adjusted" ])

(* Negative test: tampered post-split snapshot with a phantom symbol added to
   long_candidates must fail [no_phantom_picks]. *)

let _phantom_long_candidate : Weekly_snapshot.candidate =
  {
    symbol = "PHANTOM";
    score = 0.5;
    grade = "C";
    entry = 1.0;
    stop = 0.5;
    sector = "XLK";
    rationale = "should not appear";
    rs_vs_spy = None;
    resistance_grade = None;
  }

let test_aapl_2020_split_phantom_pick_fails _ =
  let bars, pick_pre, pick_post = _load_aapl_scenario () in
  let post' =
    {
      pick_post with
      long_candidates = _phantom_long_candidate :: pick_post.long_candidates;
    }
  in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"AAPL"
      ~split_date:_aapl_split_date ~factor:_aapl_split_factor ~bars
      ~pre_split_lot:_aapl_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:post' ()
  in
  let failure_names =
    Round_trip_verifier.Round_trip_result.failures result
    |> List.map ~f:(fun (c : Round_trip_verifier.check) -> c.name)
  in
  assert_that failure_names (elements_are [ equal_to "no_phantom_picks" ])

(* Tampered bar: corrupt one pre-split adjusted_close so the continuity check
   fails. *)

let _corrupt_first_pre_split_bar bars =
  match bars with
  | [] -> []
  | (b : Types.Daily_price.t) :: rest ->
      { b with adjusted_close = b.adjusted_close *. 1.5 } :: rest

let test_aapl_2020_split_bad_adjustment_fails _ =
  let bars, pick_pre, pick_post = _load_aapl_scenario () in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"AAPL"
      ~split_date:_aapl_split_date ~factor:_aapl_split_factor
      ~bars:(_corrupt_first_pre_split_bar bars)
      ~pre_split_lot:_aapl_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:pick_post ()
  in
  let failure_names =
    Round_trip_verifier.Round_trip_result.failures result
    |> List.map ~f:(fun (c : Round_trip_verifier.check) -> c.name)
  in
  assert_that failure_names
    (elements_are [ equal_to "adjusted_close_continuity" ])

(* --------- TSLA 2020-08-31 scenario (5:1 forward split) ---------

   Cost-basis check: 50 * 2213.40 = 250 * 442.68 (factor=5).
   Stop check: 2050.00 / 5 = 410.00. *)

let _tsla_pre_lot : Round_trip_verifier.held_lot =
  { symbol = "TSLA"; quantity = 50.0; entry_price = 2213.40 }

let _tsla_split_factor = 5.0
let _tsla_split_date = Date.of_string "2020-08-31"

let _load_tsla_scenario () =
  let dir = _fixture_dir "tsla-2020-split" in
  let bars = _read_bars (Filename.concat dir "bars.csv") in
  let pick_pre = _read_snapshot (Filename.concat dir "pre_split.sexp") in
  let pick_post = _read_snapshot (Filename.concat dir "post_split.sexp") in
  (bars, pick_pre, pick_post)

let test_tsla_2020_split_all_checks_pass _ =
  let bars, pick_pre, pick_post = _load_tsla_scenario () in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"TSLA"
      ~split_date:_tsla_split_date ~factor:_tsla_split_factor ~bars
      ~pre_split_lot:_tsla_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:pick_post ()
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Round_trip_verifier.Round_trip_result.t) -> r.checks)
           (elements_are
              [
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "adjusted_close_continuity");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "position_carryover");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "cost_basis_preserved");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "no_phantom_picks");
                field
                  (fun (c : Round_trip_verifier.check) -> c.name)
                  (equal_to "stop_adjusted");
              ]);
         field
           (fun (r : Round_trip_verifier.Round_trip_result.t) ->
             Round_trip_verifier.Round_trip_result.failures r)
           (equal_to []);
       ])

(* Negative test: tampered post-split snapshot with the wrong TSLA stop must
   fail [position_carryover] and [stop_adjusted]. Mirrors the AAPL coverage so
   regressions in either scenario are caught. *)

let _tampered_tsla_post_split (snapshot : Weekly_snapshot.t) =
  let held' =
    List.map snapshot.held_positions ~f:(fun h ->
        if String.equal h.symbol "TSLA" then { h with stop = 999.99 } else h)
  in
  { snapshot with held_positions = held' }

let test_tsla_2020_split_tampered_stop_fails _ =
  let bars, pick_pre, pick_post = _load_tsla_scenario () in
  let result =
    Round_trip_verifier.verify_split_round_trip ~symbol:"TSLA"
      ~split_date:_tsla_split_date ~factor:_tsla_split_factor ~bars
      ~pre_split_lot:_tsla_pre_lot ~pick_pre_split:pick_pre
      ~pick_post_split:(_tampered_tsla_post_split pick_post)
      ()
  in
  let failure_names =
    Round_trip_verifier.Round_trip_result.failures result
    |> List.map ~f:(fun (c : Round_trip_verifier.check) -> c.name)
  in
  assert_that failure_names
    (elements_are [ equal_to "position_carryover"; equal_to "stop_adjusted" ])

let suite =
  "split_replay"
  >::: [
         "aapl_2020_split_all_checks_pass"
         >:: test_aapl_2020_split_all_checks_pass;
         "aapl_2020_split_tampered_stop_fails"
         >:: test_aapl_2020_split_tampered_stop_fails;
         "aapl_2020_split_phantom_pick_fails"
         >:: test_aapl_2020_split_phantom_pick_fails;
         "aapl_2020_split_bad_adjustment_fails"
         >:: test_aapl_2020_split_bad_adjustment_fails;
         "tsla_2020_split_all_checks_pass"
         >:: test_tsla_2020_split_all_checks_pass;
         "tsla_2020_split_tampered_stop_fails"
         >:: test_tsla_2020_split_tampered_stop_fails;
       ]

let () = run_test_tt_main suite
