open Core
module T = Tax_types

let _fields line = String.split line ~on:','

(* trades.csv: 0 symbol, 1 side, 3 exit_date, 4 days_held, 8 pnl_dollars. *)
let _trade_of_line line : T.realized_trade option =
  match _fields line with
  | symbol :: side :: _entry :: exit_date :: days_held :: _entry_p :: _exit_p
    :: _qty :: pnl :: _ ->
      Some
        {
          symbol;
          side;
          exit_year = Date.of_string exit_date |> Date.year;
          days_held = Int.of_string days_held;
          pnl = Float.of_string pnl;
        }
  | _ -> None

let _load_trades path =
  match In_channel.read_lines path with
  | [] -> []
  | _header :: rows -> List.filter_map rows ~f:_trade_of_line

(* equity_curve.csv: date, portfolio_value. Returns (year-end values, initial,
   first date, last date). Rows are ascending, so last-seen per year wins. *)
let _load_equity path =
  match In_channel.read_lines path with
  | [] | [ _ ] -> failwithf "empty equity curve: %s" path ()
  | _header :: (first :: _ as rows) ->
      let parse l =
        match _fields l with
        | date :: value :: _ -> Some (Date.of_string date, Float.of_string value)
        | _ -> None
      in
      let parsed = List.filter_map rows ~f:parse in
      let first_date, initial =
        parse first |> Option.value_exn ~message:"unparseable first equity row"
      in
      let tbl = Hashtbl.create (module Int) in
      let last_date = ref first_date in
      List.iter parsed ~f:(fun (d, v) ->
          last_date := d;
          Hashtbl.set tbl ~key:(Date.year d) ~data:v);
      let year_ends =
        Hashtbl.to_alist tbl
        |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
      in
      (year_ends, initial, first_date, !last_date)

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
    span_years = Float.of_int days /. 365.25;
  }
