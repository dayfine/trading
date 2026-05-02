open OUnit2
open Core
open Matchers
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let test_compute_hash_deterministic _ =
  let h1 = Snapshot_schema.compute_hash Snapshot_schema.all_fields in
  let h2 = Snapshot_schema.compute_hash Snapshot_schema.all_fields in
  assert_that (h1, h2)
    (all_of
       [
         field (fun (a, _) -> String.length a) (gt (module Int_ord) 0);
         field (fun (a, b) -> String.equal a b) (equal_to true);
       ])

let test_compute_hash_order_sensitive _ =
  let open Snapshot_schema in
  let h_canonical = compute_hash [ EMA_50; SMA_50; ATR_14 ] in
  let h_swapped = compute_hash [ SMA_50; EMA_50; ATR_14 ] in
  assert_that (String.equal h_canonical h_swapped) (equal_to false)

let test_compute_hash_field_set_sensitive _ =
  let open Snapshot_schema in
  let h_short = compute_hash [ EMA_50; SMA_50 ] in
  let h_long = compute_hash [ EMA_50; SMA_50; ATR_14 ] in
  assert_that (String.equal h_short h_long) (equal_to false)

let test_default_schema_locks_in_phase_a_fields _ =
  let open Snapshot_schema in
  assert_that default.fields
    (elements_are
       [
         equal_to EMA_50;
         equal_to SMA_50;
         equal_to ATR_14;
         equal_to RSI_14;
         equal_to Stage;
         equal_to RS_line;
         equal_to Macro_composite;
       ])

let test_default_schema_n_fields _ =
  assert_that (Snapshot_schema.n_fields Snapshot_schema.default) (equal_to 7)

let test_index_of_present_and_absent _ =
  let open Snapshot_schema in
  let s = create ~fields:[ EMA_50; ATR_14; Stage ] in
  assert_that
    (index_of s EMA_50, index_of s ATR_14, index_of s Stage, index_of s RSI_14)
    (equal_to (Some 0, Some 1, Some 2, None))

let test_create_caches_hash _ =
  let s = Snapshot_schema.create ~fields:Snapshot_schema.all_fields in
  let recomputed = Snapshot_schema.compute_hash s.fields in
  assert_that (String.equal s.schema_hash recomputed) (equal_to true)

let test_field_name_round_trip _ =
  let names =
    List.map Snapshot_schema.all_fields ~f:Snapshot_schema.field_name
  in
  assert_that names
    (elements_are
       [
         equal_to "EMA_50";
         equal_to "SMA_50";
         equal_to "ATR_14";
         equal_to "RSI_14";
         equal_to "Stage";
         equal_to "RS_line";
         equal_to "Macro_composite";
       ])

let suite =
  "Snapshot_schema tests"
  >::: [
         "compute_hash deterministic" >:: test_compute_hash_deterministic;
         "compute_hash order sensitive" >:: test_compute_hash_order_sensitive;
         "compute_hash field set sensitive"
         >:: test_compute_hash_field_set_sensitive;
         "default schema locks in Phase A fields"
         >:: test_default_schema_locks_in_phase_a_fields;
         "default schema n_fields = 7" >:: test_default_schema_n_fields;
         "index_of present and absent" >:: test_index_of_present_and_absent;
         "create caches hash" >:: test_create_caches_hash;
         "field_name round trip" >:: test_field_name_round_trip;
       ]

let () = run_test_tt_main suite
