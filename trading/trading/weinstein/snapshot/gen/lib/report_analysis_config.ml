(* The backtest's builder, so every field it threads reaches the report too,
   except the F5 screen-time volume waiver: the backtest waives volume at screen
   time only because [Volume_eject_runner] re-checks it in the fill week, and
   the live path has no fill-week check, so the report keeps the gate (#3726). *)
let of_strategy_config (config : Weinstein_strategy.config) =
  {
    (Weinstein_strategy.stock_analysis_config_for ~config) with
    require_breakout_volume =
      Stock_analysis.default_config.require_breakout_volume;
  }
