((fold_count 15) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 12.950175847379974) (stdev 22.618292019823588)
      (min -19.005390539999958) (max 76.327379320000063)))
    (sharpe_ratio
     ((mean 0.64281770518313874) (stdev 1.035903103408901)
      (min -1.3497426614545693) (max 2.477847091992945)))
    (max_drawdown_pct
     ((mean 14.790393995098752) (stdev 7.6295421545449154)
      (min 4.83580819694276) (max 29.472804615426089)))
    (calmar_ratio
     ((mean 1.3816425612264558) (stdev 1.9832979358211229)
      (min -0.89513301326801242) (max 6.4305724204432115)))
    (cagr_pct
     ((mean 12.960955114086703) (stdev 22.637319854560033)
      (min -19.017083297276237) (max 76.395891247279053)))
    (avg_holding_days
     ((mean 33.199530843360172) (stdev 9.39446128560447)
      (min 22.226415094339622) (max 51.270270270270274))))
   ((variant_label enable_laggard_rotation=false)
    (total_return_pct
     ((mean 9.9079609736363654) (stdev 29.195159744388157)
      (min -21.820384539999978) (max 93.990199840000017)))
    (sharpe_ratio
     ((mean 0.4890418412942758) (stdev 1.0914641722044118)
      (min -1.5265829749615876) (max 1.7773837115778701)))
    (max_drawdown_pct
     ((mean 16.509850913755358) (stdev 8.2190028315059251)
      (min 5.4714282449759857) (max 28.783825487566112)))
    (calmar_ratio
     ((mean 1.2949295516897255) (stdev 2.0147265623033346)
      (min -0.91222036204668167) (max 5.1821425269268)))
    (cagr_pct
     ((mean 9.91734694384506) (stdev 29.219952822630351)
      (min -21.833564792835613) (max 94.078264461689969)))
    (avg_holding_days
     ((mean 38.152084024047582) (stdev 19.028567158409018) (min 12)
      (max 74.3529411764706))))))
 (sensitivity
  (((variant_label enable_laggard_rotation=false) (sharpe_wins 6)
    (calmar_wins 6) (total_return_wins 5) (max_drawdown_wins 5))))
 (verdicts
  ((enable_laggard_rotation=false
    (Fail (wins 6) (n 15) (worst_fold "") (worst_gap NAN)
     (reason "fold-pair count mismatch: measured 15, gate expects 14"))))))
