(** Panel-backed bar reader — see [bar_panels.mli]. *)

open Core
module BA1 = Bigarray.Array1
module BA2 = Bigarray.Array2

type t = { ohlcv : Ohlcv_panels.t; calendar : Date.t array }

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

let create ~ohlcv ~calendar =
  match _calendar_len_mismatch ~calendar ~ohlcv with
  | Some msg -> Error (Status.invalid_argument_error msg)
  | None -> Ok { ohlcv; calendar }

let symbol_index t = Ohlcv_panels.symbol_index t.ohlcv
let n_days t = Array.length t.calendar

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
