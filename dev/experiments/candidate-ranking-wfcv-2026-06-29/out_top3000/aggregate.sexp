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
   ((variant_label quality_ranking)
    (total_return_pct
     ((mean 21.229335680719338) (stdev 19.59567305165443)
      (min -3.1224639800000351) (max 60.852267339999976)))
    (sharpe_ratio
     ((mean 0.66673989612067908) (stdev 0.49592068175480453)
      (min -0.010118735568471956) (max 1.8699854205119681)))
    (max_drawdown_pct
     ((mean 15.655147144510071) (stdev 6.21226672639082)
      (min 6.70467284619564) (max 25.703206005002222)))
    (calmar_ratio
     ((mean 0.76136705008115846) (stdev 0.63406584756222439)
      (min -0.061347425216931289) (max 2.2137534034199)))
    (cagr_pct
     ((mean 9.79325770155398) (stdev 8.7125854639992664)
      (min -1.5746825701705713) (max 26.848193826749434)))
    (avg_holding_days
     ((mean 41.228695788042742) (stdev 9.18098920297499)
      (min 19.890410958904109) (max 55.661538461538463))))))
 (sensitivity
  (((variant_label quality_ranking) (sharpe_wins 4) (calmar_wins 5)
    (total_return_wins 5) (max_drawdown_wins 6))))
 (verdicts
  ((quality_ranking
    (Fail (wins 4) (n 13) (worst_fold fold-003) (worst_gap 0.39508107942933)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-003 trails by 0.3951 > \206\148=0.3000"))))))
