open Core
open OUnit2
open Matchers
open Universe

let _tmp_path suffix =
  Stdlib.Filename.temp_file "snapshot_test_" ("_" ^ suffix ^ ".sexp")

let _sample_snapshot () : Snapshot.t =
  {
    date = Date.create_exn ~y:1990 ~m:Month.May ~d:31;
    method_ =
      Decomposition_from_index
        { anchor = `Shiller_sp_composite; factor_skeleton = `French_5_industry };
    size = 4;
    entries =
      [
        {
          symbol = "SYNTH_Cnsmr_0001";
          weight = 0.25;
          sector = "Cnsmr";
          synthetic = true;
        };
        {
          symbol = "SYNTH_Manuf_0001";
          weight = 0.25;
          sector = "Manuf";
          synthetic = true;
        };
        {
          symbol = "SYNTH_HiTec_0001";
          weight = 0.25;
          sector = "HiTec";
          synthetic = true;
        };
        {
          symbol = "SYNTH_Hlth_0001";
          weight = 0.25;
          sector = "Hlth";
          synthetic = true;
        };
      ];
    aggregate_period_return = 0.10;
  }

let test_save_load_round_trip _ =
  let path = _tmp_path "round_trip" in
  let original = _sample_snapshot () in
  match Snapshot.save original ~path with
  | Error err -> assert_failure ("save failed: " ^ Status.show err)
  | Ok () ->
      let loaded = Snapshot.load ~path in
      (try Stdlib.Sys.remove path with _ -> ());
      assert_that loaded (is_ok_and_holds (equal_to original))

let test_total_weight_sums_to_one_for_uniform _ =
  let snapshot = _sample_snapshot () in
  assert_that (Snapshot.total_weight snapshot) (float_equal 1.0)

let test_load_missing_file_is_internal_error _ =
  assert_that
    (Snapshot.load ~path:"/nonexistent/snapshot_test_does_not_exist.sexp")
    (is_error_with Status.Internal)

let test_load_garbage_file_is_failed_precondition _ =
  let path = _tmp_path "garbage" in
  Out_channel.write_all path ~data:"(not a snapshot sexp)";
  let result = Snapshot.load ~path in
  (try Stdlib.Sys.remove path with _ -> ());
  assert_that result (is_error_with Status.Failed_precondition)

let suite =
  "Snapshot"
  >::: [
         "test_save_load_round_trip" >:: test_save_load_round_trip;
         "test_total_weight_sums_to_one_for_uniform"
         >:: test_total_weight_sums_to_one_for_uniform;
         "test_load_missing_file_is_internal_error"
         >:: test_load_missing_file_is_internal_error;
         "test_load_garbage_file_is_failed_precondition"
         >:: test_load_garbage_file_is_failed_precondition;
       ]

let () = run_test_tt_main suite
