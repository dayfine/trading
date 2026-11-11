(** Single-instrument Weinstein stage-timing strategy — a long/flat reference
    strategy that trades exactly one symbol (default SPY).

    This is a deliberately minimal testbed, {b separate} from the production
    {!Weinstein_strategy}. It exists to answer two questions cheaply:

    - {b Direction-finding.} On the cleanest possible signal (the index itself),
      does Weinstein stage timing — enter in Stage 2, exit on the Stage 3→4
      roll-over or a trailing-stop hit — beat buy-and-hold on {e risk-adjusted}
      terms? The Weinstein thesis is that Stage-4 exits dodge the deep
      drawdowns, trading some total return for a higher Sharpe / Calmar.
    - {b Headroom bound.} It puts a realizable floor under the trade-autopsy's
      perfect-hindsight estimates: a real, causal stage-timing rule on one
      symbol is something the autopsy's idealized exits can be measured against.

    {1 What it reuses}

    - {!Stage.classify} on the symbol's own weekly bars (read via
      {!Bar_reader.weekly_bars_for}) for the stage signal. The symbol {e is} the
      market, so there is no macro gate — entries are never blocked on a
      market-breadth read (the production strategy's macro gate is degenerate
      here and is omitted entirely).
    - {!Weinstein_stops} for the per-position trailing stop: the initial stop is
      seeded from a support-floor lookup on entry, then advanced daily by the
      {!Weinstein_stops.update} state machine and triggered by
      {!Weinstein_stops.check_stop_hit}.

    {1 What it does NOT do}

    - No shorting. Stage 4 means "exit to flat", never "go short". Stage-4
      shorting is an explicit follow-on, not this module.
    - No screener, no portfolio-risk position sizing, no sector gating. Sizing
      is all-cash ([floor(cash / close)]), mirroring {!Bah_benchmark_strategy}.

    {1 Cadence}

    - {b Friday (weekly close):} re-classify the stage and make the
      enter/exit-on-signal decision.
    - {b Every day:} advance + check the trailing stop on a held position.

    {1 Statefulness}

    Like the production strategy, the instance carries closure-scoped mutable
    state across [on_market_close] calls: the current trailing-stop state and
    the prior stage (for Stage1/Stage3 flat-MA disambiguation). The state is
    seeded fresh per {!make}. *)

type config = {
  symbol : string;
      (** Instrument to trade. Default {!default_symbol} ([SPY]). Bare ticker,
          no exchange suffix — matches the on-disk CSV layout under
          [data/S/Y/SPY/]. *)
  stage_config : Stage.config;
      (** Stage-classifier parameters (30-week MA period, slope thresholds,
          etc). Default {!Stage.default_config}. *)
  stops_config : Weinstein_stops.config;
      (** Trailing-stop parameters (correction depth, buffers, support-floor
          lookback). Default {!Weinstein_stops.default_config}. *)
  fallback_stop_buffer : float;
      (** Multiplicative buffer used to place the initial stop when the
          support-floor lookup finds no qualifying correction. For a long the
          stop falls at [entry_price *. fallback_stop_buffer]; a value below 1.0
          (default {!default_fallback_stop_buffer}, [0.92] = an 8% stop)
          therefore sits below entry. For a short the mirror is used — the stop
          sits {e above} entry at [entry_price /. fallback_stop_buffer]. *)
  enable_stage4_short : bool;
      (** Stage-4 short leg. When [false] ({b the default}, bit-identical to the
          original long/flat strategy) a Stage-4 read means "exit to flat" and
          the strategy is never short. When [true] the strategy {b goes short}
          in Stage 4 instead of sitting flat — a faithful Weinstein adaptation
          (he shorts Stage-4 declines; book §Short-Selling Rules). It is a
          {e testbed dial} only: default-off per
          [.claude/rules/experiment-flag-discipline.md] R1, and not promoted to
          the default config (R3) without a ledger ACCEPT.

          Short mechanics (mirror of the long side):
          - {b Entry.} On a weekly close, when flat and SPY's stage read is a
            Stage-4 exit signal (Stage 4, or a Stage 3→4 roll-over), open a
            short sized by the same all-cash [floor(cash / close)] rule as the
            long entry.
          - {b Stop.} {!Weinstein_stops} with [side = Short]: the initial stop
            sits {e above} the Stage-4 rally high (a counter-rally-high support
            floor, or the fallback buffer above entry) and ratchets {e down} as
            price falls. Triggered intraday by [high ≥ stop_level].
          - {b Exit.} The short is covered when SPY leaves Stage 4 — i.e. the
            weekly stage read becomes Stage 1 (basing) or Stage 2 (advancing) —
            or on a short-stop hit. (A flat Stage-2 read on the same Friday then
            opens a fresh long via the normal entry path.) *)
}

val name : string
(** Human-readable strategy name, [SpyOnlyWeinstein]. *)

val default_symbol : string
(** [SPY]. *)

val default_fallback_stop_buffer : float
(** [0.92] — an 8% loose initial stop, matching Weinstein's 8% correction rule
    (book §5.1) when no structural support floor is available. *)

val default_enable_stage4_short : bool
(** [false] — the Stage-4 short leg is off by default, keeping the strategy
    long/flat and bit-identical to its pre-short-leg behaviour. *)

val default_config : config
(** [default_config] uses {!default_symbol}, {!Stage.default_config},
    {!Weinstein_stops.default_config}, {!default_fallback_stop_buffer}, and
    {!default_enable_stage4_short} ([false] — long/flat). *)

val config_with :
  ?symbol:string ->
  ?enable_stage4_short:bool ->
  ma_period_weeks:int ->
  unit ->
  config
(** [config_with ?symbol ?enable_stage4_short ~ma_period_weeks ()] is
    {!default_config} with the stage-classifier moving-average period overridden
    to [ma_period_weeks] weeks (and optionally a different [symbol] and the
    Stage-4 short leg flipped on via [enable_stage4_short], default
    {!default_enable_stage4_short} = [false]).

    The MA period is the single Weinstein-faithful dial that distinguishes the
    investor preset ([30] weeks — Weinstein's default for position trading) from
    the trader preset ([10] weeks — his faster cadence). Only
    [stage_config.ma_period] changes; the stops config and fallback buffer are
    untouched. The weekly-bar lookback the strategy reads scales with this
    period so a shorter MA does not over-read history. *)

val make :
  ?config:config ->
  bar_reader:Bar_reader.t ->
  unit ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** [make ?config ~bar_reader ()] constructor. Returns a first-class
    {!Trading_strategy.Strategy_interface.STRATEGY} module whose
    [on_market_close] implements the cadence above.

    @param config Strategy parameters. Defaults to {!default_config}.
    @param bar_reader
      The snapshot-backed bar source the runner constructs; used to read the
      symbol's weekly aggregates (for {!Stage.classify}) and daily bars (for the
      support-floor seed). The simulator's per-tick [get_price] supplies today's
      OHLC bar for the stop check and sizing. *)
