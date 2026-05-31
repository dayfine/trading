(** In-process snapshot directory builder — see [csv_snapshot_builder.mli]. *)

open Core
open Csv
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Pipeline = Snapshot_pipeline.Pipeline

(* ===== Cleanup ledger and signal/at_exit handlers ============================

   Each call to [build] allocates a /tmp/panel_runner_csv_snapshot_<hash>/ dir
   (~26-30 MB at 530 symbols). Long-running walk-forward rigs accumulate one
   per fold. The success path of the caller cleans these via [cleanup]; the
   leak we guard against here is the {b abnormal} exit path (issue #1393):

   - Uncaught exception: [Stdlib.at_exit] still fires.
   - Graceful SIGTERM / SIGINT / SIGHUP: we install handlers that re-raise as
     [Stdlib.exit 130], which lets at_exit run.
   - SIGKILL: uncoverable by design; [startup_orphan_sweep] is the
     belt-and-suspenders mitigation.

   The ledger is a plain hashtbl keyed by dir path. The codebase is
   single-domain; if Domain.spawn shows up later we can add a Mutex. *)

let _ledger : (string, unit) Hashtbl.t = Hashtbl.create (module String) ~size:64

(* Recursive rm-rf via Sys.command. The path comes from Filename.temp_dir so
   we trust its shape, but quote anyway for safety. Errors are swallowed —
   on a partial-cleanup the OS reaper / next startup_orphan_sweep handles it. *)
let _rm_rf path =
  if Stdlib.Sys.file_exists path then
    let cmd = Printf.sprintf "rm -rf %s" (Stdlib.Filename.quote path) in
    ignore (Stdlib.Sys.command cmd : int)

let _at_exit_cleanup () =
  Hashtbl.iter_keys _ledger ~f:_rm_rf;
  Hashtbl.clear _ledger

(* Signal handler that re-raises as exit 130. Stdlib.exit invokes the at_exit
   chain in registration order, so our cleanup runs before the process dies.
   Code 130 is the conventional "terminated by SIGINT" exit code (128 + 2);
   we use it uniformly for SIGTERM / SIGINT / SIGHUP since the caller cares
   only that we exited cleanly. *)
let _on_signal _ = Stdlib.exit 130
let _handlers_installed = ref false

let _install_handlers_once () =
  if not !_handlers_installed then (
    _handlers_installed := true;
    Stdlib.at_exit _at_exit_cleanup;
    let h = Stdlib.Sys.Signal_handle _on_signal in
    (* Sys.set_signal raises Invalid_argument on platforms that don't know
       the signal (e.g. SIGHUP on Windows). Swallow — we are best-effort. *)
    let safe_set sig_ =
      try Stdlib.Sys.set_signal sig_ h with Invalid_argument _ -> ()
    in
    safe_set Stdlib.Sys.sigterm;
    safe_set Stdlib.Sys.sigint;
    safe_set Stdlib.Sys.sighup)

let register_for_cleanup dir =
  _install_handlers_once ();
  Hashtbl.set _ledger ~key:dir ~data:()

let cleanup dir =
  Hashtbl.remove _ledger dir;
  _rm_rf dir

let registered_dirs () = Hashtbl.keys _ledger

(* Belt-and-suspenders sweep: SIGKILL / power-loss can still leave orphans.
   Sweep /tmp/panel_runner_csv_snapshot_* with mtime older than max_age_hours
   and remove. Errors per-dir are swallowed so one bad entry doesn't abort
   the sweep. *)
let _default_max_age_hours = 24.0

(* Read mtime for [full] if it is an existing directory; None otherwise.
   Swallows stat / is_directory errors uniformly (permission, race with
   another sweeper). *)
let _dir_mtime full =
  match Stdlib.Sys.is_directory full with
  | false -> None
  | exception _ -> None
  | true -> (
      match Core_unix.stat full with
      | exception _ -> None
      | stat -> Some stat.st_mtime)

let _sweep_one ~now ~max_age_seconds tmp_dir entry =
  if not (String.is_prefix entry ~prefix:"panel_runner_csv_snapshot_") then 0
  else
    let full = Filename.concat tmp_dir entry in
    match _dir_mtime full with
    | None -> 0
    | Some mtime ->
        let age = now -. mtime in
        if Float.( <= ) age max_age_seconds then 0
        else (
          _rm_rf full;
          1)

let startup_orphan_sweep ?(max_age_hours = _default_max_age_hours) () =
  let tmp_dir = Stdlib.Filename.get_temp_dir_name () in
  match Stdlib.Sys.readdir tmp_dir with
  | exception _ -> 0
  | entries ->
      let now = Core_unix.gettimeofday () in
      let max_age_seconds = max_age_hours *. 3600.0 in
      Array.fold entries ~init:0 ~f:(fun acc entry ->
          acc + _sweep_one ~now ~max_age_seconds tmp_dir entry)

(* ===== Per-symbol CSV → .snap pipeline (unchanged from F.3.a-3) ============= *)

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
  (* Register before doing any work — if [List.map] below raises, the at_exit
     hook still cleans the partially-populated dir. Closes #1393. *)
  register_for_cleanup dir;
  let entries =
    List.map universe
      ~f:(_read_build_write_one ~data_dir ~start_date ~end_date ~dir)
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  _write_manifest_or_fail ~dir manifest;
  (dir, manifest)
