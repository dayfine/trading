((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 23.733961079328427) (stdev 22.319855913446375)
      (min -20.530799810653573) (max 64.490662116923048)))
    (sharpe_ratio
     ((mean 0.73503086558447228) (stdev 0.549174901743562)
      (min -0.62958198906520779) (max 1.5965160491826409)))
    (max_drawdown_pct
     ((mean 15.721541414237585) (stdev 6.99663814844931)
      (min 9.87033780406796) (max 35.850924423529392)))
    (calmar_ratio
     ((mean 0.86098496203459485) (stdev 0.65868705415403894)
      (min -0.303355474082625) (max 2.0678244998774282)))
    (cagr_pct
     ((mean 10.821824171790736) (stdev 10.083307656331192)
      (min -10.861516221410717) (max 28.275774454284086)))
    (avg_holding_days
     ((mean 42.37165370195909) (stdev 9.5000630562402648) (min 23.578125)
      (max 58.258064516129032))))
   ((variant_label earliness_ranking)
    (total_return_pct
     ((mean 23.425576628338547) (stdev 25.495638925962471)
      (min -1.2601150200000149) (max 81.653900811538477)))
    (sharpe_ratio
     ((mean 0.6616249444662935) (stdev 0.49264547914379087)
      (min 0.031683695666833357) (max 1.5214869657393475)))
    (max_drawdown_pct
     ((mean 16.815237331516723) (stdev 6.0565094602092016)
      (min 8.7560009780727377) (max 29.656056027647036)))
    (calmar_ratio
     ((mean 0.74301674184486288) (stdev 0.76037105523400306)
      (min -0.023942062894857136) (max 2.4325200588243381)))
    (cagr_pct
     ((mean 10.606532566526607) (stdev 10.950441497429589)
      (min -0.63248651988382365) (max 34.806597276585038)))
    (avg_holding_days
     ((mean 40.798759994150537) (stdev 9.7062466755651489) (min 18.1625)
      (max 58.6))))))
 (sensitivity
  (((variant_label earliness_ranking) (sharpe_wins 6) (calmar_wins 5)
    (total_return_wins 6) (max_drawdown_wins 5))))
 (verdicts
  ((earliness_ranking
    (Fail (wins 6) (n 13) (worst_fold fold-007)
     (worst_gap 0.61749046530198937)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-007 trails by 0.6175 > \206\148=0.3000"))))))
