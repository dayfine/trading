open Core
module T = Tax_types

type winner_row = {
  symbol : string;
  exit_year : int;
  days_held : int;
  days_to_lt : int;
  pnl : float;
  is_long_term : bool;
  st_tax : float;
  lt_tax : float;
  boundary_tax_delta : float;
}
[@@deriving sexp, equal]

let _row ~st_rate ~lt_rate ~lt_days (tr : T.realized_trade) =
  let is_long_term = tr.days_held >= lt_days in
  let days_to_lt = Int.max 0 (lt_days - tr.days_held) in
  let st_tax = tr.pnl *. st_rate and lt_tax = tr.pnl *. lt_rate in
  let boundary_tax_delta = if is_long_term then 0. else st_tax -. lt_tax in
  {
    symbol = tr.symbol;
    exit_year = tr.exit_year;
    days_held = tr.days_held;
    days_to_lt;
    pnl = tr.pnl;
    is_long_term;
    st_tax;
    lt_tax;
    boundary_tax_delta;
  }

let top_winners (config : Tax_config.t) (trades : T.realized_trade list) =
  let st_rate, lt_rate = Tax_config.effective_rates config in
  trades
  |> List.filter ~f:(fun t -> Float.(t.pnl > 0.))
  |> List.sort ~compare:(fun a b -> Float.compare b.pnl a.pnl)
  |> (fun l -> List.take l config.top_winners)
  |> List.map ~f:(_row ~st_rate ~lt_rate ~lt_days:config.lt_days)
