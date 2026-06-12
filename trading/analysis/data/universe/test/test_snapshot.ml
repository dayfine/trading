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
          avg_dollar_volume = None;
        };
        {
          symbol = "SYNTH_Manuf_0001";
          weight = 0.25;
          sector = "Manuf";
          synthetic = true;
          avg_dollar_volume = None;
        };
        {
          symbol = "SYNTH_HiTec_0001";
          weight = 0.25;
          sector = "HiTec";
          synthetic = true;
          avg_dollar_volume = None;
        };
        {
          symbol = "SYNTH_Hlth_0001";
          weight = 0.25;
          sector = "Hlth";
          synthetic = true;
          avg_dollar_volume = None;
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

(* Backward-compat: a snapshot written in the pre-[avg_dollar_volume] 4-field
   entry shape (the form used by all 297 checked-in goldens) decodes with
   [avg_dollar_volume = None]. This is the load-bearing regression guard. *)
let test_legacy_4field_entry_decodes_to_none _ =
  let path = _tmp_path "legacy_4field" in
  Out_channel.write_all path
    ~data:
      "((date 2013-05-31) (method_ Composition_from_individuals) (size 1)\n\
      \ (entries (((symbol AAPL) (weight 1.0) (sector Tech) (synthetic false))))\n\
      \ (aggregate_period_return 0.0))\n";
  let result = Snapshot.load ~path in
  (try Stdlib.Sys.remove path with _ -> ());
  assert_that result
    (is_ok_and_holds
       (field
          (fun s -> s.Snapshot.entries)
          (elements_are
             [
               all_of
                 [
                   field
                     (fun (e : Snapshot.entry) -> e.symbol)
                     (equal_to "AAPL");
                   field
                     (fun (e : Snapshot.entry) -> e.avg_dollar_volume)
                     is_none;
                 ];
             ])))

(* A [None] entry serializes back to the 4-field shape — the on-disk sexp omits
   the [avg_dollar_volume] field, so existing goldens round-trip byte-identically
   after this schema change. *)
let test_none_entry_omits_field_on_save _ =
  let path = _tmp_path "none_omit" in
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:2013 ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size = 1;
      entries =
        [
          {
            symbol = "AAPL";
            weight = 1.0;
            sector = "Tech";
            synthetic = false;
            avg_dollar_volume = None;
          };
        ];
      aggregate_period_return = 0.0;
    }
  in
  (match Snapshot.save snapshot ~path with
  | Error err -> assert_failure ("save failed: " ^ Status.show err)
  | Ok () -> ());
  let on_disk = In_channel.read_all path in
  (try Stdlib.Sys.remove path with _ -> ());
  assert_that
    (String.is_substring on_disk ~substring:"avg_dollar_volume")
    (equal_to false)

(* A [Some] entry round-trips through save/load with the volume preserved. *)
let test_some_entry_round_trips _ =
  let path = _tmp_path "some_round_trip" in
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:2020 ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size = 1;
      entries =
        [
          {
            symbol = "AAPL";
            weight = 1.0;
            sector = "Tech";
            synthetic = false;
            avg_dollar_volume = Some 1.25e8;
          };
        ];
      aggregate_period_return = 0.0;
    }
  in
  (match Snapshot.save snapshot ~path with
  | Error err -> assert_failure ("save failed: " ^ Status.show err)
  | Ok () -> ());
  let loaded = Snapshot.load ~path in
  (try Stdlib.Sys.remove path with _ -> ());
  assert_that loaded (is_ok_and_holds (equal_to snapshot))

let suite =
  "Snapshot"
  >::: [
         "test_save_load_round_trip" >:: test_save_load_round_trip;
         "test_legacy_4field_entry_decodes_to_none"
         >:: test_legacy_4field_entry_decodes_to_none;
         "test_none_entry_omits_field_on_save"
         >:: test_none_entry_omits_field_on_save;
         "test_some_entry_round_trips" >:: test_some_entry_round_trips;
         "test_total_weight_sums_to_one_for_uniform"
         >:: test_total_weight_sums_to_one_for_uniform;
         "test_load_missing_file_is_internal_error"
         >:: test_load_missing_file_is_internal_error;
         "test_load_garbage_file_is_failed_precondition"
         >:: test_load_garbage_file_is_failed_precondition;
       ]

let () = run_test_tt_main suite
