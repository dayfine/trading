(** Tier-bookkeeping wrapper around a [STRATEGY] module for the Tiered loader
    path.

    Step 3f-part3 of the backtest-tiered-loader plan
    (dev/plans/backtest-tiered-loader-2026-04-19.md §3f), extended on 2026-04-22
    by the strategy↔bar_loader integration
    (dev/plans/backtest-tiered-strategy-integration-2026-04-22.md) and revised
    on 2026-04-23 to fix bull-crash A/B parity by promoting every Summary-tier
    symbol to Full each Friday (rather than only the [Shadow_screener]'s top-N
    picks; see [_run_friday_cycle] note in the .ml). The wrapper now sits on two
    seams:

    {1 Tier bookkeeping}

    Around each inner [on_market_close] call:

    - On Fridays (weekly cadence, detected via the primary index bar's
      day-of-week): {b before} delegating to the inner strategy, promote every
      universe symbol to [Summary_tier], then promote {e every} Summary-tier
      symbol to [Full_tier], and seed [bar_history] with each newly-promoted
      symbol's [Full.t.bars] so the inner strategy's screener sees the same
      history it would have accumulated under the Legacy path. Promoting every
      Summary symbol (rather than a screener-cascade-filtered subset) is
      load-bearing for parity: inner's [_screen_universe] only analyzes symbols
      with bars in [Bar_history], so any candidate Legacy would have considered
      must reach Full first.
    - On any [CreateEntering] transition emitted by the wrapped strategy:
      promote the entering symbol to [Full_tier] and seed [bar_history] with its
      [Full.t.bars]. Ensures Full-tier OHLCV is available the first time stops /
      indicators read it for a new position.
    - On any position that has just transitioned to [Closed] (detected by
      diffing the portfolio state across calls): demote the symbol to
      [Metadata_tier]. Frees the Full-tier bars. [Bar_history] retains its
      accumulated series — future [accumulate] calls for the same symbol are
      no-ops after the throttle cuts them off.

    {1 get_price throttle}

    The wrapper wraps the simulator's [get_price] with a filter so the inner
    strategy only accumulates [Bar_history] for symbols that are structurally
    always needed (primary index, sector ETFs, global indices), currently at
    [Full_tier], or currently held in the portfolio. All other universe symbols
    resolve to [None], so {!Bar_history.accumulate} silently skips them. This is
    the core memory win over the Legacy path.

    {1 Purely additive transitions}

    The wrapper is purely additive with respect to the wrapped strategy's
    transition output — all of the underlying strategy's transitions pass
    through unchanged. The tier bookkeeping and the [get_price] filter are the
    only observable side effects. *)

open Core
open Trading_strategy
module Bar_history = Weinstein_strategy.Bar_history

type config = {
  bar_loader : Bar_loader.t;  (** Shared tier-aware bar loader. *)
  bar_history : Bar_history.t;
      (** Shared daily-bar buffer — the same one passed to
          [Weinstein_strategy.make ~bar_history]. The wrapper seeds it on Full
          promotion so the inner strategy's readers see accumulated bars without
          touching strategy code. *)
  universe : string list;
      (** Symbols eligible for Summary promotion on Friday. Typically
          [deps.all_symbols] from the runner. *)
  always_loaded_symbols : String.Set.t;
      (** Symbols whose [get_price] is always passed through regardless of tier.
          The primary index, sector ETFs, and global indices live here — they're
          structurally required every day for day-of-week detection, the sector
          map, and the macro global-consensus indicator. At most a dozen
          symbols. *)
  seed_warmup_start : Core.Date.t;
      (** Earliest date the wrapper includes when seeding [bar_history] from
          loader [Full.t.bars]. Match the Runner's [warmup_start]
          ([start_date - warmup_days]) so the seeded window equals what Legacy's
          [Bar_history.accumulate] would have grown day-by-day over the warmup
          + simulation. Loader-side [Full.t.bars] carries ~1800 days by default;
            if we seeded that raw, [Stock_analysis.analyze] would see strictly
            more weekly bars under Tiered than under Legacy and the RS /
            resistance / MA outputs would silently diverge. *)
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
    primary index bar's day-of-week): promotes [config.universe] to Summary,
    then promotes every Summary-tier symbol to Full, and seeds
    [config.bar_history] with each Full symbol's [Full.t.bars]. 2. Constructs a
    throttled [get_price'] that returns [None] for any symbol that is (a) not in
    [config.always_loaded_symbols], (b) not currently at [Full_tier], and (c)
    not currently held in the portfolio. Delegates to [inner.on_market_close]
    with [get_price']. 3. Records the resulting transitions to
    [config.stop_log]. 4. Demotes any symbols whose positions transitioned to
    [Closed] since the previous call. 5. Promotes any [CreateEntering]
    transition's symbol to [Full_tier] and seeds [config.bar_history] with its
    bars.

    The transition list returned to the simulator is unchanged — the tier
    bookkeeping does not emit transitions.

    Any [Bar_loader.promote] error is logged to stderr and swallowed so a data
    issue on a single symbol doesn't abort the entire backtest; the simulator
    continues on whatever tier the symbol reached. Demotion is infallible so no
    error path. *)
