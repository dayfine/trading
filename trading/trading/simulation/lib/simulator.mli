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
}

val create_deps :
  symbols:string list ->
  data_dir:Fpath.t ->
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  commission:Trading_engine.Types.commission_config ->
  ?metric_suite:metric_suite ->
  ?benchmark_symbol:string ->
  ?market_data_adapter:Trading_simulation_data.Market_data_adapter.t ->
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
      unused for adapter construction when [market_data_adapter] is supplied. *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t Status.status_or
(** Create a simulator. Returns error if end_date <= start_date. *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. *)

val run : t -> run_result Status.status_or
(** Run the full simulation from start to end date. *)

val get_config : t -> config
