(** Tier-bookkeeping wrapper around a [STRATEGY] module for the Tiered loader
    path.

    Step 3f-part3 of the backtest-tiered-loader plan
    (dev/plans/backtest-tiered-loader-2026-04-19.md §3f), extended on 2026-04-22
    by the strategy↔bar_loader integration
    (dev/plans/backtest-tiered-strategy-integration-2026-04-22.md). Stage 3 PR
    3.2 of the columnar-data-shape plan
    (dev/plans/data-panels-stage3-2026-04-25.md) deleted [Bar_history]; the
    Friday-cycle seed step is now gone. The wrapper still sits on two seams:

    {1 Tier bookkeeping}

    Around each inner [on_market_close] call:

    - On Fridays (weekly cadence, detected via the primary index bar's
      day-of-week): {b before} delegating to the inner strategy, promote every
      universe symbol to [Full_tier]. The promote drives [Bar_loader] tier
      bookkeeping and emits [Promote_full] trace events — historically it also
      seeded a parallel [Bar_history] cache, but with that cache deleted the
      promote alone remains.
    - On any [CreateEntering] transition emitted by the wrapped strategy:
      promote the entering symbol to [Full_tier].
    - On any position that has just transitioned to [Closed] (detected by
      diffing the portfolio state across calls): demote the symbol to
      [Metadata_tier]. Frees the Full-tier bars.

    {1 get_price throttle}

    The wrapper wraps the simulator's [get_price] with a filter so the inner
    strategy only sees prices for symbols that are structurally always needed
    (primary index, sector ETFs, global indices), currently at [Full_tier], or
    currently held in the portfolio. All other universe symbols resolve to
    [None]. With panel-backed bar reads, the strategy reads OHLCV directly from
    the panels and does not depend on this throttle for memory; the throttle
    survives because it shapes the [get_price] view passed into the inner
    strategy's day-of-week / fallback paths.

    {1 Purely additive transitions}

    The wrapper is purely additive with respect to the wrapped strategy's
    transition output — all of the underlying strategy's transitions pass
    through unchanged. The tier bookkeeping and the [get_price] filter are the
    only observable side effects. *)

open Core
open Trading_strategy

type config = {
  bar_loader : Bar_loader.t;  (** Shared tier-aware bar loader. *)
  universe : string list;
      (** Symbols eligible for Full promotion on Friday. Typically
          [deps.all_symbols] from the runner. *)
  always_loaded_symbols : String.Set.t;
      (** Symbols whose [get_price] is always passed through regardless of tier.
          The primary index, sector ETFs, and global indices live here — they're
          structurally required every day for day-of-week detection, the sector
          map, and the macro global-consensus indicator. At most a dozen
          symbols. *)
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
    and layers tier bookkeeping + [get_price] throttling on top.

    Precondition: [config.bar_loader] has already been populated with Metadata
    tier for [config.universe] (the runner does this in its initial [Load_bars]
    wrap before calling the simulator). [wrap] itself does not load bars; it
    only promotes / demotes existing entries.

    The returned module's [on_market_close]: 1. If today is a Friday (per the
    primary index bar's day-of-week): promotes every symbol in [config.universe]
    to [Full_tier]. 2. Constructs a throttled [get_price'] that returns [None]
    for any symbol that is (a) not in [config.always_loaded_symbols], (b) not
    currently at [Full_tier], and (c) not currently held in the portfolio.
    Delegates to [inner.on_market_close] with [get_price']. 3. Records the
    resulting transitions to [config.stop_log]. 4. Demotes any symbols whose
    positions transitioned to [Closed] since the previous call. 5. Promotes any
    [CreateEntering] transition's symbol to [Full_tier].

    The transition list returned to the simulator is unchanged — the tier
    bookkeeping does not emit transitions.

    Any [Bar_loader.promote] error is logged to stderr and swallowed so a data
    issue on a single symbol doesn't abort the entire backtest; the simulator
    continues on whatever tier the symbol reached. Demotion is infallible so no
    error path. *)
