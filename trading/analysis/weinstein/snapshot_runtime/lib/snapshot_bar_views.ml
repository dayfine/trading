(** Bar-shaped views over [Snapshot_callbacks.t] — see [snapshot_bar_views.mli].
*)

open Core
module BA1 = Bigarray.Array1
module Bar_panels = Data_panel.Bar_panels
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Phase F.2 PR 2: views are type-equal to [Bar_panels]'s — see the .mli. The
   record definitions live in [Bar_panels] today; PR 3 (Phase F.3) hoists them
   here when [Bar_panels] is deleted. *)
type weekly_view = Bar_panels.weekly_view
type daily_view = Bar_panels.daily_view

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

(* Calendar slack for date-keyed weekly windows. The snapshot fan-out is
   per-field over an inclusive [from, until] window; [from] is computed by
   walking back from [as_of]. We need enough slack to cover weekends +
   holidays + partial weeks. 8x weeks-to-days conversion (7 weekdays + 1
   holiday slack) covers ISO-week buckets + a partial leading week. *)
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

let _assemble_daily_bars ~adj ~close ~high ~low ~open_ ~volume :
    Types.Daily_price.t list =
  let adj_t = _table_of adj in
  let high_t = _table_of high in
  let low_t = _table_of low in
  let open_t = _table_of open_ in
  let vol_t = _table_of volume in
  let bar_for (date, close_v) =
    if Float.is_nan close_v then None
    else
      match
        ( Hashtbl.find adj_t date,
          Hashtbl.find high_t date,
          Hashtbl.find low_t date,
          Hashtbl.find open_t date,
          Hashtbl.find vol_t date )
      with
      | Some adj_v, Some high_v, Some low_v, Some open_v, Some vol_v ->
          Some
            {
              Types.Daily_price.date;
              open_price = open_v;
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
    let adj = read Snapshot_schema.Adjusted_close in
    let high = read Snapshot_schema.High in
    let low = read Snapshot_schema.Low in
    let open_ = read Snapshot_schema.Open in
    let volume = read Snapshot_schema.Volume in
    _assemble_daily_bars ~adj ~close ~high ~low ~open_ ~volume

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

(* Mon-Fri only — no NYSE holiday calendar. The panel's runtime calendar
   ([Panel_runner._build_calendar] / [diag_panel_vs_snapshot_extended._build_calendar])
   is built the same way, so the two paths walk the same set of dates. *)
let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

(* Build the [n] weekday dates ending at [as_of] (inclusive), in chronological
   order. [as_of] must itself be a weekday (caller checks). Walks back day by
   day, skipping Sat/Sun, until [n] dates have been collected. *)
let _weekdays_ending_at ~as_of ~n =
  let rec loop d acc remaining =
    if remaining = 0 then acc
    else if _is_weekday d then
      loop (Date.add_days d (-1)) (d :: acc) (remaining - 1)
    else loop (Date.add_days d (-1)) acc remaining
  in
  loop as_of [] n

(* Bar_panels.daily_view_for walks the last [lookback] calendar columns
   ending at [as_of_day] (the panel calendar is all weekdays Mon-Fri,
   including holidays — see [Panel_runner._build_calendar]) and NaN-skips
   per cell. Result count = lookback − n_nan_cells_in_window.

   Snapshot equivalent: build the same [lookback] weekday window ending at
   [as_of], look up Close/High/Low per date in the snapshot, drop dates
   missing from the snapshot (= holidays / no-data days, panel cell would
   be NaN there) and dates whose Close field is NaN (matches panel's NaN
   skip on the close panel). *)
let daily_view_for (cb : Snapshot_callbacks.t) ~symbol ~as_of ~lookback =
  if lookback <= 0 || not (_is_weekday as_of) then _empty_daily_view
  else
    let weekdays = _weekdays_ending_at ~as_of ~n:lookback in
    let from = match weekdays with [] -> as_of | d :: _ -> d in
    let read field =
      _read_history_or_empty cb ~symbol ~from ~until:as_of ~field
    in
    let close_t = _table_of (read Snapshot_schema.Close) in
    let high_t = _table_of (read Snapshot_schema.High) in
    let low_t = _table_of (read Snapshot_schema.Low) in
    let rows =
      List.filter_map weekdays ~f:(fun date ->
          match Hashtbl.find close_t date with
          | None -> None
          | Some close_v when Float.is_nan close_v -> None
          | Some close_v -> (
              match (Hashtbl.find high_t date, Hashtbl.find low_t date) with
              | Some high_v, Some low_v -> Some (date, high_v, low_v, close_v)
              | _ -> None))
    in
    let n = List.length rows in
    if n = 0 then _empty_daily_view
    else
      let arr_of f = Array.of_list (List.map rows ~f) in
      {
        highs = arr_of (fun (_, h, _, _) -> h);
        lows = arr_of (fun (_, _, l, _) -> l);
        closes = arr_of (fun (_, _, _, c) -> c);
        dates = arr_of (fun (d, _, _, _) -> d);
        n_days = n;
      }

(* low_window: produce a Bigarray.Array1.t holding the [len] daily Low values
   ending at [as_of]. Bar_panels.low_window slices the raw Low panel over
   [len] calendar columns and does NOT NaN-skip — NaN cells (holidays /
   pre-IPO / suspended days) are passed through. The panel returns [None] only
   when the symbol is not in the universe or the requested window falls
   outside the panel's calendar.

   Snapshot equivalent: build [len] weekday dates ending at [as_of], look up
   Low per date in the snapshot, fill missing dates (holidays / pre-IPO /
   suspended days) with NaN. The snapshot's [Ok []] case (symbol is in the
   manifest but has no rows in the window — typically pre-IPO) corresponds to
   the panel's "row is all NaN in the window", so we return [Some all_nan]
   rather than [None] to match panel parity.

   Returns [None] when [len <= 0], [as_of] is not a weekday, or
   [read_field_history] errors (symbol unknown, schema skew, etc.). *)
let low_window (cb : Snapshot_callbacks.t) ~symbol ~as_of ~len =
  if len <= 0 || not (_is_weekday as_of) then None
  else
    let weekdays = _weekdays_ending_at ~as_of ~n:len in
    let from = match weekdays with [] -> as_of | d :: _ -> d in
    match
      cb.read_field_history ~symbol ~from ~until:as_of
        ~field:Snapshot_schema.Low
    with
    | Error _ -> None
    | Ok rows ->
        let low_t = _table_of rows in
        let buf = BA1.create Bigarray.Float64 Bigarray.C_layout len in
        List.iteri weekdays ~f:(fun i d ->
            match Hashtbl.find low_t d with
            | Some v -> BA1.set buf i v
            | None -> BA1.set buf i Float.nan);
        Some buf
