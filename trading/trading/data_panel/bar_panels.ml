(** Panel-backed bar reader — see [bar_panels.mli]. *)

open Core
module BA1 = Bigarray.Array1
module BA2 = Bigarray.Array2

type t = {
  ohlcv : Ohlcv_panels.t;
  calendar : Date.t array;
  date_to_col : (Date.t, int) Hashtbl.t;
}

let _calendar_len_mismatch ~calendar ~ohlcv =
  let n_cal = Array.length calendar in
  let n_panel = Ohlcv_panels.n_days ohlcv in
  if n_cal <> n_panel then
    Some
      (Printf.sprintf
         "Bar_panels.create: calendar length %d does not match \
          Ohlcv_panels.n_days %d"
         n_cal n_panel)
  else None

let _build_date_to_col calendar =
  let tbl = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add tbl ~key:d ~data:i |> (ignore : [ `Ok | `Duplicate ] -> unit));
  tbl

let create ~ohlcv ~calendar =
  match _calendar_len_mismatch ~calendar ~ohlcv with
  | Some msg -> Error (Status.invalid_argument_error msg)
  | None ->
      let date_to_col = _build_date_to_col calendar in
      Ok { ohlcv; calendar; date_to_col }

let symbol_index t = Ohlcv_panels.symbol_index t.ohlcv
let n_days t = Array.length t.calendar
let column_of_date t date = Hashtbl.find t.date_to_col date

let _check_as_of t ~as_of_day =
  let n = n_days t in
  if as_of_day < 0 || as_of_day >= n then
    invalid_arg
      (Printf.sprintf "Bar_panels: as_of_day %d out of range [0, %d)" as_of_day
         n)

(* Reconstruct a single Daily_price.t from row [r] / column [t]. Returns
   None if the close cell is NaN (no bar that day for this symbol). The
   volume panel is float64 but Daily_price.volume is int — round to nearest
   int. NaN volume reads as 0; the bar is dropped earlier on close=NaN
   anyway, so this only fires for malformed inputs. *)
let _read_bar ~ohlcv ~row ~day ~date : Types.Daily_price.t option =
  let close_p = Ohlcv_panels.close ohlcv in
  let close = BA2.unsafe_get close_p row day in
  if Float.is_nan close then None
  else
    let open_p = Ohlcv_panels.open_ ohlcv in
    let high_p = Ohlcv_panels.high ohlcv in
    let low_p = Ohlcv_panels.low ohlcv in
    let vol_p = Ohlcv_panels.volume ohlcv in
    let adj_p = Ohlcv_panels.adjusted_close ohlcv in
    let vol_f = BA2.unsafe_get vol_p row day in
    let volume =
      if Float.is_nan vol_f then 0 else Int.of_float (Float.round_nearest vol_f)
    in
    Some
      {
        Types.Daily_price.date;
        open_price = BA2.unsafe_get open_p row day;
        high_price = BA2.unsafe_get high_p row day;
        low_price = BA2.unsafe_get low_p row day;
        close_price = close;
        volume;
        adjusted_close = BA2.unsafe_get adj_p row day;
      }

let _row_for t symbol = Symbol_index.to_row (symbol_index t) symbol

let daily_bars_for t ~symbol ~as_of_day =
  _check_as_of t ~as_of_day;
  match _row_for t symbol with
  | None -> []
  | Some row ->
      let acc = ref [] in
      for day = as_of_day downto 0 do
        match _read_bar ~ohlcv:t.ohlcv ~row ~day ~date:t.calendar.(day) with
        | None -> ()
        | Some bar -> acc := bar :: !acc
      done;
      !acc

let weekly_bars_for t ~symbol ~n ~as_of_day =
  let daily = daily_bars_for t ~symbol ~as_of_day in
  if List.is_empty daily then []
  else
    let weekly =
      Time_period.Conversion.daily_to_weekly ~include_partial_week:true daily
    in
    let len = List.length weekly in
    if len <= n then weekly else List.drop weekly (len - n)

let low_window t ~symbol ~as_of_day ~len =
  let n = n_days t in
  let pos = as_of_day - len + 1 in
  if len <= 0 || pos < 0 || as_of_day >= n then None
  else
    (* Slice row over columns [pos..as_of_day]. [BA2.slice_left] returns the
       row as a 1D Array1; [BA1.sub] then narrows to the window. Both
       operations are zero-copy. *)
    Option.map (_row_for t symbol) ~f:(fun row ->
        let row_view = BA2.slice_left (Ohlcv_panels.low t.ohlcv) row in
        BA1.sub row_view pos len)

(* ------------------------------------------------------------------ *)
(* Float-array views (Stage 4 PR-A)                                     *)
(*                                                                      *)
(* The weekly_view / daily_view primitives walk panel cells directly    *)
(* and emit float arrays — no [Daily_price.t list] intermediate. This   *)
(* is the foundation for {!Panel_callbacks}, which builds Stage / Rs /  *)
(* Sector / Macro / Stops callback bundles over the resulting arrays.   *)
(* ------------------------------------------------------------------ *)

type weekly_view = {
  closes : float array;
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
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

let _empty_daily_view : daily_view =
  { highs = [||]; lows = [||]; closes = [||]; dates = [||]; n_days = 0 }

(* Walk panel cells along [from_day..to_day_inclusive], dropping NaN closes,
   and return the count + per-field float buffers (sized to the maximum span
   so this allocates exactly once). All buffers are written into the same
   prefix index in lockstep, so the count tells how many are valid. *)
let _read_row_cells ~ohlcv ~calendar ~row ~from_day ~to_day_inclusive =
  let n_max = to_day_inclusive - from_day + 1 in
  let highs = Array.create ~len:n_max Float.nan in
  let lows = Array.create ~len:n_max Float.nan in
  let closes = Array.create ~len:n_max Float.nan in
  let volumes = Array.create ~len:n_max Float.nan in
  let adjusted = Array.create ~len:n_max Float.nan in
  let dates = Array.create ~len:n_max calendar.(from_day) in
  let close_p = Ohlcv_panels.close ohlcv in
  let high_p = Ohlcv_panels.high ohlcv in
  let low_p = Ohlcv_panels.low ohlcv in
  let vol_p = Ohlcv_panels.volume ohlcv in
  let adj_p = Ohlcv_panels.adjusted_close ohlcv in
  let count = ref 0 in
  for day = from_day to to_day_inclusive do
    let close = BA2.unsafe_get close_p row day in
    if not (Float.is_nan close) then (
      let i = !count in
      highs.(i) <- BA2.unsafe_get high_p row day;
      lows.(i) <- BA2.unsafe_get low_p row day;
      closes.(i) <- close;
      volumes.(i) <- BA2.unsafe_get vol_p row day;
      adjusted.(i) <- BA2.unsafe_get adj_p row day;
      dates.(i) <- calendar.(day);
      Int.incr count)
  done;
  (!count, highs, lows, closes, volumes, adjusted, dates)

let _take_prefix arr n = Array.sub arr ~pos:0 ~len:n

let daily_view_for t ~symbol ~as_of_day ~lookback =
  _check_as_of t ~as_of_day;
  if lookback <= 0 then _empty_daily_view
  else
    match _row_for t symbol with
    | None -> _empty_daily_view
    | Some row ->
        let from_day = max 0 (as_of_day - lookback + 1) in
        let count, highs, lows, closes, _vol, _adj, dates =
          _read_row_cells ~ohlcv:t.ohlcv ~calendar:t.calendar ~row ~from_day
            ~to_day_inclusive:as_of_day
        in
        if count = 0 then _empty_daily_view
        else
          {
            highs = _take_prefix highs count;
            lows = _take_prefix lows count;
            closes = _take_prefix closes count;
            dates = _take_prefix dates count;
            n_days = count;
          }

(* ISO-week key: year + week number, Monday-anchored. Two adjacent days are
   in the same bucket iff [Week_bucketing] would group them. *)
let _week_key (date : Date.t) : int * int =
  (Date.year date, Date.week_number date)

(* Stage 4 PR-C: Single-pass panel-to-weekly aggregation.

   Walks panel cells [0..as_of_day] once, NaN-skips, emits weekly buckets
   directly into pre-sized output arrays. No daily-prefix intermediate (the
   pre-PR-C path allocated 6 arrays of size [as_of_day + 1] in
   [_read_row_cells] and then again 5 arrays of size [n_weeks] in
   [_aggregate_weekly]). Allocations are now O(n_weeks) per call instead of
   O(n_days + n_weeks).

   Each bucket's [date] is the latest trading day in the week (typically
   Friday for complete weeks, last traded day for partial / holiday weeks);
   [closes] is the adjusted close of that day; [highs] is max within week;
   [lows] is min within week; [volumes] is sum within week. Matches the
   pre-PR-C [_aggregate_weekly] semantics bit-for-bit. *)
let _count_weeks_in_panel ~ohlcv ~calendar ~row ~as_of_day =
  let close_p = Ohlcv_panels.close ohlcv in
  let n_weeks = ref 0 in
  let prev_key = ref (-1, -1) in
  let any_seen = ref false in
  for day = 0 to as_of_day do
    let close = BA2.unsafe_get close_p row day in
    if not (Float.is_nan close) then
      let k = _week_key calendar.(day) in
      if (not !any_seen) || not ([%equal: int * int] k !prev_key) then (
        Int.incr n_weeks;
        prev_key := k;
        any_seen := true)
  done;
  !n_weeks

let _fill_weekly_buckets ~ohlcv ~calendar ~row ~as_of_day ~w_closes ~w_highs
    ~w_lows ~w_vol ~w_dates =
  let close_p = Ohlcv_panels.close ohlcv in
  let high_p = Ohlcv_panels.high ohlcv in
  let low_p = Ohlcv_panels.low ohlcv in
  let vol_p = Ohlcv_panels.volume ohlcv in
  let adj_p = Ohlcv_panels.adjusted_close ohlcv in
  let bucket = ref (-1) in
  let cur_key = ref (-1, -1) in
  for day = 0 to as_of_day do
    let close = BA2.unsafe_get close_p row day in
    if not (Float.is_nan close) then (
      let k = _week_key calendar.(day) in
      if !bucket < 0 || not ([%equal: int * int] k !cur_key) then (
        Int.incr bucket;
        cur_key := k);
      let b = !bucket in
      let h = BA2.unsafe_get high_p row day in
      if Float.( > ) h w_highs.(b) then w_highs.(b) <- h;
      let lo = BA2.unsafe_get low_p row day in
      if Float.( < ) lo w_lows.(b) then w_lows.(b) <- lo;
      w_vol.(b) <- w_vol.(b) +. BA2.unsafe_get vol_p row day;
      w_closes.(b) <- BA2.unsafe_get adj_p row day;
      w_dates.(b) <- calendar.(day))
  done

let _weekly_view_from_panel ~ohlcv ~calendar ~row ~as_of_day : weekly_view =
  let nw = _count_weeks_in_panel ~ohlcv ~calendar ~row ~as_of_day in
  if nw = 0 then _empty_weekly_view
  else
    let w_closes = Array.create ~len:nw Float.nan in
    let w_highs = Array.create ~len:nw Float.neg_infinity in
    let w_lows = Array.create ~len:nw Float.infinity in
    let w_vol = Array.create ~len:nw 0.0 in
    let w_dates = Array.create ~len:nw calendar.(0) in
    _fill_weekly_buckets ~ohlcv ~calendar ~row ~as_of_day ~w_closes ~w_highs
      ~w_lows ~w_vol ~w_dates;
    {
      closes = w_closes;
      highs = w_highs;
      lows = w_lows;
      volumes = w_vol;
      dates = w_dates;
      n = nw;
    }

let weekly_view_for t ~symbol ~n ~as_of_day =
  _check_as_of t ~as_of_day;
  match _row_for t symbol with
  | None -> _empty_weekly_view
  | Some row ->
      let view =
        _weekly_view_from_panel ~ohlcv:t.ohlcv ~calendar:t.calendar ~row
          ~as_of_day
      in
      if view.n <= n then view
      else
        let drop = view.n - n in
        let take a = Array.sub a ~pos:drop ~len:n in
        {
          closes = take view.closes;
          highs = take view.highs;
          lows = take view.lows;
          volumes = take view.volumes;
          dates = take view.dates;
          n;
        }
