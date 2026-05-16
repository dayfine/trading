open Core
open OUnit2
open Matchers
open Manifest_rehash_lib

(* Build a fake L1/L2-sharded data dir under a fresh tmp root and return its
   absolute path. The caller is responsible for cleanup. *)
let _csv_header = "date,open,high,low,close,adjusted_close,volume"
let _csv_row = "2024-03-19,100.0,105.0,98.0,103.0,103.0,1000"

let _write_csv ~root ~symbol =
  let l1 = String.make 1 symbol.[0] in
  let l2 = String.make 1 symbol.[String.length symbol - 1] in
  let sym_dir =
    Filename.concat (Filename.concat (Filename.concat root l1) l2) symbol
  in
  Core_unix.mkdir_p sym_dir;
  let csv = Filename.concat sym_dir "data.csv" in
  Out_channel.write_all csv ~data:(_csv_header ^ "\n" ^ _csv_row ^ "\n");
  csv

let _with_tmp_data_dir f =
  let root =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name "manifest_rehash" ""
  in
  Exn.protect
    ~f:(fun () -> f root)
    ~finally:(fun () ->
      try
        let _ : Core_unix.Exit_or_signal.t =
          Core_unix.system (Printf.sprintf "rm -rf %s" (Filename.quote root))
        in
        ()
      with _ -> ())

let _shard_manifest_path ~root ~symbol =
  let l1 = String.make 1 symbol.[0] in
  let l2 = String.make 1 symbol.[String.length symbol - 1] in
  Filename.concat (Filename.concat (Filename.concat root l1) l2) "manifest.sexp"

(* {1 dry-run leaves no manifest on disk} *)

let test_dry_run_counts_but_does_not_write _ =
  _with_tmp_data_dir (fun root ->
      let _ = _write_csv ~root ~symbol:"AAPL" in
      let _ = _write_csv ~root ~symbol:"MSFT" in
      let counters =
        Manifest_rehash_lib.run ~data_dir_str:root ~source:"EODHD"
          ~endpoint_fmt:"/eod/%s" ~dry_run:true ~only_missing:true
      in
      assert_that counters
        (all_of
           [
             field (fun c -> c.walked) (equal_to 2);
             field (fun c -> c.rehashed) (equal_to 2);
             field (fun c -> c.skipped_existing) (equal_to 0);
             field (fun c -> List.length c.failures) (equal_to 0);
           ]);
      assert_that
        (Stdlib.Sys.file_exists (_shard_manifest_path ~root ~symbol:"AAPL"))
        (equal_to false))

(* {1 rehash writes manifest entries for every CSV} *)

let test_rehash_writes_entries_for_missing _ =
  _with_tmp_data_dir (fun root ->
      let _ = _write_csv ~root ~symbol:"AAPL" in
      let _ = _write_csv ~root ~symbol:"MSFT" in
      let counters =
        Manifest_rehash_lib.run ~data_dir_str:root ~source:"EODHD"
          ~endpoint_fmt:"/eod/%s" ~dry_run:false ~only_missing:true
      in
      assert_that counters
        (all_of
           [
             field (fun c -> c.walked) (equal_to 2);
             field (fun c -> c.rehashed) (equal_to 2);
             field (fun c -> c.skipped_existing) (equal_to 0);
             field (fun c -> List.length c.failures) (equal_to 0);
           ]);
      let aapl_manifest =
        Manifest.read ~path:(_shard_manifest_path ~root ~symbol:"AAPL")
      in
      assert_that aapl_manifest
        (is_ok_and_holds
           (field
              (fun m -> Manifest.find m ~symbol:"AAPL")
              (is_some_and
                 (all_of
                    [
                      field
                        (fun (e : Manifest.file_metadata) -> e.source)
                        (equal_to "EODHD");
                      field
                        (fun (e : Manifest.file_metadata) -> e.endpoint)
                        (equal_to "/eod/AAPL");
                    ])))))

(* {1 second run with [-only-missing] skips already-rehashed symbols} *)

let test_only_missing_skips_already_present _ =
  _with_tmp_data_dir (fun root ->
      let _ = _write_csv ~root ~symbol:"AAPL" in
      let _first =
        Manifest_rehash_lib.run ~data_dir_str:root ~source:"EODHD"
          ~endpoint_fmt:"/eod/%s" ~dry_run:false ~only_missing:true
      in
      let counters =
        Manifest_rehash_lib.run ~data_dir_str:root ~source:"EODHD"
          ~endpoint_fmt:"/eod/%s" ~dry_run:false ~only_missing:true
      in
      assert_that counters
        (all_of
           [
             field (fun c -> c.walked) (equal_to 1);
             field (fun c -> c.skipped_existing) (equal_to 1);
             field (fun c -> c.rehashed) (equal_to 0);
           ]))

let suite =
  "manifest_rehash_test_suite"
  >::: [
         "test_dry_run_counts_but_does_not_write"
         >:: test_dry_run_counts_but_does_not_write;
         "test_rehash_writes_entries_for_missing"
         >:: test_rehash_writes_entries_for_missing;
         "test_only_missing_skips_already_present"
         >:: test_only_missing_skips_already_present;
       ]

let () = run_test_tt_main suite
