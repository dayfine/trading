open Core

(* Daily_price -> engine price_bar. *)
let _to_price_bar symbol (p : Types.Daily_price.t) :
    Trading_engine.Types.price_bar =
  {
    symbol;
    open_price = p.open_price;
    high_price = p.high_price;
    low_price = p.low_price;
    close_price = p.close_price;
  }

let today_bars ~adapter ~symbols ~date =
  List.filter_map symbols ~f:(fun symbol ->
      Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol
        ~date
      |> Option.map ~f:(_to_price_bar symbol))

let strategy_transitions ~strategy ~adapter ~cadence ~date ~portfolio ~positions
    =
  if not (Trading_simulation_data.Time_series.is_period_end ~cadence date) then
    Ok []
  else
    let (module S : Trading_strategy.Strategy_interface.STRATEGY) = strategy in
    let get_price symbol =
      Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol
        ~date
    in
    let get_indicator symbol indicator_name period cadence =
      Trading_simulation_data.Market_data_adapter.get_indicator adapter ~symbol
        ~indicator_name ~period ~cadence ~date
    in
    let view : Trading_strategy.Portfolio_view.t =
      { cash = portfolio.Trading_portfolio.Portfolio.current_cash; positions }
    in
    Result.map (S.on_market_close ~get_price ~get_indicator ~portfolio:view)
      ~f:(fun output -> output.transitions)
