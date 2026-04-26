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

module Bar_reader = Bar_reader
(** Panel-backed bar source. See {!Bar_reader}. *)

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
  bar_history_max_lookback_days : int option;
      (** Hypothesis-testing field (perf workstream C1). Vestigial after the
          Stage 3 PR 3.2 deletion of [Bar_history] — the parallel cache no
          longer exists, so trimming has no behavioural effect. The field is
          kept on [config] so existing override sexps and CLI flags continue to
          parse; setting it is a no-op. Will be removed once backtest_runner CLI
          surface drops the corresponding flag. *)
  skip_ad_breadth : bool;
      (** Hypothesis-testing field (perf workstream C1). When [true], the runner
          does NOT call [Weinstein_strategy.Ad_bars.load]; macro indicators that
          depend on AD-breadth fall through to a degraded mode (treat AD-breadth
          as constant). Default [false] — current behaviour. Used for hypothesis
          tests like H3 (does AD-breadth load dominate RSS at 10K-symbol
          scale?). NOT safe to flip on in production. *)
  skip_sector_etf_load : bool;
      (** Hypothesis-testing field (perf workstream C1). When [true], the runner
          clears [sector_etfs] before strategy construction so sector-ETF bars
          are not loaded. Sector classification falls back to whatever
          [Sector_map] alone provides. Default [false] — current behaviour. Used
          for hypothesis tests like H4 (are sector ETF + index loads bounded?).
          NOT safe to flip on in production. *)
  universe_cap : int option;
      (** Hypothesis-testing field (perf workstream C1). When [Some n], the
          runner truncates the loaded universe to the first [n] symbols (after
          the existing [String.compare] sort) before strategy construction.
          [None] (default) uses the full universe. Used for hypothesis tests
          like H5 (how does RSS scale with universe size?). NOT safe to flip on
          in production. *)
  full_compute_tail_days : int option;
      (** Hypothesis-testing field (perf workstream H2). When [Some n], the
          Tiered loader's [Bar_loader.Full_compute.tail_days] is set to [n]
          instead of the default. Caps the bar count retained per Full-tier
          symbol.

          [None] (default) uses [Full_compute.default_config.tail_days] (1800).
          The Legacy [loader_strategy] does not use [Full_compute] at all, so
          the override is a no-op on that path. Stage 3 PR 3.2 deleted
          [Bar_history], so the strategy no longer reads from [Full.t.bars] via
          the Friday-cycle seed; this override remains relevant only to the
          loader's own retention.

          Hypothesis-testing only — like the other hypothesis toggles. NOT safe
          to flip on in production. See H2 in
          [dev/plans/backtest-perf-2026-04-24.md]. *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting.

    The five hypothesis-testing fields ([bar_history_max_lookback_days],
    [skip_ad_breadth], [skip_sector_etf_load], [universe_cap],
    [full_compute_tail_days]) all default to behaviour-preserving values.
    Setting any of them changes runner / strategy behaviour and is intended for
    perf measurement A/Bs only — see the H-series in
    [dev/plans/backtest-perf-2026-04-24.md]. *)

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
  bar_reader:Bar_reader.t ->
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
  ?bar_panels:Data_panel.Bar_panels.t ->
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
    @param bar_panels
      Optional [Bar_panels.t] (panel-backed bar reader). When provided, the
      strategy reads OHLCV bars from panel columns via {!Bar_reader.of_panels}.
      When omitted, an empty reader is used — every read returns the empty list,
      which is sufficient for tests that exercise control paths where no
      panel-backed bar is ever consumed (empty universe, no held positions,
      etc.). Production callers must always supply this. *)
