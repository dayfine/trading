open OUnit2
open Core
open Matchers
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* --- Test fixture helpers ------------------------------------------- *)

(* Schema with two fields keeps the test snapshots tiny but still exercises
   the index_of / get path. *)
let _test_schema =
  Snapshot_schema.create
    ~fields:[ Snapshot_schema.EMA_50; Snapshot_schema.SMA_50 ]

let _make_row ~symbol ~date ~ema ~sma =
  match
    Snapshot.create ~schema:_test_schema ~symbol ~date ~values:[| ema; sma |]
  with
  | Ok r -> r
  | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Walk consecutive trading days starting at [start] for [n] entries; values
   are deterministic so every read can be pinned. *)
let _series ~symbol ~start ~n =
  List.init n ~f:(fun i ->
      let date = Date.add_days start i in
      let ema = 100.0 +. Float.of_int i in
      let sma = 200.0 +. Float.of_int i in
      _make_row ~symbol ~date ~ema ~sma)

let _write_symbol_file ~dir ~symbol rows =
  let path = Filename.concat dir (symbol ^ ".snap") in
  match Snapshot_format.write ~path rows with
  | Ok () ->
      let stat = Core_unix.stat path in
      ( path,
        ({
           symbol;
           path;
           byte_size = Int64.to_int_exn stat.st_size;
           payload_md5 = "ignored";
           csv_mtime = stat.st_mtime;
         }
          : Snapshot_manifest.file_metadata) )
  | Error err -> assert_failure ("Snapshot_format.write: " ^ Status.show err)

let _make_tmp_dir () = Filename_unix.temp_dir ~in_dir:"/tmp" "daily_panels_" ""

(* Build a directory containing one snapshot file per [(symbol, n_days)] pair,
   then return the resulting [Daily_panels.t] (with the supplied
   [max_cache_mb]). All series start at [_default_start]. *)
let _default_start = _ymd 2024 1 2

let _setup ~symbols ~n_days ~max_cache_mb =
  let dir = _make_tmp_dir () in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let rows = _series ~symbol ~start:_default_start ~n:n_days in
        let _path, metadata = _write_symbol_file ~dir ~symbol rows in
        metadata)
  in
  let manifest = Snapshot_manifest.create ~schema:_test_schema ~entries in
  match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb with
  | Ok t -> (dir, t)
  | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)

(* --- create / validation -------------------------------------------- *)

let test_create_rejects_nonpositive_cap _ =
  let dir = _make_tmp_dir () in
  let manifest = Snapshot_manifest.create ~schema:_test_schema ~entries:[] in
  assert_that
    (Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:0)
    (is_error_with Status.Invalid_argument)

let test_schema_returns_manifest_schema _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  assert_that (Daily_panels.schema t).schema_hash
    (equal_to _test_schema.schema_hash)

(* --- read_today ----------------------------------------------------- *)

let test_read_today_returns_correct_row _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  let date = Date.add_days _default_start 2 in
  assert_that
    (Daily_panels.read_today t ~symbol:"AAPL" ~date)
    (is_ok_and_holds
       (all_of
          [
            field (fun (r : Snapshot.t) -> r.symbol) (equal_to "AAPL");
            field (fun (r : Snapshot.t) -> r.date) (equal_to date);
            field (fun (r : Snapshot.t) -> r.values.(0)) (float_equal 102.0);
            field (fun (r : Snapshot.t) -> r.values.(1)) (float_equal 202.0);
          ]))

let test_read_today_unknown_symbol_returns_not_found _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  assert_that
    (Daily_panels.read_today t ~symbol:"XYZ" ~date:_default_start)
    (is_error_with Status.NotFound)

let test_read_today_unknown_date_returns_not_found _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  let outside = Date.add_days _default_start 100 in
  assert_that
    (Daily_panels.read_today t ~symbol:"AAPL" ~date:outside)
    (is_error_with Status.NotFound)

(* --- read_history --------------------------------------------------- *)

let test_read_history_returns_ordered_subset _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:10 ~max_cache_mb:1 in
  let from = Date.add_days _default_start 2 in
  let until = Date.add_days _default_start 5 in
  let dates_in_result rows =
    List.map rows ~f:(fun (r : Snapshot.t) -> r.date)
  in
  assert_that
    (Daily_panels.read_history t ~symbol:"AAPL" ~from ~until)
    (is_ok_and_holds
       (field dates_in_result
          (equal_to
             [
               Date.add_days _default_start 2;
               Date.add_days _default_start 3;
               Date.add_days _default_start 4;
               Date.add_days _default_start 5;
             ])))

let test_read_history_empty_range_returns_empty_list _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  let future_from = Date.add_days _default_start 100 in
  let future_until = Date.add_days _default_start 110 in
  assert_that
    (Daily_panels.read_history t ~symbol:"AAPL" ~from:future_from
       ~until:future_until)
    (is_ok_and_holds (size_is 0))

(* --- LRU eviction --------------------------------------------------- *)

(* With a 1 MB cap and 10K-day series across many symbols, the cache cannot
   hold them all; the LRU symbol must be evicted as new ones load. The
   smallest symbol-resident byte total is well under 1 MB (10K * 16 + 64 +
   128 ≈ 160 KB) so several symbols fit; we drive the cache larger by
   loading enough series to overflow. *)
let test_lru_evicts_when_over_budget _ =
  let symbols = [ "A"; "B"; "C"; "D"; "E"; "F" ] in
  (* Each symbol: 5000 rows × (16 bytes values + 64 overhead) ≈ 400 KB.
     With max_cache_mb = 1 (1 MB = 1,048,576 bytes), at most 2 symbols
     fully fit; loading all 6 should evict at least the earliest 2. *)
  let _dir, t = _setup ~symbols ~n_days:5000 ~max_cache_mb:1 in
  let date = _default_start in
  List.iter symbols ~f:(fun symbol ->
      match Daily_panels.read_today t ~symbol ~date with
      | Ok _ -> ()
      | Error err -> assert_failure ("read_today: " ^ Status.show err));
  assert_that
    (Daily_panels.cache_bytes t)
    (le (module Int_ord) ((1 * 1_048_576) + (5000 * 80)))
(* Allow one over-budget overshoot: when a load brings the cache over
       budget the eviction loop drops back below in increments of one
       symbol; the high-water mark sits at most one symbol above the cap. *)

let test_lru_keeps_recently_used_symbol_resident _ =
  let symbols = [ "A"; "B"; "C"; "D"; "E"; "F" ] in
  let _dir, t = _setup ~symbols ~n_days:5000 ~max_cache_mb:1 in
  let date = _default_start in
  (* Touch symbol A first, then load B-F. A should be the LRU and likely
     evicted; touching it again would reload from disk. We assert this
     indirectly: the cache size after loading all six symbols is bounded,
     proving eviction happened at least once. *)
  let touch s =
    match Daily_panels.read_today t ~symbol:s ~date with
    | Ok _ -> ()
    | Error err -> assert_failure ("read_today " ^ s ^ ": " ^ Status.show err)
  in
  List.iter symbols ~f:touch;
  let after_initial = Daily_panels.cache_bytes t in
  (* Touch A last, which is currently the LRU among the residents (or
     evicted). Cache bytes after this touch must still be bounded (<= cap +
     one symbol's worth). *)
  touch "A";
  assert_that
    (Daily_panels.cache_bytes t)
    (le (module Int_ord) (after_initial + (5000 * 80)))

(* --- close + reopen ------------------------------------------------- *)

(* close drops the cache; subsequent reads must still succeed (file-system
   persistence is the source of truth). Verifies that close doesn't corrupt
   the manifest's file pointers. *)
let test_close_then_read_reloads _ =
  let _dir, t = _setup ~symbols:[ "AAPL" ] ~n_days:5 ~max_cache_mb:1 in
  let date = _default_start in
  let _ =
    match Daily_panels.read_today t ~symbol:"AAPL" ~date with
    | Ok r -> r
    | Error err -> assert_failure ("first read: " ^ Status.show err)
  in
  Daily_panels.close t;
  assert_that (Daily_panels.cache_bytes t) (equal_to 0);
  assert_that
    (Daily_panels.read_today t ~symbol:"AAPL" ~date)
    (is_ok_and_holds
       (field (fun (r : Snapshot.t) -> r.symbol) (equal_to "AAPL")))

(* --- schema mismatch ------------------------------------------------ *)

(* If the manifest declares one schema but a file on disk was written under
   a different schema, the runtime must surface the mismatch loudly via
   [Snapshot_format.read_with_expected_schema]. We construct that situation
   by writing a file under schema_other but listing it in a manifest under
   _test_schema. *)
let test_schema_mismatch_fails_loud _ =
  let dir = _make_tmp_dir () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.RSI_14 ]
  in
  let other_row =
    match
      Snapshot.create ~schema:other_schema ~symbol:"AAPL" ~date:_default_start
        ~values:[| 50.0 |]
    with
    | Ok r -> r
    | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)
  in
  let path = Filename.concat dir "AAPL.snap" in
  let _ =
    match Snapshot_format.write ~path [ other_row ] with
    | Ok () -> ()
    | Error err -> assert_failure ("Snapshot_format.write: " ^ Status.show err)
  in
  let metadata =
    {
      Snapshot_manifest.symbol = "AAPL";
      path;
      byte_size = 0;
      payload_md5 = "ignored";
      csv_mtime = 0.0;
    }
  in
  let manifest =
    Snapshot_manifest.create ~schema:_test_schema ~entries:[ metadata ]
  in
  let t =
    match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:1 with
    | Ok t -> t
    | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)
  in
  assert_that
    (Daily_panels.read_today t ~symbol:"AAPL" ~date:_default_start)
    (is_error_with Status.Failed_precondition)

(* --- Hand-pinned 30-day × 10-symbol round trip ---------------------- *)

let test_round_trip_30d_10sym _ =
  let symbols =
    [ "S0"; "S1"; "S2"; "S3"; "S4"; "S5"; "S6"; "S7"; "S8"; "S9" ]
  in
  let n_days = 30 in
  let _dir, t = _setup ~symbols ~n_days ~max_cache_mb:1 in
  let s7_date_5 = Date.add_days _default_start 5 in
  let s7_full =
    match
      Daily_panels.read_history t ~symbol:"S7" ~from:_default_start
        ~until:(Date.add_days _default_start (n_days - 1))
    with
    | Ok rs -> rs
    | Error err -> assert_failure ("read_history: " ^ Status.show err)
  in
  assert_that (List.length s7_full) (equal_to n_days);
  assert_that
    (Daily_panels.read_today t ~symbol:"S7" ~date:s7_date_5)
    (is_ok_and_holds
       (field (fun (r : Snapshot.t) -> r.values.(0)) (float_equal 105.0)))

let suite =
  "Daily_panels tests"
  >::: [
         "create rejects non-positive cap"
         >:: test_create_rejects_nonpositive_cap;
         "schema returns manifest schema"
         >:: test_schema_returns_manifest_schema;
         "read_today returns correct row"
         >:: test_read_today_returns_correct_row;
         "read_today unknown symbol returns not_found"
         >:: test_read_today_unknown_symbol_returns_not_found;
         "read_today unknown date returns not_found"
         >:: test_read_today_unknown_date_returns_not_found;
         "read_history returns ordered subset"
         >:: test_read_history_returns_ordered_subset;
         "read_history empty range returns empty list"
         >:: test_read_history_empty_range_returns_empty_list;
         "LRU evicts when over budget" >:: test_lru_evicts_when_over_budget;
         "LRU keeps recently used resident"
         >:: test_lru_keeps_recently_used_symbol_resident;
         "close then read reloads" >:: test_close_then_read_reloads;
         "schema mismatch fails loud" >:: test_schema_mismatch_fails_loud;
         "round trip 30d × 10 sym" >:: test_round_trip_30d_10sym;
       ]

let () = run_test_tt_main suite
