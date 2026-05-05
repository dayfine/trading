(** Per-symbol weekly MA cache (Stage 4 PR-D).

    {b Wedge.} The strategy's hot path calls
    {!Panel_callbacks.stage_callbacks_of_weekly_view} once per symbol per Friday
    tick (across screener + stops + sector + macro branches). Each call
    previously rebuilt the SMA / WMA / EMA series over the weekly closes by
    walking the float array through an [Indicator_types.t list], running
    [Sma.calculate_sma] / [Sma.calculate_weighted_ma] / [Ema.calculate_ema],
    then collecting the result back into a [float array]. For ~300 symbols ×
    ~312 Fridays in a 6y backtest that's ~93k recomputes — each allocating ≥3
    transient lists.

    This cache memoises the MA values per [(symbol, ma_type, period)] key. The
    MA is computed once per key (over the symbol's full available weekly
    history) at first request and reused on every subsequent
    [stage_callbacks_of_weekly_view] call for the same key. The cache is
    backtest-scoped — created at simulator construction, dropped at the end of
    the run.

    {b Bit-equality (SMA / WMA).} For sliding-window MAs (SMA and WMA), the MA
    value at week [i] depends only on closes [(i-period+1)..i]. The cached
    full-history MA's value at any position is therefore bit-identical to the
    truncated bar-list path's MA at the corresponding view position. The
    cap-by-view-depth in the consumer's [get_ma] callback (returning [None] for
    offsets past the truncated bar-list path's MA depth) makes the callback
    bundle bit-equal to the bar-list bundle.

    {b EMA caveat.} EMA is recursive: the value at week [i] depends on
    [closes[0..i]]. The bar-list path computes EMA over the truncated weekly
    view's closes (length [view.n]); the cache computes EMA over the full weekly
    history. The seeds therefore differ. With the default [period = 30] and view
    size ≥ 52, the recurrence converges to within TA-Lib's 2-decimal output
    rounding within the first few windows, so at the offsets the strategy
    actually reads ([0..7]) the cached values match. The default Stage config
    uses WMA, not EMA, so this concern is dormant in production today.

    {b Cache hit / miss.} The cache stores Friday-aligned MA values (one entry
    per ISO week of the symbol's history). A cache hit requires the consumer's
    view's newest date to exactly match a cached date — i.e., Friday calls hit,
    mid-week calls miss. The Weinstein screener / macro / sector branches are
    Friday-only and hit the cache; the daily stops_runner falls back to the
    inline path on non-Fridays.

    Sized memory: [n_symbols] × (per-symbol full weekly history × 8 bytes ×
    n_distinct_(ma_type, period)_combos). For 300 symbols × 312 weeks × 1 combo
    = ~750 KB total — negligible. *)

open Core

type t
(** Opaque cache, allocated per backtest run. *)

val of_snapshot_views :
  Snapshot_runtime.Snapshot_callbacks.t -> max_as_of:Date.t -> t
(** [of_snapshot_views cb ~max_as_of] builds an empty cache backed by [cb]. The
    cache holds a reference to [cb] so subsequent [ma_values_for] calls can read
    the symbol's full weekly history on demand.

    [max_as_of] is the upper-bound date for the weekly history reads — it is
    passed as [as_of] to {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for}
    along with [n = Int.max_value] to fetch every weekly bucket on or before
    [max_as_of]. Callers typically pass the last calendar date of the backtest
    (the snapshot directory's terminal date). *)

val ma_values_for :
  t ->
  symbol:string ->
  ma_type:Stage.ma_type ->
  period:int ->
  float array * Date.t array
(** [ma_values_for t ~symbol ~ma_type ~period] returns the MA values array
    paired with their aligned dates (chronological, oldest-first). The arrays
    have equal length: [(full_history_n_weeks - period + 1)] when the symbol has
    at least [period] weeks, otherwise both arrays are empty.

    On first call for [(symbol, ma_type, period)] the cache reads the symbol's
    full weekly history from the underlying snapshot, computes the MA via the
    same kernel [Stage._compute_ma] uses ([Sma.calculate_sma] /
    [Sma.calculate_weighted_ma] / [Ema.calculate_ema]), and stores the result.
    Subsequent calls return the cached arrays directly.

    The returned arrays are owned by the cache; do not mutate them. *)

val locate_date : Date.t array -> Date.t -> int option
(** [locate_date dates target] returns the index [i] such that
    [dates.(i) = target], or [None] if [target] is not present. Linear scan from
    the array tail. Callers use this to map a view's most-recent date to its
    position in the cached MA values array; on a cache miss (non-Friday view
    date) the consumer falls back to inline MA computation. *)
