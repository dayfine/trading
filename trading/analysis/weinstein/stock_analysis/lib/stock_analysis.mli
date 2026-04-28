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

val is_breakout_candidate : t -> bool
(** [is_breakout_candidate analysis] returns true if the stock shows a potential
    Stage 2 breakout: transitioning from Stage 1, with rising MA and strong
    volume.

    Uses the sub-analysis results directly — no additional I/O. *)

val is_breakdown_candidate : t -> bool
(** [is_breakdown_candidate analysis] returns true if the stock shows a
    potential Stage 4 breakdown: transitioning from Stage 3 into Stage 4. Used
    for identifying short candidates. *)
