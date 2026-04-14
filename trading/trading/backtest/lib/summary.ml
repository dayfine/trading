open Core

(** Floats rendered with [%.2f] — avoids full-precision noise in the
    human-readable summary sexp. *)
module Money = struct
  type t = float

  let sexp_of_t f = Sexp.Atom (sprintf "%.2f" f)
end

(** Metrics rendered via [metric_set_to_sexp_pairs] — lowercased metric keys and
    [%.2f] values, matching the format emitted since the first backtest runs.
    The default [sexp_of_metric_set] uses capitalized variant names and
    full-precision floats. *)
module Metric_set = struct
  type t = Trading_simulation_types.Metric_types.metric_set

  let sexp_of_t = Trading_simulation_types.Metric_types.metric_set_to_sexp_pairs
end

type t = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  n_steps : int;
  initial_cash : Money.t;
  final_portfolio_value : Money.t;
  n_round_trips : int;
  metrics : Metric_set.t;
}
[@@deriving sexp_of]
