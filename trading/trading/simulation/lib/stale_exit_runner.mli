(** Applies the stale/delisted force-exit selected by
    {!Trading_simulation.Stale_hold.force_exit_candidates}.

    The detector ({!Stale_hold.detect_stale}) only records stale holds; this
    runner is the {b application} half of issue #1484. When
    [config.stale_exit_after_days = Some n], a held position whose underlying
    symbol has stopped emitting bars for [n] days is force-sold at its last
    available close as a {b realised} trade — so it lands in [trades.csv] /
    realised P&L and frees cash, instead of being carried open at a stale mark
    indefinitely and counted in terminal NAV.

    Why a realised trade rather than a routed [TriggerExit] (the
    {!Margin_runner} pattern): the symbol has {b no bar today}, so the engine
    cannot fill an order against absent market data — a routed exit order would
    never complete. This runner applies the exit directly at the last close.

    The runner is strategy-agnostic: it operates on the broker portfolio and the
    generic [Position.t] state machine. Default-off
    ([stale_exit_after_days = None]) makes [tick] an identity. *)

open Core

val exit_reason : Stale_hold.force_exit -> Trading_strategy.Position.exit_reason
(** The [Position.exit_reason] stamped on the synthetic exit: a [StrategySignal]
    tagged [label = "stale_force_exit"], with
    [detail = Some "last_bar_date=<d> days_since_last_bar=<n>"] read off the
    candidate. [Stop_log.exit_trigger_of_reason] maps it to the
    [Strategy_signal] value that lands in the run's [exit_trigger] column, which
    is how a delisting-driven exit is told apart from a stop or a strategy sell
    (issue #2672 ask 2).

    Exported for testing: {!tick} drives the position to [Closed] and drops it
    from the positions map in the same fold that stamps the reason, so no caller
    can read the tag back off the result. Pure. *)

val tick :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  config:Stale_hold.config ->
  commission:Trading_engine.Types.commission_config ->
  date:Date.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  ?last_known_price:(symbol:string -> float option) ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Trading_strategy.Position.t String.Map.t ->
  unit ->
  Trading_portfolio.Portfolio.t
  * Trading_strategy.Position.t String.Map.t
  * Trading_base.Types.trade list
(** Force-exit every stale held position selected by
    {!Stale_hold.force_exit_candidates}. For each candidate:

    - builds a synthetic market trade at the candidate's last close (a long is
      flattened with a Sell, a short with a Buy) carrying the engine's
      [max(per_share * qty, minimum)] commission;
    - applies it to [portfolio] ([apply_single_trade]) — realising the P&L and
      freeing cash;
    - drives the matching Holding [Position.t] through Exiting to Closed and
      drops it from [positions] (no-op when no Holding position for the symbol
      exists — the portfolio is the source of truth).

    [?last_known_price] is forwarded verbatim to
    {!Stale_hold.force_exit_candidates}: it prices the #2672
    [exit_without_prior_bar] candidates (those with no prior bar to read a close
    from) off the caller's last-resolved-close cache, falling back to average
    cost. Omitted, it is a lookup returning [None] for every symbol — inert
    while that flag is off, which is the default.

    Returns the post-exit [(portfolio, positions, trades)] with [trades] in
    chronological (candidate) order, ready to merge into the step's trade list.
    A trade the portfolio rejects is skipped and not reported. Returns the
    inputs unchanged (empty trade list) when [today_bars] is empty (no
    force-exit on a weekend / holiday — matches the detector's false-positive
    guard), when [config.stale_exit_after_days = None] /
    [config.enabled = false], or when no candidate has reached the threshold —
    the default-off, byte-identical path. *)
