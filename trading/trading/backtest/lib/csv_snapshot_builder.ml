(** In-process snapshot directory builder — see [csv_snapshot_builder.mli]. *)

open Core
open Csv
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Pipeline = Snapshot_pipeline.Pipeline

(* Read one symbol's CSV; tolerate NotFound / missing CSV by returning an
   empty bar list (mirrors the legacy Ohlcv_panels.load_from_csv_calendar
   path's "row stays NaN" semantics). Other errors fail the runner. *)
let _read_one_symbol ~data_dir ~start_date ~end_date symbol =
  let storage =
    match Csv_storage.create ~data_dir symbol with
    | Ok s -> s
    | Error err ->
        failwithf "Csv_snapshot_builder: Csv_storage.create %s: %s" symbol
          (Status.show err) ()
  in
  match Csv_storage.get storage ~start_date ~end_date () with
  | Ok bars -> (symbol, bars)
  | Error err when Status.equal_code err.code Status.NotFound -> (symbol, [])
  | Error err ->
      failwithf "Csv_snapshot_builder: Csv_storage.get %s: %s" symbol
        (Status.show err) ()

let _build_rows_or_fail ~symbol ~bars =
  match
    Pipeline.build_for_symbol ~symbol ~bars ~schema:Snapshot_schema.default ()
  with
  | Ok rows -> rows
  | Error err ->
      failwithf "Csv_snapshot_builder: Pipeline.build_for_symbol %s: %s" symbol
        err.Status.message ()

let _write_symbol_snap ~dir ~symbol rows =
  let path = Filename.concat dir (symbol ^ ".snap") in
  match Snapshot_format.write ~path rows with
  | Ok () -> path
  | Error err ->
      failwithf "Csv_snapshot_builder: Snapshot_format.write %s: %s" symbol
        err.Status.message ()

(* Per-symbol manifest entry. The [byte_size] / [payload_md5] / [csv_mtime]
   fields are observational only — the runtime [Daily_panels] reader does
   not validate them at create time. Sentinel values keep the constructor
   stdlib-only (no [Core_unix.stat]). [active_through] is the symbol's
   delisting marker, taken from the last input bar; surfaces through
   [Daily_panels.active_through_for] to the screener PI filter. *)
let _file_metadata_of ~symbol ~path ~active_through :
    Snapshot_manifest.file_metadata =
  {
    symbol;
    path;
    byte_size = 0;
    payload_md5 = "ignored";
    csv_mtime = 0.0;
    active_through;
  }

let _active_through_of_bars (bars : Types.Daily_price.t list) : Date.t option =
  List.last bars
  |> Option.bind ~f:(fun (b : Types.Daily_price.t) -> b.active_through)

let _write_manifest_or_fail ~dir manifest =
  let path = Filename.concat dir "manifest.sexp" in
  match Snapshot_manifest.write ~path manifest with
  | Ok () -> ()
  | Error err ->
      failwithf "Csv_snapshot_builder: Snapshot_manifest.write: %s"
        err.Status.message ()

(* Stream per-symbol: read CSV → build rows → write [.snap] → drop bars before
   moving to the next symbol. Avoids retaining the full
   [(symbol, bars) list] across the universe — at 15y SP500 scale the
   intermediate list-of-lists costs ~195 MB RSS (15y memory cliff Fix C). *)
let _read_build_write_one ~data_dir ~start_date ~end_date ~dir symbol =
  let symbol, bars = _read_one_symbol ~data_dir ~start_date ~end_date symbol in
  let active_through = _active_through_of_bars bars in
  let rows = _build_rows_or_fail ~symbol ~bars in
  let path = _write_symbol_snap ~dir ~symbol rows in
  _file_metadata_of ~symbol ~path ~active_through

let build ~data_dir ~universe ~start_date ~end_date =
  let dir = Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_" "" in
  let entries =
    List.map universe
      ~f:(_read_build_write_one ~data_dir ~start_date ~end_date ~dir)
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  _write_manifest_or_fail ~dir manifest;
  (dir, manifest)
