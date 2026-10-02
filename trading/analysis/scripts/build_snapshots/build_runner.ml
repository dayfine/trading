open Core
module Carry = Manifest_carry
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Series_tail = Snapshot_pipeline.Series_tail
module Series_level = Snapshot_pipeline.Series_level
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

let default_progress_every = 50

(* Calendar-day span of extra history loaded BEFORE the window start to feed the
   resistance sketch's weekly prefix (resistance-v2 §D4). 3650 days ~ 520
   trading weeks (the deepest [Res_max_high_520w] horizon + [Res_bars_seen]
   cap), so a symbol that traded through the whole span is never a false virgin
   at the scenario start. CLIs surface this as [--sketch-deep-days]. *)
let default_sketch_deep_days = 3650
let default_survivor_tolerance_days = Build_cli.default_survivor_tolerance_days
let default_exceptions_path = Build_cli.default_exceptions_path
let tail_report_name = "terminal_runs.csv"
let survivor_tolerance_param = Build_cli.survivor_tolerance_param
let tail_params = Build_cli.tail_params
let load_tail_exceptions = Build_cli.load_tail_exceptions
let load_splice_exceptions = Build_cli.load_splice_exceptions
let tail_exceptions_or_exit = Build_cli.tail_exceptions_or_exit
let splice_exceptions_or_exit = Build_cli.splice_exceptions_or_exit

type progress = {
  symbols_total : int;
  symbols_done : int;
  last_completed : string;
  started_at : float;
  updated_at : float;
}
[@@deriving sexp]

let _existing_manifest ~output_dir =
  let path = Filename.concat output_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path with Ok m -> Some m | Error _ -> None

(* Series end IS the delisting evidence (#2672): a symbol whose last stored bar
   falls more than [survivor_tolerance_days] behind the universe's own last bar
   stopped trading, so stamp that date. One still printing at the end keeps
   [None] ("still trading / unknown"). An explicit marker on the bars wins.

   The reference is the DATA's end, never the operator's [--end-date] (#2693):
   the 2026-09-06 rebuild passed [-end-date 2026-09-06] against a CSV store
   whose last bar was 2026-08-17, and every one of the 2,999 symbols — all 778
   survivors included — came back marked. *)
let _derive_active_through ~universe_end ~survivor_tolerance_days ~bar_marker
    ~last_bar =
  match bar_marker with
  | Some _ as explicit -> explicit
  | None -> (
      match (universe_end, last_bar) with
      | Some end_, Some last when Date.diff end_ last > survivor_tolerance_days
        ->
          Some last
      | _ -> None)

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

(* Sketch-v5 PR 4: side-tables are always emitted, so the final manifest always
   stamps the side-table format hash — a reader gates the [.weekly] files on it
   ({!Weekly_sidetable_reader.load_gated}). *)
let _write_final_manifest ~manifest_path ~schema ~entries ~elapsed =
  let manifest = Snapshot_manifest.create ~schema ~entries in
  let manifest =
    Snapshot_manifest.set_weekly_sidetable_format_hash manifest
      Weekly_sidetable.format_hash
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
    ~symbols_total ~started_at ~hygiene i acc symbol =
  match
    Symbol_builder.process_symbol ~data_dir ~start_date ~end_date
      ~sketch_deep_days ~schema ~benchmark_bars ~output_dir ~existing
      ~manifest_path ~checkpoint:true ~hygiene symbol
  with
  | None -> acc
  | Some built ->
      let symbols_done = i + 1 in
      _maybe_emit_progress ~output_dir ~progress_every ~symbols_total
        ~symbols_done ~last_completed:symbol ~started_at;
      acc @ [ built ]

(* The universe's end of data: the latest bar ANY symbol in this build printed.
   Derived from the bars, never from [--end-date] (#2693) — an [--end-date]
   past the store's own end silently marks every survivor delisted. Symbols
   whose series stops more than the tolerance before it are the delisted ones. *)
let _universe_end builts =
  List.filter_map builts ~f:(fun (b : Symbol_builder.built) -> b.last_bar)
  |> List.max_elt ~compare:Date.compare

(* The universe's end is only resolvable once every symbol is read, so the
   per-symbol [active_through] is filled in here rather than at checkpoint
   time. Reused (incremental-skip) entries read no bars, so they keep the value
   their own build derived. *)
let _entry_with_derived_marker ~universe_end ~survivor_tolerance_days
    (b : Symbol_builder.built) =
  match b.last_bar with
  | None -> b.entry
  | Some _ ->
      let active_through =
        _derive_active_through ~universe_end ~survivor_tolerance_days
          ~bar_marker:b.entry.active_through ~last_bar:b.last_bar
      in
      { b.entry with active_through }

(* Survivor count, logged so an operator can see at a glance whether the
   vintage's marker split looks sane (#2693: the defect it catches showed up as
   "2,999 of 2,999 marked" on a store with 778 live names).

   Called on the FINAL written set — this run's entries plus any carried
   forward (#2669) — not on the run's own symbols, so on a top-up the split
   still describes the whole warehouse index the operator is signing off. That
   is deliberately unlike [progress.sexp] and the tail report, which stay
   run-scoped because they count work this run actually did. *)
let _log_marker_split entries =
  let marked =
    List.count entries ~f:(fun (e : Snapshot_manifest.file_metadata) ->
        Option.is_some e.active_through)
  in
  Printf.printf "active_through: %d marked, %d survivors (of %d symbols)\n%!"
    marked
    (List.length entries - marked)
    (List.length entries)

let _finalize_entries ~survivor_tolerance_days builts =
  let universe_end = _universe_end builts in
  let entries =
    List.map builts
      ~f:(_entry_with_derived_marker ~universe_end ~survivor_tolerance_days)
  in
  entries

(* Review sidecar (#2672): every terminal run below the ratio, whatever the
   gates decided, so a human reads the vintage's classes once. Written even when
   empty — a header-only file is the positive evidence that the scan ran and
   found nothing. *)
let _write_tail_report ~output_dir builts =
  let findings =
    List.concat_map builts ~f:(fun (b : Symbol_builder.built) -> b.findings)
  in
  let path = Filename.concat output_dir tail_report_name in
  (try Out_channel.write_all path ~data:(Series_tail.to_csv findings)
   with Sys_error msg ->
     Printf.eprintf "%s write failed: %s\n%!" tail_report_name msg);
  Printf.printf "%s\n%!" (Series_tail.summary findings)

(* Sibling review sidecar, written by {!Level_pass} only when the pass is armed
   (#2732 follow-up): the tail report is unconditional because its pass always
   runs, while this one is default-off, so an un-armed build leaves no file. *)
let _write_level_report ~level_config ~output_dir builts =
  Level_pass.write_report level_config ~output_dir
    (List.filter_map builts ~f:(fun (b : Symbol_builder.built) -> b.level))

let build ?(survivor_tolerance_days = default_survivor_tolerance_days)
    ?(splice_cuts = Map.empty (module String))
    ?(twin_config = Twin_detector.Config.default)
    ?(level_config = Series_level.Config.default) ~symbols ~csv_data_dir
    ~output_dir ~benchmark_symbol ~start_date ~end_date ~sketch_deep_days
    ~incremental ~progress_every ~tail_config ~tail_exceptions () =
  _ensure_dir output_dir;
  let schema = Snapshot_schema.default in
  let data_dir = Fpath.v csv_data_dir in
  let symbols, twin_dropped =
    Twin_pass.run twin_config ~data_dir ~start_date ~end_date ~output_dir
      symbols
  in
  let excluded = Set.of_list (module String) twin_dropped in
  let symbols_total = List.length symbols in
  let benchmark_bars =
    Symbol_builder.benchmark_bars_opt ~data_dir ~start_date ~end_date
      ~benchmark_symbol
  in
  let existing = if incremental then _existing_manifest ~output_dir else None in
  let manifest_path = Filename.concat output_dir "manifest.sexp" in
  let hygiene =
    Symbol_builder.make_hygiene ~tail_config ~tail_exceptions ~level_config
      ~splice_cuts
  in
  let started_at = Core_unix.time () in
  let t0 = Time_ns.now () in
  let builts =
    List.foldi symbols ~init:[]
      ~f:
        (_fold_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
           ~benchmark_bars ~output_dir ~existing ~manifest_path ~progress_every
           ~symbols_total ~started_at ~hygiene)
  in
  let entries = _finalize_entries ~survivor_tolerance_days builts in
  let carried = Carry.carried_entries ~existing ~schema ~excluded entries in
  Carry.log_carry_forward carried;
  let final_entries = carried @ entries in
  _log_marker_split final_entries;
  let elapsed = Time_ns.diff (Time_ns.now ()) t0 in
  (* Only the MANIFEST and its marker-split log get the merged set.
     [progress.sexp] and the tail report stay scoped to this run's own symbols —
     a carried entry did no work in this run, so counting it would report
     [symbols_done > symbols_total] on a top-up. *)
  _write_final_manifest ~manifest_path ~schema ~entries:final_entries ~elapsed;
  _write_tail_report ~output_dir builts;
  _write_level_report ~level_config ~output_dir builts;
  _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at;
  _verify_or_warn ~manifest_path
