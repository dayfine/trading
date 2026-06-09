((fold_count 11) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label force_exit_off)
    (total_return_pct
     ((mean 17.892751465317033) (stdev 24.58288749886087)
      (min -8.1435056600000362) (max 82.569206079999972)))
    (sharpe_ratio
     ((mean 0.884115046372353) (stdev 0.93807504863628588)
      (min -0.77856107699706234) (max 2.3654857611127684)))
    (max_drawdown_pct
     ((mean 11.318980253331837) (stdev 3.2356318255592234)
      (min 6.129957054398159) (max 16.568001291129992)))
    (calmar_ratio
     ((mean 2.2618865908391808) (stdev 3.9337767438617766)
      (min -0.60597440595609187) (max 13.531415764703578)))
    (cagr_pct
     ((mean 17.907508381769112) (stdev 24.60481712492625)
      (min -8.14884970725831) (max 82.6444950243172)))
    (avg_holding_days
     ((mean 36.729685441368169) (stdev 12.728469960128512) (min 22.325)
      (max 60.615384615384613))))
   ((variant_label baseline)
    (total_return_pct
     ((mean 17.892751465317033) (stdev 24.58288749886087)
      (min -8.1435056600000362) (max 82.569206079999972)))
    (sharpe_ratio
     ((mean 0.884115046372353) (stdev 0.93807504863628588)
      (min -0.77856107699706234) (max 2.3654857611127684)))
    (max_drawdown_pct
     ((mean 11.318980253331837) (stdev 3.2356318255592234)
      (min 6.129957054398159) (max 16.568001291129992)))
    (calmar_ratio
     ((mean 2.2618865908391808) (stdev 3.9337767438617766)
      (min -0.60597440595609187) (max 13.531415764703578)))
    (cagr_pct
     ((mean 17.907508381769112) (stdev 24.60481712492625)
      (min -8.14884970725831) (max 82.6444950243172)))
    (avg_holding_days
     ((mean 36.729685441368169) (stdev 12.728469960128512) (min 22.325)
      (max 60.615384615384613))))))
 (sensitivity
  (((variant_label force_exit_off) (sharpe_wins 0) (calmar_wins 0)
    (total_return_wins 0) (max_drawdown_wins 0))))
 (verdicts
  ((force_exit_off
    (Fail (wins 0) (n 11) (worst_fold "") (worst_gap NAN)
     (reason "fold-pair count mismatch: measured 11, gate expects 10"))))))
