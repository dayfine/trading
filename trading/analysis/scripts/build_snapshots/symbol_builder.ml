(* Per-symbol stage of the snapshot build: load a symbol's CSV bars, apply the
   series-hygiene passes (splice cut, tail rule, store-level classify), run the
   snapshot pipeline, and write the [.snap] + [.weekly] files. Extracted from
   [build_runner.ml]; see {!Build_runner} for the orchestration around it. *)

open Core
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Series_tail = Snapshot_pipeline.Series_tail
module Series_splice = Snapshot_pipeline.Series_splice
module Series_level = Snapshot_pipeline.Series_level
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

(* One built symbol: its manifest entry, the date of its last stored bar (None
   when the entry was reused from a previous incremental run, so no bars were
   read), the tail findings to report, and the store-level review row when the
   level pass is armed and this symbol's stored series failed its rule. *)
type built = {
  entry : Snapshot_manifest.file_metadata;
  last_bar : Core.Date.t option;
  findings : Series_tail.finding list;
  level : Series_level.finding option;
}

(* Series-hygiene knobs, bundled so the per-symbol call chain threads one
   parameter rather than three. *)
type hygiene = {
  config : Series_tail.Config.t;
  exceptions : Series_tail.Exceptions.t;
  level_config : Series_level.Config.t;
      (* Store-level sanity ({!Series_level}), REPORT-ONLY: it classifies the
         series this builder already decided to store and has no action type, so
         an armed pass changes no [.snap] and no manifest entry. Defaults to
         [enabled = false], under which [classify] reads no bar. *)
  splice_cuts : Core.Date.t Map.M(String).t;
      (* Symbols to cut at build time, and the date to keep bars from (#2672
         class ii). Decided by the scanner that sees every symbol's full
         history; applied here to the build-window bars AND to the deep-history
         prefix that feeds the weekly side-table. Symbols the scanner DROPPED
         never reach the runner — they are removed from [symbols]. *)
}

(* Constructor rather than an inline record literal at the call site, so [build]
   stays a readable sequence of stages as the bundle grows a field. *)
let make_hygiene ~tail_config ~tail_exceptions ~level_config ~splice_cuts =
  {
    config = tail_config;
    exceptions = tail_exceptions;
    level_config;
    splice_cuts;
  }

let _file_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".snap")

(* Sketch-v5 weekly side-table file, next to the symbol's [.snap]. *)
let _weekly_path ~output_dir ~symbol =
  Filename.concat output_dir (symbol ^ ".weekly")

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

(* Last-bar [active_through] is the symbol's delisting marker when the source
   carries one. The CSV loader sets the same value on every row of a symbol's
   history, so reading the tail is equivalent to reading any row. In practice no
   vendor path populates it (the EODHD parser leaves it [None]) — see
   {!_derive_active_through} for the series-end derivation that does. *)
let _active_through_of_bars (bars : Types.Daily_price.t list) : Date.t option =
  List.last bars
  |> Option.bind ~f:(fun (b : Types.Daily_price.t) -> b.active_through)

let _last_bar_date (bars : Types.Daily_price.t list) : Date.t option =
  List.last bars |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.date)

let _write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows =
  (* Emit the v2 columnar mmap format ({!Snapshot_columnar}); it validates
     single-symbol + single-schema and sorts rows by date, exactly the
     preconditions a per-symbol [.snap] file already satisfies. The verifier
     ([Snapshot_verifier]) format-detects, so v2 round-trips on read-back. *)
  match Snapshot_columnar.write ~path rows with
  | Error err -> Error err
  | Ok () -> Ok (_file_metadata ~symbol ~path ~csv_mtime ~active_through)

(* Sketch-v5 PR 4: ALWAYS write the sparse [SYMBOL.weekly] side-table next to
   the [.snap], built from the SAME weekly aggregation the retired dense sketch
   used to consume. It is now the ONLY overhead-supply representation the reader
   has (the dense [Res_*] columns were dropped from the canonical schema), so
   emission is unconditional rather than behind the old [--emit-weekly-sidetable]
   flag. Best-effort — a side-table write failure is logged, not fatal, so it
   never aborts the [.snap] warehouse build. *)
let _write_weekly ~output_dir ~symbol ~deep_bars ~bars =
  let path = _weekly_path ~output_dir ~symbol in
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars ~bars in
  match Weekly_sidetable.write_file ~path entries with
  | Ok () -> ()
  | Error err ->
      Printf.eprintf "weekly side-table write failed for %s: %s\n%!" symbol
        (Status.show err)

(* Phantom-bar hygiene, applied to the windowed bars BEFORE the pipeline sees
   them: the [.snap] (and its weekly side-table) then contain only real prints.
   [deep_bars] are strictly before the window and feed only the side-table's
   depth, so a TRUNCATION leaves them alone — it edits the series' end, and a
   bar before the window cannot be part of it. (The splice cut below edits the
   series' START, so it does reach them.) *)
let _clean_tail ~(hygiene : hygiene) ~symbol bars =
  Series_tail.apply hygiene.config ~exceptions:hygiene.exceptions ~symbol bars

(* Store-level sanity reads the series the builder is ABOUT TO STORE — after the
   splice cut and after the tail rule — because the question it asks is whether
   what lands in the [.snap] is a plausible price series at all. Its residual
   class is defined against exactly those bars: a mis-scale seam falling OUTSIDE
   the build window presents, inside the window, as a uniformly mis-scaled
   stored series with no discontinuity for either shape rule to key on. Running
   it on the raw pre-cut bars would instead re-find defects those rules already
   removed. Report-only: the row is carried out to the sidecar, never acted
   on. *)
let _classify_level ~(hygiene : hygiene) ~symbol bars =
  Series_level.classify hygiene.level_config ~symbol bars

(* The #2732 prefix cut is the one tail edit that moves the series' START, so
   unlike a truncation it DOES reach the deep prefix: the mis-scaled segment is
   by construction older than the cut date, so every deep bar predates it and
   leaving them would put AGR's $73,566 weekly bars into the side-table — the
   only overhead-supply representation the reader has. Same [keep_from] the
   splice cut uses, so the two cannot drift apart. *)
let _cut_deep_prefix ~findings deep_bars =
  match Series_tail.prefix_cut_from findings with
  | None -> deep_bars
  | Some date -> Series_splice.keep_from date deep_bars

(* Splice hygiene runs BEFORE the tail rule: cutting away the earlier issuer
   first means the tail rule then reads one company's series, which is the
   series whose terminal run it is meant to classify.

   Applied to [deep_bars] as well as the window bars, and that is not a
   symmetry for its own sake: the scan and build windows are the same, so a cut
   date is always inside the window and the whole deep prefix — up to
   [sketch_deep_days] of it — is by construction the EARLIER issuer's. Cutting
   it yields [] for a cut symbol, which is the right depth for a series that
   starts at the cut. Leaving it would put ten years of the previous company's
   weekly bars into the side-table, which is the only overhead-supply
   representation the reader has — precisely the two-issuers defect the cut
   exists to close. *)
let _cut_splice ~(hygiene : hygiene) ~symbol bars =
  match Map.find hygiene.splice_cuts symbol with
  | None -> bars
  | Some date -> Series_splice.keep_from date bars

(* The per-symbol checkpoint carries only the EXPLICIT marker: the universe's
   end is not known until every symbol has been read, so the series-end
   derivation happens once in {!_finalize_entries}. *)
let _build_one_symbol ~symbol ~bars ~deep_bars ~schema ~benchmark_bars
    ~output_dir ~csv_mtime ~hygiene =
  let path = _file_path ~output_dir ~symbol in
  let deep_bars = _cut_splice ~hygiene ~symbol deep_bars in
  let bars, findings =
    _clean_tail ~hygiene ~symbol (_cut_splice ~hygiene ~symbol bars)
  in
  let deep_bars = _cut_deep_prefix ~findings deep_bars in
  let level = _classify_level ~hygiene ~symbol bars in
  let last_bar = _last_bar_date bars in
  let active_through = _active_through_of_bars bars in
  match
    Pipeline.build_for_symbol ~symbol ~bars ~deep_bars ~schema ?benchmark_bars
      ()
  with
  | Error err -> Error err
  | Ok rows ->
      _write_weekly ~output_dir ~symbol ~deep_bars ~bars;
      Result.map
        (_write_and_checksum ~symbol ~path ~csv_mtime ~active_through rows)
        ~f:(fun entry -> { entry; last_bar; findings; level })

(* An incremental-skipped symbol reuses its previous entry verbatim, including
   the [active_through] that build derived. No bars were read, so [last_bar] is
   [None] and the entry is passed through the final derivation untouched — and
   for the same reason it contributes no tail findings and no level row, which
   keeps both sidecars scoped to the work this run actually did. *)
let _maybe_reuse ~existing ~symbol =
  let open Option.Let_syntax in
  let%bind m = existing in
  let%map entry = Snapshot_manifest.find m ~symbol in
  { entry; last_bar = None; findings = []; level = None }

let _checkpoint_manifest ~manifest_path ~schema entry =
  match
    Snapshot_manifest.update_for_symbol ~path:manifest_path ~schema entry
  with
  | Ok () -> ()
  | Error err ->
      Printf.eprintf "manifest checkpoint failed for %s: %s\n%!"
        entry.Snapshot_manifest.symbol (Status.show err)

let _build_or_log ~symbol ~bars ~deep_bars ~schema ~benchmark_bars ~output_dir
    ~csv_mtime ~manifest_path ~checkpoint ~hygiene =
  match
    _build_one_symbol ~symbol ~bars ~deep_bars ~schema ~benchmark_bars
      ~output_dir ~csv_mtime ~hygiene
  with
  | Error err ->
      Printf.eprintf "skip %s: build: %s\n%!" symbol (Status.show err);
      None
  | Ok built ->
      if checkpoint then _checkpoint_manifest ~manifest_path ~schema built.entry;
      Some built

let _try_build_and_checkpoint ~data_dir ~start_date ~end_date ~sketch_deep_days
    ~schema ~benchmark_bars ~output_dir ~manifest_path ~checkpoint ~csv_mtime
    ~hygiene symbol =
  match
    Bar_loader.load_split_bars ~data_dir ~start_date ~end_date ~sketch_deep_days
      ~symbol
  with
  | Error err ->
      Printf.eprintf "skip %s: load: %s\n%!" symbol (Status.show err);
      None
  | Ok (deep_bars, bars) ->
      _build_or_log ~symbol ~bars ~deep_bars ~schema ~benchmark_bars ~output_dir
        ~csv_mtime ~manifest_path ~checkpoint ~hygiene

let process_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
    ~benchmark_bars ~output_dir ~existing ~manifest_path ~checkpoint ~hygiene
    symbol =
  match Bar_loader.csv_mtime ~data_dir ~symbol with
  | None ->
      Printf.eprintf "skip %s: no CSV\n%!" symbol;
      None
  | Some csv_mtime ->
      if _should_skip ~existing ~symbol ~csv_mtime ~schema then
        _maybe_reuse ~existing ~symbol
      else
        _try_build_and_checkpoint ~data_dir ~start_date ~end_date
          ~sketch_deep_days ~schema ~benchmark_bars ~output_dir ~manifest_path
          ~checkpoint ~csv_mtime ~hygiene symbol

let _load_benchmark_bars ~data_dir ~start_date ~end_date sym =
  match
    Bar_loader.load_windowed_bars ~data_dir ~start_date ~end_date ~symbol:sym
  with
  | Ok bars -> Some bars
  | Error err ->
      Printf.eprintf "warning: benchmark %s load failed: %s\n%!" sym
        (Status.show err);
      None

let benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol =
  Option.bind benchmark_symbol
    ~f:(_load_benchmark_bars ~data_dir ~start_date ~end_date)
