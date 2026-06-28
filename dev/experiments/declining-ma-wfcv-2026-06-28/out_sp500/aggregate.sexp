((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 22.029700098118948) (stdev 24.302294513583902)
      (min -14.47308799999999) (max 75.926718525546235)))
    (sharpe_ratio
     ((mean 0.72580977863861318) (stdev 0.68180124766096739)
      (min -0.41579310396668329) (max 2.0038132279073193)))
    (max_drawdown_pct
     ((mean 12.694799212814475) (stdev 3.8542018292457643)
      (min 7.567926828577086) (max 22.181308999999995)))
    (calmar_ratio
     ((mean 1.0335726920870409) (stdev 1.2480795823121775)
      (min -0.33966040580027379) (max 4.3227792451102864)))
    (cagr_pct
     ((mean 9.9834001806883759) (stdev 10.838441299996484)
      (min -7.5241901176876569) (max 32.663031985843752)))
    (avg_holding_days
     ((mean 41.052632974487) (stdev 10.097694440403625)
      (min 24.630769230769232) (max 56.03448275862069))))
   ((variant_label declining_ma_gate_on)
    (total_return_pct
     ((mean 22.015725559657412) (stdev 24.325075433947386)
      (min -14.654756999999959) (max 75.926718525546235)))
    (sharpe_ratio
     ((mean 0.72537241508301953) (stdev 0.68259595292462849)
      (min -0.42147883018939952) (max 2.0038132279073193)))
    (max_drawdown_pct
     ((mean 12.707273058968319) (stdev 3.887580640617248)
      (min 7.567926828577086) (max 22.343468999999981)))
    (calmar_ratio
     ((mean 1.0334233487385036) (stdev 1.2482576980438453)
      (min -0.34160186933125747) (max 4.3227792451102864)))
    (cagr_pct
     ((mean 9.97583601839899) (stdev 10.851704283029115)
      (min -7.6225242274496789) (max 32.663031985843752)))
    (avg_holding_days
     ((mean 41.059179619331516) (stdev 10.087273824535462)
      (min 24.630769230769232) (max 56.03448275862069))))))
 (sensitivity
  (((variant_label declining_ma_gate_on) (sharpe_wins 0) (calmar_wins 0)
    (total_return_wins 0) (max_drawdown_wins 0))))
 (verdicts
  ((declining_ma_gate_on
    (Fail (wins 0) (n 13) (worst_fold fold-011)
     (worst_gap 0.0056857262227162364)
     (reason "M-threshold miss: 0 wins < 7 required"))))))
