(** Strategy dispatch for the panel runner — see [panel_strategy_builder.mli].
*)

module Spy_only = Weinstein_strategy.Spy_only_weinstein_strategy
module Sector_rotation = Weinstein_strategy.Sector_rotation_weinstein_strategy

let build ~ad_bars ~ticker_sectors ~config ~strategy_choice ~bar_reader
    ~audit_recorder =
  match (strategy_choice : Strategy_choice.t) with
  | Weinstein ->
      Weinstein_strategy.make ~ad_bars ~ticker_sectors ~bar_reader
        ~audit_recorder config
  | Bah_benchmark { symbol } ->
      Trading_strategy.Bah_benchmark_strategy.make { symbol }
  | Spy_only_weinstein { symbol; ma_period_weeks; enable_stage4_short } ->
      let config =
        Spy_only.config_with ~symbol ~enable_stage4_short ~ma_period_weeks ()
      in
      Spy_only.make ~config ~bar_reader ()
  | Sector_rotation_weinstein { k; ma_period_weeks } ->
      let config = Sector_rotation.config_with ~k ~ma_period_weeks () in
      Sector_rotation.make ~config ~bar_reader ()
