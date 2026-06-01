(** Sector-rotation Weinstein stage-timing strategy — a long/flat reference
    strategy that holds the top-[k] strongest Stage-2 sector ETFs, ranked by
    relative strength vs a benchmark (default SPY).

    This is the multi-symbol generalization of {!Spy_only_weinstein_strategy}:
    instead of trading one fixed symbol, it screens a list of tradable sector
    ETFs each week, keeps only those in Stage 2, ranks them by RS vs the
    benchmark, and holds the top [k]. It is a deliberately minimal testbed,
    {b separate} from the production {!Weinstein_strategy}, that isolates the
    {e selection} layer (which Stage-2 names to hold) from the screener /
    portfolio-risk / macro machinery.

    {1 What it reuses}

    - {!Stage.classify} on each symbol's own weekly bars (read via
      {!Bar_reader.weekly_bars_for}) for the per-symbol stage signal.
    - {!Rs.analyze} (RS vs the benchmark's weekly bars) for the cross-sectional
      ranking — spine item 7 (relative strength for selection).
    - {!Spy_only_transitions} for the (symbol-parameterised) entry / stage-exit
      / stop-exit transition builders, and {!Spy_only_signals} for the
      per-symbol stage-exit verdict — both are generic over the symbol.
    - {!Weinstein_stops} for the per-position trailing stop: each held symbol
      carries its own stop state, seeded from a support-floor lookup on entry,
      advanced daily by the {!Weinstein_stops.update} state machine, and
      triggered by {!Weinstein_stops.check_stop_hit}.

    {1 What it does NOT do}

    - No shorting. Long/flat only — a symbol leaving the target set, or rolling
      into Stage 3/4, exits to flat; it never goes short.
    - No screener, no portfolio-risk position sizing, no sector gating, no macro
      gate. Sizing equal-weights available cash across the entry slots being
      filled this Friday (which
      {e degenerates to all-cash sizing when [k = 1]}). The macro gate is
      intentionally omitted to isolate the selection signal: this is faithful
      per [.claude/rules/weinstein-faithful-core.md] — the RS-ranked Stage-2
      selection across sectors directly implements spine items 2 (buy only Stage
      2), 4 (exit Stage 3/4), and 7 (RS for selection); the broad-tape macro
      gate is a follow-on dial, not part of this testbed.

    {1 Cadence}

    - {b Friday (weekly close):} re-classify every tradable symbol's stage,
      compute RS for the Stage-2 names, rank, and make the rotation decision —
      exit holdings that left the top-[k] target set (or rolled into Stage 3/4),
      enter target symbols not yet held.
    - {b Every day:} advance + check the trailing stop on each held position
      (keyed per symbol).

    {1 Statefulness}

    The instance carries closure-scoped mutable state across [on_market_close]
    calls: a per-symbol trailing-stop state map and a per-symbol prior-stage
    map. Both are seeded fresh per {!make}. A symbol's stop state is cleared
    when its position exits, so a re-entry re-seeds. *)

type config = {
  symbols : string list;
      (** Tradable sector ETFs. Default {!default_symbols} (the 11 SPDR sector
          tickers). The benchmark is {e not} in this list — it is used only for
          RS ranking, never traded. *)
  benchmark_symbol : string;
      (** Benchmark used for the RS ranking, never traded. Default
          {!default_benchmark_symbol} ([SPY]). Must be present in the scenario's
          universe so the bar reader loads its weekly bars. *)
  k : int;
      (** Maximum number of concurrent holdings. Default {!default_k} ([1]). At
          [k = 1] the strategy holds the single strongest Stage-2 sector and the
          per-slot cash sizing degenerates to all-cash. *)
  stage_config : Stage.config;
      (** Stage-classifier parameters (30-week MA period, slope thresholds).
          Default {!Stage.default_config}. *)
  stops_config : Weinstein_stops.config;
      (** Trailing-stop parameters. Default {!Weinstein_stops.default_config}.
      *)
  rs_config : Rs.config;
      (** RS trend-analysis parameters. Default {!Rs.default_config}. Only the
          [current_normalized] field of the result is used (for ranking). *)
  fallback_stop_buffer : float;
      (** Multiplicative buffer placing the initial long stop at
          [entry_price *. fallback_stop_buffer] when the support-floor lookup
          finds no qualifying correction. Default
          {!default_fallback_stop_buffer} ([0.92] = an 8% stop). *)
}

val name : string
(** Human-readable strategy name, [SectorRotationWeinstein]. *)

val default_symbols : string list
(** The 11 SPDR sector ETFs:
    [XLK; XLF; XLI; XLV; XLE; XLP; XLY; XLU; XLB; XLRE; XLC]. *)

val default_benchmark_symbol : string
(** [SPY] — the RS-ranking benchmark, never traded. *)

val default_k : int
(** [1] — hold a single strongest Stage-2 sector by default. *)

val default_fallback_stop_buffer : float
(** [0.92] — an 8% loose initial stop, matching Weinstein's 8% correction rule
    (book §5.1) when no structural support floor is available. *)

val default_config : config
(** [default_config] uses {!default_symbols}, {!default_benchmark_symbol},
    {!default_k}, {!Stage.default_config}, {!Weinstein_stops.default_config},
    {!Rs.default_config}, and {!default_fallback_stop_buffer}. *)

val config_with :
  ?symbols:string list ->
  ?benchmark_symbol:string ->
  k:int ->
  ma_period_weeks:int ->
  unit ->
  config
(** [config_with ?symbols ?benchmark_symbol ~k ~ma_period_weeks ()] is
    {!default_config} with [k] holdings and the stage-classifier moving-average
    period overridden to [ma_period_weeks] weeks (and optionally a different
    tradable [symbols] list / [benchmark_symbol]).

    The MA period is the Weinstein-faithful dial distinguishing the investor
    preset ([30] weeks) from the trader preset ([10] weeks). Only
    [stage_config.ma_period] changes; the stops / RS / fallback-buffer configs
    are untouched. The weekly-bar lookback the strategy reads scales with this
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
      The snapshot-backed bar source the runner constructs; used to read each
      tradable symbol's + the benchmark's weekly aggregates (for
      {!Stage.classify} and {!Rs.analyze}) and daily bars (for the support-floor
      stop seed). The simulator's per-tick [get_price] supplies today's OHLC bar
      for the stop check and sizing. *)
