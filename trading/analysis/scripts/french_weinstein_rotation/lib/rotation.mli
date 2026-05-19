(** Cross-sectional Weinstein-style industry rotation on the Kenneth French
    49-Industry daily fixture.

    Strategy spec (per
    [dev/plans/cross-cycle-weinstein-validation-2026-05-19.md] §M2 PR-D):

    For each industry, on each trading day, compute:
    - A synthetic price level (cumulative product of [1 + daily_return]).
    - A trailing simple moving average over [ma_trading_days] (default 150 ≈ 30
      weeks × 5 trading days).
    - Stage 1-4 classification (see {!Stage}).
    - 13-week relative strength: cumulative return over the last
      [rs_lookback_days] (default 65) minus the cross-industry mean cumulative
      return over the same window.

    On each rebalance day (every [rebalance_days] trading days, default 5),
    select the top-[top_k] (default 5) Stage-2 industries ranked by RS for the
    long sleeve, and (in the long-short variant) the bottom-[top_k] Stage-4
    industries by inverse RS for the short sleeve. Equal-weight within each
    sleeve. The basket is held until the next rebalance.

    Cash position: any sleeve weight not allocated to a real industry stays in
    cash (earns 0). E.g. if only 3 Stage-2 industries exist on day t, the long
    sleeve holds 3 × (1 / top_k) = 0.6 in industries and 0.4 in cash. *)

open Core

(** Long-only puts only long-sleeve weight on; idle weight stays in cash.
    Long-short adds the short sleeve (negative weights on bottom-K Stage-4
    industries by inverse RS). *)
type variant = Long_only | Long_short [@@deriving show, eq]

type config = {
  ma_trading_days : int;
      (** Trailing window for the per-industry moving average. Default 150 (≈ 30
          weeks × 5 trading days). *)
  rs_lookback_days : int;
      (** Trailing window for cross-sectional relative strength. Default 65 (≈
          13 weeks × 5 trading days). *)
  rebalance_days : int;
      (** Cadence of basket rebalancing in trading days. Default 5 (weekly). *)
  top_k : int;
      (** Long sleeve size + short sleeve size when applicable. Default 5. *)
  variant : variant;  (** [Long_only] or [Long_short]. Default [Long_only]. *)
  slope_lookback_days : int;
      (** Slope assessment lookback for Stage classification. Default 30 (≈ 6
          weeks). *)
  slope_threshold_pct : float;
      (** Slope threshold separating Stage 2/4 from Stage 1/3. Default 0.005
          (0.5% over the lookback distance, normalised by price). *)
}
[@@deriving show, eq]

val default_config : config
(** All-defaults config as described above. *)

type decade_report = {
  decade_label : string;  (** ["1920s"], ["1930s"], ..., ["2020s"]. *)
  n_days : int;
  strategy_cagr : float;
  strategy_sharpe : float;
  strategy_maxdd : float;
  bh_cagr : float;
  bh_sharpe : float;
  bh_maxdd : float;
  pct_days_invested : float;
      (** Average gross exposure (sum of |weights|) across the decade, in %. For
          [Long_only] this is the % of capital deployed long; for [Long_short]
          it includes the short notional too. *)
}
[@@deriving show, eq]
(** Per-decade summary stats for the strategy + buy-and-hold (= equal-weighted
    49-industry market) benchmark. *)

type result = {
  config : config;
  industries : string list;  (** Industry names in source-file order. *)
  dates : Date.t array;
      (** Trading days the strategy ran over (matches the loaded fixture's
          chronologically-ascending dates 1:1). *)
  strategy_daily_returns : float array;
      (** Strategy daily return, in decimal form (e.g. 0.0046 = 0.46%). Length =
          [Array.length dates]. *)
  benchmark_daily_returns : float array;
      (** Equal-weighted 49-industry market daily return, same length. *)
  decade_reports : decade_report list;
      (** Per-decade summary stats, sorted ascending. *)
}

val compute_strategy :
  rows:Loader.daily_row array ->
  industries:string list ->
  config:config ->
  result
(** [compute_strategy ~rows ~industries ~config] runs the rotation strategy over
    the loaded series. Returns:

    - The full daily return series of strategy + benchmark (= equal-weighted
      market, treating missing-industry cells as 0 with proper renormalisation).
    - Per-decade Sharpe / MaxDD / CAGR.

    The function is pure — same input → identical output. *)
