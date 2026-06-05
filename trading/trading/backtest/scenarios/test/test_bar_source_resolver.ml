(** Unit test for {!Scenario_lib.Bar_source_resolver.resolve} — the
    [scenario_runner.exe] helper that maps the [--snapshot-dir] CLI value into a
    [Backtest.Bar_data_source.t option].

    Two contracts pinned here:

    - [resolve None] -> [None]. The runner then omits [?bar_data_source] and
      [Backtest.Runner.run_backtest] defaults to CSV mode — the pre-snapshot
      behaviour, unchanged.
    - [resolve (Some dir)] -> [Some (Snapshot { snapshot_dir = dir; manifest })]
      where [manifest] is the one written at [<dir>/manifest.sexp]. The snapshot
      dir + a written manifest are built with the same Phase-B pipeline trick
      [test_snapshot_mode_parity.ml] uses, so this exercises the real
      [Snapshot_manifest.read] path the resolver depends on rather than a stub.

    The missing/corrupt-manifest path calls [Stdlib.exit 1], so it is not
    asserted here (an [exit] inside an OUnit child would abort the runner);
    [backtest_runner]'s equivalent helper has the same exit semantics and is the
    canonical reference. *)

open OUnit2
open Core
open Matchers
module Bar_data_source = Backtest.Bar_data_source
module Bar_source_resolver = Scenario_lib.Bar_source_resolver
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Pipeline = Snapshot_pipeline.Pipeline

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* A handful of deterministic bars — just enough for the Phase-B pipeline to
   produce a valid [.snap] file + manifest entry. *)
let _bars ~n =
  let start = _ymd 2020 1 2 in
  List.init n ~f:(fun i ->
      let close = 100.0 +. (Float.of_int i *. 0.5) in
      {
        Types.Daily_price.date = Date.add_days start i;
        open_price = close -. 0.10;
        high_price = close +. 0.20;
        low_price = close -. 0.30;
        close_price = close;
        volume = 1_000_000 + (i * 1000);
        adjusted_close = close;
        active_through = None;
      })

(* Build a minimal snapshot warehouse at [snapshot_dir]: one [.snap] file per
   symbol via the Phase-B pipeline, plus the directory manifest written to
   [<snapshot_dir>/manifest.sexp] — the exact path the resolver reads. *)
let _write_snapshot_warehouse ~snapshot_dir symbols =
  let schema = Snapshot_schema.default in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let bars = _bars ~n:40 in
        let rows =
          match Pipeline.build_for_symbol ~symbol ~bars ~schema () with
          | Ok r -> r
          | Error err ->
              assert_failure ("Pipeline.build_for_symbol: " ^ Status.show err)
        in
        let path = Filename.concat snapshot_dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            assert_failure ("Snapshot_format.write: " ^ Status.show err));
        let stat = Core_unix.stat path in
        ({
           symbol;
           path;
           byte_size = Int64.to_int_exn stat.st_size;
           payload_md5 = "ignored";
           csv_mtime = stat.st_mtime;
           active_through = None;
         }
          : Snapshot_manifest.file_metadata))
  in
  let manifest = Snapshot_manifest.create ~schema ~entries in
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> assert_failure ("Snapshot_manifest.write: " ^ Status.show err));
  manifest

let test_resolve_none_is_csv_default _ =
  (* No [--snapshot-dir]: resolver yields [None] so the runner stays in CSV
     mode, bit-identical to the pre-snapshot behaviour. *)
  assert_that (Bar_source_resolver.resolve None) is_none

let test_resolve_some_builds_snapshot_selector _ =
  let snapshot_dir =
    Filename_unix.temp_dir ~in_dir:"/tmp" "snapdir_resolve_" ""
  in
  let symbols = [ "AAA"; "BBB" ] in
  let written = _write_snapshot_warehouse ~snapshot_dir symbols in
  (* [resolve (Some dir)] reads [<dir>/manifest.sexp] and constructs a
     [Snapshot] selector carrying the same dir + the on-disk manifest. We pin
     the dir and the manifest's [schema_hash] + entry count (the manifest [t]
     has no derived [equal], so we assert its observable fields). *)
  assert_that
    (Bar_source_resolver.resolve (Some snapshot_dir))
    (is_some_and
       (matching ~msg:"Expected Snapshot selector"
          (function
            | Bar_data_source.Snapshot { snapshot_dir = d; manifest } ->
                Some (d, manifest)
            | Bar_data_source.Csv -> None)
          (all_of
             [
               field (fun (d, _) -> d) (equal_to snapshot_dir);
               field
                 (fun (_, m) -> m.Snapshot_manifest.schema_hash)
                 (equal_to written.Snapshot_manifest.schema_hash);
               field
                 (fun (_, m) -> List.length m.Snapshot_manifest.entries)
                 (equal_to (List.length symbols));
             ])))

let suite =
  "bar_source_resolver"
  >::: [
         "resolve None -> CSV default (None)"
         >:: test_resolve_none_is_csv_default;
         "resolve (Some dir) -> Snapshot selector"
         >:: test_resolve_some_builds_snapshot_selector;
       ]

let () = run_test_tt_main suite
