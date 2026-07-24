(** Regime-conditional long-leverage "dawn" signal (P1b, default-off).

    Runs the long book levered ([initial_long_margin_req < 1.0]) ONLY while the
    primary index is in a young post-bear "dawn" — its weekly moving average is
    currently rising and the most recent negative->positive slope flip happened
    recently — and cash-account otherwise. Green-lit 2026-07-24; authority
    [dev/notes/regime-dependency-evaluation-2026-07-24.md] §1/§3 +
    [dev/notes/margin-m4-validation-2026-07-23.md] §Addendum.

    {b Faithfulness} ([.claude/rules/weinstein-faithful-core.md] W1/W2). A
    {b deployment-intensity dial}: how much buying power the long engine
    deploys, conditioned on a {b trailing} regime label off the weekly MA. The
    spine is untouched (stage classification, Stage-2-only buys, breakout+volume
    entry, stops, macro/sector gate). NOT reversal timing — the MA-flip-age
    label is lagging by construction (it errs late, never early). The 2024
    melt-up-lag false-positive is the named WF-CV falsifier, not a bug.

    {b Default-off invariant} (experiment-flag-discipline R1). When
    [config.dawn_leverage_enabled = false] the wiring ({!dawn_effective_config})
    returns the config unchanged before any bar fetch or signal computation, so
    merging the mechanism changes no backtest result.

    {b Reuse.} The MA is not re-implemented: {!dawn_active} reads MA values via
    {!Panel_callbacks.stage_callbacks_of_weekly_view} over the primary index's
    weekly view (the same [Sma]/[Wma]/[Ema] kernel the stage classifier uses),
    and "rising" is the stage classifier's Rising direction (slope over
    [slope_lookback] weeks vs [slope_threshold]). *)

open Core

val flip_age_weeks :
  get_ma:(week_offset:int -> float option) ->
  slope_lookback:int ->
  slope_threshold:float ->
  max_flip_age_weeks:int ->
  int option
(** Age (in weeks) of the most recent negative->positive weekly-MA slope flip,
    or [None] when there is no qualifying recent flip.

    Returns [Some age] iff (a) the MA is currently rising (offset 0 is Rising:
    [(ma_0 - ma_{slope_lookback}) / ma_{slope_lookback} >= slope_threshold]) and
    (b) walking back from offset 0 a NOT-rising week is reached at some offset
    [k <= max_flip_age_weeks + 1]; then [age = k - 1] (the oldest consecutive
    rising week, i.e. the first rising week after the flip). Returns [None] when
    the current week is not rising, when the consecutive-rising run exceeds
    [max_flip_age_weeks + 1] (the flip is older than the window), or when the MA
    history runs out (a data boundary is reached before a non-rising week —
    inconclusive, treated conservatively as no recent flip).

    [get_ma ~week_offset] indexes the weekly MA with offset 0 = the current week
    and larger offsets older; it returns [None] past the available MA depth.
    Lookahead-free: only offsets [>= 0] are consulted. Pure. *)

val is_dawn :
  get_ma:(week_offset:int -> float option) ->
  slope_lookback:int ->
  slope_threshold:float ->
  max_flip_age_weeks:int ->
  bool
(** [Option.is_some (flip_age_weeks ...)] — the dawn label as a boolean. Pure.
*)

val effective_initial_long_margin_req :
  config:Weinstein_strategy_config.config -> dawn_active:bool -> float
(** [config.dawn_initial_long_margin_req] when [config.dawn_leverage_enabled]
    and [dawn_active] are both [true]; otherwise
    [config.initial_long_margin_req]. Pure. *)

val dawn_active :
  config:Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  bool
(** Compute the dawn label for [current_date] from the primary index
    ([config.indices.primary]). Fetches a deep-enough weekly view via
    {!Bar_reader.weekly_view_for} (depth =
    [ma_period + max_flip_age + slope_lookback] plus slack, so the flip search
    sees past the default 52-week [lookback_bars]), builds a {!Stage.callbacks}
    bundle over it, and delegates to {!is_dawn} with [config.stage_config]'s
    [slope_lookback] / [slope_threshold] and
    [config.dawn_max_ma_flip_age_weeks]. Does NOT consult
    [dawn_leverage_enabled] — {!dawn_effective_config} gates the call. *)

val dawn_effective_config :
  Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Weinstein_strategy_config.config
(** The config to feed the Friday entry walk with dawn leverage applied. When
    [config.dawn_leverage_enabled = false] returns [config] {b unchanged} (no
    fetch, exact no-op, R1). Otherwise computes {!dawn_active}; on a dawn week
    with a fractional [dawn_initial_long_margin_req] it returns
    [{ config with initial_long_margin_req = dawn_initial_long_margin_req }]
    (the only functional reader of [initial_long_margin_req] is the entry-walk
    buying-power ceiling); when not dawn, or when the effective requirement
    equals the base one, returns [config] unchanged. *)

val validate : Weinstein_strategy_config.config -> unit
(** Raise [Failure] when [config.dawn_leverage_enabled = true] and either
    [margin_config.enabled = false] (dawn leverage runs margin-armed by
    convention so borrowed dollars are priced + maintenance applies) or
    [dawn_initial_long_margin_req] is outside the interval 0.0 < req <= 1.0. A
    no-op when the mechanism is disabled. Called at {!Weinstein_strategy.make}.
*)
