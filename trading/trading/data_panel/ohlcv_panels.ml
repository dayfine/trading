open Core
open Csv
module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

type t = {
  symbol_index : Symbol_index.t;
  n_rows : int;
  n_cols : int;
  open_ : panel;
  high : panel;
  low : panel;
  close : panel;
  volume : panel;
}

let _make_nan_panel ~n_rows ~n_cols : panel =
  let p = BA2.create Bigarray.Float64 Bigarray.C_layout n_rows n_cols in
  BA2.fill p Float.nan;
  p

let create symbol_index ~n_days =
  if n_days < 0 then
    invalid_arg
      (Printf.sprintf "Ohlcv_panels.create: n_days must be >= 0, got %d" n_days);
  let n_rows = Symbol_index.n symbol_index in
  let n_cols = n_days in
  {
    symbol_index;
    n_rows;
    n_cols;
    open_ = _make_nan_panel ~n_rows ~n_cols;
    high = _make_nan_panel ~n_rows ~n_cols;
    low = _make_nan_panel ~n_rows ~n_cols;
    close = _make_nan_panel ~n_rows ~n_cols;
    volume = _make_nan_panel ~n_rows ~n_cols;
  }

let n t = t.n_rows
let n_days t = t.n_cols
let symbol_index t = t.symbol_index
let open_ t = t.open_
let high t = t.high
let low t = t.low
let close t = t.close
let volume t = t.volume

let _check_bounds t ~symbol_index ~day =
  if symbol_index < 0 || symbol_index >= t.n_rows then
    invalid_arg
      (Printf.sprintf
         "Ohlcv_panels.write_row: symbol_index %d out of range [0, %d)"
         symbol_index t.n_rows);
  if day < 0 || day >= t.n_cols then
    invalid_arg
      (Printf.sprintf "Ohlcv_panels.write_row: day %d out of range [0, %d)" day
         t.n_cols)

let write_row t ~symbol_index ~day (price : Types.Daily_price.t) =
  _check_bounds t ~symbol_index ~day;
  BA2.unsafe_set t.open_ symbol_index day price.open_price;
  BA2.unsafe_set t.high symbol_index day price.high_price;
  BA2.unsafe_set t.low symbol_index day price.low_price;
  BA2.unsafe_set t.close symbol_index day price.close_price;
  BA2.unsafe_set t.volume symbol_index day (Float.of_int price.volume)

let _csv_path_for ~data_dir symbol =
  let symbol_dir = Csv_storage.symbol_data_dir ~data_dir symbol in
  Fpath.(symbol_dir / "data.csv") |> Fpath.to_string

let _load_one_symbol_into_panels t ~row ~start_date ~n_days ~data_dir symbol =
  let path = _csv_path_for ~data_dir symbol in
  match Sys_unix.file_exists path with
  | `No | `Unknown -> Ok () (* tolerate missing CSV: row stays NaN *)
  | `Yes -> (
      match Csv_storage.create ~data_dir symbol with
      | Error err -> Error err
      | Ok storage -> (
          match Csv_storage.get storage ~start_date () with
          | Error err ->
              if Status.equal_code err.code Status.NotFound then Ok ()
              else Error err
          | Ok prices ->
              let n_to_write = Int.min n_days (List.length prices) in
              List.iteri (List.take prices n_to_write) ~f:(fun day price ->
                  write_row t ~symbol_index:row ~day price);
              Ok ()))

let load_from_csv symbol_index ~data_dir ~start_date ~n_days =
  let t = create symbol_index ~n_days in
  let universe = Symbol_index.symbols symbol_index in
  let result =
    List.foldi universe ~init:(Ok ()) ~f:(fun row acc symbol ->
        match acc with
        | Error _ as e -> e
        | Ok () ->
            _load_one_symbol_into_panels t ~row ~start_date ~n_days ~data_dir
              symbol)
  in
  match result with Ok () -> Ok t | Error err -> Error err

(* Build a [Date.t -> column] lookup from the calendar. The calendar is small
   (typically a few thousand entries for multi-year backtests), so a Hashtbl
   keyed on Date.t makes the per-bar resolution O(1). On duplicate dates in
   the calendar (shouldn't happen but be defensive) keep the first
   occurrence. *)
let _calendar_index calendar =
  let tbl = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add tbl ~key:d ~data:i |> (ignore : [ `Ok | `Duplicate ] -> unit));
  tbl

let _early_start_date = Date.create_exn ~y:1900 ~m:Month.Jan ~d:1

(* Read every bar by passing a very early start_date; the calendar then
   filters which bars actually land in the panels. *)
let _load_one_symbol_calendar t ~row ~calendar_idx ~data_dir symbol =
  let path = _csv_path_for ~data_dir symbol in
  match Sys_unix.file_exists path with
  | `No | `Unknown -> Ok () (* tolerate missing CSV: row stays NaN *)
  | `Yes -> (
      match Csv_storage.create ~data_dir symbol with
      | Error err -> Error err
      | Ok storage -> (
          match Csv_storage.get storage ~start_date:_early_start_date () with
          | Error err ->
              if Status.equal_code err.code Status.NotFound then Ok ()
              else Error err
          | Ok prices ->
              List.iter prices ~f:(fun (price : Types.Daily_price.t) ->
                  match Hashtbl.find calendar_idx price.date with
                  | None -> () (* date not in calendar: skip *)
                  | Some day -> write_row t ~symbol_index:row ~day price);
              Ok ()))

let load_from_csv_calendar symbol_index ~data_dir ~calendar =
  let n_days = Array.length calendar in
  let t = create symbol_index ~n_days in
  let calendar_idx = _calendar_index calendar in
  let universe = Symbol_index.symbols symbol_index in
  let result =
    List.foldi universe ~init:(Ok ()) ~f:(fun row acc symbol ->
        match acc with
        | Error _ as e -> e
        | Ok () ->
            _load_one_symbol_calendar t ~row ~calendar_idx ~data_dir symbol)
  in
  match result with Ok () -> Ok t | Error err -> Error err
