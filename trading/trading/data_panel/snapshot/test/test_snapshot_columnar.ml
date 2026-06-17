open OUnit2
open Core
open Matchers
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "snapshot_columnar_test_" ".snapc"

(* Distinct per-row, per-field values that include negatives and NaN so the
   round-trip exercises bit-identity, not just ordinary float equality. The
   field at index [date_seed mod n_fields] is forced to NaN. *)
let _values_for ~date_seed n =
  Array.init n ~f:(fun i ->
      if i = date_seed mod n then Float.nan
      else Float.of_int ((date_seed * 100) + i) +. (0.5 *. Float.of_int (i - 3)))

let _make_row ~symbol ~date_seed =
  let n = Snapshot_schema.n_fields Snapshot_schema.default in
  let date = Date.add_days (Date.of_string "2024-01-01") date_seed in
  match
    Snapshot.create ~schema:Snapshot_schema.default ~symbol ~date
      ~values:(_values_for ~date_seed n)
  with
  | Ok s -> s
  | Error err -> failwith (Status.show err)

(* ~50 rows for one symbol, deliberately built out of date order so [write]'s
   sort is exercised. *)
let _sample_rows ?(symbol = "AAPL") () =
  let seeds = List.init 50 ~f:(fun i -> ((i * 7) + 3) mod 90) in
  let seeds = List.dedup_and_sort seeds ~compare:Int.compare in
  (* Re-shuffle so input is NOT sorted. *)
  let seeds = List.rev seeds @ [ List.hd_exn seeds ] in
  let seeds = List.dedup_and_sort seeds ~compare:Int.compare |> List.rev in
  List.map seeds ~f:(fun s -> _make_row ~symbol ~date_seed:s)

(* Bit-pattern of every cell, row by row — NaN compares equal here (same bits),
   which ordinary float equality would not give. *)
let _bits_of_rows rows =
  List.map rows ~f:(fun (s : Snapshot.t) ->
      Array.to_list s.values |> List.map ~f:Int64.bits_of_float)

let _dates_of_rows rows =
  List.map rows ~f:(fun (s : Snapshot.t) -> Date.to_string s.date)

let _write_then_read path rows =
  Result.bind (Snapshot_columnar.write ~path rows) ~f:(fun () ->
      Snapshot_columnar.with_reader ~path ~f:Snapshot_columnar.read_all)

(* ----- 1. round-trip bit-identical ----- *)

let test_round_trip_bit_identical _ =
  let path = _tmp_path () in
  let rows = _sample_rows () in
  let sorted =
    List.sort rows ~compare:(fun (a : Snapshot.t) b ->
        Date.compare a.date b.date)
  in
  assert_that
    (_write_then_read path rows)
    (is_ok_and_holds
       (all_of
          [
            field _bits_of_rows (equal_to (_bits_of_rows sorted));
            field _dates_of_rows (equal_to (_dates_of_rows sorted));
            each (field (fun (s : Snapshot.t) -> s.symbol) (equal_to "AAPL"));
            each
              (field
                 (fun (s : Snapshot.t) -> s.schema.schema_hash)
                 (equal_to Snapshot_schema.default.schema_hash));
          ]))

(* ----- 2. read_range subset ----- *)

let _sorted_sample () =
  _sample_rows ()
  |> List.sort ~compare:(fun (a : Snapshot.t) b -> Date.compare a.date b.date)

let test_read_range_subset _ =
  let path = _tmp_path () in
  let rows = _sample_rows () in
  let sorted = _sorted_sample () in
  let from = (List.nth_exn sorted 10).date in
  let until = (List.nth_exn sorted 20).date in
  let expected =
    List.filter sorted ~f:(fun (s : Snapshot.t) ->
        Date.( >= ) s.date from && Date.( <= ) s.date until)
  in
  let read () =
    Result.bind (Snapshot_columnar.write ~path rows) ~f:(fun () ->
        Snapshot_columnar.with_reader ~path ~f:(fun r ->
            Snapshot_columnar.read_range r ~from ~until))
  in
  assert_that (read ())
    (is_ok_and_holds
       (all_of
          [
            field _bits_of_rows (equal_to (_bits_of_rows expected));
            field _dates_of_rows (equal_to (_dates_of_rows expected));
          ]))

(* ----- 3. empty / boundary ranges ----- *)

let _range_dates path rows ~from ~until =
  Result.bind (Snapshot_columnar.write ~path rows) ~f:(fun () ->
      Snapshot_columnar.with_reader ~path ~f:(fun r ->
          Result.map
            (Snapshot_columnar.read_range r ~from ~until)
            ~f:_dates_of_rows))

let test_range_until_before_from _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let from = (List.nth_exn sorted 20).date in
  let until = (List.nth_exn sorted 10).date in
  assert_that
    (_range_dates path (_sample_rows ()) ~from ~until)
    (is_ok_and_holds is_empty)

let test_range_entirely_before _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let first = (List.hd_exn sorted).date in
  let from = Date.add_days first (-100) in
  let until = Date.add_days first (-1) in
  assert_that
    (_range_dates path (_sample_rows ()) ~from ~until)
    (is_ok_and_holds is_empty)

let test_range_entirely_after _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let last = (List.last_exn sorted).date in
  let from = Date.add_days last 1 in
  let until = Date.add_days last 100 in
  assert_that
    (_range_dates path (_sample_rows ()) ~from ~until)
    (is_ok_and_holds is_empty)

let test_range_exact_endpoints_returns_all _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let from = (List.hd_exn sorted).date in
  let until = (List.last_exn sorted).date in
  assert_that
    (_range_dates path (_sample_rows ()) ~from ~until)
    (is_ok_and_holds (equal_to (_dates_of_rows sorted)))

(* ----- 4. single-symbol & single-schema validation ----- *)

let test_write_rejects_mixed_symbols _ =
  let path = _tmp_path () in
  let rows =
    [
      _make_row ~symbol:"AAPL" ~date_seed:0;
      _make_row ~symbol:"MSFT" ~date_seed:1;
    ]
  in
  assert_that
    (Snapshot_columnar.write ~path rows)
    (is_error_with Status.Invalid_argument)

let test_write_rejects_mixed_schemas _ =
  let path = _tmp_path () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let other_row =
    match
      Snapshot.create ~schema:other_schema ~symbol:"AAPL"
        ~date:(Date.of_string "2024-02-01")
        ~values:[| 1.0 |]
    with
    | Ok s -> s
    | Error err -> failwith (Status.show err)
  in
  let rows = [ _make_row ~symbol:"AAPL" ~date_seed:0; other_row ] in
  assert_that
    (Snapshot_columnar.write ~path rows)
    (is_error_with Status.Invalid_argument)

(* ----- 5. schema-hash gate ----- *)

let test_schema_hash_skew_detected _ =
  let path = _tmp_path () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let read () =
    Result.bind
      (Snapshot_columnar.write ~path (_sample_rows ()))
      ~f:(fun () ->
        Snapshot_columnar.read_with_expected_schema ~path ~expected:other_schema)
  in
  assert_that (read ()) (is_error_with Status.Failed_precondition)

let test_schema_hash_match_succeeds _ =
  let path = _tmp_path () in
  let read () =
    Result.bind
      (Snapshot_columnar.write ~path (_sample_rows ()))
      ~f:(fun () ->
        Snapshot_columnar.read_with_expected_schema ~path
          ~expected:Snapshot_schema.default)
  in
  assert_that (read ())
    (is_ok_and_holds (size_is (List.length (_sorted_sample ()))))

(* ----- 6. bad magic (a v1 file) ----- *)

let test_bad_magic_rejected _ =
  let path = _tmp_path () in
  let v1_row =
    _make_row ~symbol:"AAPL" ~date_seed:0 |> fun (s : Snapshot.t) -> s
  in
  let open_v1 () =
    Result.bind (Snapshot_format.write ~path [ v1_row ]) ~f:(fun () ->
        Snapshot_columnar.with_reader ~path ~f:Snapshot_columnar.read_all)
  in
  assert_that (open_v1 ()) (is_error_with Status.Internal)

(* ----- 7. empty list ----- *)

let test_empty_list_round_trip _ =
  let path = _tmp_path () in
  assert_that (_write_then_read path []) (is_ok_and_holds is_empty)

(* ----- map-once regression: many sequential read_range on one reader ----- *)

(* The reader maps all columns once at [open_reader]; [read_range] slices the
   held views. This guards that change: one opened reader must serve many
   sequential [read_range] calls, each returning the correct subset, with no
   per-call re-mapping and no cross-call state corruption. We issue one
   single-day [read_range] per row and check every result against the rows
   sharing that date. *)
let test_reader_serves_many_sequential_read_ranges _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let n = List.length sorted in
  let expected_at i =
    let d = (List.nth_exn sorted i).date in
    _dates_of_rows
      (List.filter sorted ~f:(fun (s : Snapshot.t) -> Date.equal s.date d))
  in
  let read_each_day () =
    Result.bind
      (Snapshot_columnar.write ~path (_sample_rows ()))
      ~f:(fun () ->
        Snapshot_columnar.with_reader ~path ~f:(fun r ->
            Result.all
              (List.init n ~f:(fun i ->
                   let d = (List.nth_exn sorted i).date in
                   Result.map
                     (Snapshot_columnar.read_range r ~from:d ~until:d)
                     ~f:_dates_of_rows))))
  in
  assert_that (read_each_day ())
    (is_ok_and_holds
       (elements_are (List.init n ~f:(fun i -> equal_to (expected_at i)))))

(* ----- header accessors ----- *)

let test_header_accessors _ =
  let path = _tmp_path () in
  let sorted = _sorted_sample () in
  let read () =
    Result.bind
      (Snapshot_columnar.write ~path (_sample_rows ()))
      ~f:(fun () ->
        Snapshot_columnar.with_reader ~path ~f:(fun r ->
            Ok
              ( Snapshot_columnar.symbol r,
                Snapshot_columnar.schema_hash r,
                Snapshot_columnar.n_rows r )))
  in
  assert_that (read ())
    (is_ok_and_holds
       (equal_to
          ("AAPL", Snapshot_schema.default.schema_hash, List.length sorted)))

(* ----- date <-> int round-trip ----- *)

let test_date_round_trips_through_epoch_days _ =
  let path = _tmp_path () in
  (* A spread of dates including a leap day and a far-future date. *)
  let dates =
    [ "2024-02-29"; "1970-01-01"; "2099-12-31"; "2001-09-11" ]
    |> List.map ~f:Date.of_string
  in
  let n = Snapshot_schema.n_fields Snapshot_schema.default in
  let rows =
    List.mapi dates ~f:(fun i date ->
        match
          Snapshot.create ~schema:Snapshot_schema.default ~symbol:"AAPL" ~date
            ~values:(_values_for ~date_seed:i n)
        with
        | Ok s -> s
        | Error err -> failwith (Status.show err))
  in
  let sorted =
    List.sort rows ~compare:(fun (a : Snapshot.t) b ->
        Date.compare a.date b.date)
  in
  assert_that
    (_write_then_read path rows)
    (is_ok_and_holds (field _dates_of_rows (equal_to (_dates_of_rows sorted))))

let suite =
  "Snapshot_columnar tests"
  >::: [
         "round trip bit identical" >:: test_round_trip_bit_identical;
         "read range subset" >:: test_read_range_subset;
         "range until before from" >:: test_range_until_before_from;
         "range entirely before" >:: test_range_entirely_before;
         "range entirely after" >:: test_range_entirely_after;
         "range exact endpoints returns all"
         >:: test_range_exact_endpoints_returns_all;
         "write rejects mixed symbols" >:: test_write_rejects_mixed_symbols;
         "write rejects mixed schemas" >:: test_write_rejects_mixed_schemas;
         "schema hash skew detected" >:: test_schema_hash_skew_detected;
         "schema hash match succeeds" >:: test_schema_hash_match_succeeds;
         "bad magic rejected" >:: test_bad_magic_rejected;
         "empty list round trip" >:: test_empty_list_round_trip;
         "reader serves many sequential read_ranges"
         >:: test_reader_serves_many_sequential_read_ranges;
         "header accessors" >:: test_header_accessors;
         "date round trips through epoch days"
         >:: test_date_round_trips_through_epoch_days;
       ]

let () = run_test_tt_main suite
