(** Tier-bookkeeping wrapper around a [STRATEGY] module for the Tiered loader
    path.

    Step 3f-part3 of the backtest-tiered-loader plan
    (dev/plans/backtest-tiered-loader-2026-04-19.md §3f). The wrapper observes
    each [on_market_close] call and drives [Bar_loader] tier transitions so the
    Tiered runner path actually promotes / demotes as the strategy moves through
    the simulator loop:

    - On Fridays (weekly cadence, detected via the primary index bar's
      day-of-week): promote every universe symbol to [Summary_tier], run the
      [Shadow_screener] cascade on the resulting summaries, and promote the
      top-[full_candidate_limit] candidates to [Full_tier]. The shadow screener
      output is used for tier promotion decisions and emits a [Promote_full]
      trace phase for the candidates.
    - On any [CreateEntering] transition emitted by the wrapped strategy:
      promote the entering symbol to [Full_tier]. Ensures Full-tier OHLCV is
      available the first time stops/indicators read it for a new position.
    - On any position that has just transitioned to [Closed] (detected by
      diffing the portfolio state across calls): demote the symbol to
      [Metadata_tier]. Frees the Full-tier bars now that the strategy no longer
      tracks the position.

    The wrapper is {b purely additive} with respect to the wrapped strategy —
    all of the underlying strategy's transitions pass through unchanged. This
    keeps the 3g parity gate clean: the wrapper adds [Bar_loader] bookkeeping
    but never changes the set of transitions the simulator sees. The
    [Shadow_screener] output on Fridays is used for tier promotion only in this
    increment; replacing the inner screener's candidates with shadow output is a
    follow-on step the plan explicitly scopes outside 3f-part3.

    The [stop_log] hook replicates {!Strategy_wrapper}'s behaviour — the Tiered
    path uses this wrapper {b instead of} [Strategy_wrapper], not on top of it,
    so transition capture composes into one place. *)

open Trading_strategy

type config = {
  bar_loader : Bar_loader.t;  (** Shared tier-aware bar loader. *)
  universe : string list;
      (** Symbols eligible for Summary promotion on Friday. Typically
          [deps.all_symbols] from the runner. *)
  screening_config : Screener.config;
      (** Cascade config forwarded verbatim to [Shadow_screener.screen]. *)
  full_candidate_limit : int;
      (** Maximum number of Shadow_screener buy + short candidates to promote to
          Full tier on a single Friday. Protects against a runaway promotion
          batch when the shadow cascade admits many candidates. Typical values
          track
          [screening_config.max_buy_candidates +
           screening_config.max_short_candidates]. *)
  stop_log : Stop_log.t;
      (** Shared stop-log collector. The wrapper records transitions to it on
          every call, same contract as {!Strategy_wrapper}. *)
  primary_index : string;
      (** Primary benchmark ticker used to read the "current bar" for Friday
          detection and as-of date resolution. Typically
          [config.indices.primary]. *)
}

val wrap :
  config:config ->
  (module Strategy_interface.STRATEGY) ->
  (module Strategy_interface.STRATEGY)
(** [wrap ~config inner] returns a [STRATEGY] module that delegates to [inner]
    and layers tier bookkeeping on top.

    Precondition: [config.bar_loader] has already been populated with Metadata
    tier for [config.universe] (the runner does this in its initial [Load_bars]
    wrap before calling the simulator). [wrap] itself does not load bars; it
    only promotes / demotes existing entries.

    The returned module's [on_market_close]: 1. Delegates to
    [inner.on_market_close]. 2. Records the resulting transitions to
    [config.stop_log]. 3. Demotes any symbols whose positions transitioned to
    [Closed] since the previous call. 4. If today is a Friday (per the primary
    index bar's day-of-week): promotes [config.universe] to Summary, runs
    [Shadow_screener.screen] over the summaries, and promotes the
    top-[config.full_candidate_limit] buy+short candidates to Full. 5. Promotes
    any [CreateEntering] transition's symbol to Full.

    The transition list returned to the simulator is unchanged — step (4) is
    pure bookkeeping; step (5) is also pure bookkeeping, not an emission.

    Any [Bar_loader.promote] error is logged to stderr and swallowed so a data
    issue on a single symbol doesn't abort the entire backtest; the simulator
    continues on whatever tier the symbol reached. Demotion is infallible so no
    error path. *)
