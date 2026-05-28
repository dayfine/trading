(** Performance metrics for the per-symbol diagnostic backtest.

    Cadence-agnostic helpers that operate on a strategy equity curve (array of
    equity values, one per period) and its per-period returns. The diagnostic
    uses weekly cadence ({!periods_per_year} = 52.0). Mirrors the helpers in
    {!French_weinstein_rotation_lib.Metrics} but bundled here so the diagnostic
    doesn't cross-link into another script's private library.

    All functions are pure. *)

val periods_per_year : float
(** [52.0] — weekly-cadence annualisation factor. CAGR uses [n / 52.0] years;
    Sharpe uses [sqrt(52.0)]. *)

val cagr_from_returns : returns:float array -> float
(** Compound annual growth rate over the period series. Returns [0.0] for empty
    input, zero or negative terminal cumulative return, or zero years. *)

val sharpe_from_returns : returns:float array -> float
(** Annualised Sharpe ratio on per-period returns (excess over zero — the
    diagnostic uses cash-relative comparison). Returns [0.0] for [n < 2] or zero
    variance. *)

val max_drawdown_from_equity : equity:float array -> float
(** Peak-to-trough maximum drawdown of the equity curve, expressed as a negative
    fraction (e.g. [-0.34] for a 34% drawdown). Returns [0.0] when no drawdown
    occurred. *)

val returns_from_equity : equity:float array -> float array
(** Convert an equity curve [e_0; e_1; ...; e_n] to its per-period returns
    [(e_1 - e_0)/e_0; ...; (e_n - e_{n-1})/e_{n-1}]. Returns empty array when
    fewer than 2 equity samples; substitutes 0.0 for ratios where the previous
    equity is exactly zero (sign-preserving and avoids NaN). *)
