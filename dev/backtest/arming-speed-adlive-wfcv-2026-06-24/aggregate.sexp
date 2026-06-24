((fold_count 26) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 9.297480757740793) (stdev 12.567167593515228)
      (min -8.6955870000000122) (max 52.069607110000028)))
    (sharpe_ratio
     ((mean 0.56220603057674678) (stdev 0.90687264203454754)
      (min -2.187221439883138) (max 1.9088877370576522)))
    (max_drawdown_pct
     ((mean 9.9476017188729315) (stdev 2.7490235851082812)
      (min 4.9922928915191438) (max 15.546422189757436)))
    (calmar_ratio
     ((mean 1.0304014842292029) (stdev 1.4491628199165612)
      (min -0.980960015966069) (max 5.4854355249188105)))
    (cagr_pct
     ((mean 9.3045915551289173) (stdev 12.577156186137005)
      (min -8.70127590470492) (max 52.113272788324473)))
    (avg_holding_days
     ((mean 34.200075632919571) (stdev 10.305707624689829)
      (min 7.7272727272727275) (max 59.5))))
   ((variant_label fast_v_arm_on_rate_alone=true)
    (total_return_pct
     ((mean 9.3571257435100232) (stdev 12.518148304841114)
      (min -8.6955870000000122) (max 52.069607110000028)))
    (sharpe_ratio
     ((mean 0.56703564016405972) (stdev 0.90513838903626342)
      (min -2.187221439883138) (max 1.9088877370576522)))
    (max_drawdown_pct
     ((mean 9.8279673283003532) (stdev 2.5585240621475753)
      (min 4.9922928915191438) (max 14.31071699999997)))
    (calmar_ratio
     ((mean 1.0361728143501829) (stdev 1.4443902601520024)
      (min -0.980960015966069) (max 5.4854355249188105)))
    (cagr_pct
     ((mean 9.3642772490259834) (stdev 12.528102733595828)
      (min -8.70127590470492) (max 52.113272788324473)))
    (avg_holding_days
     ((mean 34.083116423200181) (stdev 10.284168938395911)
      (min 7.7272727272727275) (max 59.5))))
   ((variant_label fast_v_arm_on_rate_alone=false)
    (total_return_pct
     ((mean 9.297480757740793) (stdev 12.567167593515228)
      (min -8.6955870000000122) (max 52.069607110000028)))
    (sharpe_ratio
     ((mean 0.56220603057674678) (stdev 0.90687264203454754)
      (min -2.187221439883138) (max 1.9088877370576522)))
    (max_drawdown_pct
     ((mean 9.9476017188729315) (stdev 2.7490235851082812)
      (min 4.9922928915191438) (max 15.546422189757436)))
    (calmar_ratio
     ((mean 1.0304014842292029) (stdev 1.4491628199165612)
      (min -0.980960015966069) (max 5.4854355249188105)))
    (cagr_pct
     ((mean 9.3045915551289173) (stdev 12.577156186137005)
      (min -8.70127590470492) (max 52.113272788324473)))
    (avg_holding_days
     ((mean 34.200075632919571) (stdev 10.305707624689829)
      (min 7.7272727272727275) (max 59.5))))))
 (sensitivity
  (((variant_label fast_v_arm_on_rate_alone=true) (sharpe_wins 1)
    (calmar_wins 1) (total_return_wins 1) (max_drawdown_wins 1))
   ((variant_label fast_v_arm_on_rate_alone=false) (sharpe_wins 0)
    (calmar_wins 0) (total_return_wins 0) (max_drawdown_wins 0))))
 (verdicts
  ((fast_v_arm_on_rate_alone=true
    (Fail (wins 1) (n 26) (worst_fold fold-010)
     (worst_gap 0.0077869523835187859)
     (reason
      "M-threshold miss: 1 wins < 14 required; worst fold fold-010 trails by 0.0078 > \206\148=0.0000")))
   (fast_v_arm_on_rate_alone=false
    (Fail (wins 0) (n 26) (worst_fold fold-000) (worst_gap 0)
     (reason "M-threshold miss: 0 wins < 14 required"))))))
