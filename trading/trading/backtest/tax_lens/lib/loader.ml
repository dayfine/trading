open Core
module T = Tax_types

let _fields line = String.split line ~on:','

(* Calendar-year length in days, for the CAGR span conversion. *)
let _days_per_year = 365.25

let _realized_trade ~symbol ~side ~exit_date ~days_held ~pnl : T.realized_trade
    =
  {
    symbol;
    side;
    exit_year = Date.of_string exit_date |> Date.year;
    days_held = Int.of_string days_held;
    pnl = Float.of_string pnl;
  }

(* trades.csv: 0 symbol, 1 side, 3 exit_date, 4 days_held, 8 pnl_dollars. A row
   with fewer than 9 fields is malformed and raises — it is never silently
   dropped, so [load_exn]'s "raises on malformed input" contract holds for
   short rows, not just rows with bad field content. *)
let _trade_of_line line : T.realized_trade =
  match _fields line with
  | symbol :: side :: _entry :: exit_date :: days_held :: _entry_p :: _exit_p
    :: _qty :: pnl :: _ ->
      _realized_trade ~symbol ~side ~exit_date ~days_held ~pnl
  | fields ->
      failwithf "malformed trades.csv row (expected >= 9 fields, got %d): %s"
        (List.length fields) line ()

let _load_trades path =
  match In_channel.read_lines path with
  | [] -> []
  | _header :: rows -> List.map rows ~f:_trade_of_line

(* equity_curve.csv: 0 date, 1 portfolio_value. A row with fewer than 2 fields
   is malformed and raises — it is never silently dropped, mirroring
   [_trade_of_line]'s contract for trades.csv, so [load_exn]'s "raises on
   malformed input" contract holds for every data row, not just the first. *)
let _equity_row line : Date.t * float =
  match _fields line with
  | date :: value :: _ -> (Date.of_string date, Float.of_string value)
  | fields ->
      failwithf
        "malformed equity_curve.csv row (expected >= 2 fields, got %d): %s"
        (List.length fields) line ()

(* Last equity value per year, ascending by year. Rows are date-ascending, so
   the last-seen value per year wins. *)
let _year_ends parsed =
  let tbl = Hashtbl.create (module Int) in
  List.iter parsed ~f:(fun (d, v) -> Hashtbl.set tbl ~key:(Date.year d) ~data:v);
  Hashtbl.to_alist tbl
  |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)

(* equity_curve.csv: date, portfolio_value. Returns (year-end values, initial,
   first date, last date). [rows] is non-empty here (the [[] | [ _ ]] case
   above already handled the "no data rows" case), so [List.hd_exn] is
   safe. *)
let _load_equity path =
  match In_channel.read_lines path with
  | [] | [ _ ] -> failwithf "empty equity curve: %s" path ()
  | _header :: rows ->
      let parsed = List.map rows ~f:_equity_row in
      let first_date, initial = List.hd_exn parsed in
      let last_date =
        List.last parsed |> Option.value_map ~default:first_date ~f:fst
      in
      (_year_ends parsed, initial, first_date, last_date)

let load_exn dir =
  let trades = _load_trades (Filename.concat dir "trades.csv") in
  let year_ends, initial_capital, first_date, last_date =
    _load_equity (Filename.concat dir "equity_curve.csv")
  in
  let days = Date.diff last_date first_date in
  {
    T.trades;
    equity_year_ends = year_ends;
    initial_capital;
    span_years = Float.of_int days /. _days_per_year;
  }
