(** Bar source abstraction — see [bar_reader.mli]. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Daily_panels = Snapshot_runtime.Daily_panels
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Closure-based representation: each constructor captures its backing's read
   primitives and packages them as same-shape closures. The strategy's hot
   path invokes one of these closures per call site per tick — no backing
   dispatch, no variant match.

   [ma_cache] is set by [of_panels] callers that build a cache up-front; the
   other constructors leave it [None]. The strategy's cache-aware MA paths
   key off [Some].

   [snapshot_callbacks] is the underlying field-accessor shim for
   {!of_snapshot_views} / {!of_in_memory_bars}. The strategy's macro / sector
   entry points consume this directly via the [*_of_snapshot_views] APIs
   on {!Macro_inputs} (Phase F.3.b-2 / c-2 / d-2 caller migration). For
   panel-backed and empty readers, this is a sentinel cb whose every read
   returns [Error NotFound]; the macro / sector path then sees empty views,
   matching the prior bar-list / panel-view behaviour for readers that were
   never meant to back a real screening run. *)
type t = {
  daily_bars_for : symbol:string -> as_of:Date.t -> Types.Daily_price.t list;
  weekly_bars_for :
    symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list;
  weekly_view_for :
    symbol:string -> n:int -> as_of:Date.t -> Bar_panels.weekly_view;
  daily_view_for :
    symbol:string -> as_of:Date.t -> lookback:int -> Bar_panels.daily_view;
  ma_cache : Weekly_ma_cache.t option;
  snapshot_callbacks : Snapshot_callbacks.t;
}

let ma_cache t = t.ma_cache
let snapshot_callbacks t = t.snapshot_callbacks

(* Sentinel cb for readers that have no underlying snapshot directory
   ({!of_panels} and {!empty}). Every [read_field] / [read_field_history] call
   returns [Error NotFound], which {!Snapshot_bar_views.weekly_view_for} /
   {!Snapshot_bar_views.weekly_bars_for} fold to the empty view / empty list.
   This matches the contract for these constructors today: panel-backed
   readers are unused in production after Phase F.3.a-3 redo, and the empty
   reader is documented to return empty results from every read. *)
let _empty_snapshot_callbacks : Snapshot_callbacks.t =
  let not_found =
    Error
      {
        Status.code = Status.NotFound;
        message = "Bar_reader: snapshot_callbacks not available on this reader";
      }
  in
  {
    read_field = (fun ~symbol:_ ~date:_ ~field:_ -> not_found);
    read_field_history = (fun ~symbol:_ ~from:_ ~until:_ ~field:_ -> not_found);
  }

(* Empty views — used as the sentinel return when [as_of] falls outside the
   snapshot's calendar or the snapshot has no rows. Match the empty literals
   {!Bar_panels} / {!Snapshot_bar_views} use internally so consumers can rely
   on [n = 0] / [n_days = 0] as the "missing" signal. *)
let _empty_weekly_view : Bar_panels.weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

let _empty_daily_view : Bar_panels.daily_view =
  { highs = [||]; lows = [||]; closes = [||]; dates = [||]; n_days = 0 }

(* {1 Panel-backed constructor (Bar_panels.t over a CSV-loaded calendar)}

   Restored by the partial revert of the Phase F.3.a-3 strategy-side flip.
   The runner's strategy bar reads stay on this constructor until the
   path-dependent divergence in {!of_snapshot_views} is forward-fixed; see
   [bar_reader.mli] module-doc for context. *)

let _panel_daily_bars_for panels ~symbol ~as_of =
  match Bar_panels.column_of_date panels as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.daily_bars_for panels ~symbol ~as_of_day

let _panel_weekly_bars_for panels ~symbol ~n ~as_of =
  match Bar_panels.column_of_date panels as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.weekly_bars_for panels ~symbol ~n ~as_of_day

let _panel_weekly_view_for panels ~symbol ~n ~as_of =
  match Bar_panels.column_of_date panels as_of with
  | None -> _empty_weekly_view
  | Some as_of_day -> Bar_panels.weekly_view_for panels ~symbol ~n ~as_of_day

let _panel_daily_view_for panels ~symbol ~as_of ~lookback =
  match Bar_panels.column_of_date panels as_of with
  | None -> _empty_daily_view
  | Some as_of_day ->
      Bar_panels.daily_view_for panels ~symbol ~as_of_day ~lookback

let of_panels ?ma_cache panels =
  {
    daily_bars_for = _panel_daily_bars_for panels;
    weekly_bars_for = _panel_weekly_bars_for panels;
    weekly_view_for = _panel_weekly_view_for panels;
    daily_view_for = _panel_daily_view_for panels;
    ma_cache;
    (* Panel-backed readers have no underlying snapshot directory; the
       sentinel cb yields empty views from {!Snapshot_bar_views}. Production
       does not use this constructor (Phase F.3.a-3 redo flipped the runner
       to {!of_snapshot_views}); F.3.e deletes [of_panels] entirely. *)
    snapshot_callbacks = _empty_snapshot_callbacks;
  }

(* {1 Empty backing — used by tests where no read is expected}

   The closures simply return the empty list / empty view directly, without
   allocating a [Bar_panels.t] or opening a snapshot directory. This is the
   smallest constructor and matches the "no read expected" contract
   precisely. *)
let empty () =
  {
    daily_bars_for = (fun ~symbol:_ ~as_of:_ -> []);
    weekly_bars_for = (fun ~symbol:_ ~n:_ ~as_of:_ -> []);
    weekly_view_for = (fun ~symbol:_ ~n:_ ~as_of:_ -> _empty_weekly_view);
    daily_view_for = (fun ~symbol:_ ~as_of:_ ~lookback:_ -> _empty_daily_view);
    ma_cache = None;
    (* The sentinel cb's "every read errors" semantics matches the
       closures above's "every read returns empty" semantics through
       {!Snapshot_bar_views}'s NotFound-to-empty fold. *)
    snapshot_callbacks = _empty_snapshot_callbacks;
  }

(* {1 Snapshot-backed constructor (Phase F.2 PR 2)}

   Reads fan out through [Snapshot_bar_views] over a [Snapshot_callbacks.t].
   The shim's "missing data → empty view" contract matches [Bar_panels]', so
   the strategy's downstream callees see the same fallback semantics.

   All four readers ([daily_bars_for], [weekly_bars_for], [weekly_view_for],
   [daily_view_for]) are backed by [Snapshot_bar_views] helpers. The
   bar-list readers are needed in production by [Stops_split_runner]
   (split-event detection across the last two daily bars) and
   [Entry_audit_capture] (effective entry close-price); the view readers
   are needed by every panel-callback constructor. *)

let _snapshot_weekly_view_for cb ~symbol ~n ~as_of =
  Snapshot_bar_views.weekly_view_for cb ~symbol ~n ~as_of

let _snapshot_daily_bars_for cb ~symbol ~as_of =
  Snapshot_bar_views.daily_bars_for cb ~symbol ~as_of

let _snapshot_weekly_bars_for cb ~symbol ~n ~as_of =
  Snapshot_bar_views.weekly_bars_for cb ~symbol ~n ~as_of

(* Synthesize a Mon-Fri weekday calendar covering [as_of - lookback - slack
   .. as_of] when [of_snapshot_views] is constructed without an explicit
   [~calendar]. Used by tests and by the in-memory-bars convenience
   constructor; the panel runner passes its real calendar through.

   The slack is the same shape as the panel runner's calendar (every weekday
   between warmup_start and end_date), but bounded to a single
   [daily_view_for]/[low_window] call's window. This matches the panel
   behaviour for any window contained in the snapshot's date range. *)
let _synth_calendar ~as_of ~lookback : Date.t array =
  let calendar_days = (lookback * 3 / 2) + 14 in
  let from = Date.add_days as_of (-calendar_days) in
  let rec loop d acc =
    if Date.( > ) d as_of then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop from [])

let _snapshot_daily_view_for ?calendar cb ~symbol ~as_of ~lookback =
  let calendar =
    match calendar with Some c -> c | None -> _synth_calendar ~as_of ~lookback
  in
  Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback ~calendar

let of_snapshot_views ?calendar (cb : Snapshot_runtime.Snapshot_callbacks.t) =
  {
    daily_bars_for = _snapshot_daily_bars_for cb;
    weekly_bars_for = _snapshot_weekly_bars_for cb;
    weekly_view_for = _snapshot_weekly_view_for cb;
    daily_view_for = _snapshot_daily_view_for ?calendar cb;
    ma_cache = None;
    (* Expose the underlying cb so the strategy's macro / sector path
       (Phase F.3.b-2 / c-2 / d-2 caller migration) reads through the
       snapshot directly via [Macro_inputs.*_of_snapshot_views] without
       re-routing through the bar_reader's panel-shaped views. *)
    snapshot_callbacks = cb;
  }

(* {1 In-memory-bars constructor (Phase F.3.a-1)}

   Materialise a snapshot directory under a tmp dir, then route reads through
   [of_snapshot_views]. The Bar_panels alternative ([of_panels] composed with
   a synthetic [Bar_panels.t] built from in-memory bars) is the path this
   constructor replaces; keeping it here lets every Bar_panels-backed test
   migrate to a panel-free reader without changing call sites. *)

(* Cache cap for the in-memory case: small directories (handful of symbols
   × thousands of days) easily fit in a few MB, but giving the LRU some
   headroom avoids thrashing on tests that read across many symbols. *)
let _in_memory_cache_mb = 16

let _build_for_symbol_or_fail ~symbol ~bars =
  match
    Pipeline.build_for_symbol ~symbol ~bars ~schema:Snapshot_schema.default ()
  with
  | Ok rows -> rows
  | Error err ->
      failwithf "Bar_reader.of_in_memory_bars: Pipeline.build_for_symbol %s: %s"
        symbol err.Status.message ()

let _write_symbol_snap ~dir ~symbol rows =
  let path = Filename.concat dir (symbol ^ ".snap") in
  match Snapshot_format.write ~path rows with
  | Ok () -> path
  | Error err ->
      failwithf "Bar_reader.of_in_memory_bars: Snapshot_format.write %s: %s"
        symbol err.Status.message ()

(* The directory manifest needs per-symbol metadata; for the in-memory case
   the byte_size / payload_md5 / csv_mtime fields are observational only —
   the runtime [Daily_panels] reader does not validate them at create time.
   Filling sentinel values keeps the constructor stdlib-only (no
   [Core_unix.stat]). *)
let _file_metadata_of ~symbol ~path : Snapshot_manifest.file_metadata =
  { symbol; path; byte_size = 0; payload_md5 = "ignored"; csv_mtime = 0.0 }

let _open_daily_panels ~dir ~manifest =
  match
    Daily_panels.create ~snapshot_dir:dir ~manifest
      ~max_cache_mb:_in_memory_cache_mb
  with
  | Ok p -> p
  | Error err ->
      failwithf "Bar_reader.of_in_memory_bars: Daily_panels.create: %s"
        err.Status.message ()

let _write_manifest_or_fail ~dir manifest =
  let path = Filename.concat dir "manifest.sexp" in
  match Snapshot_manifest.write ~path manifest with
  | Ok () -> ()
  | Error err ->
      failwithf "Bar_reader.of_in_memory_bars: Snapshot_manifest.write: %s"
        err.Status.message ()

let of_in_memory_bars (symbol_bars : (string * Types.Daily_price.t list) list) =
  let dir = Stdlib.Filename.temp_dir "bar_reader_in_memory_" "" in
  let entries =
    List.map symbol_bars ~f:(fun (symbol, bars) ->
        let rows = _build_for_symbol_or_fail ~symbol ~bars in
        let path = _write_symbol_snap ~dir ~symbol rows in
        _file_metadata_of ~symbol ~path)
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  _write_manifest_or_fail ~dir manifest;
  let panels = _open_daily_panels ~dir ~manifest in
  of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(* {1 Public read API — direct closure invocations} *)

let daily_bars_for t = t.daily_bars_for
let weekly_bars_for t = t.weekly_bars_for
let weekly_view_for t = t.weekly_view_for
let daily_view_for t = t.daily_view_for
