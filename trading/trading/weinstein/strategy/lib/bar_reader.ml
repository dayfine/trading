(** Bar source abstraction — see [bar_reader.mli]. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels

type t = { panels : Bar_panels.t; ma_cache : Weekly_ma_cache.t option }

let of_panels ?ma_cache panels = { panels; ma_cache }
let ma_cache t = t.ma_cache

(** Build an empty [Bar_panels.t] backed by a zero-symbol universe + zero-day
    calendar. Used by [empty ()] for tests where no panel-backed read is
    expected. *)
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

let empty () = { panels = _empty_panels (); ma_cache = None }

(* When [as_of] is not in the calendar (e.g., the backtest hasn't started yet,
   or the strategy was somehow handed a date outside the bounds), return the
   empty list. The strategy's downstream code already tolerates an empty
   result: [Stage.classify_with_callbacks] returns the Stage1 default,
   [Sector.analyze] returns the empty result, etc. *)
let daily_bars_for t ~symbol ~as_of =
  match Bar_panels.column_of_date t.panels as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.daily_bars_for t.panels ~symbol ~as_of_day

let weekly_bars_for t ~symbol ~n ~as_of =
  match Bar_panels.column_of_date t.panels as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.weekly_bars_for t.panels ~symbol ~n ~as_of_day

(* Float-array views: same calendar-fallback semantics as the bar-list reads.
   Returning the empty view (n=0 / n_days=0) when [as_of] is not in the
   calendar matches the empty-list contract callers already tolerate. *)

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

let weekly_view_for t ~symbol ~n ~as_of =
  match Bar_panels.column_of_date t.panels as_of with
  | None -> _empty_weekly_view
  | Some as_of_day -> Bar_panels.weekly_view_for t.panels ~symbol ~n ~as_of_day

let daily_view_for t ~symbol ~as_of ~lookback =
  match Bar_panels.column_of_date t.panels as_of with
  | None -> _empty_daily_view
  | Some as_of_day ->
      Bar_panels.daily_view_for t.panels ~symbol ~as_of_day ~lookback
