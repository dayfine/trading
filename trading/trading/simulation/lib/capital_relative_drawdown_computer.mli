(** Capital-relative drawdown computer.

    Emits the single metric [MaxUnderwaterVsInitialPct]: the worst shortfall of
    portfolio value below the {b initial} capital, as a percent of initial. This
    is distinct from the peak-relative [MaxDrawdown] — it measures psychological
    depth against the starting stake rather than against the running high-water
    mark.

    The model: for each trading-day step, capital-relative drawdown percent =
    [max(0, (initial_cash - portfolio_value) / initial_cash × 100)]. The metric
    is the maximum of this series across the run — a strategy that 3×'d then
    fell 40% never dips below its initial stake and reads 0; one whose NAV fell
    below its starting money reads positive.

    Pure: same step list → same output. See
    {!Trading_simulation_types.Metric_types.MaxUnderwaterVsInitialPct} for the
    full semantic spec. *)

val computer :
  ?initial_cash:float ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the capital-relative drawdown computer.

    @param initial_cash
      The starting capital, used as the baseline the NAV is compared against.
      Pass the simulator's configured [initial_cash]; if absent or [<= 0.0] the
      metric reports [0.0] (defensive fallback, mirroring [AvgTradeSizePct]). *)
