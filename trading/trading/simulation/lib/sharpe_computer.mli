(** Sharpe ratio metric computer. *)

val computer :
  ?risk_free_rate:float ->
  ?cash_yield:Trading_simulation_cash_yield.Cash_yield.t ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
(** Annualised Sharpe of the per-trading-day portfolio returns ([sqrt 252]
    scaling).

    Without [cash_yield] the excess is over a flat annual [risk_free_rate]
    (default [0.0]) — the pre-#3137 behaviour, unchanged. With [cash_yield]
    (#3137) each period's return is first reduced by the cash yield accrued over
    the calendar days it spans
    ({!Trading_simulation_cash_yield.Cash_yield.period_rate}), i.e. Sharpe on
    excess return over the same rate the book's cash earns; [risk_free_rate] is
    then ignored. Raises [Failure] if a mark precedes the rate series' first
    observation. *)
