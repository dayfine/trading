(** Weinstein stage-analysis strategy.

    Implements Stan Weinstein's Stage 2 entry / Stage 3-4 exit methodology as a
    [STRATEGY] module that the existing simulator can run.

    {1 Weekly cadence}

    This strategy is designed for weekly calls (Friday close). Pair it with
    [Simulator.create_deps ~strategy_cadence:Weekly] so the simulator only calls
    [on_market_close] on Fridays.

    {1 State}

    The STRATEGY interface is stateless (positions are passed in every call).
    Weinstein-specific state (stop states, prior stage classifications, last
    macro result) lives in a closure created by [make]. In simulation the state
    evolves across weekly calls. In live mode it should be saved/loaded via
    [Weinstein_trading_state].

    {1 on_market_close behaviour}

    On each weekly call the strategy: 1. Updates trailing stops for all held
    positions; emits [UpdateRiskParams] for adjusted stops, [TriggerExit] for
    stops hit. 2. Runs macro analysis using the index bars provided via
    [get_price]. 3. If in a non-bearish regime (or the first call): runs stock
    screener over all symbols available via [get_price]. 4. Emits
    [CreateEntering] for top-ranked buy candidates that pass portfolio-risk
    limits (no new entries if macro is Bearish). *)

(** {1 Configuration} *)

type config = {
  universe : string list;  (** All ticker symbols to consider for screening. *)
  index_symbol : string;
      (** Symbol for the broad market index (e.g. "GSPCX"). Used for macro
          analysis and RS computation. *)
  stage : Stage.config;  (** Stage classifier parameters. *)
  macro : Macro.config;  (** Macro analyser parameters. *)
  screening : Screener.config;  (** Screener cascade parameters. *)
  portfolio : Portfolio_risk.config;  (** Position sizing and risk limits. *)
  stops : Weinstein_stops.config;
      (** Trailing stop state machine parameters. *)
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

val make : config -> (module Trading_strategy.Strategy_interface.STRATEGY)
(** Create a Weinstein strategy module with fresh internal state.

    Calling [make] twice creates two independent instances with their own stop
    states. Re-use the same instance across weekly calls to accumulate stop
    history.

    The returned module satisfies the [STRATEGY] interface. Register it with the
    simulator via [Simulator.create_deps ~strategy]. *)
