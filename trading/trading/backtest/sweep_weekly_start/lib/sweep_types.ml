open Core

type cell = {
  start_date : Date.t;
  final_value : float;
  total_return : float;
  cagr : float;
  max_dd : float;
  sharpe : float;
}
[@@deriving sexp, eq, show]

type summary = {
  best_cell_start : Date.t;
  best_cagr : float;
  worst_cell_start : Date.t;
  worst_cagr : float;
  median_cagr : float;
  mean_cagr : float;
  stddev_cagr : float;
  n_cells : int;
}
[@@deriving sexp, eq, show]

type sweep_result = {
  run_date : Date.t;
  end_date : Date.t;
  symbol : string;
  initial_cash : float;
  years_back : int;
  cells : cell list;
  summary : summary;
}
[@@deriving sexp, eq, show]

type config = {
  symbol : string;
  initial_cash : float;
  years_back : int;
  end_date : Date.t;
  fixtures_root : string;
  universe_path : string;
}
