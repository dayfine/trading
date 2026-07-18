open Types

(** Combined per-stock analysis result for the Weinstein screening pipeline.

    Aggregates the outputs of Stage, RS, Volume, and Resistance analysis into a
    single value per ticker. This is what the Screener consumes.

    Pure function: given the same bars and benchmark, always returns the same
    result. *)

type config = {
  stage : Stage.config;
  rs : Rs.config;
  volume : Volume.config;
  resistance : Resistance.config;
  breakout_event_lookback : int;
      (** Bars to scan for peak-volume event when detecting a breakout. Default:
          8 (~2 months of weekly bars). *)
  base_lookback_weeks : int;
      (** How far back (in bars) to search for the prior base high. Default: 52
          (~1 year). *)
  base_end_offset_weeks : int;
      (** How many recent bars to exclude from the base search. Default: 8. *)
  continuation : Continuation.config option;
      (** When [Some cfg], the continuation-buy detector (Weinstein Ch. 3
          "continuation buy") runs and populates {!t.continuation}, which then
          feeds the OR-arm in {!is_breakout_candidate}. When [None] (default),
          the detector is skipped and {!t.continuation} is [None] — preserves
          bit-equality with pre-feature behaviour. Gated at this level so
          callers (strategy / screener) can enable continuation buys via
          [Weinstein_strategy_config.enable_continuation_buys] without touching
          tests that rely on bit-equal screener output. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** When [Some cfg], the continuous overhead-supply score
          ({!Resistance_supply}) runs for a survivor whose callback bundle
          supplies a sketch and whose breakout price is known, populating
          {!t.supply}. When [None] (default), {!t.supply} is always [None] —
          bit-identical to pre-feature behaviour. Gated at this level (mirroring
          [continuation]) so the strategy can arm it via
          [Weinstein_strategy_config.overhead_supply] without perturbing tests
          that rely on bit-equal screener output. The [@sexp.default None]
          attribute is inert here (this config does not derive sexp) but marks
          the field as an additive, default-off option. *)
  virgin_crossing_readmission : bool; [@sexp.default false]
      (** resistance-v2 lever (a): when [true], a Stage-2 survivor that has
          crossed into virgin territory (above its 520-week max high) on volume
          is re-admitted by {!is_breakout_candidate} even when
          [early_stage2_max_weeks] would otherwise reject it as stale — the
          book's "new high ground" breakout (weinstein-book-reference.md §Buy
          Criteria). The virgin test needs only a sketch from
          [callbacks.get_sketch]; sketch absent → [t.virgin_readmission = false]
          (no fabrication). Independent of [overhead_supply] — virginity does
          not depend on the scoring config. [false] (default) is bit-identical
          to pre-feature behaviour. The [@sexp.default false] attribute is inert
          here (this config does not derive sexp) but marks the field as an
          additive, default-off option. *)
}
(** Configuration bundling all sub-module configs. *)

val default_config : config
(** [default_config] assembles sub-module defaults. *)

type t = {
  ticker : string;
  stage : Stage.result;
  rs : Rs.result option;  (** None if insufficient bar history to compute RS. *)
  volume : Volume.result option;
      (** None if there is no identifiable breakout bar in the recent window. *)
  resistance : Resistance.result option;
      (** None if no breakout price can be determined from the bars. *)
  support : Support.result option;
      (** Below-breakdown support density grade. Mirror of [resistance] for the
          short-side cascade — measures how much prior trading sits below the
          breakdown floor (heavy support = decline will struggle through; virgin
          support = stock falls freely). [None] when no breakdown price can be
          determined. *)
  breakout_price : float option;
      (** Detected breakout price (top of prior base / resistance zone). Used by
          the screener to set suggested entry. *)
  breakdown_price : float option;
      (** Detected breakdown price (bottom of prior base / support floor).
          Mirror of [breakout_price] for the short-side cascade. Computed as the
          minimum [low_price] over the prior-base window
          [(base_end_offset_weeks .. base_lookback_weeks)]. *)
  prior_stage : Weinstein_types.stage option;
      (** Stage from the previous week, passed forward for transition tracking.
      *)
  continuation : Continuation.result option;
      (** Continuation-buy detector output. [None] when
          [config.continuation = None] (default — feature off) OR when the
          underlying callbacks couldn't compute the result. [Some r] with
          [r.is_continuation = true] indicates the bar matches Weinstein's Ch. 3
          continuation pattern and feeds the OR-arm in {!is_breakout_candidate}.
      *)
  supply : Resistance_supply.result option;
      (** Continuous overhead-supply score (resistance-v2). [None] when
          [config.overhead_supply = None] (default — feature off), when the
          callback bundle's [get_sketch] returned [None] (no warehouse sketch, a
          read error, or the bar-list / live CSV path), or when no breakout
          price could be determined. [Some r] carries [r.score] in [0, 1] (0 =
          virgin territory, 1 = heavy recent supply just above the breakout),
          consumed by the screener's long-side [w_overhead_supply] scoring
          weight in place of the binary virgin/clean grade. *)
  virgin_readmission : bool;
      (** resistance-v2 lever (a) eligibility. [true] iff
          [config.virgin_crossing_readmission] is armed AND
          [callbacks.get_sketch] returned a sketch AND a breakout price exists
          AND the breakout is virgin ([Resistance_supply.is_virgin] — crosses
          the 520-week max high). Read by {!is_breakout_candidate}'s
          re-admission arm to bypass the [early_stage2_max_weeks] staleness
          rejection for a genuine new-high breakout. [false] whenever the flag
          is off — bit-identical to pre-feature behaviour. *)
  as_of_date : Core.Date.t;  (** The date this analysis was computed. *)
}
(** The full per-stock analysis. *)

type callbacks = {
  get_high : week_offset:int -> float option;
      (** Bar high at [week_offset] weeks back (offset 0 = current week). Used
          by the breakout-price scan over the prior-base window. *)
  get_volume : week_offset:int -> float option;
      (** Bar volume at [week_offset] weeks back, encoded as a float. Used by
          the peak-volume scan over the recent window. *)
  get_split_factor : week_offset:int -> float option;
      (** Per-bar split-adjustment factor [adjusted_close / close_price] at
          [week_offset] weeks back. Used by the breakout / breakdown scans to
          truncate the lookback window at the most recent split boundary: a
          factor that materially diverges from offset 0's factor means a split
          occurred between that bar and the present, and bars on the far side of
          the split would leak into the scan in a different price space.

          Returns [None] when no bar exists at that offset, when the bar's
          [close_price] is non-positive, or when the panel doesn't carry both
          raw and adjusted close (in which case truncation is a no-op and the
          caller falls through to the original full-window scan). *)
  get_sketch : unit -> Resistance_supply.sketch option;
      (** Returns the precomputed resistance sketch for this analysis's (symbol,
          as_of), read from the warehouse sketch columns by the panel adapter.
          [None] when the panel doesn't carry the sketch columns, any sketch
          field read fails, or the caller is the bar-list / live CSV path
          ({!callbacks_from_bars}, which returns [fun () -> None]). Invoked when
          [config.overhead_supply] OR [config.virgin_crossing_readmission] is
          armed — so when both features are off this closure is never called and
          the panel does no extra reads. *)
  stage : Stage.callbacks;
      (** Nested Stage callbacks. {!Stage.callbacks_from_bars} or a panel
          adapter constructs this. *)
  rs : Rs.callbacks;
      (** Nested RS callbacks. {!Rs.callbacks_from_bars} or a panel adapter
          constructs this. *)
  volume : Volume.callbacks;
      (** Nested Volume callbacks. {!Volume.callbacks_from_bars} or a panel
          adapter constructs this. *)
  resistance : Resistance.callbacks;
      (** Nested Resistance callbacks. {!Resistance.callbacks_from_bars} or a
          panel adapter constructs this. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}.

    Threads the per-callee callback bundles ({!Stage.callbacks},
    {!Rs.callbacks}, {!Volume.callbacks}, {!Resistance.callbacks}) through one
    nested record so that panel-backed callers don't have to re-expose those
    individual closures at every layer. As of Stage 4 PR-B, every sub-callee
    consumes callbacks rather than {!Daily_price.t list} — the strategy hot path
    no longer materialises bar lists. *)

val callbacks_from_bars :
  config:config ->
  bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  callbacks
(** [callbacks_from_bars ~config ~bars ~benchmark_bars] builds a {!callbacks}
    record by precomputing [bars]'s high/volume index closures and delegating
    nested bundles to {!Stage.callbacks_from_bars}, {!Rs.callbacks_from_bars},
    {!Volume.callbacks_from_bars}, and {!Resistance.callbacks_from_bars}. The
    constructor [{ analyze }] uses internally; exposed for callers (e.g. tests,
    future panel adapters) that already hold bar lists and want to delegate to
    {!analyze_with_callbacks}. *)

val analyze :
  config:config ->
  ticker:string ->
  bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  prior_stage:Weinstein_types.stage option ->
  as_of_date:Core.Date.t ->
  t
(** [analyze ~config ~ticker ~bars ~benchmark_bars ~prior_stage ~as_of_date]
    runs all sub-analyses for one stock.

    @param bars Weekly bars for the stock (chronological, oldest first).
    @param benchmark_bars Weekly bars for the benchmark index (e.g., SPX).
    @param prior_stage Previous week's stage result for this ticker.
    @param as_of_date The analysis date.

    Pure function.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It builds a {!callbacks} record via {!callbacks_from_bars} and delegates.
    Behaviour is bit-identical to the callback API for the same underlying
    [bars]. *)

val analyze_with_callbacks :
  config:config ->
  ticker:string ->
  callbacks:callbacks ->
  prior_stage:Weinstein_types.stage option ->
  as_of_date:Core.Date.t ->
  t
(** [analyze_with_callbacks ~config ~ticker ~callbacks ~prior_stage ~as_of_date]
    is the indicator-callback shape of {!analyze}. Used by panel-backed callers
    that read indicator values via the strategy's [get_indicator_fn] / panel
    views rather than walking {!Daily_price.t list}s for any sub-analysis.

    @param config Same configuration as {!analyze}.
    @param callbacks
      Bundle of indicator callbacks. [callbacks.get_high] and
      [callbacks.get_volume] back the breakout-price scan (over the prior-base
      window) and the peak-volume scan (over the recent window).
      [callbacks.stage] / [callbacks.rs] / [callbacks.volume] /
      [callbacks.resistance] thread through to the corresponding callees.
    @param prior_stage Same as {!analyze}.
    @param as_of_date Same as {!analyze}.

    Pure function: same callback outputs always produce the same result. The
    wrapper {!analyze} guarantees byte-identical results for any
    [(bars, benchmark_bars)] input by constructing callbacks that index the same
    pre-computed series the bar-list path computes internally. *)

val is_breakout_candidate : ?early_stage2_max_weeks:int -> t -> bool
(** [is_breakout_candidate ?early_stage2_max_weeks analysis] returns true if the
    stock shows a potential Stage 2 breakout: transitioning from Stage 1, with
    rising MA and strong volume.

    [early_stage2_max_weeks] is the early-Stage2 admission window: a fresh
    Stage2 (no observed Stage1→Stage2 transition) qualifies only while
    [weeks_advancing <= early_stage2_max_weeks]. Defaults to [4] — bit-identical
    to the historical hardcoded window, so every existing caller is unchanged.
    The screener threads [Screener.config.early_stage2_max_weeks] here so the
    window is a tunable axis.

    OR-arm (Interpretation B of issue #889): a stock that has [Some r] in
    {!t.continuation} with [r.is_continuation = true] also qualifies, even when
    the Stage1→Stage2 transition is no longer in scope
    ([weeks_advancing > early_stage2_max_weeks]). This admits the Weinstein Ch.
    3 "continuation buy" pattern as a new-position candidate when
    [config.continuation = Some _].

    Virgin-crossing re-admission arm (resistance-v2 lever (a)): a Stage-2 stock
    with [t.virgin_readmission = true] (the [virgin_crossing_readmission] flag
    is armed AND the stock has crossed into virgin territory) also qualifies,
    even when [weeks_advancing > early_stage2_max_weeks]. This is the book's
    "new high ground" breakout — a fresh breakout into virgin territory is a
    valid Stage-2 entry regardless of how long ago the Stage-2 transition
    happened. [false] (default) when the flag is off, so admission is
    bit-identical to pre-feature.

    Volume confirmation (Strong / Adequate) and the RS-not-negative-declining
    gate apply to all arms equally.

    Uses the sub-analysis results directly — no additional I/O. *)

val is_breakdown_candidate : t -> bool
(** [is_breakdown_candidate analysis] returns true if the stock shows a
    potential Stage 4 breakdown: transitioning from Stage 3 into Stage 4. Used
    for identifying short candidates. *)
