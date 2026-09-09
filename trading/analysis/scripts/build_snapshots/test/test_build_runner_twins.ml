(** End-to-end pin for the rename-twin pass on the {!Build_runner} build path
    (#2730).

    The defect: [-dedupe-rename-twins] existed only on
    [build_scenario_snapshots.exe], while the vintage warehouse rebuilds go
    through [build_snapshots.exe] → {!Build_runner.build}. The [_v7mark]
    warehouses those rebuilds produced therefore still index rename-twin pairs
    (NLS/BFX, BB/BBRY, AABA/YHOO, …) — one instrument under two tickers with
    bar-for-bar identical prices — and a backtest that holds both legs
    double-counts the position.

    Three shapes are pinned here, all through the real builder against real CSV
    files:

    - the default (disabled) config is a passthrough: every symbol is indexed
      and no sidecar is written, so every pre-#2730 build stays byte-identical;
    - an armed config drops the losing leg from the manifest and names the pair
      in [rename_twin_report.txt];
    - an armed {e incremental} rerun over a warehouse built without the pass
      {b removes} the dropped leg from the merged index rather than carrying its
      pre-run entry forward (the interaction with the #2669 merge — without the
      exclusion the pass would report the drop while the manifest kept serving
      the duplicate). *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* The twin criterion needs a dense overlap of at least
   [Config.default.min_overlap_days] (100) shared dates, so the fixtures carry
   130 consecutive daily bars each. *)
let _bars_per_series = 130
let _late_end = Date.of_string "2021-12-31"

(* The dropped leg ends one week earlier, which is what makes the survivor
   deterministic: {!Twin_detector} keeps the latest-[data_end] leg. *)
let _early_end = Date.add_days _late_end (-7)
let _survivor = "TWINB"
let _dropped = "TWINA"
let _control = "OTHER"

let _report_path ~output_dir =
  Filename.concat output_dir "rename_twin_report.txt"

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_twins" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

(* Flat series, so the series-tail pass finds nothing to truncate and only the
   twin bookkeeping is under test. The two twin legs carry the SAME closes on
   their shared dates (that is the twin criterion); the control trades at a
   different level entirely, so it can never match either. *)
let _series ~last ~close =
  List.init _bars_per_series ~f:(fun i ->
      _bar (Date.add_days last (i - (_bars_per_series - 1))) close)

let _fixtures =
  [
    (_survivor, _series ~last:_late_end ~close:50.0);
    (_dropped, _series ~last:_early_end ~close:50.0);
    (_control, _series ~last:_late_end ~close:20.0);
  ]

let _all_symbols = List.map _fixtures ~f:fst

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _write_all_csvs ~data_dir =
  List.iter _fixtures ~f:(fun (symbol, bars) ->
      _write_csv ~data_dir ~symbol bars)

let _armed_config = { Twin_detector.Config.default with enabled = true }

let _build ~twin_config ~incremental ~data_dir ~output_dir =
  Build_runner.build ~twin_config ~symbols:_all_symbols ~csv_data_dir:data_dir
    ~output_dir ~benchmark_symbol:None ~start_date:None ~end_date:None
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default
    ~tail_exceptions:Series_tail.Exceptions.empty ()

let _manifest_symbols ~output_dir =
  match
    Snapshot_manifest.read ~path:(Filename.concat output_dir "manifest.sexp")
  with
  | Error e -> assert_failure ("manifest read: " ^ Status.show e)
  | Ok (m : Snapshot_manifest.t) ->
      List.map m.entries ~f:(fun (e : Snapshot_manifest.file_metadata) ->
          e.symbol)
      |> List.sort ~compare:String.compare

(* One build in a fresh temp dir. Returns the symbols the manifest indexes
   (sorted) paired with the sidecar's contents ([None] when it was not
   written). *)
let _build_once_in_dir ~twin_config dir =
  let data_dir = Filename.concat dir "csv" in
  let output_dir = Filename.concat dir "snap" in
  Core_unix.mkdir_p data_dir;
  _write_all_csvs ~data_dir;
  _build ~twin_config ~incremental:false ~data_dir ~output_dir;
  let report =
    let path = _report_path ~output_dir in
    if Stdlib.Sys.file_exists path then Some (In_channel.read_all path)
    else None
  in
  (_manifest_symbols ~output_dir, report)

let _build_once ~twin_config = _with_temp_dir (_build_once_in_dir ~twin_config)

(* A warehouse first built WITHOUT the pass (so all three legs are indexed),
   then rebuilt incrementally WITH it. Returns the symbols the merged manifest
   indexes, sorted. *)
let _dedupe_incrementally_in_dir dir =
  let data_dir = Filename.concat dir "csv" in
  let output_dir = Filename.concat dir "snap" in
  Core_unix.mkdir_p data_dir;
  _write_all_csvs ~data_dir;
  _build ~twin_config:Twin_detector.Config.default ~incremental:false ~data_dir
    ~output_dir;
  let before = _manifest_symbols ~output_dir in
  _build ~twin_config:_armed_config ~incremental:true ~data_dir ~output_dir;
  (before, _manifest_symbols ~output_dir)

(** Default-off passthrough: with {!Twin_detector.Config.default} the builder
    reads no series, drops nothing, and writes no sidecar — so every warehouse
    built before #2730 is reproducible bit-for-bit by an un-armed build. *)
let test_disabled_config_indexes_every_symbol _ =
  assert_that
    (_build_once ~twin_config:Twin_detector.Config.default)
    (pair
       (elements_are
          [ equal_to _control; equal_to _dropped; equal_to _survivor ])
       is_none)

(** Armed: the two bar-identical legs collapse to one. [TWINB] survives because
    its series ends a week later than [TWINA]'s, and the control — same shape,
    different price level — is untouched. *)
let test_armed_config_drops_the_losing_leg _ =
  assert_that
    (fst (_build_once ~twin_config:_armed_config))
    (elements_are [ equal_to _control; equal_to _survivor ])

(* The two lines {!Twin_detector.render} must produce for this fixture: the
   summary count, and the group naming the survivor and its dropped leg. *)
let _expected_sidecar_lines =
  [
    contains_substring "1 group(s), 1 symbol(s) dropped";
    contains_substring (Printf.sprintf "survivor %s <- [%s]" _survivor _dropped);
  ]

(** The drop is auditable: the sidecar names the survivor and the leg it
    replaced, so an operator who copies an output directory out of the container
    carries the evidence of what the build removed. *)
let test_armed_config_writes_the_pair_into_the_sidecar _ =
  assert_that
    (snd (_build_once ~twin_config:_armed_config))
    (is_some_and (all_of _expected_sidecar_lines))

(** The incremental interaction (#2669 x #2730). The pre-run manifest indexes
    all three symbols; the deduping rerun produces entries for two. Carrying the
    untouched third forward — which is what the #2669 merge does for every OTHER
    absent symbol — would silently reinstate the duplicate, so a twin-dropped
    symbol is excluded from the carry set and leaves the index. *)
let test_incremental_rerun_removes_the_dropped_leg_from_the_index _ =
  assert_that
    (_with_temp_dir _dedupe_incrementally_in_dir)
    (pair
       (elements_are
          [ equal_to _control; equal_to _dropped; equal_to _survivor ])
       (elements_are [ equal_to _control; equal_to _survivor ]))

let () =
  run_test_tt_main
    ("build_runner_twins"
    >::: [
           "the default disabled config indexes every symbol and writes no \
            sidecar" >:: test_disabled_config_indexes_every_symbol;
           "an armed config drops the losing twin leg from the manifest"
           >:: test_armed_config_drops_the_losing_leg;
           "an armed config names the pair in the sidecar report"
           >:: test_armed_config_writes_the_pair_into_the_sidecar;
           "an incremental rerun removes the dropped leg from the merged index"
           >:: test_incremental_rerun_removes_the_dropped_leg_from_the_index;
         ])
