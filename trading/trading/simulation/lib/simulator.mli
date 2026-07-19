(** Simulation engine for backtesting trading strategies.

    Core types are defined in {!Simulator_types} and included here. *)

include module type of Trading_simulation_types.Simulator_types

(** {1 Simulator} *)

type t
(** Abstract simulator type *)

type step_outcome =
  | Stepped of t * step_result  (** Simulation advanced one step *)
  | Completed of run_result  (** Simulation complete with final results *)

(** {1 Dependencies} *)

type dependencies = {
  symbols : string list;
  data_dir : Fpath.t;
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
  engine : Trading_engine.Engine.t;
  order_manager : Trading_orders.Manager.order_manager;
  market_data_adapter : Trading_simulation_data.Market_data_adapter.t;
  metric_suite : metric_suite;
  benchmark_symbol : string option;
      (** Optional benchmark symbol whose adjusted-close % change is captured
          per step on [step_result.benchmark_return]. The benchmark may be
          outside [symbols] — bars are fetched independently. The antifragility
          computer reads these per-step values to compute ConcavityCoef and
          BucketAsymmetry. *)
  stale_hold_policy : Stale_hold.config;
      (** Stale-held-position detection policy. Default
          {!Stale_hold.default_config} (enabled, K=5 days). Each step queries
          {!Stale_hold.detect_stale} and appends events to [stale_hold_log]. The
          detector is a recorder, not a force-closer — see {!Stale_hold} for the
          deferred-M&A rationale. *)
  stale_hold_log : Stale_hold.Log.t;
      (** Per-run collector populated by every step where at least one held
          position is stale. Drained by the runner at end-of-run. *)
  margin_config : Trading_portfolio.Margin_config.t;
      (** Phase-2 margin-accounting parameters (issue #859). When
          [enabled = false] (the default), every margin code path is a no-op and
          existing baselines are bit-equal. *)
  initial_long_margin_req : float;
      (** Long-side leverage dial (margin M1b-2). [1.0] (the default, a cash
          account) disarms long leverage: the fill seam is bit-equal to
          [Portfolio.apply_single_trade]. When [< 1.0], a levered long BUY funds
          its cash shortfall into [Portfolio.long_margin_debit] up to the
          buying-power ceiling ([equity /. req]) enforced upstream by the entry
          walk. Threaded from [config.initial_long_margin_req]. *)
  long_margin_rate_annual_pct : float;
      (** Annualized interest rate on the long-margin debit (margin M1b-2).
          [0.0] (the default) charges nothing; when positive,
          {!Margin_runner.tick} capitalizes one trading day's interest onto
          [long_margin_debit] each step. Threaded from
          [config.long_margin_rate_annual_pct]. *)
  exempt_closing_trades_from_cash_floor : bool;
      (** NS1 (#1557#3): passed to [Portfolio.create] when the run's portfolio
          is built. When [true], the cash floor skips the reducing portion of a
          closing trade (long sell / short cover). [false] (the default)
          preserves byte-equal baselines. The backtest runner threads this from
          [config.portfolio_config.exempt_closing_trades_from_cash_floor]. *)
  on_trade_fill : (Trading_base.Types.trade -> Trading_base.Types.trade) option;
      (** Optional post-fill per-trade adjustment, applied inside the
          simulator's accept-trades path before the portfolio accounts for each
          trade. [None] (the default) preserves byte-equal baselines.

          Strategy-agnostic, cost-model-agnostic hook so the simulator does not
          depend on the higher-layer [Backtest_cost_model.Cost_model]. Callers
          in the backtest layer construct the hook from
          [Cost_model.apply_per_trade_commission] and thread it through. *)
  active_through_for : (string -> Core.Date.t option) option;
      (** Optional per-symbol [active_through] lookup. When [Some f], the
          simulator prunes [symbols] once at {!create} time: any symbol [s] with
          [f s = Some d] and [Core.Date.(d < config.start_date)] is dropped from
          the per-step bar-fetch loop ({!_get_today_bars}). [config.start_date]
          is the simulator's first day (== fold start date including warmup); a
          symbol whose last active day is strictly before this start cannot
          contribute any usable bar to the run.

          Domain framing: this is NOT survivor bias. Filtering on
          [active_through < fold_start_date] removes symbols that were genuinely
          uninvestable AT THE TIME of the fold's start (already delisted before
          the simulator began). Filtering on the present ("active_today") WOULD
          be survivor bias — that cut is wrong and is not performed here.

          Default [None] preserves bit-equal baselines: no pruning, every symbol
          participates in every step's bar-fetch loop. Authority:
          [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4. *)
}

val create_deps :
  symbols:string list ->
  data_dir:Fpath.t ->
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  commission:Trading_engine.Types.commission_config ->
  ?metric_suite:metric_suite ->
  ?benchmark_symbol:string ->
  ?market_data_adapter:Trading_simulation_data.Market_data_adapter.t ->
  ?stale_hold_policy:Stale_hold.config ->
  ?stale_hold_log:Stale_hold.Log.t ->
  ?slippage_bps:int ->
  ?margin_config:Trading_portfolio.Margin_config.t ->
  ?initial_long_margin_req:float ->
  ?long_margin_rate_annual_pct:float ->
  ?exempt_closing_trades_from_cash_floor:bool ->
  ?on_trade_fill:(Trading_base.Types.trade -> Trading_base.Types.trade) ->
  ?active_through_for:(string -> Core.Date.t option) ->
  unit ->
  dependencies
(** Create standard dependencies with default engine, order manager, and
    adapter. Strategy cadence is set via [config.strategy_cadence].

    @param benchmark_symbol
      Optional symbol used to populate [step_result.benchmark_return] (e.g.
      ["SPY"]). When omitted, the field is [None] on every step and the
      antifragility metrics emit 0.0.
    @param market_data_adapter
      Optional pre-built market data adapter. When supplied, it replaces the
      default CSV-backed adapter that {!create_deps} would otherwise build from
      [data_dir]. Used by the daily-snapshot streaming path (Phase D —
      [dev/plans/daily-snapshot-streaming-2026-04-27.md]) where the caller
      supplies a callback-mode adapter backed by [Daily_panels.t] instead of a
      [Price_cache.t]. [data_dir] is still required for the
      [dependencies.data_dir] field that downstream callers may read but is
      unused for adapter construction when [market_data_adapter] is supplied.
    @param stale_hold_log
      Per-run collector populated by every step where at least one held position
      is stale. Defaults to a fresh log; pass a pre-built one when the caller
      wants to drain events at run end (the backtest runner does this to persist
      [stale_holds.sexp]).
    @param slippage_bps
      Explicit basis-points slippage applied at every trade fill. Default [0]
      (no slippage — preserves the no-friction baseline). Plumbed directly into
      {!Trading_engine.Types.engine_config.slippage_bps}. Use non-zero for
      cost-overlay runs (P4 from
      [dev/notes/next-session-priorities-2026-05-07.md]).
    @param margin_config
      Phase-2 margin-accounting parameters (issue #859). Default
      {!Trading_portfolio.Margin_config.default_config} — disabled, so the
      simulator's per-step margin code paths are no-ops and existing baselines
      are bit-equal.
    @param initial_long_margin_req
      Long-side leverage dial (margin M1b-2). Default [1.0] (cash account) — the
      fill seam is bit-equal to [Portfolio.apply_single_trade]. See the field
      doc on {!dependencies.initial_long_margin_req}.
    @param long_margin_rate_annual_pct
      Annualized interest rate on the long-margin debit (margin M1b-2). Default
      [0.0] — no interest is charged, baselines bit-equal. See the field doc on
      {!dependencies.long_margin_rate_annual_pct}.
    @param exempt_closing_trades_from_cash_floor
      NS1 (#1557#3) cash-floor closing-trade exemption, passed to
      [Portfolio.create]. Default [false] — the floor faces every full trade
      exactly as before, so existing baselines are bit-equal. See the field doc
      on {!dependencies.exempt_closing_trades_from_cash_floor}.
    @param on_trade_fill
      Optional per-trade adjustment applied to every accepted fill before the
      portfolio accounts for it. Default [None] — preserves byte-equal
      baselines. Used by the backtest layer to wire the
      {!Backtest_cost_model.Cost_model} per-trade flat commission into the
      simulator without giving [trading.simulation] a layering dependency on the
      higher-layer cost-model module.
    @param active_through_for
      Optional per-symbol [active_through] lookup driving universe pruning at
      {!create} time. Default [None] preserves baselines — no pruning. See the
      field doc on {!dependencies.active_through_for} for the domain rationale
      (point-in-time pruning, NOT survivor bias). *)

val prune_symbols_by_active_through :
  symbols:string list ->
  active_through_for:(string -> Core.Date.t option) ->
  fold_start_date:Core.Date.t ->
  string list
(** Win #4 pure helper: drop symbols from [symbols] whose [active_through_for]
    returns [Some d] with [Core.Date.(d < fold_start_date)]. [None] symbols (no
    delisting marker — still trading or unknown) pass through unchanged.

    Point-in-time framing: filters on the fold's START date (a date in the past
    relative to the present), so symbols delisted later during the fold are
    KEPT. This is NOT survivor bias — filtering on the current date would be,
    but that cut is not performed here. Invoked from {!create} when
    [dependencies.active_through_for] is [Some _]; tests pin the predicate
    directly. Authority: [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4. *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t Status.status_or
(** Create a simulator. Returns error if end_date <= start_date. *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. *)

val run : t -> run_result Status.status_or
(** Run the full simulation from start to end date. *)

val get_config : t -> config
