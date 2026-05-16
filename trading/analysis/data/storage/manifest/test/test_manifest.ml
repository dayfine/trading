open Core
open OUnit2
open Matchers
open Manifest

(* Use [Alternate_sexp] for parity with the manifest's on-disk form so the
   round-trip equality check compares the exact same int64-nanos value the
   serializer wrote. The serializer emits ["YYYY-MM-DD HH:MM:SSZ"] (UTC,
   space separator). *)
let _sample_fetched_at =
  Time_ns.Alternate_sexp.t_of_sexp (Sexp.Atom "2026-05-17 10:31:14Z")

let _sample_date_from = Date.create_exn ~y:2026 ~m:Month.Jan ~d:1
let _sample_date_to = Date.create_exn ~y:2026 ~m:Month.May ~d:17

let _sample_entry ?(symbol = "AAPL.US") ?(rows_count = 100)
    ?(sha256 = "deadbeef00000000deadbeef00000000") () =
  {
    symbol;
    source = "EODHD";
    endpoint = "/eod/" ^ symbol;
    date_range = Some (_sample_date_from, _sample_date_to);
    rows_count;
    sha256;
    vendor_revision_tag = "2026-05-16";
    fetched_at = _sample_fetched_at;
    fetch_id = "req-1c8f3d4e";
    api_key_id = "eodhd-prod";
  }

let _with_tmp_file ~contents f =
  let path =
    Filename_unix.temp_file ~in_dir:Filename.temp_dir_name "manifest_test"
      ".bin"
  in
  Out_channel.write_all path ~data:contents;
  Exn.protect
    ~f:(fun () -> f path)
    ~finally:(fun () -> try Stdlib.Sys.remove path with _ -> ())

let _with_tmp_path f =
  let path =
    Filename_unix.temp_file ~in_dir:Filename.temp_dir_name "manifest" ".sexp"
  in
  (* [Filename.temp_file] creates an empty file; some tests want a missing
     path so they remove it up front and rely on the cleanup below. *)
  (try Stdlib.Sys.remove path with _ -> ());
  Exn.protect
    ~f:(fun () -> f path)
    ~finally:(fun () -> try Stdlib.Sys.remove path with _ -> ())

(* {1 [create]} *)

let test_create_empty _ =
  let m = create () in
  assert_that m
    (all_of
       [
         field (fun m -> m.schema_version) (equal_to current_schema_version);
         field (fun m -> List.length m.entries) (equal_to 0);
       ])

let test_create_with_entries _ =
  let entry = _sample_entry () in
  let m = create ~entries:[ entry ] () in
  assert_that m.entries (elements_are [ equal_to entry ])

(* {1 [upsert_entry]} *)

let test_upsert_appends_new_entry _ =
  let m = create () in
  let e1 = _sample_entry ~symbol:"AAPL.US" () in
  let m' = upsert_entry m e1 in
  assert_that m'.entries (elements_are [ equal_to e1 ])

let test_upsert_replaces_existing_symbol_in_place _ =
  let e1 = _sample_entry ~symbol:"AAPL.US" ~rows_count:100 () in
  let e2 = _sample_entry ~symbol:"MSFT.US" ~rows_count:50 () in
  let e1_updated = _sample_entry ~symbol:"AAPL.US" ~rows_count:200 () in
  let m = create ~entries:[ e1; e2 ] () in
  let m' = upsert_entry m e1_updated in
  (* AAPL is replaced in place at index 0; MSFT stays at index 1. *)
  assert_that m'.entries (elements_are [ equal_to e1_updated; equal_to e2 ])

let test_upsert_is_idempotent_for_identical_entry _ =
  let e = _sample_entry () in
  let m = upsert_entry (create ()) e in
  let m' = upsert_entry m e in
  assert_that m'.entries (elements_are [ equal_to e ])

(* {1 [find]} *)

let test_find_returns_some_when_symbol_present _ =
  let e = _sample_entry ~symbol:"AAPL.US" () in
  let m = create ~entries:[ e ] () in
  assert_that (find m ~symbol:"AAPL.US") (is_some_and (equal_to e))

let test_find_returns_none_when_symbol_absent _ =
  let m = create ~entries:[ _sample_entry ~symbol:"AAPL.US" () ] () in
  assert_that (find m ~symbol:"MSFT.US") is_none

(* {1 [write] + [read] round-trip} *)

let test_write_then_read_round_trip _ =
  let entries =
    [
      _sample_entry ~symbol:"AAPL.US" ();
      _sample_entry ~symbol:"MSFT.US" ~rows_count:42 ();
    ]
  in
  let m = create ~entries () in
  _with_tmp_path (fun path ->
      let result =
        match write ~path m with Error e -> Error e | Ok () -> read ~path
      in
      assert_that result
        (is_ok_and_holds
           (all_of
              [
                field
                  (fun r -> r.schema_version)
                  (equal_to current_schema_version);
                field
                  (fun r -> r.entries)
                  (elements_are (List.map entries ~f:equal_to));
              ])))

(* Writing an entry without a [date_range] exercises the [@sexp.option] path
   so we know an absent field decodes back to [None] cleanly. *)
let test_round_trip_preserves_none_date_range _ =
  let entry = { (_sample_entry ()) with date_range = None } in
  let m = create ~entries:[ entry ] () in
  _with_tmp_path (fun path ->
      let result =
        match write ~path m with Error e -> Error e | Ok () -> read ~path
      in
      assert_that result
        (is_ok_and_holds
           (field (fun r -> r.entries) (elements_are [ equal_to entry ]))))

(* {1 [read] error paths} *)

let test_read_missing_path_returns_not_found _ =
  let result = read ~path:"/tmp/manifest_test_does_not_exist_12345.sexp" in
  assert_that result (is_error_with Status.NotFound)

(* A manifest written with a different [schema_version] must be rejected so
   downstream readers do not silently mis-decode evolving schemas. The cleanest
   way to forge a future-version manifest is to write a valid one and then
   bump the version field in the sexp file directly — that way the rest of
   the record (timestamps in whatever local-zone form Time_ns_unix produced)
   continues to parse and only the version field trips the check. *)
let test_read_rejects_mismatched_schema_version _ =
  _with_tmp_path (fun path ->
      let m = create () in
      (match write ~path m with
      | Ok () -> ()
      | Error e -> assert_failure ("write failed: " ^ Status.show e));
      let original = In_channel.read_all path in
      let bumped =
        String.substr_replace_first original
          ~pattern:(Printf.sprintf "(schema_version %d)" current_schema_version)
          ~with_:"(schema_version 99)"
      in
      Out_channel.write_all path ~data:bumped;
      let result = read ~path in
      assert_that result (is_error_with Status.Failed_precondition))

(* {1 [sha256_of_file]} *)

(* MD5 of the empty string per RFC 1321 §A.5 is "d41d8cd98f00b204e9800998ecf8427e".
   Pinning this value catches the case where the hash algorithm is silently
   swapped (e.g. to a real SHA-256 producing a 64-hex digest of zero bytes
   "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"). The
   field name is [sha256] aspirationally; v1 is MD5. *)
let test_sha256_of_empty_file _ =
  _with_tmp_file ~contents:"" (fun path ->
      let result = sha256_of_file ~path in
      assert_that result
        (is_ok_and_holds (equal_to "d41d8cd98f00b204e9800998ecf8427e")))

(* MD5 of "hello world" per the RFC 1321 reference implementation is
   "5eb63bbbe01eeed093cb22bb8f5acdc3". *)
let test_sha256_of_known_content _ =
  _with_tmp_file ~contents:"hello world" (fun path ->
      let result = sha256_of_file ~path in
      assert_that result
        (is_ok_and_holds (equal_to "5eb63bbbe01eeed093cb22bb8f5acdc3")))

let test_sha256_missing_path_returns_not_found _ =
  let result =
    sha256_of_file ~path:"/tmp/manifest_sha_test_does_not_exist_67890.csv"
  in
  assert_that result (is_error_with Status.NotFound)

let suite =
  "manifest_test_suite"
  >::: [
         "test_create_empty" >:: test_create_empty;
         "test_create_with_entries" >:: test_create_with_entries;
         "test_upsert_appends_new_entry" >:: test_upsert_appends_new_entry;
         "test_upsert_replaces_existing_symbol_in_place"
         >:: test_upsert_replaces_existing_symbol_in_place;
         "test_upsert_is_idempotent_for_identical_entry"
         >:: test_upsert_is_idempotent_for_identical_entry;
         "test_find_returns_some_when_symbol_present"
         >:: test_find_returns_some_when_symbol_present;
         "test_find_returns_none_when_symbol_absent"
         >:: test_find_returns_none_when_symbol_absent;
         "test_write_then_read_round_trip" >:: test_write_then_read_round_trip;
         "test_round_trip_preserves_none_date_range"
         >:: test_round_trip_preserves_none_date_range;
         "test_read_missing_path_returns_not_found"
         >:: test_read_missing_path_returns_not_found;
         "test_read_rejects_mismatched_schema_version"
         >:: test_read_rejects_mismatched_schema_version;
         "test_sha256_of_empty_file" >:: test_sha256_of_empty_file;
         "test_sha256_of_known_content" >:: test_sha256_of_known_content;
         "test_sha256_missing_path_returns_not_found"
         >:: test_sha256_missing_path_returns_not_found;
       ]

let () = run_test_tt_main suite
