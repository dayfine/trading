open Core
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_verifier = Snapshot_pipeline.Snapshot_verifier
module Series_tail = Snapshot_pipeline.Series_tail
module Series_splice = Snapshot_pipeline.Series_splice
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

(* Slack, in calendar days, between the universe's last bar and a symbol's own
   last bar before that symbol counts as delisted (#2693). The vendor lags a
   few names by a day or two — a symbol whose series stops on the Wednesday of
   the store's final week is still trading, not delisted. CLIs surface this as
   [--survivor-tolerance-days]. *)
let default_survivor_tolerance_days = 7

(* Committed veto list for {!Series_tail}. Documented, not defaulted: the flag
   stays optional so a build's behaviour never depends on the caller's cwd. *)
let default_exceptions_path = "trading/test_data/warehouse_exceptions.sexp"
let tail_report_name = "terminal_runs.csv"

(* One built symbol: its manifest entry, the date of its last stored bar (None
   when the entry was reused from a previous incremental run, so no bars were
   read), and the tail findings to report. *)
type built = {
  entry : Snapshot_manifest.file_metadata;
  last_bar : Core.Date.t option;
  findings : Series_tail.finding list;
}

(* Series-hygiene knobs, bundled so the per-symbol call chain threads one
   parameter rather than three. *)
type hygiene_opts = {
  config : Series_tail.Config.t;
  exceptions : Series_tail.Exceptions.t;
  splice_cuts : Core.Date.t Map.M(String).t;
      (* Symbols to cut at build time, and the date to keep bars from (#2672
         class ii). Decided by the scanner that sees every symbol's full
         history; applied here to the build-window bars. Symbols the scanner
         DROPPED never reach the runner — they are removed from [symbols]. *)
}

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
   depth, so they are left alone. *)
let _clean_tail ~(hygiene : hygiene_opts) ~symbol bars =
  Series_tail.apply hygiene.config ~exceptions:hygiene.exceptions ~symbol bars

(* Splice hygiene runs BEFORE the tail rule: cutting away the earlier issuer
   first means the tail rule then reads one company's series, which is the
   series whose terminal run it is meant to classify. *)
let _cut_splice ~(hygiene : hygiene_opts) ~symbol bars =
  match Map.find hygiene.splice_cuts symbol with
  | None -> bars
  | Some date -> Series_splice.keep_from date bars

(* The per-symbol checkpoint carries only the EXPLICIT marker: the universe's
   end is not known until every symbol has been read, so the series-end
   derivation happens once in {!_finalize_entries}. *)
let _build_one_symbol ~symbol ~bars ~deep_bars ~schema ~benchmark_bars
    ~output_dir ~csv_mtime ~hygiene =
  let path = _file_path ~output_dir ~symbol in
  let bars, findings =
    _clean_tail ~hygiene ~symbol (_cut_splice ~hygiene ~symbol bars)
  in
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
        ~f:(fun entry -> { entry; last_bar; findings })

(* An incremental-skipped symbol reuses its previous entry verbatim, including
   the [active_through] that build derived. No bars were read, so [last_bar] is
   [None] and the entry is passed through the final derivation untouched. *)
let _maybe_reuse ~existing ~symbol =
  let open Option.Let_syntax in
  let%bind m = existing in
  let%map entry = Snapshot_manifest.find m ~symbol in
  { entry; last_bar = None; findings = [] }

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
    _load_split_bars ~data_dir ~start_date ~end_date ~sketch_deep_days ~symbol
  with
  | Error err ->
      Printf.eprintf "skip %s: load: %s\n%!" symbol (Status.show err);
      None
  | Ok (deep_bars, bars) ->
      _build_or_log ~symbol ~bars ~deep_bars ~schema ~benchmark_bars ~output_dir
        ~csv_mtime ~manifest_path ~checkpoint ~hygiene

let _process_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
    ~benchmark_bars ~output_dir ~existing ~manifest_path ~checkpoint ~hygiene
    symbol =
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
          ~checkpoint ~csv_mtime ~hygiene symbol

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
    _process_symbol ~data_dir ~start_date ~end_date ~sketch_deep_days ~schema
      ~benchmark_bars ~output_dir ~existing ~manifest_path ~checkpoint:true
      ~hygiene symbol
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
  List.filter_map builts ~f:(fun b -> b.last_bar)
  |> List.max_elt ~compare:Date.compare

(* The universe's end is only resolvable once every symbol is read, so the
   per-symbol [active_through] is filled in here rather than at checkpoint
   time. Reused (incremental-skip) entries read no bars, so they keep the value
   their own build derived. *)
let _entry_with_derived_marker ~universe_end ~survivor_tolerance_days b =
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
   "2,999 of 2,999 marked" on a store with 778 live names). *)
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
  _log_marker_split entries;
  entries

(* Review sidecar (#2672): every terminal run below the ratio, whatever the
   gates decided, so a human reads the vintage's classes once. Written even when
   empty — a header-only file is the positive evidence that the scan ran and
   found nothing. *)
let _write_tail_report ~output_dir builts =
  let findings = List.concat_map builts ~f:(fun b -> b.findings) in
  let path = Filename.concat output_dir tail_report_name in
  (try Out_channel.write_all path ~data:(Series_tail.to_csv findings)
   with Sys_error msg ->
     Printf.eprintf "%s write failed: %s\n%!" tail_report_name msg);
  Printf.printf "%s\n%!" (Series_tail.summary findings)

(* Pure loader: the failure is a value, so both halves are testable. The CLI
   shells turn the [Error] into an exit via [tail_exceptions_or_exit] /
   [splice_exceptions_or_exit]. One file, two sections, two parsers — each
   ignores the other's section. *)
let _read_exceptions_file ~what ~parse p =
  match Or_error.try_with (fun () -> parse (Sexp.load_sexp p)) with
  | Ok t -> Ok t
  | Error e ->
      Status.error_invalid_argument
        (Printf.sprintf "%s exceptions load failed (%s): %s" what p
           (Error.to_string_hum e))

let load_tail_exceptions path =
  match path with
  | None -> Ok Series_tail.Exceptions.empty
  | Some p ->
      _read_exceptions_file ~what:"tail" p ~parse:(fun s ->
          Series_tail.Exceptions.of_file (Series_tail.Exceptions.file_of_sexp s))

let load_splice_exceptions path =
  match path with
  | None -> Ok Series_splice.Exceptions.empty
  | Some p ->
      _read_exceptions_file ~what:"splice" p ~parse:(fun s ->
          Series_splice.Exceptions.of_file
            (Series_splice.Exceptions.file_of_sexp s))

(* A malformed or missing exceptions file is FATAL: silently falling back to "no
   exceptions" would edit exactly the symbols a reviewer vetoed. *)
let _exceptions_or_exit = function
  | Ok t -> t
  | Error err ->
      Printf.eprintf "%s\n%!" (Status.show err);
      exit 1

let tail_exceptions_or_exit path =
  _exceptions_or_exit (load_tail_exceptions path)

let splice_exceptions_or_exit path =
  _exceptions_or_exit (load_splice_exceptions path)

let build ?(survivor_tolerance_days = default_survivor_tolerance_days)
    ?(splice_cuts = Map.empty (module String)) ~symbols ~csv_data_dir
    ~output_dir ~benchmark_symbol ~start_date ~end_date ~sketch_deep_days
    ~incremental ~progress_every ~tail_config ~tail_exceptions () =
  _ensure_dir output_dir;
  let schema = Snapshot_schema.default in
  let symbols_total = List.length symbols in
  let data_dir = Fpath.v csv_data_dir in
  let benchmark_bars =
    _benchmark_bars_opt ~data_dir ~start_date ~end_date ~benchmark_symbol
  in
  let existing = if incremental then _existing_manifest ~output_dir else None in
  let manifest_path = Filename.concat output_dir "manifest.sexp" in
  let hygiene =
    { config = tail_config; exceptions = tail_exceptions; splice_cuts }
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
  let elapsed = Time_ns.diff (Time_ns.now ()) t0 in
  _write_final_manifest ~manifest_path ~schema ~entries ~elapsed;
  _write_tail_report ~output_dir builts;
  _emit_final_progress ~output_dir ~symbols_total ~entries ~started_at;
  _verify_or_warn ~manifest_path

(* Shared CLI surface for the survivor tolerance, so both builders expose the
   same flag and default. *)
let survivor_tolerance_param =
  let%map_open.Command days =
    flag "survivor-tolerance-days"
      (optional_with_default default_survivor_tolerance_days int)
      ~doc:
        (Printf.sprintf
           "N Calendar days a symbol's last bar may trail the universe's last \
            bar and still count as still-trading (active_through stays unset). \
            Default %d."
           default_survivor_tolerance_days)
  in
  days

(* Shared CLI surface for the tail knobs, so both builders expose exactly the
   same flags and defaults. Only the three gate knobs are flags: the mis-scale
   threshold and the stray-gap parameters are measured constants of the defect
   classes, not per-build choices ({!Series_tail}). *)
let tail_params =
  let d = Series_tail.Config.default in
  let%map_open.Command ratio =
    flag "stub-ratio"
      (optional_with_default d.stub.ratio float)
      ~doc:"R Terminal-run close ratio below which a bar is a stub candidate"
  and max_bars =
    flag "stub-max-bars"
      (optional_with_default d.stub.max_bars int)
      ~doc:"N Longest terminal run still truncatable (longer = long low tail)"
  and max_price =
    flag "stub-max-price"
      (optional_with_default d.stub.max_price float)
      ~doc:"P The run's first close must be below this to count as a stub"
  and no_stub_truncation =
    flag "no-stub-truncation" no_arg
      ~doc:"Report terminal stub tails without truncating them"
  and no_stray_drop =
    flag "no-stray-drop" no_arg
      ~doc:"Report stray late bars without dropping them"
  and exceptions_path =
    flag "tail-exceptions" (optional string)
      ~doc:
        (Printf.sprintf
           "PATH Warehouse exceptions sexp, shape ((keep_tail (SYM ...)) \
            (splice ((keep SYM) (drop SYM) (cut_at SYM DATE)))). Both sections \
            optional. Committed list: %s"
           default_exceptions_path)
  in
  ( {
      Series_tail.Config.stub =
        {
          d.stub with
          truncate = not no_stub_truncation;
          ratio;
          max_bars;
          max_price;
        };
      stray = { d.stray with drop = not no_stray_drop };
    },
    exceptions_path )
