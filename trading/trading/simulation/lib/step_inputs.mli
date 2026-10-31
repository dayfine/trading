(** What the simulator reads from the market data adapter each step: the day's
    engine bars and the strategy's transitions. Extracted from [Simulator]
    (#3477) so it stays under the file length limit; behaviour is unchanged. *)

val today_bars :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  symbols:string list ->
  date:Core.Date.t ->
  Trading_engine.Types.price_bar list
(** The [date] bar of every symbol in [symbols] that has one, as engine price
    bars, in [symbols] order. *)

val strategy_transitions :
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  cadence:Types.Cadence.t ->
  date:Core.Date.t ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  Trading_strategy.Position.transition list Status.status_or
(** Call the strategy's [on_market_close] when [date] closes a [cadence] period,
    with price and indicator lookups bound to [date] on [adapter]; return [[]]
    on every other day without calling it. *)
