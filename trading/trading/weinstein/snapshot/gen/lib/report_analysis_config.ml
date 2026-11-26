let of_strategy_config (config : Weinstein_strategy.config) =
  {
    Stock_analysis.default_config with
    overhead_supply = config.overhead_supply;
    virgin_crossing_readmission = config.virgin_crossing_readmission;
    virgin_supply_basis = config.virgin_supply_basis;
    entry_anchor_local_range_weeks = config.entry_anchor_local_range_weeks;
    entry_cap_local_range_weeks = config.entry_cap_local_range_weeks;
    entry_freshness_basis = config.entry_freshness_basis;
  }
