let apply ~(config : Weinstein_strategy.config) bar_reader ~as_of ~longs ~shorts
    =
  let flag_spikes =
    Spike_bar_gate.flag_candidates bar_reader ~as_of
      ~threshold_pct:config.spike_bar_threshold_pct
  in
  let longs, participation_warnings =
    Participation_gate.partition ~liquidity_config:config.liquidity_config
      bar_reader ~as_of longs
  in
  let longs, long_warnings = flag_spikes longs in
  let shorts, short_warnings = flag_spikes shorts in
  (longs, shorts, participation_warnings @ long_warnings @ short_warnings)
