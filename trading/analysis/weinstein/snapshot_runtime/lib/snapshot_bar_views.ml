(** Bar-shaped views over [Snapshot_callbacks.t] — see [snapshot_bar_views.mli].
*)

open Core
module BA1 = Bigarray.Array1
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Phase F.3.e-1: this module is now the canonical home of [weekly_view] and
   [daily_view]. [Data_panel.Bar_panels.weekly_view] / [.daily_view] alias
   these via [type =] until F.3.e-3 deletes {!Data_panel.Bar_panels}. *)
type weekly_view = {
  closes : float array;
  raw_closes : float array;
  highs : float array;
  lows : float array;
  volumes : float array;
  dates : Date.t array;
  n : int;
}

type daily_view = {
  highs : float array;
  lows : float array;
  closes : float array;
  dates : Date.t array;
  n_days : int;
}

let _empty_weekly_view : weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

let _empty_daily_view : daily_view =
  { highs = [||]; lows = [||]; closes = [||]; dates = [||]; n_days = 0 }

(* Calendar slack for date-keyed weekly windows: 7 weekdays + 1 holiday
   slack per week covers ISO-week buckets + a partial leading week. The
   daily-view path takes the panel calendar as a parameter (#848) instead. *)
let _weekly_calendar_span ~n = (n * 8) + 7

(* Fetch one field's history; return [] (not an error) on any failure. The
   shim's surface contract is "missing data → empty view" (matches Bar_panels
   semantics); this helper enforces that at the per-field level. *)
let _read_history_or_empty (cb : Snapshot_callbacks.t) ~symbol ~from ~until
    ~field =
  match cb.read_field_history ~symbol ~from ~until ~field with
  | Ok rows -> rows
  | Error _ -> []

(* Align five field-histories ([Adjusted_close, Close, High, Low, Volume])
   by date into a single chronologically-ordered [Daily_price.t list]. Each
   input list is already chronologically sorted (Daily_panels.read_history
   sort contract). A bar is included iff [Close] is non-NaN AND every other
   field has a row for the same date.

   Implementation: build hashtables per non-Close field keyed by date, then
   walk the [Close] list once and look up the others. O(n_close + n_other);
   no nested-loop blow-up. *)
let _table_of (rows : (Date.t * float) list) =
  let tbl = Hashtbl.create (module Date) in
  List.iter rows ~f:(fun (d, v) ->
      Hashtbl.set tbl ~key:d ~data:v |> (ignore : unit -> unit));
  tbl

let _round_volume v =
  if Float.is_nan v then 0 else Int.of_float (Float.round_nearest v)

(* Open is read like the other field histories so the assembled bar matches
   the panel path's [_read_bar] bit-for-bit. The schema includes
   [Snapshot_schema.Open] since Phase A.1 (#786); missing rows degrade to
   NaN, mirroring the panel's NaN cell on a day the symbol has no bar. *)
let _assemble_daily_bars ~open_ ~adj ~close ~high ~low ~volume :
    Types.Daily_price.t list =
  let open_t = _table_of open_ in
  let adj_t = _table_of adj in
  let high_t = _table_of high in
  let low_t = _table_of low in
  let vol_t = _table_of volume in
  let lookup_or_nan tbl date =
    Hashtbl.find tbl date |> Option.value ~default:Float.nan
  in
  let bar_for (date, close_v) =
    if Float.is_nan close_v then None
    else
      match
        ( Hashtbl.find adj_t date,
          Hashtbl.find high_t date,
          Hashtbl.find low_t date,
          Hashtbl.find vol_t date )
      with
      | Some adj_v, Some high_v, Some low_v, Some vol_v ->
          Some
            {
              Types.Daily_price.date;
              open_price = lookup_or_nan open_t date;
              high_price = high_v;
              low_price = low_v;
              close_price = close_v;
              volume = _round_volume vol_v;
              adjusted_close = adj_v;
            }
      | _ -> None
  in
  List.filter_map close ~f:bar_for

(* Convert a weekly [Daily_price.t] list (output of daily_to_weekly) into the
   [weekly_view] float-array shape. *)
let _weekly_view_of_bars (weekly : Types.Daily_price.t list) : weekly_view =
  let n = List.length weekly in
  if n = 0 then _empty_weekly_view
  else
    let arr_of f = Array.of_list (List.map weekly ~f) in
    {
      closes = arr_of (fun b -> b.adjusted_close);
      raw_closes = arr_of (fun b -> b.close_price);
      highs = arr_of (fun b -> b.high_price);
      lows = arr_of (fun b -> b.low_price);
      volumes = arr_of (fun b -> Float.of_int b.volume);
      dates = arr_of (fun b -> b.date);
      n;
    }

let _truncate_weekly_view (v : weekly_view) ~n : weekly_view =
  if v.n <= n then v
  else
    let drop = v.n - n in
    let take a = Array.sub a ~pos:drop ~len:n in
    {
      closes = take v.closes;
      raw_closes = take v.raw_closes;
      highs = take v.highs;
      lows = take v.lows;
      volumes = take v.volumes;
      dates = take v.dates;
      n;
    }

(* Read OHLCV histories over [(from, as_of)] for [symbol] and assemble into
   a [Daily_price.t list] in chronological order. Returns [] under the same
   "missing → empty" contract as the rest of the module. Shared by
   {!weekly_view_for}, {!daily_bars_for} and {!weekly_bars_for}. *)
let _daily_bars_in_range cb ~symbol ~from ~as_of =
  let read field =
    _read_history_or_empty cb ~symbol ~from ~until:as_of ~field
  in
  let close = read Snapshot_schema.Close in
  if List.is_empty close then []
  else
    let open_ = read Snapshot_schema.Open in
    let adj = read Snapshot_schema.Adjusted_close in
    let high = read Snapshot_schema.High in
    let low = read Snapshot_schema.Low in
    let volume = read Snapshot_schema.Volume in
    _assemble_daily_bars ~open_ ~adj ~close ~high ~low ~volume

let weekly_view_for (cb : Snapshot_callbacks.t) ~symbol ~n ~as_of =
  if n <= 0 then _empty_weekly_view
  else
    let from = Date.add_days as_of (-_weekly_calendar_span ~n) in
    let bars = _daily_bars_in_range cb ~symbol ~from ~as_of in
    if List.is_empty bars then _empty_weekly_view
    else
      let weekly =
        Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
      in
      _truncate_weekly_view (_weekly_view_of_bars weekly) ~n

(* History window for [daily_bars_for] / [weekly_bars_for]. The strategy
   readers return everything from time-zero up to [as_of]; the snapshot
   path is keyed by date so we walk back a fixed-width window large enough
   to cover any practical backtest horizon (10 years / 3653 days). The
   [_assemble_daily_bars] tail filter NaN-skips pre-IPO / suspended cells,
   so the window doesn't need to align with [symbol]'s actual history. *)
let _bar_list_history_days = 3653

let daily_bars_for (cb : Snapshot_callbacks.t) ~symbol ~as_of :
    Types.Daily_price.t list =
  let from = Date.add_days as_of (-_bar_list_history_days) in
  _daily_bars_in_range cb ~symbol ~from ~as_of

let weekly_bars_for (cb : Snapshot_callbacks.t) ~symbol ~n ~as_of :
    Types.Daily_price.t list =
  if n <= 0 then []
  else
    let from = Date.add_days as_of (-_bar_list_history_days) in
    let bars = _daily_bars_in_range cb ~symbol ~from ~as_of in
    if List.is_empty bars then []
    else
      let weekly =
        Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
      in
      let len = List.length weekly in
      if len <= n then weekly else List.drop weekly (len - n)

(* Index of [as_of] in [calendar], or [-1] if absent. Mirrors
   {!Bar_panels.column_of_date}'s exact-match contract: a date not in the
   calendar (out-of-window, off-calendar holiday) yields no column. *)
let _calendar_index_of (calendar : Date.t array) (as_of : Date.t) =
  Array.findi calendar ~f:(fun _ d -> Date.equal d as_of)
  |> Option.value_map ~default:(-1) ~f:fst

(* Walk calendar columns [from_idx..as_of_idx], emit one row per non-NaN
   close. Mirrors {!Bar_panels._read_row_cells}: missing snapshot rows
   leave NaN in the close lookup, same as panel NaN-close skip. *)
let _walk_daily_view_window ~calendar ~from_idx ~as_of_idx ~close_t ~high_t
    ~low_t : daily_view =
  let n_window = as_of_idx - from_idx + 1 in
  let highs = Array.create ~len:n_window Float.nan in
  let lows = Array.create ~len:n_window Float.nan in
  let closes = Array.create ~len:n_window Float.nan in
  let dates = Array.create ~len:n_window calendar.(from_idx) in
  let count = ref 0 in
  for i = from_idx to as_of_idx do
    let date = calendar.(i) in
    match Hashtbl.find close_t date with
    | None -> ()
    | Some close_v when Float.is_nan close_v -> ()
    | Some close_v ->
        let high_v =
          Hashtbl.find high_t date |> Option.value ~default:Float.nan
        in
        let low_v =
          Hashtbl.find low_t date |> Option.value ~default:Float.nan
        in
        let j = !count in
        closes.(j) <- close_v;
        highs.(j) <- high_v;
        lows.(j) <- low_v;
        dates.(j) <- date;
        Int.incr count
  done;
  let n = !count in
  if n = 0 then _empty_daily_view
  else
    let take a = Array.sub a ~pos:0 ~len:n in
    {
      highs = take highs;
      lows = take lows;
      closes = take closes;
      dates = take dates;
      n_days = n;
    }

(* The snapshot path takes the panel's calendar and walks the same column
   set as {!Bar_panels.daily_view_for}. Without [~calendar] the window
   would be ambiguous between "lookback weekdays" (panel) and "lookback
   actual rows in the snapshot" (pre-#848 path) — the divergence root
   cause per the #848 investigation. *)
let daily_view_for (cb : Snapshot_callbacks.t) ~symbol ~as_of ~lookback
    ~calendar =
  if lookback <= 0 then _empty_daily_view
  else
    let as_of_idx = _calendar_index_of calendar as_of in
    if as_of_idx < 0 then _empty_daily_view
    else
      let from_idx = max 0 (as_of_idx - lookback + 1) in
      let from_date = calendar.(from_idx) in
      let until_date = calendar.(as_of_idx) in
      let read field =
        _read_history_or_empty cb ~symbol ~from:from_date ~until:until_date
          ~field
      in
      let close = read Snapshot_schema.Close in
      if List.is_empty close then _empty_daily_view
      else
        let high = read Snapshot_schema.High in
        let low = read Snapshot_schema.Low in
        let close_t = _table_of close in
        let high_t = _table_of high in
        let low_t = _table_of low in
        _walk_daily_view_window ~calendar ~from_idx ~as_of_idx ~close_t ~high_t
          ~low_t

(* Mirrors {!Bar_panels.low_window}'s zero-copy panel-slice semantics:
   walk the calendar columns, NaN-passthrough on missing rows ({!Ohlcv_panels}
   initialises panels to NaN). Returns [None] only on len<=0, as_of not in
   calendar, window underflow, or unknown symbol. *)
let low_window (cb : Snapshot_callbacks.t) ~symbol ~as_of ~len ~calendar =
  if len <= 0 then None
  else
    let n_cal = Array.length calendar in
    let as_of_idx = _calendar_index_of calendar as_of in
    let from_idx = as_of_idx - len + 1 in
    if as_of_idx < 0 || from_idx < 0 || as_of_idx >= n_cal then None
    else
      let from_date = calendar.(from_idx) in
      let until_date = calendar.(as_of_idx) in
      match
        cb.read_field_history ~symbol ~from:from_date ~until:until_date
          ~field:Snapshot_schema.Low
      with
      | Error _ -> None
      | Ok rows ->
          let low_t = _table_of rows in
          let buf = BA1.create Bigarray.Float64 Bigarray.C_layout len in
          for j = 0 to len - 1 do
            let date = calendar.(from_idx + j) in
            let v =
              Hashtbl.find low_t date |> Option.value ~default:Float.nan
            in
            BA1.set buf j v
          done;
          Some buf
