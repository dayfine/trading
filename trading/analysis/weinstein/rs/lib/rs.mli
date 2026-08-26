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
          0.98 (i.e., a drop of less than 2% is still flat).

          Observable {b only} when [enable_positive_declining] is [true]: with
          the flag off both sides of this comparison classify [Positive_flat],
          so the threshold has no effect on any output. *)
  enable_positive_declining : bool;
      (** Arms the {!Weinstein_types.Positive_declining} state (issue #2556).

          [false] (default) is the behaviour the classifier had before the state
          existed: a positive-zone value that has fallen by more than
          [1 - flat_threshold] is reported as [Positive_flat], indistinguishable
          from a genuinely flat one. [true] reports it as [Positive_declining] —
          RS above the Mansfield zero line but trending lower, which book §4.4
          (Ch. 4, "inferior action in the RS line compared to the price
          performance ... don't ever buy that stock") treats as a reason to
          stand aside rather than a hold.

          Consumers reached only when armed:
          - {b long admission} — [Stock_analysis.breakout_candidate_rejection]
            rejects the candidate with [Rs_declining], same as
            [Negative_declining];
          - {b scoring} — [Screener_scoring] awards zero points (the magnitude
            of any penalty is not book-dictated, so none is invented here);
          - {b sector confidence} — [Sector] scores the bucket [0.0];
          - {b short admission} — [Screener_admission.rs_blocks_short] does
            {b not} block, since §4.4's short-side exemption requires RS "in
            good shape {i and improving}" and a falling line fails the second
            half.

          Default-off per [.claude/rules/experiment-flag-discipline.md] R1;
          searchable as a {!Weinstein_strategy_config} axis (R2). No default
          flip without a ledger ACCEPT plus a confirmation grid (R3). *)
}
(** Configuration for RS trend analysis. *)

val default_config : config
(** Sensible defaults:
    [rs_ma_period = 52; trend_lookback = 4; flat_threshold = 0.98;
     enable_positive_declining = false]. *)

val min_aligned_bars_for_trend : config -> int
(** [min_aligned_bars_for_trend config] is the smallest number of date-aligned
    weekly bars a caller must supply for the {!result.trend} to be a real
    classification rather than a degenerate default.

    [= rs_ma_period - 1 + trend_lookback + 1]; [56] at {!default_config}.

    Two facts compose into that floor:
    - The zero-line MA consumes [rs_ma_period - 1] bars, so [n] aligned bars
      yield an RS history of [n - rs_ma_period + 1] entries.
    - Classification compares the newest history entry against the one
      [trend_lookback] entries back, so it needs [trend_lookback + 1] entries.
      With fewer than [2] it short-circuits to [Positive_flat]; with
      [2.. trend_lookback] the comparison silently clamps to a shorter span — it
      neither errors nor returns [None], it returns a plausible classification
      computed over the wrong window.

    Both degenerate regimes are pinned end-to-end through the strategy's own
    panel path by [test_rs_trend_live.ml]
    ([old_depth_collapses_to_positive_flat] for the [n < 2] guard,
    [clamp_band_compares_over_a_shorter_span] for the clamp band).

    Callers that build their own weekly view (the strategy's [lookback_bars])
    must size it at least this deep — under-sizing does not error, it degrades
    to a constant [Positive_flat] for every symbol, which is what issue #2380
    recorded across 4,231 tickets. *)

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

type callbacks = {
  get_stock_close : week_offset:int -> float option;
      (** Stock weekly adjusted close at [week_offset] weeks back. *)
  get_benchmark_close : week_offset:int -> float option;
      (** Benchmark weekly adjusted close at [week_offset] weeks back. *)
  get_date : week_offset:int -> Core.Date.t option;
      (** Calendar date for the aligned [week_offset]. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}.

    All three closures must be date-aligned: at any [week_offset:k], they refer
    to the same week. {!callbacks_from_bars} guarantees this for the bar-list
    path; panel-backed callers are responsible for the alignment. *)

val callbacks_from_bars :
  stock_bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  callbacks
(** [callbacks_from_bars ~stock_bars ~benchmark_bars] joins the two lists on
    date and returns a {!callbacks} record whose closures index the resulting
    aligned triples. The constructor [{ analyze }] uses internally; exposed for
    callers (e.g. {!Stock_analysis.analyze}) that already hold both bar lists
    and want to delegate to {!analyze_with_callbacks} via the same plumbing. *)

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
