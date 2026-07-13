open Core
open Validator_types

let _date_opt s = try Some (Date.of_string s) with _ -> None
let _float_opt s = if String.is_empty s then None else Float.of_string_opt s
let _cell a i = if i < Array.length a then a.(i) else ""
let _str_opt s = if String.is_empty s then None else Some s

(* trades.csv column indices (see [Result_writer._trades_csv_header]). *)
let _t_symbol = 0
let _t_side = 1
let _t_entry_date = 2
let _t_exit_date = 3
let _t_entry_price = 5
let _t_exit_price = 6
let _t_quantity = 7
let _t_exit_trigger = 12
let _t_stop_distance = 15
let _t_stop_kind = 16

(* Trailing [position_id] column (added by #1942); absent on legacy 19-column
   rows, where [_cell] returns "" and the join falls back to symbol|entry_date. *)
let _t_position_id = 19

(* open_positions.csv column indices (symbol,side,entry_date,entry_price,qty). *)
let _o_symbol = 0
let _o_side = 1
let _o_entry_date = 2
let _o_entry_price = 3
let _o_quantity = 4

let _mk_trade a =
  {
    symbol = _cell a _t_symbol;
    side = _cell a _t_side;
    entry_date = Date.of_string (_cell a _t_entry_date);
    exit_date = Date.of_string (_cell a _t_exit_date);
    entry_price = Float.of_string (_cell a _t_entry_price);
    exit_price = Float.of_string (_cell a _t_exit_price);
    quantity = Float.of_string (_cell a _t_quantity);
    exit_trigger = _cell a _t_exit_trigger;
    stop_trigger_kind = _cell a _t_stop_kind;
    stop_initial_distance_pct = _float_opt (_cell a _t_stop_distance);
    position_id = _str_opt (_cell a _t_position_id);
  }

(* A trades.csv row is well-formed when its date + numeric cells all parse. *)
let _trade_ok a =
  Option.is_some (_date_opt (_cell a _t_entry_date))
  && Option.is_some (_date_opt (_cell a _t_exit_date))
  && Option.is_some (_float_opt (_cell a _t_entry_price))
  && Option.is_some (_float_opt (_cell a _t_exit_price))
  && Option.is_some (_float_opt (_cell a _t_quantity))

let _parse_trade_line line =
  let a = Array.of_list (String.split line ~on:',') in
  if _trade_ok a then Some (_mk_trade a) else None

let _mk_open a =
  {
    symbol = _cell a _o_symbol;
    side = _cell a _o_side;
    entry_date = Date.of_string (_cell a _o_entry_date);
    entry_price = Float.of_string (_cell a _o_entry_price);
    quantity = Float.of_string (_cell a _o_quantity);
  }

let _open_ok a =
  Option.is_some (_date_opt (_cell a _o_entry_date))
  && Option.is_some (_float_opt (_cell a _o_entry_price))
  && Option.is_some (_float_opt (_cell a _o_quantity))

let _parse_open_line line =
  let a = Array.of_list (String.split line ~on:',') in
  if _open_ok a then Some (_mk_open a) else None

let _drop_header = function [] | [ _ ] -> [] | _ :: rows -> rows

let parse_trades_csv path =
  In_channel.read_lines path |> _drop_header
  |> List.filter_map ~f:_parse_trade_line

let parse_open_positions_csv path =
  In_channel.read_lines path |> _drop_header
  |> List.filter_map ~f:_parse_open_line

let _entry_context_of (e : Backtest.Trade_audit.entry_decision) =
  {
    stage = e.stage;
    macro_trend = e.macro_trend;
    ma_direction = e.ma_direction;
    resistance_quality = e.resistance_quality;
  }

type audit_join_row = {
  position_id : string;
  symbol : string;
  entry_date : Date.t;
  context : entry_context;
}

let _sd_key ~symbol ~entry_date = symbol ^ "|" ^ Date.to_string entry_date

let _records_of_sexp sexp =
  try (Backtest.Trade_audit.audit_blob_of_sexp sexp).audit_records
  with _ -> (
    try Backtest.Trade_audit.audit_records_of_sexp sexp with _ -> [])

(* Audit records are keyed by position_id AND (symbol, entry_date). The latter
   misses on real runs because the audit entry_date is the SIGNAL Friday while a
   trades.csv row carries the FILL date (next trading day) — so a row that
   carries a position_id must join on it, and only legacy rows without one fall
   back to the symbol|date key. *)
let _build_audit_tables records =
  let by_pid = Hashtbl.create (module String) in
  let by_sd = Hashtbl.create (module String) in
  List.iter records ~f:(fun (r : audit_join_row) ->
      Hashtbl.set by_pid ~key:r.position_id ~data:r.context;
      Hashtbl.set by_sd
        ~key:(_sd_key ~symbol:r.symbol ~entry_date:r.entry_date)
        ~data:r.context);
  (by_pid, by_sd)

let _lookup (by_pid, by_sd) (row : trade_row) =
  match row.position_id with
  | Some pid -> Hashtbl.find by_pid pid
  | None -> Hashtbl.find by_sd (_sd_key ~symbol:row.symbol ~entry_date:row.entry_date)

let build_audit_lookup rows = _lookup (_build_audit_tables rows)

let _join_row_of_record (r : Backtest.Trade_audit.audit_record) =
  let e = r.entry in
  {
    position_id = e.position_id;
    symbol = e.symbol;
    entry_date = e.entry_date;
    context = _entry_context_of e;
  }

let load_audit_lookup path =
  match try Some (Sexp.load_sexp path) with _ -> None with
  | None -> fun _ -> None
  | Some sexp ->
      build_audit_lookup (List.map (_records_of_sexp sexp) ~f:_join_row_of_record)

(* Two dates share an ISO trading week iff (year, week_number) match. *)
let _same_week d1 d2 =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

(* Last daily bar of each ISO week, dropping a trailing week whose last
   observed day is not a Friday. Mirrors
   [Time_period.Conversion.daily_to_weekly ~include_partial_week:false] for
   the (date, adjusted_close) fields this validator reads — inlined so this
   trading/trading/backtest library carries no analysis/ indicator import
   (architecture rule A2). *)
let _ends_on_friday (b : Types.Daily_price.t) =
  Day_of_week.equal (Date.day_of_week b.date) Day_of_week.Fri

(* Drop the trailing week when its last observed day is not a Friday. *)
let _drop_trailing_partial last_bars =
  match List.rev last_bars with
  | last :: rest_rev when not (_ends_on_friday last) -> List.rev rest_rev
  | _ -> last_bars

let _weekly_last_bars (daily : Types.Daily_price.t list) =
  let groups =
    List.group daily ~break:(fun a b ->
        not (_same_week a.Types.Daily_price.date b.Types.Daily_price.date))
  in
  _drop_trailing_partial (List.filter_map groups ~f:List.last)

let _bars_of_daily daily =
  let weekly = _weekly_last_bars daily in
  {
    weekly_dates =
      Array.of_list_map weekly ~f:(fun b -> b.Types.Daily_price.date);
    weekly_closes =
      Array.of_list_map weekly ~f:(fun b -> b.Types.Daily_price.adjusted_close);
    daily =
      Array.of_list_map daily ~f:(fun (b : Types.Daily_price.t) ->
          (b.date, b.close_price, b.volume));
  }

let _load_one ~data_dir ~run_end symbol =
  let open Result.Let_syntax in
  let%bind storage =
    Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol
  in
  let%map daily = Csv.Csv_storage.get storage ~end_date:run_end () in
  _bars_of_daily daily

let load_bars ~data_dir ~run_end =
  let cache = Hashtbl.create (module String) in
  fun symbol ->
    Hashtbl.find_or_add cache symbol ~default:(fun () ->
        _load_one ~data_dir ~run_end symbol |> Result.ok)
