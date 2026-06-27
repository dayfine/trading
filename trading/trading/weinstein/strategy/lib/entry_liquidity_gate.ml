let apply ~(config : Liquidity_config.t) ~bar_reader ~current_date candidates =
  let dollar_adv_for ticker =
    Liquidity_metric.dollar_adv ~lookback_days:config.adv_lookback_days
      (Bar_reader.daily_bars_for bar_reader ~symbol:ticker ~as_of:current_date)
  in
  Liquidity_gate.filter ~min_entry_dollar_adv:config.min_entry_dollar_adv
    ~dollar_adv_for candidates
