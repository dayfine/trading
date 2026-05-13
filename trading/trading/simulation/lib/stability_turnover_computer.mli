(** Portfolio-quality metrics: rolling-Sharpe stability, position turnover, and
    Friday-sampled position concentration.

    Three step-based metrics produced by a single folding computer:

    - {b RollingSharpeStability} — standard deviation of the rolling
      90-trading-day Sharpe series. Lower means risk-adjusted return is steady
      across regimes; higher means it lurches. [0.0] when fewer than two full
      windows are available.

    - {b PositionTurnover} — average daily churn intensity. Sums
      [|Δ position_notional|] step-over-step across all symbols and divides by
      [mean(portfolio_value) × n_trading_days]. [0.0] for a buy-and-hold book.

    - {b PositionConcentrationHhi} — Friday-sampled Herfindahl index of
      position-value weights. Bounded in [0, 1]; 1.0 means a single position
      holds the entire gross book. The metric is named after the antitrust
      concentration index because the simulator has no sector→symbol map;
      symbol-level diversity is the available proxy. [0.0] when no Friday step
      has any open position.

    [TradeFrequencyAnnualized] is produced separately as a {b derived} metric
    (see {!Stability_turnover_computer.trade_frequency_annualized_derived}),
    since it depends only on [NumTrades] (already computed by
    {!Trade_aggregates_computer}) and the config window — no per-step state is
    required. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the stability + turnover step-based computer. Produces the three
    step-folding metrics listed above. *)

val trade_frequency_annualized_derived :
  Trading_simulation_types.Simulator_types.derived_metric_computer
(** Derived computer for [TradeFrequencyAnnualized]: divides [NumTrades] by the
    config window's calendar-year length. Returns [0.0] when the window is
    non-positive. *)
