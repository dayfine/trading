open Core
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

let default_progress_every = 50

(* Calendar-day span of extra history loaded BEFORE the window start to feed the
   resistance sketch's weekly prefix (resistance-v2 §D4). 3650 days ~ 520
   trading weeks (the deepest [Res_max_high_520w] horizon + [Res_bars_seen]
   cap), so a symbol that traded through the whole span is never a false virgin
   at the scenario start. CLIs surface this as [--sketch-deep-days]. *)
let default_sketch_deep_days = 3650

type progress = {
  symbols_total : int;
  symbols_done : int;
  last_completed : string;
  started_at : float;
  updated_at : float;
}
[@@deriving sexp]

let _csv_mtime ~data_dir ~symbol =
  let dir = Csv.Csv_storage.symbol_data_dir ~data_dir symbol in
  let csv_path = Fpath.add_seg dir "data.csv" |> Fpath.to_string in
  if Stdlib.Sys.file_exists csv_path then
    Some (Core_unix.stat csv_path).st_mtime
  else None

let _load_bars ~data_dir ~symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "create %s: %s" symbol (Status.show err)))
  | Ok storage -> Csv.Csv_storage.get storage ()

(* Window a symbol's loaded bars to the inclusive [start_date, end_date] range
   before the snapshot pipeline sees them. Mirrors [Csv_snapshot_builder]'s
   windowing so a snapshot-mode warehouse stays cache-friendly (see
   {!Bar_window} for the perf rationale + warmup caveat). When both bounds are
   [None] the bars pass through unchanged. *)
let _window_bars ~start_date ~end_date bars =
  Bar_window.filter ?start:start_date ?end_:end_date bars

let _load_windowed_bars ~data_dir ~start_date ~end_date ~symbol =
  match _load_bars ~data_dir ~symbol with
  | Error _ as err -> err
  | Ok bars -> Ok (_window_bars ~start_date ~end_date bars)

(* Deep-history slice [[start_date - sketch_deep_days, start_date)] that feeds
   ONLY the resistance sketch (resistance-v2 §D4). Empty when [start_date] is
   [None] (full-history build already carries all bars in the window). The
   inclusive [end_ = start - 1 day] keeps the slice strictly before the window,
   so it never overlaps [_window_bars ~start_date]. *)
let _deep_bars ~sketch_deep_days ~start_date bars =
  match start_date with
  | None -> []
  | Some start ->
      let deep_start = Date.add_days start (-sketch_deep_days) in
      let deep_end = Date.add_days start (-1) in
      Bar_window.filter ~start:deep_start ~end_:deep_end bars

(* Load a symbol once, split into (deep_bars, window_bars): rows are emitted for
   [window_bars] only, while [deep_bars] widen the sketch's weekly prefix. *)
let _load_split_bars ~data_dir ~start_date ~end_date ~sketch_deep_days ~symbol =
  match _load_bars ~data_dir ~symbol with
  | Error e -> Error e
  | Ok bars ->
      Ok
        ( _deep_bars ~sketch_deep_days ~start_date bars,
          _window_bars ~start_date ~end_date bars )

let _file_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".snap")

(* Sketch-v5 weekly side-table file, next to the symbol's [.snap]. *)
let _weekly_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".weekly")

let _existing_manifest ~output_dir =
  let path = Filename.concat output_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path with Ok m -> Some m | Error _ -> None

let _entry_is_current ~csv_mtime (e : Snapshot_manifest.file_metadata) =
  Float.( <= ) csv_mtime e.csv_mtime && Stdlib.Sys.file_exists e.path

let _should_skip ~existing ~symbol ~csv_mtime ~schema =
  match existing with
  | None -> false
  | Some (m : Snapshot_manifest.t) ->
      String.equal m.schema_hash schema.Snapshot_schema.schema_hash
      && Option.value_map
           (Snapshot_manifest.find m ~symbol)
           ~default:false
           ~f:(_entry_is_current ~csv_mtime)

let _file_metadata ~symbol ~path ~csv_mtime ~active_through =
  let bytes = In_channel.read_all path in
  {
    Snapshot_manifest.symbol;
    path;
    byte_size = String.length bytes;
    payload_md5 = Stdlib.Digest.to_hex (Stdlib.Digest.string bytes);
    csv_mtime;
    active_through;
  }

(* Last-bar [active_through] is the symbol's delisting marker. The CSV loader
   sets the same value on every row of a symbol's history, so reading the tail
   is equivalent to reading any row. *)
let _active_through_of_bars (bars : Types.Daily_price.t list) : Date.t option =
  List.last bars
  |> Option.bind ~f:(fun (b : Types.Daily_price.t) -> b.active_through)

let _write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows =
  (* Emit the v2 columnar mmap format ({!Snapshot_columnar}); it validates
     single-symbol + single-schema and sorts rows by date, exactly the
     preconditions a per-symbol [.snap] file already satisfies. The verifier
     ([Snapshot_verifier]) format-detects, so v2 round-trips on read-back. *)
  match Snapshot_columnar.write ~path rows with
  | Error err -> Error err
  | Ok () -> Ok (_file_metadata ~symbol ~path ~csv_mtime ~active_through)

(* Sketch-v5 (PR 1): behind [--emit-weekly-sidetable], write the sparse weekly
   side-table next to the [.snap] from the SAME weekly aggregation the sketch
   consumes. Best-effort — a side-table write failure is logged, not fatal, so
   it never aborts the [.snap] warehouse build. No-op when the flag is off, so
   the default warehouse output is byte-identical. *)
let _maybe_write_weekly ~emit_weekly_sidetable ~output_dir ~symbol ~deep_bars
    ~bars =
  if emit_weekly_sidetable then
    let path = _weekly_path ~output_dir ~symbol in
    let entries = Weekly_sidetable_builder.of_bars ~deep_bars ~bars in
    match Weekly_sidetable.write_file ~path entries with
    | Ok () -> ()
    | Error err ->
        Printf.eprintf "weekly side-table write failed for %s: %s\n%!" symbol
          (Status.show err)

let _build_one_symbol ~symbol ~bars ~deep_bars ~schema ~benchmark_bars
    ~output_dir ~csv_mtime ~emit_weekly_sidetable =
  let path = _file_path ~output_dir ~symbol in
  let active_through = _active_through_of_bars bars in
  match
    Pipeline.build_for_symbol ~symbol ~bars ~deep_bars ~schema ?benchmark_bars
      ()
  with
  | Error err -> Error err
  | Ok rows ->
      _maybe_write_weekly ~emit_weekly_sidetable ~output_dir ~symbol ~deep_bars
        ~bars;
      _write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows

let _maybe_reuse ~existing ~symbol =
  match existing with
  | None -> None
  | Some m -> Snapshot_manifest.find m ~symbol

let _checkpoint_manifest ~manifest_path ~schema entry =
  match
    Snapshot_manifest.update_for_symbol ~path:manifest_path ~schema entry
  with
  | Ok () -> ()
  | Error err ->
      Printf.eprintf "manifest checkpoint failed for %s: %s\n%!"
        entry.Snapshot_manifest.symbol (Status.show err)

let _build_or_log ~symbol ~bars ~deep_bars ~schema ~benchmark_bars ~output_dir
    ~csv_mtime ~manifest_path ~checkpoint ~emit_weekly_sidetable =
  match
    _build_one_symbol ~symbol ~bars ~deep_bars ~schema ~benchmark_bars
      ~output_dir ~csv_mtime ~emit_weekly_sidetable
  with
  | Error err ->
      Printf.eprintf "skip %s: build: %s\n%!" symbol (Status.show err);
      None
  | Ok entry ->
      if checkpoint then _checkpoint_manifest ~manifest_path ~schema entry;
      Some entry

let _try_build_and_checkpoint ~data_dir ~start_date ~end_date ~sketch_deep_days
    ~schema ~benchmark_bars ~output_dir ~manifest_path ~checkpoint ~csv_mtime
    ~emit_weekly_sidetable symbol =
  match
    _load_split_bars ~data_dir ~start_date ~end_date ~sketch_deep_days ~symbol
  with
  | Error err ->
      Printf.eprintf "skip %s: load: %s\n%!" symbol (Status.show err);
      None
  | Ok (deep_bars, bars) ->
      _build_or_log ~symbol ~bars ~deep_bars ~schema ~benchmark_bars ~output_dir
        ~csv_mtime ~manifest_path ~checkpoint ~emit_weekly_sidetable

let _process_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
    ~benchmark_bars ~output_dir ~existing ~manifest_path ~checkpoint
    ~emit_weekly_sidetable symbol =
  match _csv_mtime ~data_dir ~symbol with
  | None ->
      Printf.eprintf "skip %s: no CSV\n%!" symbol;
      None
  | Some csv_mtime ->
      if _should_skip ~existing ~symbol ~csv_mtime ~schema then
        _maybe_reuse ~existing ~symbol
      else
        _try_build_and_checkpoint ~data_dir ~start_date ~end_date
          ~sketch_deep_days ~schema ~benchmark_bars ~output_dir ~manifest_path
          ~checkpoint ~csv_mtime ~emit_weekly_sidetable symbol

let _load_benchmark_bars ~data_dir ~start_date ~end_date sym =
  match _load_windowed_bars ~data_dir ~start_date ~end_date ~symbol:sym with
  | Ok bars -> Some bars
  | Error err ->
      Printf.eprintf "warning: benchmark %s load failed: %s\n%!" sym
        (Status.show err);
      None

let _benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol =
  Option.bind benchmark_symbol
    ~f:(_load_benchmark_bars ~data_dir ~start_date ~end_date)

let _verify_or_warn ~manifest_path =
  match Snapshot_verifier.verify_directory ~manifest_path with
  | Error err ->
      Printf.eprintf "verify failed: %s\n%!" (Status.show err);
      exit 2
  | Ok r ->
      Printf.printf "verify: %d/%d files OK (failed=%d)\n%!" r.passed r.total
        r.failed;
      if r.failed > 0 then exit 3

let _ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then Stdlib.Sys.mkdir path 0o755

let _write_progress ~output_dir ~progress =
  let path = Filename.concat output_dir "progress.sexp" in
  let tmp = path ^ ".tmp" in
  try
    let data = Sexp.to_string_hum (sexp_of_progress progress) in
    Out_channel.write_all tmp ~data;
    Stdlib.Sys.rename tmp path
  with Sys_error msg | Failure msg -> (
    Printf.eprintf "progress write failed: %s\n%!" msg;
    try Stdlib.Sys.remove tmp with _ -> ())

let _make_progress ~symbols_total ~symbols_done ~last_completed ~started_at =
  {
    symbols_total;
    symbols_done;
    last_completed;
    started_at;
    updated_at = Core_unix.time ();
  }

let _maybe_emit_progress ~output_dir ~progress_every ~symbols_total
    ~symbols_done ~last_completed ~started_at =
  if symbols_done > 0 && symbols_done mod progress_every = 0 then
    _write_progress ~output_dir
      ~progress:
        (_make_progress ~symbols_total ~symbols_done ~last_completed ~started_at)

let _last_symbol entries =
  match List.last entries with
  | Some e -> e.Snapshot_manifest.symbol
  | None -> ""

let _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at =
  let symbols_done = List.length entries in
  let last_completed = _last_symbol entries in
  _write_progress ~output_dir
    ~progress:
      (_make_progress ~symbols_total ~symbols_done ~last_completed ~started_at)

(* When [weekly_sidetable_hash] is [Some h] (the [--emit-weekly-sidetable] run),
   stamp it on the final manifest so a reader can gate the [.weekly] files. When
   [None] the manifest is byte-identical to a pre-sketch-v5 build. *)
let _write_final_manifest ~manifest_path ~schema ~entries ~weekly_sidetable_hash
    ~elapsed =
  let manifest = Snapshot_manifest.create ~schema ~entries in
  let manifest =
    match weekly_sidetable_hash with
    | Some h -> Snapshot_manifest.set_weekly_sidetable_format_hash manifest h
    | None -> manifest
  in
  match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () ->
      Printf.printf "wrote %d entries to %s in %.2fs\n%!" (List.length entries)
        manifest_path
        (Time_ns.Span.to_sec elapsed)
  | Error err ->
      Printf.eprintf "manifest write failed: %s\n%!" (Status.show err);
      exit 1

let _fold_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
    ~benchmark_bars ~output_dir ~existing ~manifest_path ~progress_every
    ~symbols_total ~started_at ~emit_weekly_sidetable i acc symbol =
  match
    _process_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
      ~benchmark_bars ~output_dir ~existing ~manifest_path ~checkpoint:true
      ~emit_weekly_sidetable symbol
  with
  | None -> acc
  | Some entry ->
      let symbols_done = i + 1 in
      _maybe_emit_progress ~output_dir ~progress_every ~symbols_total
        ~symbols_done ~last_completed:symbol ~started_at;
      acc @ [ entry ]

let build ~symbols ~csv_data_dir ~output_dir ~benchmark_symbol ~start_date
    ~end_date ~sketch_deep_days ~incremental ~progress_every
    ?(emit_weekly_sidetable = false) () =
  _ensure_dir output_dir;
  let schema = Snapshot_schema.default in
  let symbols_total = List.length symbols in
  let data_dir = Fpath.v csv_data_dir in
  let benchmark_bars =
    _benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol
  in
  let existing = if incremental then _existing_manifest ~output_dir else None in
  let manifest_path = Filename.concat output_dir "manifest.sexp" in
  let started_at = Core_unix.time () in
  let t0 = Time_ns.now () in
  let entries =
    List.foldi symbols ~init:[]
      ~f:
        (_fold_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
           ~benchmark_bars ~output_dir ~existing ~manifest_path ~progress_every
           ~symbols_total ~started_at ~emit_weekly_sidetable)
  in
  let elapsed = Time_ns.diff (Time_ns.now ()) t0 in
  let weekly_sidetable_hash =
    if emit_weekly_sidetable then Some Weekly_sidetable.format_hash else None
  in
  _write_final_manifest ~manifest_path ~schema ~entries ~weekly_sidetable_hash
    ~elapsed;
  _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at;
  _verify_or_warn ~manifest_path
