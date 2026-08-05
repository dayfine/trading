(** Private OHLCV-assembly helpers for [Snapshot_bar_views]. Not part of the
    public library surface. See [.mli] for doc. *)

open Core
module Panel_views = Data_panel_snapshot.Panel_views

let empty_weekly_view : Panel_views.weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

let empty_daily_view : Panel_views.daily_view =
  {
    highs = [||];
    lows = [||];
    raw_closes = [||];
    adjusted_closes = [||];
    dates = [||];
    n_days = 0;
  }

type daily_tables = {
  close_t : (Date.t, float) Hashtbl.t;
  adj_t : (Date.t, float) Hashtbl.t;
  high_t : (Date.t, float) Hashtbl.t;
  low_t : (Date.t, float) Hashtbl.t;
}

(* Column buffers the walker fills in place; the first [count] slots are live. *)
type _daily_buffers = {
  b_highs : float array;
  b_lows : float array;
  b_raw_closes : float array;
  b_adjusted_closes : float array;
  b_dates : Date.t array;
}

let _alloc_daily_buffers ~len ~first_date =
  let f () = Array.create ~len Float.nan in
  {
    b_highs = f ();
    b_lows = f ();
    b_raw_closes = f ();
    b_adjusted_closes = f ();
    b_dates = Array.create ~len first_date;
  }

(* Copy one calendar date's cells into slot [j]. Every field other than the raw
   close degrades to NaN when the snapshot has no cell for the date — including
   [Adjusted_close], so a missing adjustment cell yields a NaN split factor
   rather than a silently-neutral 1.0. *)
let _emit_daily_row (b : _daily_buffers) (t : daily_tables) ~date ~close_v ~j =
  let find tbl = Hashtbl.find tbl date |> Option.value ~default:Float.nan in
  b.b_raw_closes.(j) <- close_v;
  b.b_adjusted_closes.(j) <- find t.adj_t;
  b.b_highs.(j) <- find t.high_t;
  b.b_lows.(j) <- find t.low_t;
  b.b_dates.(j) <- date

let walk_daily_view_window ~calendar ~from_idx ~as_of_idx
    ~(tables : daily_tables) : Panel_views.daily_view =
  let n_window = as_of_idx - from_idx + 1 in
  let b = _alloc_daily_buffers ~len:n_window ~first_date:calendar.(from_idx) in
  let count = ref 0 in
  for i = from_idx to as_of_idx do
    let date = calendar.(i) in
    match Hashtbl.find tables.close_t date with
    | None -> ()
    | Some close_v when Float.is_nan close_v -> ()
    | Some close_v ->
        _emit_daily_row b tables ~date ~close_v ~j:!count;
        Int.incr count
  done;
  let n = !count in
  if n = 0 then empty_daily_view
  else
    let take a = Array.sub a ~pos:0 ~len:n in
    {
      highs = take b.b_highs;
      lows = take b.b_lows;
      raw_closes = take b.b_raw_closes;
      adjusted_closes = take b.b_adjusted_closes;
      dates = take b.b_dates;
      n_days = n;
    }

let table_of (rows : (Date.t * float) list) =
  let tbl = Hashtbl.create (module Date) in
  List.iter rows ~f:(fun (d, v) ->
      Hashtbl.set tbl ~key:d ~data:v |> (ignore : unit -> unit));
  tbl

let _round_volume v =
  if Float.is_nan v then 0 else Int.of_float (Float.round_nearest v)

let _make_daily_price ~open_t ~active_through ~date ~close_v ~adj_v ~high_v
    ~low_v ~vol_v =
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
    active_through;
  }

let _match_ohlcv ~open_t ~active_through ~adj_t ~high_t ~low_t ~vol_t ~date
    ~close_v =
  match
    ( Hashtbl.find adj_t date,
      Hashtbl.find high_t date,
      Hashtbl.find low_t date,
      Hashtbl.find vol_t date )
  with
  | Some adj_v, Some high_v, Some low_v, Some vol_v ->
      Some
        (_make_daily_price ~open_t ~active_through ~date ~close_v ~adj_v ~high_v
           ~low_v ~vol_v)
  | _ -> None

let bar_for ~open_t ~active_through ~adj_t ~high_t ~low_t ~vol_t (date, close_v)
    =
  if Float.is_nan close_v then None
  else
    _match_ohlcv ~open_t ~active_through ~adj_t ~high_t ~low_t ~vol_t ~date
      ~close_v
