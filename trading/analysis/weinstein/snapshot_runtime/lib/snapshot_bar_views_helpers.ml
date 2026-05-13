(** Private OHLCV-assembly helpers for [Snapshot_bar_views]. Not part of the
    public library surface. See [.mli] for doc. *)

open Core

let table_of (rows : (Date.t * float) list) =
  let tbl = Hashtbl.create (module Date) in
  List.iter rows ~f:(fun (d, v) ->
      Hashtbl.set tbl ~key:d ~data:v |> (ignore : unit -> unit));
  tbl

let _round_volume v =
  if Float.is_nan v then 0 else Int.of_float (Float.round_nearest v)

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
    active_through = None;
  }

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

let bar_for ~open_t ~adj_t ~high_t ~low_t ~vol_t (date, close_v) =
  if Float.is_nan close_v then None
  else _match_ohlcv ~open_t ~adj_t ~high_t ~low_t ~vol_t ~date ~close_v
