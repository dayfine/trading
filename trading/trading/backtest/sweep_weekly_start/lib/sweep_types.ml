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

type coverage = {
  requested_end_date : Date.t;
  last_bar_date : Date.t;
  tolerance_days : int;
  clamped : bool;
}
[@@deriving sexp, eq, show]

type dropped_cell = { start_date : Date.t; reason : string }
[@@deriving sexp, eq, show]

type sweep_result = {
  run_date : Date.t;
  end_date : Date.t;
  symbol : string;
  initial_cash : float;
  years_back : int;
  cells : cell list;
  summary : summary;
  coverage : coverage option; [@sexp.option]
  dropped_cells : dropped_cell list; [@sexp.list]
}
[@@deriving sexp, eq, show]

type config = {
  symbol : string;
  initial_cash : float;
  years_back : int;
  end_date : Date.t;
  fixtures_root : string;
  universe_path : string;
  max_end_date_gap_days : int;
}
