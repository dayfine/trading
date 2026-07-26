open Core

type realized_trade = {
  symbol : string;
  exit_year : int;
  days_held : int;
  pnl : float;
  side : string;
}
[@@deriving sexp, equal]

type run_data = {
  trades : realized_trade list;
  equity_year_ends : (int * float) list;
  initial_capital : float;
  span_years : float;
}
[@@deriving sexp]
