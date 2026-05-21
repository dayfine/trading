((schema_version 1)
 (spec
  ((bounds
    ((portfolio_config.max_position_pct_long (0.04 0.15))
     (portfolio_config.max_long_exposure_pct (0.45 0.85))
     (initial_stop_buffer (1 1.05))
     (screening_config.candidate_params.installed_stop_min_pct (0.06 0.13))))
   (acquisition Expected_improvement) (initial_random 10) (total_budget 60)
   (seed (2026)) (n_acquisition_candidates ())
   (objective
    (Composite ((SharpeRatio 0.4) (CalmarRatio 0.3) (MaxDrawdown -0.1))))
   (scenarios (walk-forward)) (holdout_folds (27 28 29 30))))
 (iterations
  (((parameters
     ((portfolio_config.max_position_pct_long 0.10444122477209591)
      (portfolio_config.max_long_exposure_pct 0.63134930028072345)
      (initial_stop_buffer 1.0320003325498872)
      (screening_config.candidate_params.installed_stop_min_pct
       0.12714286273793712)))
    (metric -9.7654833989609457)
    (per_scenario_metrics
     (((AvgHoldingDays 66.835833767365472) (SharpeRatio 0.77513222944209015)
       (MaxDrawdown 11.623992191204122) (CAGR 12.793719401846429)
       (CalmarRatio 1.6853163589024784) (TotalReturnPct 12.783281660414749))))))))
