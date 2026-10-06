open Core
open Result.Let_syntax
module Portfolio = Trading_portfolio.Portfolio
module Calculations = Trading_portfolio.Calculations

type source = No_yield | Constant of float | Series of string
[@@deriving sexp, eq, show]

let default_fee_bp = 10.0
let _bp_per_pct = 100.0
let _pct_per_unit = 100.0

(* ACT/360: the bank-discount basis T-bills are quoted on (see [.mli]). *)
let _day_count_basis = 360.0

type rates = Flat of float | Dated of (Date.t * float) array
type t = { rates : rates; fee_bp : float }

let constant ~rate_pct ~fee_bp = { rates = Flat rate_pct; fee_bp }

let of_series points ~fee_bp =
  match List.sort points ~compare:(fun (a, _) (b, _) -> Date.compare a b) with
  | [] -> Status.error_invalid_argument "Cash_yield: empty rate series"
  | sorted -> Ok { rates = Dated (Array.of_list sorted); fee_bp }

let _malformed ~line_no line =
  Status.error_invalid_argument
    (sprintf "Cash_yield: malformed rate row at line %d: %S" line_no line)

let _is_missing_value v = String.is_empty v || String.equal v "."

let _parse_value ~line_no ~line date v =
  if _is_missing_value v then Ok None
  else
    match Float.of_string_opt v with
    | Some rate -> Ok (Some (date, rate))
    | None -> _malformed ~line_no line

let _parse_line ~line_no line =
  match String.split (String.strip line) ~on:',' with
  | [ "" ] -> Ok None
  | [ d; v ] -> (
      match Date.of_string (String.strip d) with
      | date -> _parse_value ~line_no ~line date (String.strip v)
      | exception _ when line_no = 1 -> Ok None
      | exception _ -> _malformed ~line_no line)
  | _ -> _malformed ~line_no line

let parse_series_csv contents =
  String.split_lines contents
  |> List.mapi ~f:(fun i line -> _parse_line ~line_no:(i + 1) line)
  |> Result.all
  |> Result.map ~f:List.filter_opt

let _read_file path =
  match In_channel.read_all path with
  | contents -> Ok contents
  | exception Sys_error msg ->
      Status.error_not_found (sprintf "Cash_yield: cannot read %s: %s" path msg)

let _resolve_path ~data_dir path =
  if Filename.is_relative path then Filename.concat data_dir path else path

let _load_series ~fee_bp path =
  let%bind contents = _read_file path in
  let%bind points = parse_series_csv contents in
  of_series points ~fee_bp

let resolve source ~fee_bp ~data_dir =
  match source with
  | No_yield -> Ok None
  | Constant rate_pct -> Ok (Some (constant ~rate_pct ~fee_bp))
  | Series path ->
      let%map t = _load_series ~fee_bp (_resolve_path ~data_dir path) in
      Some t

let _before_series_error ~date ~first =
  Status.error_invalid_argument
    (sprintf "Cash_yield: date %s precedes the rate series start %s"
       (Date.to_string date) (Date.to_string first))

let _gross_pct t date =
  match t.rates with
  | Flat rate -> Ok rate
  | Dated points -> (
      match
        Array.binary_search points
          ~compare:(fun (d, _) key -> Date.compare d key)
          `Last_less_than_or_equal_to date
      with
      | Some i -> Ok (snd points.(i))
      | None -> _before_series_error ~date ~first:(fst points.(0)))

let net_annual_pct t date =
  let%map gross = _gross_pct t date in
  Float.max 0.0 (gross -. (t.fee_bp /. _bp_per_pct))

let _daily_rate t date =
  let%map net = net_annual_pct t date in
  net /. _pct_per_unit /. _day_count_basis

let period_rate t ~from_ ~to_ =
  let n_days = Date.diff to_ from_ in
  List.init (Int.max 0 n_days) ~f:(fun i -> Date.add_days from_ (i + 1))
  |> List.map ~f:(_daily_rate t)
  |> Result.all
  |> Result.map ~f:(List.sum (module Float) ~f:Fn.id)

let _short_proceeds (portfolio : Portfolio.t) =
  List.sum
    (module Float)
    portfolio.positions
    ~f:(fun position ->
      let qty = Calculations.position_quantity position in
      if Float.(qty >= 0.0) then 0.0
      else Float.abs qty *. Calculations.avg_cost_of_position position)

let interest_base (portfolio : Portfolio.t) =
  Float.max 0.0
    (Trading_portfolio.Portfolio_margin.equity_cash portfolio
    -. _short_proceeds portfolio)

let accrue t ~date (portfolio : Portfolio.t) =
  let%map rate = _daily_rate t date in
  let interest = interest_base portfolio *. rate in
  ( { portfolio with current_cash = portfolio.current_cash +. interest },
    interest )

module Accrual = struct
  type rate = t
  type t = { rate : rate; start_date : Date.t; mutable total : float }

  let create rate ~start_date = { rate; start_date; total = 0.0 }

  let step acc ~date portfolio =
    match acc with
    | None -> Ok portfolio
    | Some acc when Date.( < ) date acc.start_date -> Ok portfolio
    | Some acc ->
        let%map portfolio, interest = accrue acc.rate ~date portfolio in
        acc.total <- acc.total +. interest;
        portfolio

  let total acc = acc.total
end
