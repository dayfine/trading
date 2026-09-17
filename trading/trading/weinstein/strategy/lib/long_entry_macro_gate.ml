(** See [long_entry_macro_gate.mli]. *)

let admits ~(config : Weinstein_strategy_config.config)
    ~(macro_result : Macro.result) =
  Screener.longs_admitted_by_breadth
    ~neutral_blocks_longs:config.neutral_blocks_longs
    ~deteriorating_blocks_longs:config.deteriorating_blocks_longs
    ~macro_trend:macro_result.trend macro_result.breadth_state
  && Screener.longs_admitted_by_index_stage
       ~index_stage_veto_blocks_longs:config.index_stage_veto_blocks_longs
       (Some macro_result.Macro.index_stage.Stage.stage)
