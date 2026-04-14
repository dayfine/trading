(** Summary of a single backtest run: run metadata (dates, sizes, cash, steps)
    plus the full metric set. [sexp_of_t] renders a human-readable sexp — money
    fields use [%.2f], metric keys are lowercased, metric values are [%.2f] (or
    [%.0f] for integer-valued metrics). *)

open Core

module Money : sig
  type t = float

  val sexp_of_t : t -> Sexp.t
end

module Metric_set : sig
  type t = Trading_simulation_types.Metric_types.metric_set

  val sexp_of_t : t -> Sexp.t
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
