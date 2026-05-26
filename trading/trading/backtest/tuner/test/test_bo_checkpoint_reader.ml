(** Unit tests for {!Tuner_bin.Bo_checkpoint_reader}. Exercises the on-disk sexp
    parser, schema-version enforcement, and best-iteration argmax. *)

open OUnit2
open Core
open Matchers
module Reader = Tuner_bin.Bo_checkpoint_reader
module Spec = Tuner_bin.Bayesian_runner_spec
module Metric_types = Trading_simulation_types.Metric_types

(* ---------- Builders ---------- *)

let _minimal_spec ~bounds : Spec.t =
  {
    bounds;
    acquisition = Expected_improvement;
    initial_random = 1;
    total_budget = 3;
    seed = Some 7;
    n_acquisition_candidates = None;
    objective = Sharpe;
    scenarios = [];
    holdout_folds = None;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = None;
    gate_penalty_value = None;
    int_keys = [];
  }

let _iteration ~params ~metric : Reader.saved_iteration =
  { parameters = params; metric; per_scenario_metrics = [ Metric_types.empty ] }

let _write_sexp_tmp ~dir ~name (sexp : Sexp.t) : string =
  let path = Filename.concat dir name in
  Out_channel.write_all path ~data:(Sexp.to_string sexp);
  path

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name
      "bo_checkpoint_reader_test_" ""
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      let rec rm_tree p =
        if Sys_unix.is_directory_exn p then begin
          Sys_unix.readdir p
          |> Array.iter ~f:(fun child -> rm_tree (Filename.concat p child));
          Core_unix.rmdir p
        end
        else Core_unix.unlink p
      in
      try rm_tree dir with _ -> ())

(* ---------- best_iteration / best_iteration_index ---------- *)

let test_best_iteration_picks_max_metric _ =
  let spec = _minimal_spec ~bounds:[ ("a", (0.0, 1.0)) ] in
  let ck : Reader.t =
    {
      schema_version = Reader.current_schema_version;
      spec;
      iterations =
        [
          _iteration ~params:[ ("a", 0.1) ] ~metric:0.5;
          _iteration ~params:[ ("a", 0.7) ] ~metric:1.5;
          _iteration ~params:[ ("a", 0.3) ] ~metric:1.0;
        ];
    }
  in
  assert_that (Reader.best_iteration ck)
    (is_some_and
       (all_of
          [
            field
              (fun (it : Reader.saved_iteration) -> it.metric)
              (float_equal 1.5);
            field
              (fun (it : Reader.saved_iteration) -> it.parameters)
              (elements_are [ pair (equal_to "a") (float_equal 0.7) ]);
          ]))

let test_best_iteration_index_picks_max _ =
  let spec = _minimal_spec ~bounds:[ ("a", (0.0, 1.0)) ] in
  let ck : Reader.t =
    {
      schema_version = Reader.current_schema_version;
      spec;
      iterations =
        [
          _iteration ~params:[ ("a", 0.1) ] ~metric:0.5;
          _iteration ~params:[ ("a", 0.7) ] ~metric:1.5;
          _iteration ~params:[ ("a", 0.3) ] ~metric:1.0;
        ];
    }
  in
  assert_that (Reader.best_iteration_index ck) (is_some_and (equal_to 1))

let test_best_iteration_empty_is_none _ =
  let spec = _minimal_spec ~bounds:[ ("a", (0.0, 1.0)) ] in
  let ck : Reader.t =
    { schema_version = Reader.current_schema_version; spec; iterations = [] }
  in
  assert_that (Reader.best_iteration ck) is_none;
  assert_that (Reader.best_iteration_index ck) is_none

let test_best_iteration_breaks_ties_to_earliest _ =
  (* Two iterations with identical metric → pick the earlier (lower index). *)
  let spec = _minimal_spec ~bounds:[ ("a", (0.0, 1.0)) ] in
  let ck : Reader.t =
    {
      schema_version = Reader.current_schema_version;
      spec;
      iterations =
        [
          _iteration ~params:[ ("a", 0.2) ] ~metric:1.0;
          _iteration ~params:[ ("a", 0.8) ] ~metric:1.0;
        ];
    }
  in
  assert_that (Reader.best_iteration_index ck) (is_some_and (equal_to 0));
  assert_that (Reader.best_iteration ck)
    (is_some_and
       (field
          (fun (it : Reader.saved_iteration) -> it.parameters)
          (elements_are [ pair (equal_to "a") (float_equal 0.2) ])))

(* ---------- load: success path ---------- *)

let test_load_round_trip _ =
  let spec = _minimal_spec ~bounds:[ ("knob_a", (0.0, 1.0)) ] in
  let ck : Reader.t =
    {
      schema_version = Reader.current_schema_version;
      spec;
      iterations = [ _iteration ~params:[ ("knob_a", 0.42) ] ~metric:0.99 ];
    }
  in
  _with_temp_dir (fun dir ->
      let path =
        _write_sexp_tmp ~dir ~name:"bo_checkpoint.sexp" (Reader.sexp_of_t ck)
      in
      let loaded = Reader.load path in
      assert_that loaded.schema_version (equal_to Reader.current_schema_version);
      assert_that loaded.iterations
        (elements_are
           [
             field
               (fun (it : Reader.saved_iteration) -> it.metric)
               (float_equal 0.99);
           ]))

(* ---------- load: error paths ---------- *)

let _assert_raises_failure_substring substring f =
  try
    f ();
    assert_failure
      (Printf.sprintf "expected Failure containing %S, but no exception raised"
         substring)
  with
  | Failure msg ->
      if not (String.is_substring msg ~substring) then
        assert_failure
          (Printf.sprintf "expected Failure containing %S, got %S" substring msg)
  | exn ->
      assert_failure
        (Printf.sprintf "expected Failure, got %s" (Exn.to_string exn))

let test_load_missing_file_raises _ =
  let f () = ignore (Reader.load "/tmp/_does_not_exist_42.sexp" : Reader.t) in
  _assert_raises_failure_substring "file not found" f

let test_load_schema_mismatch_raises _ =
  let spec = _minimal_spec ~bounds:[ ("a", (0.0, 1.0)) ] in
  let wrong_version : Reader.t =
    { schema_version = 999; spec; iterations = [] }
  in
  _with_temp_dir (fun dir ->
      let path =
        _write_sexp_tmp ~dir ~name:"bo_checkpoint.sexp"
          (Reader.sexp_of_t wrong_version)
      in
      let f () = ignore (Reader.load path : Reader.t) in
      _assert_raises_failure_substring "schema_version" f)

let test_load_malformed_sexp_raises _ =
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "bo_checkpoint.sexp" in
      Out_channel.write_all path ~data:"this is not a sexp";
      let f () = ignore (Reader.load path : Reader.t) in
      _assert_raises_failure_substring "Bo_checkpoint_reader.load" f)

let suite =
  "Tuner_bin.Bo_checkpoint_reader"
  >::: [
         "best_iteration picks max metric"
         >:: test_best_iteration_picks_max_metric;
         "best_iteration_index picks max"
         >:: test_best_iteration_index_picks_max;
         "best_iteration on empty list is None"
         >:: test_best_iteration_empty_is_none;
         "best_iteration breaks ties to earliest"
         >:: test_best_iteration_breaks_ties_to_earliest;
         "load round-trips a freshly-written checkpoint"
         >:: test_load_round_trip;
         "load on missing file raises Failure with 'file not found'"
         >:: test_load_missing_file_raises;
         "load on schema_version mismatch raises Failure"
         >:: test_load_schema_mismatch_raises;
         "load on malformed sexp raises Failure"
         >:: test_load_malformed_sexp_raises;
       ]

let () = run_test_tt_main suite
