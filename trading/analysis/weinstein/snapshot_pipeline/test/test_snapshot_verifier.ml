open OUnit2
open Core
open Matchers
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_columnar_codec = Data_panel_snapshot.Snapshot_columnar_codec
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* The lib namespace [Snapshot_pipeline] holds three modules:
   [Snapshot_pipeline] (the per-symbol builder, aliased as [Pipeline] here),
   [Snapshot_manifest], and [Snapshot_verifier]. *)

let _make_bar ~date ~close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close +. 1.0;
    low_price = close -. 1.0;
    close_price = close;
    volume = 1_000_000;
    adjusted_close = close;
    active_through = None;
  }

let _ramp_bars ~n =
  let dates =
    List.init n ~f:(fun i -> Date.add_days (Date.of_string "2024-01-02") i)
  in
  List.mapi dates ~f:(fun i d ->
      _make_bar ~date:d ~close:(100.0 +. Float.of_int i))

let _make_test_dir prefix =
  let path = Filename_unix.temp_dir prefix "" in
  path

let _build_for_symbol symbol =
  match
    Pipeline.build_for_symbol ~symbol ~bars:(_ramp_bars ~n:10)
      ~schema:Snapshot_schema.default ()
  with
  | Ok rs -> rs
  | Error err -> assert_failure (Status.show err)

let _write_entry ~dir ~write symbol =
  let rows = _build_for_symbol symbol in
  let path = Filename.concat dir (symbol ^ ".snap") in
  (match write ~path rows with
  | Ok () -> ()
  | Error err -> assert_failure (Status.show err));
  let bytes = In_channel.read_all path in
  {
    Snapshot_manifest.symbol;
    path;
    byte_size = String.length bytes;
    payload_md5 = Stdlib.Digest.to_hex (Stdlib.Digest.string bytes);
    csv_mtime = 0.0;
    active_through = None;
  }

(* Build a one-symbol-per-file warehouse using [write] for the payload and
   [manifest_schema] for the manifest's expected schema (defaults to the
   builder's [default] schema; pass a different schema to provoke a skew). *)
let _build_one_symbol_dir ?(write = Snapshot_columnar.write)
    ?(manifest_schema = Snapshot_schema.default) ~symbols () =
  let dir = _make_test_dir "snapshot_verifier_test_" in
  let entries = List.map symbols ~f:(_write_entry ~dir ~write) in
  let manifest = Snapshot_manifest.create ~schema:manifest_schema ~entries in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> assert_failure (Status.show err));
  (dir, manifest_path)

(* The first bytes of a [.snap] file written by [write]. *)
let _magic_prefix path =
  let len = Snapshot_columnar_codec.magic_len in
  In_channel.with_file path ~f:(fun ic ->
      let buf = Bytes.create len in
      match In_channel.really_input ic ~buf ~pos:0 ~len with
      | Some () -> Bytes.to_string buf
      | None -> "")

(* A v2 build writes the columnar magic; the verifier format-detects and
   round-trips it. *)
let test_verify_passes_v2_directory _ =
  let dir, manifest_path =
    _build_one_symbol_dir ~symbols:[ "AAPL"; "MSFT"; "GOOG" ] ()
  in
  assert_that
    (_magic_prefix (Filename.concat dir "AAPL.snap"))
    (equal_to Snapshot_columnar_codec.magic);
  assert_that
    (Snapshot_verifier.verify_directory ~manifest_path)
    (is_ok_and_holds
       (all_of
          [
            field (fun (r : Snapshot_verifier.t) -> r.total) (equal_to 3);
            field (fun (r : Snapshot_verifier.t) -> r.passed) (equal_to 3);
            field (fun (r : Snapshot_verifier.t) -> r.failed) (equal_to 0);
          ]))

(* A legacy v1 sexp warehouse still verifies (the other detection branch). *)
let test_verify_passes_v1_directory _ =
  let dir, manifest_path =
    _build_one_symbol_dir ~write:Snapshot_format.write
      ~symbols:[ "AAPL"; "MSFT" ] ()
  in
  assert_that
    (not
       (String.equal
          (_magic_prefix (Filename.concat dir "AAPL.snap"))
          Snapshot_columnar_codec.magic))
    (equal_to true);
  assert_that
    (Snapshot_verifier.verify_directory ~manifest_path)
    (is_ok_and_holds
       (all_of
          [
            field (fun (r : Snapshot_verifier.t) -> r.total) (equal_to 2);
            field (fun (r : Snapshot_verifier.t) -> r.passed) (equal_to 2);
            field (fun (r : Snapshot_verifier.t) -> r.failed) (equal_to 0);
          ]))

(* A v2 file whose manifest declares a different schema fails the hash gate. *)
let test_verify_detects_v2_schema_skew _ =
  let _, manifest_path =
    _build_one_symbol_dir
      ~manifest_schema:
        (Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ])
      ~symbols:[ "AAPL" ] ()
  in
  assert_that
    (Snapshot_verifier.verify_directory ~manifest_path)
    (is_ok_and_holds
       (all_of
          [
            field (fun (r : Snapshot_verifier.t) -> r.total) (equal_to 1);
            field (fun (r : Snapshot_verifier.t) -> r.passed) (equal_to 0);
            field (fun (r : Snapshot_verifier.t) -> r.failed) (equal_to 1);
          ]))

(* Tampering: flip the last byte of a file to corrupt the payload md5. The v1
   file's own integrity check fires, the verifier counts it as failed. *)
let _corrupt_file path =
  let bytes = In_channel.read_all path |> Bytes.of_string in
  let n = Bytes.length bytes in
  let last = Char.to_int (Bytes.get bytes (n - 1)) in
  Bytes.set bytes (n - 1) (Char.of_int_exn (last lxor 0xFF));
  Out_channel.write_all path ~data:(Bytes.to_string bytes)

let test_verify_detects_corrupted_file _ =
  let _, manifest_path =
    _build_one_symbol_dir ~write:Snapshot_format.write
      ~symbols:[ "AAPL"; "MSFT" ] ()
  in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err -> assert_failure (Status.show err)
  in
  let aapl_path = (List.hd_exn manifest.entries).Snapshot_manifest.path in
  _corrupt_file aapl_path;
  assert_that
    (Snapshot_verifier.verify_directory ~manifest_path)
    (is_ok_and_holds
       (all_of
          [
            field (fun (r : Snapshot_verifier.t) -> r.total) (equal_to 2);
            field (fun (r : Snapshot_verifier.t) -> r.passed) (equal_to 1);
            field (fun (r : Snapshot_verifier.t) -> r.failed) (equal_to 1);
          ]))

let test_verify_returns_error_when_manifest_missing _ =
  assert_that
    (Snapshot_verifier.verify_directory
       ~manifest_path:"/tmp/snapshot_verifier_no_such_manifest.sexp")
    (is_error_with Status.NotFound)

let suite =
  "Snapshot_verifier tests"
  >::: [
         "verify passes v2 directory" >:: test_verify_passes_v2_directory;
         "verify passes v1 directory" >:: test_verify_passes_v1_directory;
         "verify detects v2 schema skew" >:: test_verify_detects_v2_schema_skew;
         "verify detects corrupted file" >:: test_verify_detects_corrupted_file;
         "verify returns error when manifest missing"
         >:: test_verify_returns_error_when_manifest_missing;
       ]

let () = run_test_tt_main suite
