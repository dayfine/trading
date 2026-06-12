(** The warmup-trading gate.

    A default-off backtest mechanism (per
    [.claude/rules/experiment-flag-discipline.md]) that suppresses all new
    position entries before the measurement [start_date]. The simulator runs
    from [start_date - warmup_days] so the Weinstein strategy trades during the
    warmup window; PR #1549's A2 root-cause showed this leaks a warmup-built
    portfolio into every measurement window (the 2009-06-26 fold's warmup
    spanned the GFC bottom → portfolio depleted to ~35% before measurement
    opened; see {!Backtest.Fold_health}).

    The gate is keyed off the
    [Weinstein_strategy_config.suppress_warmup_trading] flag, supplied by the
    runner together with its [start_date]. The strategy itself stays
    date-boundary-agnostic — it only ever sees the simulation clock, which
    starts at the warmup boundary. *)

open Trading_strategy

val filter_transitions :
  suppress:bool ->
  start_date:Core.Date.t ->
  Position.transition list ->
  Position.transition list
(** [filter_transitions ~suppress ~start_date transitions] drops every
    [Position.CreateEntering] transition whose [transition.date] is strictly
    before [start_date]; every other transition kind, and every [CreateEntering]
    dated on/after [start_date], passes through unchanged.

    No-op when [suppress = false] (the default): returns [transitions] unchanged
    (bit-identical), so every existing golden/baseline replays unchanged.

    Only new-position entries (both long and short — [CreateEntering] carries
    the [side]) are suppressed. Exits, partial exits, risk-param updates, and
    fills ([TriggerExit], [TriggerPartialExit], [UpdateRiskParams], [EntryFill],
    [EntryComplete], [ExitFill], [ExitComplete], [CancelEntry]) are never
    dropped, so warmup-window exit/stop handling is never broken. Pure. *)

val wrap_strategy :
  suppress:bool ->
  start_date:Core.Date.t ->
  (module Strategy_interface.STRATEGY) ->
  (module Strategy_interface.STRATEGY)
(** [wrap_strategy ~suppress ~start_date strategy] returns a strategy that
    delegates to [strategy] and then passes the resulting output transitions
    through {!filter_transitions}. The wrapper is purely a transition filter; it
    does not otherwise alter the inner strategy's behaviour.

    When [suppress = false] the wrapper is the identity on the inner strategy's
    output (the gate short-circuits), so the wrapped strategy is behaviourally
    bit-identical to [strategy] — the no-op default. *)
