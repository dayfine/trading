open Types

(** Weinstein Relative Strength trend analyzer.

    Classifies whether a stock's RS trend is rising, flat, declining, or
    crossing the zero line — the six states Weinstein uses to filter buy and
    short candidates.

    The raw RS computation (price ratio and Mansfield zero-line normalisation)
    is delegated to the canonical {!Relative_strength} indicator. This module
    adds the Weinstein-specific trend classification on top.

    All functions are pure. *)

type config = {
  rs_ma_period : int;
      (** Period for the RS moving average (the Mansfield zero-line MA).
          Default: 52 weeks. *)
  trend_lookback : int;
      (** Number of bars used to determine RS trend direction. Default: 4. *)
  flat_threshold : float;
      (** Within the positive zone, RS is "flat" (rather than declining) if the
          current value is at least [flat_threshold × prior_value]. Default:
          0.98 (i.e., a drop of less than 2% is still flat). *)
}
(** Configuration for RS trend analysis. *)

val default_config : config
(** Sensible defaults:
    [rs_ma_period = 52; trend_lookback = 4; flat_threshold = 0.98]. *)

type raw_rs = Relative_strength.raw_rs
(** Re-export of {!Relative_strength.raw_rs}. *)

type result = {
  current_rs : float;  (** Most recent raw RS ratio (stock / benchmark). *)
  current_normalized : float;
      (** Most recent normalized RS (Mansfield zero-line position). *)
  trend : Weinstein_types.rs_trend;  (** Classified trend direction and zone. *)
  history : raw_rs list;
      (** Full RS history used for classification (oldest first). *)
}
(** Result of the Weinstein RS trend analysis. *)

val analyze :
  config:config ->
  stock_bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  result option
(** [analyze ~config ~stock_bars ~benchmark_bars] computes the RS trend.

    @param stock_bars
      Weekly adjusted-close bars for the stock, sorted chronologically.
    @param benchmark_bars
      Weekly adjusted-close bars for the benchmark index (e.g., S&P 500), sorted
      chronologically.

    Dates are aligned: only dates present in both series contribute. Bars with
    no matching benchmark date are silently skipped.

    Returns [None] when there are fewer than [rs_ma_period] aligned bars.

    Pure function. *)
