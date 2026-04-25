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

    Pure function.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It first joins the two bar lists on date, then builds [get_stock_close],
    [get_benchmark_close], and [get_date] closures that index the resulting
    aligned arrays. Behaviour is bit-identical to the callback API for the same
    underlying aligned series. *)

val analyze_with_callbacks :
  config:config ->
  get_stock_close:(week_offset:int -> float option) ->
  get_benchmark_close:(week_offset:int -> float option) ->
  get_date:(week_offset:int -> Core.Date.t option) ->
  result option
(** [analyze_with_callbacks ~config ~get_stock_close ~get_benchmark_close
     ~get_date] is the indicator-callback shape of {!analyze}. Used by
    panel-backed callers that read aligned weekly closes via the strategy's
    [get_indicator_fn] / panel views rather than walking [Daily_price.t list]s.

    @param config Same configuration as {!analyze}.
    @param get_stock_close
      Returns the stock's weekly adjusted close at [week_offset] weeks back from
      the current week ([week_offset:0] = current week, [1] = previous, etc.).
      Returns [None] for offsets where no stock bar is available (warmup or out
      of range).
    @param get_benchmark_close
      Returns the benchmark's weekly adjusted close at [week_offset]. Same
      indexing as [get_stock_close]. Returns [None] for offsets where no
      benchmark bar is available.
    @param get_date
      Returns the calendar date corresponding to [week_offset]. Same indexing as
      the close callbacks; the caller is responsible for ensuring all three
      callbacks return values for the same set of offsets (i.e., the panel
      caller has already aligned the two series so that
      [get_stock_close ~week_offset:k] and [get_benchmark_close ~week_offset:k]
      correspond to the same week's [get_date ~week_offset:k]). Used to populate
      [raw_rs.date] in the returned [history].

    Walk semantics: walks back from [week_offset:0] until any of the three
    callbacks returns [None], yielding the depth [n] of aligned weekly data.
    Returns [None] if [n < rs_ma_period].

    Pure function: same callback outputs always produce the same result. The
    wrapper {!analyze} guarantees byte-identical results for any
    [(stock_bars, benchmark_bars)] input by constructing callbacks that index
    the same date-aligned series the bar-list path computes internally. *)
