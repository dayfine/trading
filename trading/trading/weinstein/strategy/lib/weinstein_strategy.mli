(** Weinstein stage-analysis strategy.

    Implements Stan Weinstein's Stage 2 entry / Stage 3-4 exit methodology as a
    [STRATEGY] module that the existing simulator can run.

    {1 Cadence}

    This strategy runs on daily cadence. Pair it with
    [Simulator.create_deps ~strategy_cadence:Daily].

    Stop adjustments happen every day — trailing stops follow the MA, which
    moves daily. Macro analysis and screening for new entries happen only on
    Fridays (weekly review), detected from the date of the index bar.

    {1 State}

    The STRATEGY interface is stateless (positions are passed in every call).
    Weinstein-specific state (stop states, prior stage classifications, last
    macro result) lives in a closure created by [make]. In simulation the state
    evolves across daily calls. In live mode it should be saved/loaded via
    [Weinstein_trading_state].

    {1 on_market_close behaviour}

    On each daily call the strategy: 1. Updates trailing stops for all held
    positions; emits [UpdateRiskParams] for adjusted stops, [TriggerExit] for
    stops hit. 2. On Fridays only: runs macro analysis using the index bars
    provided via [get_price]; runs stock screener over all symbols; emits
    [CreateEntering] for top-ranked buy candidates that pass portfolio-risk
    limits (no new entries if macro is Bearish). *)

open Core

(** {1 Sub-modules} *)

module Ad_bars = Ad_bars
(** NYSE advance/decline breadth data loader. See {!Ad_bars}. *)

module Bar_history = Bar_history
(** Per-symbol daily bar buffer. See {!Bar_history}. *)

module Stops_runner = Stops_runner
(** Trailing-stop state machine loop over held positions. See {!Stops_runner}.
*)

module Macro_inputs = Macro_inputs
(** Sector map + global index assembly from accumulated bar history. Exposes the
    canonical {!Macro_inputs.spdr_sector_etfs} and
    {!Macro_inputs.default_global_indices} constants for use in {!config}. *)

(** {1 Configuration} *)

type index_config = {
  primary : string;
      (** The US benchmark symbol (e.g. ["GSPCX"]). Dual-use: passed to
          {!Macro.analyze} as [~index_bars], and used by
          {!Stock_analysis.analyze} as [~benchmark_bars] when computing relative
          strength. *)
  global : (string * string) list;
      (** [(symbol, label)] pairs for non-US indices used by the macro
          global-consensus indicator. Default: empty. Use
          {!Macro_inputs.default_global_indices} for the canonical (GDAXI, N225,
          ISF.LSE) triple. [primary] is intentionally excluded from this list —
          it is already passed via [~index_bars]. *)
}
[@@deriving sexp]
(** Indices consumed by the macro analyser. The primary index is the US
    benchmark; globals are additional markets used only for the global consensus
    indicator. *)

type config = {
  universe : string list;  (** All ticker symbols to consider for screening. *)
  indices : index_config;
      (** Market indices consumed by the macro analyser. See {!index_config}. *)
  sector_etfs : (string * string) list;
      (** [(etf_symbol, sector_name)] pairs — one per sector tracked by the
          screener. When non-empty, the strategy accumulates bars for each ETF
          via [get_price] and builds a sector context map on screening days.
          Default: empty (sector gate degrades to Neutral). Use
          {!Macro_inputs.spdr_sector_etfs} for the canonical 11-sector list. *)
  stage_config : Stage.config;  (** Stage classifier parameters. *)
  macro_config : Macro.config;  (** Macro analyser parameters. *)
  screening_config : Screener.config;  (** Screener cascade parameters. *)
  portfolio_config : Portfolio_risk.config;
      (** Position sizing and risk limits. *)
  stops_config : Weinstein_stops.config;
      (** Trailing stop state machine parameters. *)
  initial_stop_buffer : float;
      (** Multiplier applied to [suggested_stop] when computing the initial stop
          level for a new entry. Default: 1.02 (2% buffer above the screener
          stop). *)
  lookback_bars : int;
      (** Number of weekly bars to pass to stage/macro analysers (default: 52).
          Must be >= 30 (one MA period). *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. The resulting config has
    [indices.primary = index_symbol] and [indices.global = []]; callers can set
    [indices.global] and [sector_etfs] via record update to opt into the full
    macro pipeline.

    @param universe Ticker symbols to screen.
    @param index_symbol US benchmark index (becomes [indices.primary]). *)

(** {1 Factory} *)

val name : string
(** Strategy name, always ["Weinstein"]. *)

val held_symbols : Trading_strategy.Portfolio_view.t -> string list
(** Ticker symbols of positions the strategy is still holding (or still trying
    to enter/exit). Closed positions are excluded — the strategy has no stake in
    them and must be free to re-enter the symbol.

    Used internally to (a) filter screener candidates and (b) populate
    [held_tickers] passed to [Screener.screen]. Public because the result is a
    natural query on strategy state and the behaviour (exclude [Closed]) is
    worth pinning by direct unit test. *)

val entries_from_candidates :
  config:config ->
  candidates:Screener.scored_candidate list ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  bar_history:Bar_history.t ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  current_date:Date.t ->
  Trading_strategy.Position.transition list
(** Generate [CreateEntering] transitions for a list of screener candidates.

    For each candidate:
    - Applies the Weinstein position sizer
      ({!Weinstein.Portfolio_risk.compute_position_size}). Candidates whose
      per-trade risk rounds to zero shares are dropped.
    - Computes the initial stop via
      {!Weinstein_stops.compute_initial_stop_with_floor}, threading [cand.side]:
      longs get a stop below the prior correction low; shorts get a stop above
      the prior rally high. Falls back to [config.initial_stop_buffer] when no
      qualifying counter-move is in the lookback window.
    - Emits a [CreateEntering] with [side = cand.side].

    Side effect: seeds [stop_states] with the computed initial stop for each new
    entry.

    Cash tracking: each entry's [target_quantity * entry_price] is deducted from
    [portfolio.cash]; candidates whose cost exceeds the remaining cash are
    skipped. For short candidates this is conservative (shorts generate proceeds
    rather than consume cash) but safe.

    Public because it's a useful primitive for callers that want to run
    screening out-of-band (e.g. custom universe loops) and feed candidates into
    the strategy's entry pipeline. *)

val make :
  ?initial_stop_states:Weinstein_stops.stop_state String.Map.t ->
  ?ad_bars:Macro.ad_bar list ->
  ?ticker_sectors:(string, string) Hashtbl.t ->
  ?bar_history:Bar_history.t ->
  config ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** Create a Weinstein strategy module with fresh internal state.

    Calling [make] twice creates two independent instances with their own stop
    states. Re-use the same instance across weekly calls to accumulate stop
    history.

    @param initial_stop_states
      Seed the stop state map — useful for tests and for restoring live state
      from persistence. Default: empty map.
    @param ad_bars
      NYSE advance/decline daily bars, passed through to {!Macro.analyze} on
      every screening day. Load once via {!Ad_bars.load} before calling [make] —
      the list lives in the closure for the lifetime of the strategy instance.
      Default: empty list (macro breadth indicators degrade to zero weight).
    @param ticker_sectors
      Stock ticker → GICS sector name hashtable, typically loaded via
      {!Sector_map.load}. Used to expand the ETF-level sector analysis to
      individual stock tickers in the screener. Default: empty table (sector
      gate degrades to Neutral for all tickers).
    @param bar_history
      Optional shared [Bar_history.t]. When provided, the strategy reads from
      and writes into the caller's buffer instead of allocating a fresh one.
      Used by the Tiered backtest path so the [Tiered_strategy_wrapper] can
      [Bar_history.seed] from [Bar_loader.get_full] after Full-tier promotions
      and have those bars visible to the strategy's own readers. Default: a
      fresh empty [Bar_history.t] (the pre-existing behaviour). *)
