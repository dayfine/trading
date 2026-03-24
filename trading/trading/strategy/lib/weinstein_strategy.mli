(** Weinstein Stage Analysis strategy.

    Implements the {!Strategy_interface.STRATEGY} interface using Stan
    Weinstein's stage analysis methodology. Designed for weekly cadence
    (call once per Friday) in tandem with the simulator's [Weekly]
    strategy_cadence setting.

    {1 Design}

    The strategy maintains private mutable state in the closure produced by
    {!make}:
    - Stop loss levels per symbol (Weinstein trailing stops)
    - Prior stage classification per symbol (for transition detection)
    - Prior macro trend (for regime change detection)

    State lives in the closure for simulation. In live trading, state should be
    loaded/saved externally (see portfolio_manager module).

    {1 Signal Logic}

    On each Friday call to [on_market_close]:
    1. For each held position: check if the 30-week MA is broken or stop hit.
       Emit [TriggerExit] if so. Emit [UpdateRiskParams] if stop raised.
    2. Macro gate: check if the market (using the index SMA) is in a bullish or
       bearish regime.
    3. Universe scan: for each tracked symbol, check if price is above the
       30-week SMA and the SMA is rising. Score candidates.
    4. Emit [CreateEntering] for top-scoring candidates that pass all gates.

    {1 Parameters in Config}

    All thresholds are configurable — never hardcoded. *)

open Core

(** Configuration for the 30-week MA check and stage classification. *)
type stage_config = {
  ma_period : int;
      (** Moving average period in weeks. Default: 30 (Weinstein's 30-week MA). *)
  ma_slope_lookback : int;
      (** Number of weeks to look back for slope calculation. Default: 4. *)
  breakout_premium_pct : float;
      (** How far above the MA counts as a breakout, as a fraction. Default:
          0.02 (2%). *)
}
[@@deriving show, eq]

val default_stage_config : stage_config

(** Configuration for the macro filter. *)
type macro_config = {
  index_symbol : string;
      (** Symbol to use as the market index. Default: "SPY". *)
  index_ma_period : int;
      (** MA period for the index. Default: 30 (weeks). *)
}
[@@deriving show, eq]

val default_macro_config : macro_config

(** Position sizing configuration. *)
type sizing_config = {
  risk_per_trade_pct : float;
      (** Maximum risk per trade as a fraction of portfolio value. Default:
          0.01 (1%). *)
  max_positions : int;  (** Maximum number of concurrent positions. Default: 20. *)
  stop_pct_below_ma : float;
      (** Initial stop as a fraction below the 30-week MA. Default: 0.07 (7%). *)
}
[@@deriving show, eq]

val default_sizing_config : sizing_config

(** Full strategy configuration. All parameters configurable for backtesting and
    tuning. *)
type config = {
  symbols : string list;
      (** Universe of symbols to scan. Strategy only trades from this list. *)
  stage : stage_config;
  macro : macro_config;
  sizing : sizing_config;
}
[@@deriving show, eq]

val default_config : symbols:string list -> config
(** Create a default config for the given symbol universe. *)

val name : string
(** Strategy name for identification. *)

val make : config -> (module Strategy_interface.STRATEGY)
(** Create a Weinstein strategy instance that implements the STRATEGY interface.

    The returned strategy module captures [config] and private mutable state in
    its closure. Each call to [on_market_close] updates the internal state.

    Expected usage: call [make] once, pass the module to [Simulator.create_deps].
    For weekly backtests, set [strategy_cadence = Weekly] in the simulator
    config. *)
