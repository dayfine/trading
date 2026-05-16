open OUnit2
open Bos
open Core
open Csv.Csv_storage
open Matchers
open Status

let ok_or_failwith_status = function
  | Stdlib.Result.Ok x -> x
  | Error status -> failwith status.message

let ok_or_failwith_os_error = function
  | Stdlib.Result.Ok x -> x
  | Error (`Msg msg) -> failwith msg

let test_dir = Fpath.v "test_data"

let setup_test_dir () =
  let dir_str = Fpath.to_string test_dir in
  (match Sys_unix.file_exists dir_str with
  | `Yes -> ok_or_failwith_os_error (OS.Dir.delete ~recurse:true test_dir)
  | _ -> ());
  ignore (ok_or_failwith_os_error (OS.Dir.create test_dir))

let teardown_test_dir () =
  let dir_str = Fpath.to_string test_dir in
  match Sys_unix.file_exists dir_str with
  | `Yes -> ok_or_failwith_os_error (OS.Dir.delete ~recurse:true test_dir)
  | _ -> ()

let prices =
  [
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
      open_price = 100.0;
      high_price = 105.0;
      low_price = 98.0;
      close_price = 103.0;
      adjusted_close = 103.0;
      volume = 1000;
      active_through = None;
    };
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
      open_price = 103.0;
      high_price = 108.0;
      low_price = 102.0;
      close_price = 107.0;
      adjusted_close = 107.0;
      volume = 1200;
      active_through = None;
    };
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
      open_price = 107.0;
      high_price = 112.0;
      low_price = 106.0;
      close_price = 111.0;
      adjusted_close = 111.0;
      volume = 1400;
      active_through = None;
    };
    {
      Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:22;
      open_price = 111.0;
      high_price = 115.0;
      low_price = 110.0;
      close_price = 114.0;
      adjusted_close = 114.0;
      volume = 1600;
      active_through = None;
    };
  ]

let test_save_and_get_prices _ =
  let symbol = "AAPL" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let expected_path = Fpath.(test_dir / "A" / "L" / "AAPL" / "data.csv") in
  assert_equal `Yes (Sys_unix.file_exists (Fpath.to_string expected_path));
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_single_char_symbol _ =
  let symbol = "X" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let expected_path = Fpath.(test_dir / "X" / "X" / "X" / "data.csv") in
  assert_equal `Yes (Sys_unix.file_exists (Fpath.to_string expected_path));
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_create_twice _ =
  let symbol = "MSFT" in
  ignore (create ~data_dir:test_dir symbol |> ok_or_failwith_status);
  ignore (create ~data_dir:test_dir symbol |> ok_or_failwith_status)

let test_invalid_symbol _ =
  let symbol = "" in
  (* Too short for our directory structure *)
  match create ~data_dir:test_dir symbol with
  | Ok _ -> assert_failure "Should have failed with invalid symbol"
  | Error _ -> ()

let test_fail_to_write_if_data_is_not_sorted _ =
  let storage = create ~data_dir:test_dir "GOOG" |> ok_or_failwith_status in
  match save storage (List.rev prices) with
  | Ok _ -> assert_failure "Expected validation error"
  | Error status ->
      assert_equal ~printer:Status.show status
        (Status.invalid_argument_error
           "Prices must be sorted by date in ascending order and contain no \
            duplicates")

let test_date_filter _ =
  let storage = create ~data_dir:test_dir "GOOG" |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let start_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let end_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let filtered_prices =
    get storage ~start_date ~end_date () |> ok_or_failwith_status
  in
  assert_equal ~printer:Int.to_string 1 (List.length filtered_prices);
  assert_equal ~printer:Types.Daily_price.show (List.nth_exn prices 1)
    (List.nth_exn filtered_prices 0)

let test_multiple_writes_non_overlapping _ =
  let storage = create ~data_dir:test_dir "META" |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let all_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices all_prices

let test_idempotent_writes _ =
  let storage = create ~data_dir:test_dir "NFLX" |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage prices);
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_reject_overlapping_contradictory_data _ =
  let storage = create ~data_dir:test_dir "TSLA" |> ok_or_failwith_status in
  let prices1 = List.take prices 2 in
  let prices2 =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 110.0;
        (* Different price for same date *)
        high_price = 115.0;
        low_price = 108.0;
        close_price = 112.0;
        adjusted_close = 112.0;
        volume = 1500;
        active_through = None;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
        open_price = 112.0;
        high_price = 118.0;
        low_price = 111.0;
        close_price = 116.0;
        adjusted_close = 116.0;
        volume = 1800;
        active_through = None;
      };
    ]
  in
  (* Write first batch *)
  ok_or_failwith_status (save storage prices1);
  (* Try to write second batch with overlapping date *)
  match save storage prices2 with
  | Ok _ ->
      assert_failure
        "Expected validation error for overlapping dates with different data"
  | Error status ->
      assert_equal ~printer:Status.show status
        (Status.invalid_argument_error
           "Cannot save data with overlapping dates and different values")

let test_allow_overlapping_with_override _ =
  let storage = create ~data_dir:test_dir "AMZN" |> ok_or_failwith_status in
  let prices1 = List.take prices 2 in
  let prices2 =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 110.0;
        high_price = 115.0;
        low_price = 108.0;
        close_price = 112.0;
        adjusted_close = 112.0;
        volume = 1500;
        active_through = None;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
        open_price = 112.0;
        high_price = 118.0;
        low_price = 111.0;
        close_price = 116.0;
        adjusted_close = 116.0;
        volume = 1800;
        active_through = None;
      };
    ]
  in
  (* Write first batch *)
  ok_or_failwith_status (save storage prices1);
  (* Write second batch with override *)
  ok_or_failwith_status (save storage ~override:true prices2);
  (* Verify final state has the second batch's data for overlapping date *)
  let all_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    (* 03/19 price from first batch, all other prices from second batch *)
    (List.take prices1 1 @ prices2)
    all_prices

let test_empty_list_after_write_with_override _ =
  let symbol = "EMPTY" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage ~override:true prices);
  ok_or_failwith_status (save storage ~override:true []);
  let saved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices saved_prices

let test_empty_list_after_write_without_override _ =
  let symbol = "EMPTY2" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage ~override:false prices);
  ok_or_failwith_status (save storage ~override:false []);
  let saved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices saved_prices

(* Streaming-refactor coverage: confirm filtering happens during the per-line
   read (not as a post-pass over the full price list). *)

let test_stream_start_date_only_filter _ =
  let storage = create ~data_dir:test_dir "STREAM1" |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let start_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21 in
  let filtered = get storage ~start_date () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    (List.drop prices 2) filtered

let test_stream_bad_line_propagates_error _ =
  let storage = create ~data_dir:test_dir "STREAM2" |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  (* Corrupt the file: append a malformed row after the valid data. The
     streaming reader should still surface the parse error. *)
  let path =
    Fpath.(test_dir / "S" / "2" / "STREAM2" / "data.csv") |> Fpath.to_string
  in
  let oc = Stdlib.open_out_gen [ Open_append ] 0o666 path in
  Out_channel.output_string oc "not,enough,columns\n";
  Out_channel.close oc;
  match get storage () with
  | Ok _ -> assert_failure "Expected parse error from corrupted CSV row"
  | Error status ->
      assert_equal ~printer:Status.show status
        (Status.invalid_argument_error
           "Expected 7 or 8 columns, line: not,enough,columns")

let test_stream_header_only_returns_empty _ =
  let storage = create ~data_dir:test_dir "STREAM3" |> ok_or_failwith_status in
  (* `save` with an empty list is a no-op (see
     test_empty_list_after_write_with_override), so write the header-only file
     by hand to exercise the header-only branch directly. `create` has already
     made the symbol directory. *)
  let path =
    Fpath.(test_dir / "S" / "3" / "STREAM3" / "data.csv") |> Fpath.to_string
  in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume,active_through\n";
  Out_channel.close oc;
  let result = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    [] result

(* Phase 3: round-trip [active_through] through CSV. Mixing [Some _] and
   [None] in the same write batch verifies that the writer emits the new
   column independently per row and that the reader maps the empty cell
   back to [None] while keeping a populated cell as [Some d]. *)
let test_save_and_get_with_active_through _ =
  let storage = create ~data_dir:test_dir "DELIST" |> ok_or_failwith_status in
  let delisted_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21 in
  let prices_with_metadata =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
        open_price = 100.0;
        high_price = 105.0;
        low_price = 98.0;
        close_price = 103.0;
        adjusted_close = 103.0;
        volume = 1000;
        active_through = None;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 103.0;
        high_price = 108.0;
        low_price = 102.0;
        close_price = 107.0;
        adjusted_close = 107.0;
        volume = 1200;
        active_through = Some delisted_date;
      };
      {
        Types.Daily_price.date = delisted_date;
        open_price = 107.0;
        high_price = 112.0;
        low_price = 106.0;
        close_price = 111.0;
        adjusted_close = 111.0;
        volume = 1400;
        active_through = Some delisted_date;
      };
    ]
  in
  ok_or_failwith_status (save storage prices_with_metadata);
  let retrieved = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices_with_metadata retrieved

(* Phase 3 backward-compatibility: a 7-column legacy CSV (no
   [active_through] column) must load with [active_through = None] for
   every row. Goldens written before this PR have the legacy schema and
   must keep loading. *)
let test_read_legacy_7col_csv _ =
  let symbol = "LEGACY" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  let path =
    Fpath.(test_dir / "L" / "Y" / "LEGACY" / "data.csv") |> Fpath.to_string
  in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume\n\
     2024-03-19,100.0,105.0,98.0,103.0,103.0,1000\n\
     2024-03-20,103.0,108.0,102.0,107.0,107.0,1200\n";
  Out_channel.close oc;
  let retrieved = get storage () |> ok_or_failwith_status in
  let expected =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
        open_price = 100.0;
        high_price = 105.0;
        low_price = 98.0;
        close_price = 103.0;
        adjusted_close = 103.0;
        volume = 1000;
        active_through = None;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 103.0;
        high_price = 108.0;
        low_price = 102.0;
        close_price = 107.0;
        adjusted_close = 107.0;
        volume = 1200;
        active_through = None;
      };
    ]
  in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    expected retrieved

(* {1 Phase 2 — manifest integration} *)

(* The shard manifest path is derived from the symbol's [<L1>/<L2>] sharding
   rule so every test that wants to inspect or tamper with the manifest can
   do so without re-implementing the path math. *)
let _manifest_path_for symbol =
  Csv.Csv_storage.shard_manifest_path ~data_dir:test_dir symbol
  |> Fpath.to_string

let _csv_path_for symbol =
  let dir = Csv.Csv_storage.symbol_data_dir ~data_dir:test_dir symbol in
  Fpath.(dir / "data.csv") |> Fpath.to_string

(* After a successful [save], the per-shard manifest contains an entry for
   the saved symbol whose sha256 matches the on-disk file. The row count
   and date range are derived from the written CSV. *)
let test_save_writes_manifest_entry _ =
  let symbol = "MAN1" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status
    (save storage ~source:"EODHD" ~endpoint:"/eod/MAN1" ~fetch_id:"req-1" prices);
  let manifest =
    Manifest.read ~path:(_manifest_path_for symbol) |> ok_or_failwith_status
  in
  let csv_hash =
    Manifest.sha256_of_file ~path:(_csv_path_for symbol)
    |> ok_or_failwith_status
  in
  assert_that
    (Manifest.find manifest ~symbol)
    (is_some_and
       (all_of
          [
            field (fun e -> e.Manifest.symbol) (equal_to symbol);
            field (fun e -> e.Manifest.source) (equal_to "EODHD");
            field (fun e -> e.Manifest.endpoint) (equal_to "/eod/MAN1");
            field (fun e -> e.Manifest.fetch_id) (equal_to "req-1");
            field (fun e -> e.Manifest.sha256) (equal_to csv_hash);
            field (fun e -> e.Manifest.rows_count) (equal_to 4);
          ]))

(* Two saves for the same symbol must produce a single entry — the second
   write upserts the first rather than appending. *)
let test_save_upserts_manifest_entry _ =
  let symbol = "MAN2" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage ~override:true prices);
  let manifest =
    Manifest.read ~path:(_manifest_path_for symbol) |> ok_or_failwith_status
  in
  assert_that
    (List.count manifest.entries ~f:(fun e -> String.equal e.symbol symbol))
    (equal_to 1)

(* [load_with_verify] returns the same rows as [get] when the manifest entry
   matches the on-disk file. *)
let test_load_with_verify_round_trip _ =
  let symbol = "VER1" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  assert_that
    (load_with_verify storage ~strictness:`Strict ())
    (is_ok_and_holds (size_is (List.length prices)))

(* Corrupting the on-disk CSV after save trips the strict-mode hash check
   with a [Status.Internal] error. The Manifest's hash stays at the original
   file's digest because we never call [save] again. *)
let _tamper_csv path =
  let oc = Stdlib.open_out_gen [ Open_append ] 0o666 path in
  Out_channel.output_string oc "# tamper\n";
  Out_channel.close oc

let test_load_with_verify_strict_detects_tampering _ =
  let symbol = "VER2" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  _tamper_csv (_csv_path_for symbol);
  assert_that
    (load_with_verify storage ~strictness:`Strict ())
    (is_error_with Internal)

(* [`Warn] mode tolerates a hash mismatch — the parser-valid replacement
   loads as [Ok] and the mismatch is only logged to stderr. The replaced
   CSV has one valid row so the parser succeeds; the on-disk sha256 differs
   from the manifest entry written by [save]. *)
let test_load_with_verify_warn_tolerates_mismatch _ =
  let symbol = "VER3" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let path = _csv_path_for symbol in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume,active_through\n\
     2024-03-19,100.0,105.0,98.0,103.0,103.0,9999,\n";
  Out_channel.close oc;
  assert_that
    (load_with_verify storage ~strictness:`Warn ())
    (is_ok_and_holds (size_is 1))

(* [`Off] mode never reads the manifest and never errors on hash mismatch. *)
let test_load_with_verify_off_skips_check _ =
  let symbol = "VER4" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let path = _csv_path_for symbol in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume,active_through\n\
     2024-03-19,100.0,105.0,98.0,103.0,103.0,1,\n";
  Out_channel.close oc;
  assert_that
    (load_with_verify storage ~strictness:`Off ())
    (is_ok_and_holds (size_is 1))

(* Legacy data (CSV present, no manifest sidecar) must load cleanly under
   both [`Strict] and [`Warn] — there is no claim to verify. *)
let test_load_with_verify_no_manifest_strict _ =
  let symbol = "LEG1" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  (* Write the CSV directly so no manifest is created. *)
  let path = _csv_path_for symbol in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume,active_through\n\
     2024-03-19,100.0,105.0,98.0,103.0,103.0,1000,\n";
  Out_channel.close oc;
  (* The manifest sidecar should not exist for this shard before we load. *)
  let manifest_path = _manifest_path_for symbol in
  (try Stdlib.Sys.remove manifest_path with _ -> ());
  assert_that
    (load_with_verify storage ~strictness:`Strict ())
    (is_ok_and_holds (size_is 1))

let test_load_with_verify_no_manifest_warn _ =
  let symbol = "LEG2" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  let path = _csv_path_for symbol in
  let oc = Stdlib.open_out path in
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume,active_through\n\
     2024-03-19,100.0,105.0,98.0,103.0,103.0,1000,\n";
  Out_channel.close oc;
  let manifest_path = _manifest_path_for symbol in
  (try Stdlib.Sys.remove manifest_path with _ -> ());
  assert_that
    (load_with_verify storage ~strictness:`Warn ())
    (is_ok_and_holds (size_is 1))

(* {1 Phase 3 — reconcile-on-refetch diff log} *)

let _reconcile_dir = Fpath.(test_dir / "_reconcile_log")

(* The reconcile log is rooted at [test_data/_reconcile_log/]. Tests share the
   same [test_dir] across cases (setup runs once), so each reconcile-test must
   reset the reconcile-log tree up front to be order-independent. *)
let _reset_reconcile_dir () =
  let path = Fpath.to_string _reconcile_dir in
  match Sys_unix.file_exists path with
  | `No | `Unknown -> ()
  | `Yes -> (
      (* The dir may have been replaced with a regular file by the
         failure-injection test; try the file removal first, then the
         recursive-directory removal as a fallback. *)
      try Stdlib.Sys.remove path
      with _ ->
        ok_or_failwith_os_error (OS.Dir.delete ~recurse:true _reconcile_dir))

(* True iff a per-symbol reconcile entry has been written under any date shard
   below [_reconcile_dir]. Used to assert presence/absence without baking in
   today's UTC date as a literal. *)
let _reconcile_log_for symbol =
  let recon_path = Fpath.to_string _reconcile_dir in
  match Sys_unix.file_exists recon_path with
  | `No | `Unknown -> None
  | `Yes ->
      let dates = Sys_unix.readdir recon_path |> Array.to_list in
      List.find_map dates ~f:(fun d ->
          let p =
            Fpath.(_reconcile_dir / d / (symbol ^ ".sexp")) |> Fpath.to_string
          in
          match Sys_unix.file_exists p with `Yes -> Some p | _ -> None)

(* A refetch with byte-identical content produces no reconcile entry. The
   sha256 of the new file matches the prior manifest entry, so [save] takes
   the [Unchanged] branch and no per-symbol log file is written. *)
let test_reconcile_no_op_when_content_unchanged _ =
  _reset_reconcile_dir ();
  let symbol = "REC1" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage ~override:true prices);
  assert_that (_reconcile_log_for symbol) is_none

(* Refetch with different rows on the same date triggers a reconcile entry.
   The entry's [old_*] fields come from the prior manifest entry; [new_*]
   fields are derived from the post-save on-disk file. *)
let test_reconcile_writes_entry_when_content_changes _ =
  _reset_reconcile_dir ();
  let symbol = "REC2" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status
    (save storage ~source:"EODHD" ~fetch_id:"req-old" prices);
  let prior_manifest =
    Manifest.read ~path:(_manifest_path_for symbol) |> ok_or_failwith_status
  in
  let prior_entry =
    match Manifest.find prior_manifest ~symbol with
    | Some e -> e
    | None -> assert_failure "expected manifest entry from first save"
  in
  let mutated_prices =
    List.map prices ~f:(fun p ->
        { p with Types.Daily_price.close_price = p.close_price +. 1.0 })
  in
  ok_or_failwith_status
    (save storage ~override:true ~source:"EODHD" ~fetch_id:"req-new"
       mutated_prices);
  let new_csv_hash =
    Manifest.sha256_of_file ~path:(_csv_path_for symbol)
    |> ok_or_failwith_status
  in
  let today_shard =
    Time_ns.to_date (Time_ns.now ()) ~zone:Time_float.Zone.utc |> Date.to_string
  in
  let log_path =
    Fpath.(_reconcile_dir / today_shard / (symbol ^ ".sexp")) |> Fpath.to_string
  in
  let log_contents = In_channel.read_all log_path in
  let entry =
    Csv.Csv_storage_manifest.reconcile_entry_of_sexp
      (Sexp.of_string (String.strip log_contents))
  in
  assert_that entry
    (all_of
       [
         field (fun e -> e.Csv.Csv_storage_manifest.symbol) (equal_to symbol);
         field
           (fun e -> e.Csv.Csv_storage_manifest.old_sha256)
           (equal_to prior_entry.Manifest.sha256);
         field
           (fun e -> e.Csv.Csv_storage_manifest.new_sha256)
           (equal_to new_csv_hash);
         field
           (fun e -> e.Csv.Csv_storage_manifest.old_rows_count)
           (equal_to prior_entry.Manifest.rows_count);
         field
           (fun e -> e.Csv.Csv_storage_manifest.new_rows_count)
           (equal_to (List.length prices));
         field
           (fun e -> e.Csv.Csv_storage_manifest.fetch_id)
           (equal_to "req-new");
       ])

(* The reconcile log is sharded by UTC date directory. After a content-changing
   refetch the date directory exists, contains the per-symbol sexp, and the
   directory's name parses as a valid date. *)
let test_reconcile_log_path_layout _ =
  _reset_reconcile_dir ();
  let symbol = "REC3" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  let mutated_prices =
    List.map prices ~f:(fun p ->
        { p with Types.Daily_price.volume = p.volume + 1 })
  in
  ok_or_failwith_status (save storage ~override:true mutated_prices);
  let date_shards =
    Sys_unix.readdir (Fpath.to_string _reconcile_dir) |> Array.to_list
  in
  assert_that (List.length date_shards) (equal_to 1);
  let shard_name = List.hd_exn date_shards in
  let _ = Date.of_string shard_name in
  let symbol_file =
    Fpath.(_reconcile_dir / shard_name / (symbol ^ ".sexp")) |> Fpath.to_string
  in
  let exists =
    match Sys_unix.file_exists symbol_file with `Yes -> true | _ -> false
  in
  assert_that exists (equal_to true)

(* First save (no prior manifest entry) skips the reconcile pass entirely.
   The reconcile-log directory must not exist after a single fresh save. *)
let test_reconcile_first_save_creates_no_log _ =
  _reset_reconcile_dir ();
  let symbol = "REC4" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  assert_that (_reconcile_log_for symbol) is_none

(* A reconcile-log write failure must not surface as an error from [save].
   We force the failure by pre-creating a non-directory at the reconcile-log
   shard path so the [_ensure_parent_dir] call inside [reconcile_on_save]
   fails. The save returns [Ok ()] regardless. *)
let test_reconcile_failure_is_non_fatal _ =
  _reset_reconcile_dir ();
  let symbol = "REC5" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  ok_or_failwith_status (save storage prices);
  (* Plant a regular file where the reconcile-log directory would live so
     [_ensure_parent_dir] fails when reconcile_on_save tries to create it. *)
  let recon_dir = Fpath.to_string _reconcile_dir in
  let oc = Stdlib.open_out recon_dir in
  Out_channel.output_string oc "not a directory\n";
  Out_channel.close oc;
  let mutated_prices =
    List.map prices ~f:(fun p ->
        { p with Types.Daily_price.high_price = p.high_price +. 0.5 })
  in
  assert_that
    (save storage ~override:true mutated_prices)
    (is_ok_and_holds (equal_to ()));
  (* Cleanup the planted file so teardown can run normally. *)
  try Stdlib.Sys.remove recon_dir with _ -> ()

let suite =
  "CSV Storage tests"
  >::: [
         "test_save_and_get_prices" >:: test_save_and_get_prices;
         "test_single_char_symbol" >:: test_single_char_symbol;
         "test_create_twice" >:: test_create_twice;
         "test_invalid_symbol" >:: test_invalid_symbol;
         "test_fail_to_write_if_data_is_not_sorted"
         >:: test_fail_to_write_if_data_is_not_sorted;
         "test_date_filter" >:: test_date_filter;
         "test_multiple_writes_non_overlapping"
         >:: test_multiple_writes_non_overlapping;
         "test_idempotent_writes" >:: test_idempotent_writes;
         "test_reject_overlapping_contradictory_data"
         >:: test_reject_overlapping_contradictory_data;
         "test_allow_overlapping_with_override"
         >:: test_allow_overlapping_with_override;
         "test_empty_list_after_write_with_override"
         >:: test_empty_list_after_write_with_override;
         "test_empty_list_after_write_without_override"
         >:: test_empty_list_after_write_without_override;
         "test_stream_start_date_only_filter"
         >:: test_stream_start_date_only_filter;
         "test_stream_bad_line_propagates_error"
         >:: test_stream_bad_line_propagates_error;
         "test_stream_header_only_returns_empty"
         >:: test_stream_header_only_returns_empty;
         "test_save_and_get_with_active_through"
         >:: test_save_and_get_with_active_through;
         "test_read_legacy_7col_csv" >:: test_read_legacy_7col_csv;
         "test_save_writes_manifest_entry" >:: test_save_writes_manifest_entry;
         "test_save_upserts_manifest_entry" >:: test_save_upserts_manifest_entry;
         "test_load_with_verify_round_trip" >:: test_load_with_verify_round_trip;
         "test_load_with_verify_strict_detects_tampering"
         >:: test_load_with_verify_strict_detects_tampering;
         "test_load_with_verify_warn_tolerates_mismatch"
         >:: test_load_with_verify_warn_tolerates_mismatch;
         "test_load_with_verify_off_skips_check"
         >:: test_load_with_verify_off_skips_check;
         "test_load_with_verify_no_manifest_strict"
         >:: test_load_with_verify_no_manifest_strict;
         "test_load_with_verify_no_manifest_warn"
         >:: test_load_with_verify_no_manifest_warn;
         "test_reconcile_no_op_when_content_unchanged"
         >:: test_reconcile_no_op_when_content_unchanged;
         "test_reconcile_writes_entry_when_content_changes"
         >:: test_reconcile_writes_entry_when_content_changes;
         "test_reconcile_log_path_layout" >:: test_reconcile_log_path_layout;
         "test_reconcile_first_save_creates_no_log"
         >:: test_reconcile_first_save_creates_no_log;
         "test_reconcile_failure_is_non_fatal"
         >:: test_reconcile_failure_is_non_fatal;
       ]

let () =
  setup_test_dir ();
  run_test_tt_main suite;
  teardown_test_dir ()
