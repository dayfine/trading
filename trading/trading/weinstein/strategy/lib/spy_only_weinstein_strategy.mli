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
          therefore sits below entry. *)
}

val name : string
(** Human-readable strategy name, [SpyOnlyWeinstein]. *)

val default_symbol : string
(** [SPY]. *)

val default_fallback_stop_buffer : float
(** [0.92] — an 8% loose initial stop, matching Weinstein's 8% correction rule
    (book §5.1) when no structural support floor is available. *)

val default_config : config
(** [default_config] uses {!default_symbol}, {!Stage.default_config},
    {!Weinstein_stops.default_config}, and {!default_fallback_stop_buffer}. *)

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
