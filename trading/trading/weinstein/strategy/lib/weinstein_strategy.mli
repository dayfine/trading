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

(** {1 Configuration} *)

type config = {
  universe : string list;  (** All ticker symbols to consider for screening. *)
  index_symbol : string;
      (** Symbol for the broad market index (e.g. "GSPCX"). Used for macro
          analysis and RS computation. *)
  sector_etfs : (string * string) list;
      (** [(etf_symbol, sector_name)] pairs — one per sector tracked by the
          screener. When non-empty, the strategy accumulates bars for each ETF
          via [get_price] and builds a sector context map on screening days.
          Default: empty (sector gate degrades to Neutral). *)
  global_index_symbols : (string * string) list;
      (** [(index_symbol, label)] pairs for the world-markets macro indicator.
          [index_symbol] is what the data source knows (e.g. ["GDAXI.INDX"]);
          [label] is the human-readable name passed to {!Macro.analyze}.
          Default: empty (global consensus indicator degrades to Neutral). *)
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
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values.

    @param universe Ticker symbols to screen.
    @param index_symbol Broad market index symbol for macro analysis. *)

(** {1 Factory} *)

val name : string
(** Strategy name, always ["Weinstein"]. *)

val spdr_sector_etfs : (string * string) list
(** Canonical mapping from SPDR sector ETF symbols to human-readable sector
    names. Covers the eleven US GICS sectors: XLK (Technology), XLF
    (Financials), XLE (Energy), XLV (Health Care), XLI (Industrials), XLP
    (Consumer Staples), XLY (Consumer Discretionary), XLU (Utilities), XLB
    (Materials), XLRE (Real Estate), XLC (Communication Services).

    Use as the [sector_etfs] field of {!config} when running against a data
    source that caches these ETFs. *)

val default_global_indices : (string * string) list
(** Canonical mapping from major non-US equity indices to labels for the macro
    global-consensus indicator. Covers DAX, Nikkei, and the FTSE proxy ETF
    (ISF.LSE — iShares Core FTSE UCITS, per dev/status/data-gaps.md). Use as the
    [global_index_symbols] field of {!config} when the data source has these
    cached. *)

val make :
  ?initial_stop_states:Weinstein_stops.stop_state String.Map.t ->
  ?ad_bars:Macro.ad_bar list ->
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
      NYSE advance/decline breadth bars used by the macro analyzer. Typically
      produced by {!Ad_bars.load}. Default: empty — macro degrades to Neutral on
      A-D indicators when missing. *)
