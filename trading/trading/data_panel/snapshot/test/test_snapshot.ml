open OUnit2
open Core
open Matchers
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot = Data_panel_snapshot.Snapshot

let _values_full () =
  Array.init (Snapshot_schema.n_fields Snapshot_schema.default) ~f:(fun i ->
      Float.of_int i +. 0.5)

let _make_full ?(symbol = "AAPL") ?(date = Date.of_string "2024-01-02") () =
  Snapshot.create ~schema:Snapshot_schema.default ~symbol ~date
    ~values:(_values_full ())

let test_create_ok _ =
  assert_that (_make_full ())
    (is_ok_and_holds
       (all_of
          [
            field (fun s -> s.Snapshot.symbol) (equal_to "AAPL");
            field
              (fun s -> Date.to_string s.Snapshot.date)
              (equal_to "2024-01-02");
            field (fun s -> Array.length s.Snapshot.values) (equal_to 13);
          ]))

let test_create_rejects_width_mismatch _ =
  let result =
    Snapshot.create ~schema:Snapshot_schema.default ~symbol:"AAPL"
      ~date:(Date.of_string "2024-01-02")
      ~values:[| 1.0; 2.0 |]
  in
  assert_that result (is_error_with Status.Invalid_argument)

let test_create_rejects_empty_symbol _ =
  let result =
    Snapshot.create ~schema:Snapshot_schema.default ~symbol:""
      ~date:(Date.of_string "2024-01-02")
      ~values:(_values_full ())
  in
  assert_that result (is_error_with Status.Invalid_argument)

let test_get_returns_cell _ =
  assert_that (_make_full ())
    (is_ok_and_holds
       (all_of
          [
            field
              (fun s -> Snapshot.get s Snapshot_schema.EMA_50)
              (equal_to (Some 0.5));
            field
              (fun s -> Snapshot.get s Snapshot_schema.Stage)
              (equal_to (Some 4.5));
          ]))

let test_get_returns_none_for_absent_field _ =
  let custom_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let result =
    Snapshot.create ~schema:custom_schema ~symbol:"X"
      ~date:(Date.of_string "2024-01-02")
      ~values:[| 1.0 |]
  in
  assert_that result
    (is_ok_and_holds
       (field (fun s -> Snapshot.get s Snapshot_schema.RSI_14) is_none))

let test_index_of_proxies_schema _ =
  assert_that (_make_full ())
    (is_ok_and_holds
       (field
          (fun s -> Snapshot.index_of s Snapshot_schema.RSI_14)
          (is_some_and (equal_to 3))))

let test_sexp_round_trip_preserves_fields _ =
  let restored =
    Result.map (_make_full ()) ~f:(fun original ->
        let sexp = Snapshot.sexp_of_t original in
        Snapshot.t_of_sexp sexp)
  in
  assert_that restored
    (is_ok_and_holds
       (all_of
          [
            field (fun s -> s.Snapshot.symbol) (equal_to "AAPL");
            field
              (fun s -> Date.to_string s.Snapshot.date)
              (equal_to "2024-01-02");
            field
              (fun s -> s.Snapshot.schema.schema_hash)
              (equal_to Snapshot_schema.default.schema_hash);
            field
              (fun s -> Array.to_list s.Snapshot.values)
              (equal_to (Array.to_list (_values_full ())));
          ]))

let suite =
  "Snapshot tests"
  >::: [
         "create ok" >:: test_create_ok;
         "create rejects width mismatch" >:: test_create_rejects_width_mismatch;
         "create rejects empty symbol" >:: test_create_rejects_empty_symbol;
         "get returns cell" >:: test_get_returns_cell;
         "get returns none for absent field"
         >:: test_get_returns_none_for_absent_field;
         "index_of proxies schema" >:: test_index_of_proxies_schema;
         "sexp round trip preserves fields"
         >:: test_sexp_round_trip_preserves_fields;
       ]

let () = run_test_tt_main suite
