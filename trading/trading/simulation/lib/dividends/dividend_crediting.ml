open Core
open Result.Let_syntax
module Portfolio = Trading_portfolio.Portfolio
module Calculations = Trading_portfolio.Calculations

type loader = string -> Corporate_actions.dividend list Status.status_or

type totals = {
  long_income : float;
  short_paid : float;
  skipped_no_amount : int;
  missing_files : int;
}
[@@deriving show, eq]

type t = {
  load : loader;
  cache : Corporate_actions.dividend list String.Table.t;
  mutable credited_through : Date.t;
  mutable totals : totals;
}

let _zero_totals =
  {
    long_income = 0.0;
    short_paid = 0.0;
    skipped_no_amount = 0;
    missing_files = 0;
  }

(* [credited_through] starts the day before [start_date], so the first step on
   or after [start_date] covers ex-dates from [start_date] on. *)
let create ~load ~start_date =
  {
    load;
    cache = String.Table.create ();
    credited_through = Date.add_days start_date (-1);
    totals = _zero_totals;
  }

let of_data_dir ~data_dir ~start_date =
  create ~load:(Corporate_actions.read_dividends ~data_dir) ~start_date

let totals t = t.totals

let _count_missing_file t =
  t.totals <- { t.totals with missing_files = t.totals.missing_files + 1 }

let _dividends_for t symbol =
  match Hashtbl.find t.cache symbol with
  | Some divs -> Ok divs
  | None ->
      let%map divs =
        match t.load symbol with
        | Ok divs -> Ok divs
        | Error { Status.code = NotFound; _ } ->
            _count_missing_file t;
            Ok []
        | Error e -> Error e
      in
      Hashtbl.set t.cache ~key:symbol ~data:divs;
      divs

(* Cash change of one dividend event on a position of signed [qty]: positive
   for a long (income), negative for a short (payment). [None] amounts are
   skipped and counted, never filled from [adjusted_amount]. *)
let _event_cash t ~qty (div : Corporate_actions.dividend) =
  match div.unadjusted_amount with
  | None ->
      t.totals <-
        { t.totals with skipped_no_amount = t.totals.skipped_no_amount + 1 };
      0.0
  | Some amount ->
      let cash = qty *. amount in
      if Float.(qty > 0.0) then
        t.totals <- { t.totals with long_income = t.totals.long_income +. cash }
      else
        t.totals <- { t.totals with short_paid = t.totals.short_paid -. cash };
      cash

let _in_window ~from_ ~to_ (div : Corporate_actions.dividend) =
  Date.( > ) div.ex_date from_ && Date.( <= ) div.ex_date to_

let _position_cash t ~from_ ~to_
    (position : Trading_portfolio.Types.portfolio_position) =
  let qty = Calculations.position_quantity position in
  if Float.(qty = 0.0) then Ok 0.0
  else
    let%map divs = _dividends_for t position.symbol in
    List.filter divs ~f:(_in_window ~from_ ~to_)
    |> List.sum (module Float) ~f:(_event_cash t ~qty)

let _credit t ~date (portfolio : Portfolio.t) =
  let from_ = t.credited_through in
  let%map changes =
    List.map portfolio.positions ~f:(_position_cash t ~from_ ~to_:date)
    |> Result.all
  in
  t.credited_through <- date;
  {
    portfolio with
    current_cash =
      portfolio.current_cash +. List.sum (module Float) changes ~f:Fn.id;
  }

let step t ~date portfolio =
  match t with
  | None -> Ok portfolio
  | Some t when Date.( <= ) date t.credited_through -> Ok portfolio
  | Some t -> _credit t ~date portfolio
