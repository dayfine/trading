(** End-to-end pin for the incremental manifest merge (#2669).

    The defect: [build_snapshots.exe -incremental] rewrote [manifest.sexp] with
    only the symbols processed in that run. Observed 2026-09-04 while topping up
    a freshly built 2,208-symbol vintage warehouse with one benchmark ticker —
    the run reported ["wrote 1 entries"] and the manifest listed only
    [GSPC.INDX] while all 2,208 [.snap] files sat untouched on disk. Since
    [Bar_source_resolver] enumerates symbols {e from the manifest}, the
    warehouse read as empty to every runner.

    These tests build a small warehouse, then re-run the builder over a
    {e subset} universe and read the resulting index back. The shapes pinned:

    - an incremental top-up over a new symbol keeps the existing ones;
    - an incremental rebuild of one existing symbol neither drops its siblings
      nor duplicates itself;
    - a {e non}-incremental run still replaces the index outright, which is how
      an operator prunes symbols the warehouse should no longer carry. *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _last_bar = Date.of_string "2021-12-31"

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_incremental" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* A flat 5-bar series — flat so the series-tail pass finds nothing to truncate
   and only the manifest bookkeeping is under test. *)
let _series () =
  List.init 5 ~f:(fun i -> _bar (Date.add_days _last_bar (i - 4)) 50.0)

let _write_csv ~data_dir ~symbol =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> failwith ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true (_series ()) with
      | Error e -> failwith ("csv save: " ^ Status.show e)
      | Ok () -> ())

(* The warehouse's initial population, plus the ticker a top-up would add. *)
let _initial_symbols = [ "AAA"; "BBB" ]
let _new_symbol = "NEW"

let _build ~incremental ~data_dir ~output_dir symbols =
  Build_runner.build ~symbols ~csv_data_dir:data_dir ~output_dir
    ~benchmark_symbol:None ~start_date:None ~end_date:None
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default
    ~tail_exceptions:Series_tail.Exceptions.empty ()

let _manifest_symbols ~output_dir =
  match
    Snapshot_manifest.read ~path:(Filename.concat output_dir "manifest.sexp")
  with
  | Error e -> failwith ("manifest read: " ^ Status.show e)
  | Ok (m : Snapshot_manifest.t) ->
      List.map m.entries ~f:(fun (e : Snapshot_manifest.file_metadata) ->
          e.symbol)
      |> List.sort ~compare:String.compare

(* Build the two-symbol warehouse, then re-run over [second_run] and return the
   symbols the final manifest indexes, sorted. *)
let _symbols_after ~incremental second_run =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      List.iter (_new_symbol :: _initial_symbols) ~f:(fun symbol ->
          _write_csv ~data_dir ~symbol);
      _build ~incremental:false ~data_dir ~output_dir _initial_symbols;
      _build ~incremental ~data_dir ~output_dir second_run;
      _manifest_symbols ~output_dir)

(** The #2669 repro: an incremental top-up over a one-symbol universe must merge
    into the existing index, not replace it. Pre-fix this returned [["NEW"]] —
    the two [.snap] files still on disk but invisible to every runner. *)
let test_incremental_topup_keeps_existing_symbols _ =
  assert_that
    (_symbols_after ~incremental:true [ _new_symbol ])
    (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to _new_symbol ])

(** A subset re-run over a symbol the warehouse already has keeps its siblings
    and yields exactly one entry for itself: the run's entry replaces the
    carried one rather than appending beside it. *)
let test_incremental_subset_rebuild_does_not_duplicate _ =
  assert_that
    (_symbols_after ~incremental:true [ "AAA" ])
    (elements_are [ equal_to "AAA"; equal_to "BBB" ])

(** The non-incremental path is unchanged: it replaces the index outright, which
    is how an operator prunes symbols the warehouse should no longer carry. *)
let test_full_rebuild_still_replaces_the_index _ =
  assert_that
    (_symbols_after ~incremental:false [ _new_symbol ])
    (elements_are [ equal_to _new_symbol ])

let () =
  run_test_tt_main
    ("build_runner_incremental"
    >::: [
           "an incremental top-up keeps the existing symbols"
           >:: test_incremental_topup_keeps_existing_symbols;
           "an incremental subset rebuild does not duplicate or drop"
           >:: test_incremental_subset_rebuild_does_not_duplicate;
           "a full rebuild still replaces the index"
           >:: test_full_rebuild_still_replaces_the_index;
         ])
