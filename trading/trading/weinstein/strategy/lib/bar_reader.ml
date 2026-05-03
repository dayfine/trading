(** Bar source abstraction — see [bar_reader.mli]. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views

(* Closure-based representation: each constructor captures its backing's read
   primitives and packages them as same-shape closures. The strategy's hot
   path invokes one of these closures per call site per tick — no backing
   dispatch, no variant match. *)
type t = {
  daily_bars_for : symbol:string -> as_of:Date.t -> Types.Daily_price.t list;
  weekly_bars_for :
    symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list;
  weekly_view_for :
    symbol:string -> n:int -> as_of:Date.t -> Bar_panels.weekly_view;
  daily_view_for :
    symbol:string -> as_of:Date.t -> lookback:int -> Bar_panels.daily_view;
  ma_cache : Weekly_ma_cache.t option;
}

let ma_cache t = t.ma_cache

(* Empty views — used as the sentinel return when [as_of] falls outside the
   panel's calendar or the snapshot has no rows. Match the empty literals
   [Bar_panels] / [Snapshot_bar_views] use internally so consumers can rely
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

(* {1 Panel-backed constructor} *)

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
  }

(* {1 Empty backing — used by tests where no read is expected} *)

(* Build an empty [Bar_panels.t] backed by a zero-symbol universe + zero-day
   calendar. Used by [empty ()] for tests where no panel-backed read is
   expected — exercising it through the panel-backed closure keeps the
   "empty universe" fallback consistent with the panel path's semantics
   (and means tests still see [Bar_panels]-shaped returns). *)
let _empty_panels () =
  let symbol_index =
    match Symbol_index.create ~universe:[] with
    | Ok t -> t
    | Error err ->
        failwithf "Bar_reader.empty: Symbol_index.create []: %s"
          err.Status.message ()
  in
  let ohlcv = Ohlcv_panels.create symbol_index ~n_days:0 in
  match Bar_panels.create ~ohlcv ~calendar:[||] with
  | Ok p -> p
  | Error err ->
      failwithf "Bar_reader.empty: Bar_panels.create: %s" err.Status.message ()

let empty () = of_panels (_empty_panels ())

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

let _snapshot_daily_view_for cb ~symbol ~as_of ~lookback =
  Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback

let _snapshot_daily_bars_for cb ~symbol ~as_of =
  Snapshot_bar_views.daily_bars_for cb ~symbol ~as_of

let _snapshot_weekly_bars_for cb ~symbol ~n ~as_of =
  Snapshot_bar_views.weekly_bars_for cb ~symbol ~n ~as_of

let of_snapshot_views (cb : Snapshot_runtime.Snapshot_callbacks.t) =
  {
    daily_bars_for = _snapshot_daily_bars_for cb;
    weekly_bars_for = _snapshot_weekly_bars_for cb;
    weekly_view_for = _snapshot_weekly_view_for cb;
    daily_view_for = _snapshot_daily_view_for cb;
    ma_cache = None;
  }

(* {1 Public read API — direct closure invocations} *)

let daily_bars_for t = t.daily_bars_for
let weekly_bars_for t = t.weekly_bars_for
let weekly_view_for t = t.weekly_view_for
let daily_view_for t = t.daily_view_for
