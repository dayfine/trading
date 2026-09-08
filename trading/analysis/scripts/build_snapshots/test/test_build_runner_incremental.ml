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

    - an incremental top-up over a new symbol keeps the existing ones, and the
      marker split logged for the run counts the carried entries too;
    - an incremental rebuild of one existing symbol neither drops its siblings
      nor duplicates itself;
    - a {e non}-incremental run still replaces the index outright, which is how
      an operator prunes symbols the warehouse should no longer carry;
    - a carried entry whose [.snap] file is gone is dropped, so the closing
      verify still passes (carry guard B);
    - a pre-run manifest written under another schema is refused whole (carry
      guard A). *)

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

(* The marker split and both carry guards report through stdout / stderr, so
   pinning what they log means reading the process's own output. Both
   descriptors are redirected to one temp file for the duration of [f] and
   restored afterwards, leaving OUnit's own reporting untouched. *)
let _with_captured_output f =
  let path = Filename_unix.temp_file "build_runner_incremental_log" ".txt" in
  Out_channel.flush Out_channel.stdout;
  Out_channel.flush Out_channel.stderr;
  let saved_out = Core_unix.dup Core_unix.stdout in
  let saved_err = Core_unix.dup Core_unix.stderr in
  let sink = Core_unix.openfile path ~mode:[ O_WRONLY; O_TRUNC ] in
  Core_unix.dup2 ~src:sink ~dst:Core_unix.stdout ();
  Core_unix.dup2 ~src:sink ~dst:Core_unix.stderr ();
  Fun.protect
    ~finally:(fun () ->
      Out_channel.flush Out_channel.stdout;
      Out_channel.flush Out_channel.stderr;
      Core_unix.dup2 ~src:saved_out ~dst:Core_unix.stdout ();
      Core_unix.dup2 ~src:saved_err ~dst:Core_unix.stderr ();
      Core_unix.close saved_out;
      Core_unix.close saved_err;
      Core_unix.close sink)
    f;
  let log = In_channel.read_all path in
  Stdlib.Sys.remove path;
  log

(* Build the two-symbol warehouse, run [between] against the output directory,
   then re-run over [second_run]. Returns the symbols the final manifest
   indexes (sorted) paired with everything that second run logged. *)
let _topup ?(between = fun ~output_dir:(_ : string) -> ()) ~incremental
    second_run =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      List.iter (_new_symbol :: _initial_symbols) ~f:(fun symbol ->
          _write_csv ~data_dir ~symbol);
      _build ~incremental:false ~data_dir ~output_dir _initial_symbols;
      between ~output_dir;
      let log =
        _with_captured_output (fun () ->
            _build ~incremental ~data_dir ~output_dir second_run)
      in
      (_manifest_symbols ~output_dir, log))

let _symbols_after ~incremental second_run =
  fst (_topup ~incremental second_run)

(* Between the builds: drop one symbol's snapshot file, leaving its manifest
   row behind as the stale index entry guard B exists to catch. *)
let _delete_snap_of symbol ~output_dir =
  Stdlib.Sys.remove (Filename.concat output_dir (symbol ^ ".snap"))

let _bogus_schema_hash = "not-this-builds-schema"

(* Between the builds: restamp the manifest under a foreign schema hash. The
   [.snap] files are left alone — the point is a manifest whose rows advertise
   another indicator set's column layout. *)
let _restamp_schema_hash ~output_dir =
  let path = Filename.concat output_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path with
  | Error e -> failwith ("manifest read: " ^ Status.show e)
  | Ok (m : Snapshot_manifest.t) -> (
      match
        Snapshot_manifest.write ~path
          { m with schema_hash = _bogus_schema_hash }
      with
      | Error e -> failwith ("manifest write: " ^ Status.show e)
      | Ok () -> ())

(** The #2669 repro: an incremental top-up over a one-symbol universe must merge
    into the existing index, not replace it. Pre-fix this returned [["NEW"]] —
    the two [.snap] files still on disk but invisible to every runner.

    The log assertion pins the second half of the contract: the marker split is
    reported over the set actually written (3 symbols), not over this run's own
    (1). It read ["of 1 symbols"] while the manifest held 3 until the split was
    moved to after the merge. *)
let test_incremental_topup_keeps_existing_symbols _ =
  assert_that
    (_topup ~incremental:true [ _new_symbol ])
    (pair
       (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to _new_symbol ])
       (contains_substring
          "active_through: 0 marked, 3 survivors (of 3 symbols)"))

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

(** Carry guard B: a candidate whose [.snap] file no longer exists is dropped
    instead of re-indexed. [BBB.snap] is deleted between the builds, so the
    top-up carries [AAA] forward and leaves [BBB] out. The verify line is
    asserted because it is what the guard protects: without the drop the stale
    row reaches {!Snapshot_verifier.verify_directory}, which fails the file and
    exits the build non-zero on every subsequent top-up. *)
let test_carried_entry_without_a_snap_file_is_dropped _ =
  assert_that
    (_topup ~incremental:true ~between:(_delete_snap_of "BBB") [ _new_symbol ])
    (pair
       (elements_are [ equal_to "AAA"; equal_to _new_symbol ])
       (contains_substring "verify: 2/2 files OK (failed=0)"))

(** Carry guard A: a pre-run manifest whose [schema_hash] differs from this
    build's is refused {e whole} — its rows describe another indicator set's
    column layout, so adopting any of them would advertise columns this build's
    readers cannot decode. The top-up therefore indexes [NEW] alone, and the
    refusal is logged rather than silent. *)
let test_cross_schema_manifest_is_not_carried _ =
  assert_that
    (_topup ~incremental:true ~between:_restamp_schema_hash [ _new_symbol ])
    (pair
       (elements_are [ equal_to _new_symbol ])
       (contains_substring "entries are NOT carried forward"))

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
           "a carried entry whose snap file is gone is dropped"
           >:: test_carried_entry_without_a_snap_file_is_dropped;
           "a cross-schema manifest is not carried forward"
           >:: test_cross_schema_manifest_is_not_carried;
         ])
