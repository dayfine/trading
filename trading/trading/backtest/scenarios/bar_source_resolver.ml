open Core

(* Mirrors [backtest_runner._resolve_bar_data_source] (PR #788). Kept
   byte-faithful to that helper: same manifest path convention
   ([<dir>/manifest.sexp]), same [Snapshot_manifest.read] call, same
   diagnostic + [exit 1] on a missing/corrupt manifest. The manifest is read
   exactly once here so the resulting selector is reused across every cell of a
   [--dir] run. *)
let resolve snapshot_dir =
  Option.map snapshot_dir ~f:(fun dir ->
      let manifest_path = Filename.concat dir "manifest.sexp" in
      match Snapshot_pipeline.Snapshot_manifest.read ~path:manifest_path with
      | Ok manifest ->
          eprintf
            "[snapshot-mode] loaded manifest at %s (schema_hash=%s, %d entries)\n\
             %!"
            manifest_path manifest.schema_hash
            (List.length manifest.entries);
          Backtest.Bar_data_source.Snapshot { snapshot_dir = dir; manifest }
      | Error err ->
          eprintf "Error: failed to read snapshot manifest at %s: %s\n"
            manifest_path (Status.show err);
          Stdlib.exit 1)
