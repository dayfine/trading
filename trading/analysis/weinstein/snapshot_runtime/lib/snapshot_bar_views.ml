(** Bar-shaped views over [Snapshot_callbacks.t] — see [snapshot_bar_views.mli].
*)

open Core
module BA1 = Bigarray.Array1
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Panel_views = Data_panel_snapshot.Panel_views

(* Phase F.3.e-1 (revised): the canonical record definitions live in
   [Data_panel_snapshot.Panel_views] — a neutral hub library with no
   [analysis/] dep. The manifest re-export ([type =] with the record body)
   keeps the field-access syntax ([v.Snapshot_bar_views.n]) working at every
   call site. The neutral hub satisfies the A2 architecture boundary, see
   [.claude/rules/qc-structural-authority.md] §A2. *)
type weekly_view = Panel_views.weekly_view = {
  closes : float array;
  raw_closes : float array;
  highs : float array;
  lows : float array;
  volumes : float array;
  dates : Date.t array;
  n : int;
}

type daily_view = Panel_views.daily_view = {
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
   shim's surface contract is "missing data → empty view"; this helper
   enforces that at the per-field level. *)
let _read_history_or_empty (cb : Snapshot_callbacks.t) ~symbol ~from ~until
    ~field =
  match cb.read_field_history ~symbol ~from ~until ~field with
  | Ok rows -> rows
  | Error _ -> []

let _table_of (rows : (Date.t * float) list) =
  let tbl = Hashtbl.create (module Date) in
  List.iter rows ~f:(fun (d, v) ->
      Hashtbl.set tbl ~key:d ~data:v |> (ignore : unit -> unit));
  tbl

let _round_volume v =
  if Float.is_nan v then 0 else Int.of_float (Float.round_nearest v)

(* Build a [Daily_price.t] from fully-matched OHLCAV values and a date. *)
let _make_daily_price ~open_t ~date ~close_v ~adj_v ~high_v ~low_v ~vol_v =
  let open_price =
    Hashtbl.find open_t date |> Option.value ~default:Float.nan
  in
  {
    Types.Daily_price.date;
    open_price;
    high_price = high_v;
    low_price = low_v;
    close_price = close_v;
    volume = _round_volume vol_v;
    adjusted_close = adj_v;
  }

(* Match OHLCV side-tables for [date]; returns [None] if any required field is
   missing. [open_t] is optional so missing open degrades to NaN. *)
let _match_ohlcv ~open_t ~adj_t ~high_t ~low_t ~vol_t ~date ~close_v =
  match
    ( Hashtbl.find adj_t date,
      Hashtbl.find high_t date,
      Hashtbl.find low_t date,
      Hashtbl.find vol_t date )
  with
  | Some adj_v, Some high_v, Some low_v, Some vol_v ->
      Some
        (_make_daily_price ~open_t ~date ~close_v ~adj_v ~high_v ~low_v ~vol_v)
  | _ -> None

(* Attempt to build one [Daily_price.t] from a (date, close) pair and the
   OHLCV side-tables. Returns [None] for NaN-close or any missing field. *)
let _bar_for ~open_t ~adj_t ~high_t ~low_t ~vol_t (date, close_v) =
  if Float.is_nan close_v then None
  else _match_ohlcv ~open_t ~adj_t ~high_t ~low_t ~vol_t ~date ~close_v

(* Align OHLCV field-histories by date → [Daily_price.t list]. Builds one
   hashtable per non-Close field, walks [Close] once (O(n)), skips NaN-close
   bars. [Open] included since Phase A.1; missing rows degrade to NaN. *)
let _assemble_daily_bars ~open_ ~adj ~close ~high ~low ~volume :
    Types.Daily_price.t list =
  let open_t = _table_of open_ in
  let adj_t = _table_of adj in
  let high_t = _table_of high in
  let low_t = _table_of low in
  let vol_t = _table_of volume in
  List.filter_map close ~f:(_bar_for ~open_t ~adj_t ~high_t ~low_t ~vol_t)

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

(* Build and truncate a weekly view from non-empty [bars]. *)
let _build_weekly_view bars ~n =
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
  in
  _truncate_weekly_view (_weekly_view_of_bars weekly) ~n

(* Fetch daily bars and build a weekly view; called when n > 0. *)
let _fetch_and_build_weekly_view cb ~symbol ~n ~as_of =
  let from = Date.add_days as_of (-_weekly_calendar_span ~n) in
  let bars = _daily_bars_in_range cb ~symbol ~from ~as_of in
  if List.is_empty bars then _empty_weekly_view else _build_weekly_view bars ~n

let weekly_view_for (cb : Snapshot_callbacks.t) ~symbol ~n ~as_of =
  if n <= 0 then _empty_weekly_view
  else _fetch_and_build_weekly_view cb ~symbol ~n ~as_of

(* Fixed-width lookback window for [daily_bars_for] / [weekly_bars_for]:
   10 years × ~365.3 calendar days = 3653. Wide enough for any backtest
   horizon; NaN-skip in [_assemble_daily_bars] handles pre-IPO cells. *)
let _bar_list_history_days = 3653

let daily_bars_for (cb : Snapshot_callbacks.t) ~symbol ~as_of :
    Types.Daily_price.t list =
  let from = Date.add_days as_of (-_bar_list_history_days) in
  _daily_bars_in_range cb ~symbol ~from ~as_of

(* Convert daily bars to weekly and return the last [n]; caller ensures
   [bars] is non-empty. *)
let _to_weekly_bars bars ~n =
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
  in
  let len = List.length weekly in
  if len <= n then weekly else List.drop weekly (len - n)

(* Fetch daily bars and return the last [n] as weekly bars; called when n > 0. *)
let _fetch_weekly_bars cb ~symbol ~n ~as_of =
  let from = Date.add_days as_of (-_bar_list_history_days) in
  let bars = _daily_bars_in_range cb ~symbol ~from ~as_of in
  if List.is_empty bars then [] else _to_weekly_bars bars ~n

let weekly_bars_for (cb : Snapshot_callbacks.t) ~symbol ~n ~as_of :
    Types.Daily_price.t list =
  if n <= 0 then [] else _fetch_weekly_bars cb ~symbol ~n ~as_of

(* Index of [as_of] in [calendar], or [-1] if absent. Exact-match contract:
   a date not in the calendar (out-of-window, off-calendar holiday) yields
   no column. *)
let _calendar_index_of (calendar : Date.t array) (as_of : Date.t) =
  Array.findi calendar ~f:(fun _ d -> Date.equal d as_of)
  |> Option.value_map ~default:(-1) ~f:fst

(* Walk calendar columns [from_idx..as_of_idx], emit one row per non-NaN
   close. Missing snapshot rows leave NaN in the close lookup, same NaN-close
   skip semantics. *)
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

(* Read close/high/low histories for [daily_view_for]; returns [None] when
   close rows are absent, [Some (close_t, high_t, low_t)] otherwise. *)
let _read_close_high_low cb ~symbol ~from_date ~until_date =
  let read field =
    _read_history_or_empty cb ~symbol ~from:from_date ~until:until_date ~field
  in
  let close = read Snapshot_schema.Close in
  if List.is_empty close then None
  else
    let high = read Snapshot_schema.High in
    let low = read Snapshot_schema.Low in
    Some (_table_of close, _table_of high, _table_of low)

(* Build a daily view from a valid [as_of_idx]; reads and walks the window. *)
let _daily_view_from_idx cb ~symbol ~calendar ~as_of_idx ~lookback =
  let from_idx = max 0 (as_of_idx - lookback + 1) in
  let from_date = calendar.(from_idx) in
  let until_date = calendar.(as_of_idx) in
  match _read_close_high_low cb ~symbol ~from_date ~until_date with
  | None -> _empty_daily_view
  | Some (close_t, high_t, low_t) ->
      _walk_daily_view_window ~calendar ~from_idx ~as_of_idx ~close_t ~high_t
        ~low_t

(* Locate [as_of] in [calendar] and build a daily view; called when lookback > 0. *)
let _find_and_build_daily_view cb ~symbol ~as_of ~lookback ~calendar =
  let as_of_idx = _calendar_index_of calendar as_of in
  if as_of_idx < 0 then _empty_daily_view
  else _daily_view_from_idx cb ~symbol ~calendar ~as_of_idx ~lookback

(* [~calendar] pins the window deterministically (pre-#848 path used
   ambiguous "lookback rows" semantics that diverged from the panel path). *)
let daily_view_for (cb : Snapshot_callbacks.t) ~symbol ~as_of ~lookback
    ~calendar =
  if lookback <= 0 then _empty_daily_view
  else _find_and_build_daily_view cb ~symbol ~as_of ~lookback ~calendar

(* Fill a pre-allocated bigarray window with Low field values keyed by
   calendar date; missing rows → NaN. *)
let _fill_low_buf ~calendar ~from_idx ~len ~low_t buf =
  for j = 0 to len - 1 do
    let date = calendar.(from_idx + j) in
    let v = Hashtbl.find low_t date |> Option.value ~default:Float.nan in
    BA1.set buf j v
  done

(* Fetch Low rows and fill the bigarray window; [from_idx] and bounds are
   pre-validated by [low_window]. *)
let _low_buf_from_idx (cb : Snapshot_callbacks.t) ~symbol ~calendar ~from_idx
    ~as_of_idx ~len =
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
      _fill_low_buf ~calendar ~from_idx ~len ~low_t buf;
      Some buf

(* Validate calendar bounds and fetch Low buf; called when len > 0. *)
let _check_and_fetch_low cb ~symbol ~as_of ~len ~calendar =
  let n_cal = Array.length calendar in
  let as_of_idx = _calendar_index_of calendar as_of in
  let from_idx = as_of_idx - len + 1 in
  if as_of_idx < 0 || from_idx < 0 || as_of_idx >= n_cal then None
  else _low_buf_from_idx cb ~symbol ~calendar ~from_idx ~as_of_idx ~len

(* Walk calendar columns → fresh [Bigarray.Array1.t]; missing rows → NaN.
   Returns [None] on len≤0, as_of absent from calendar, window underflow,
   or unknown symbol. *)
let low_window (cb : Snapshot_callbacks.t) ~symbol ~as_of ~len ~calendar =
  if len <= 0 then None
  else _check_and_fetch_low cb ~symbol ~as_of ~len ~calendar
