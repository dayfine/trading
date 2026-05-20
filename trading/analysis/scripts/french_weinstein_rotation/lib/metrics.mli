(** Performance metrics for daily-cadence return series.

    These helpers mirror the ones in
    [trading/analysis/scripts/shiller_weinstein_decades] but are
    cadence-agnostic (the caller supplies [periods_per_year]). Kept here so the
    rotation binary doesn't gain a cross-script dep on the Shiller binary's
    private helpers. *)

val cagr : returns:float array -> periods_per_year:float -> float
(** [cagr ~returns ~periods_per_year] = annualised compound return over the
    series. Returns 0.0 on empty input or zero/negative time. *)

val sharpe : returns:float array -> periods_per_year:float -> float
(** [sharpe ~returns ~periods_per_year] = annualised Sharpe ratio (excess over
    0, since we use cash-relative comparison across regimes). Returns 0.0 on
    [n < 2] or zero variance. *)

val max_drawdown : returns:float array -> float
(** [max_drawdown ~returns] = maximum peak-to-trough drawdown of the cumulative
    return curve, expressed as a negative number (e.g. -0.34 for a 34%
    drawdown). Returns 0.0 if no drawdown. *)

val cumulative_return : returns:float array -> float
(** [cumulative_return ~returns] = end-state cumulative return as a multiplier.
    1.0 = flat, 2.0 = doubled. *)

val beta : strategy:float array -> market:float array -> float
(** [beta ~strategy ~market] = OLS regression slope of strategy returns against
    market returns. Both arrays must be the same length. *)
