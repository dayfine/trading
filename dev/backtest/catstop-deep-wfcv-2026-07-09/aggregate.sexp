((fold_count 26) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 7.7705621210762725) (stdev 13.391159047482921) (min -16.62697474)
      (max 40.843236710000035)))
    (sharpe_ratio
     ((mean 0.49177450147199669) (stdev 0.90881911197750775)
      (min -1.4697858986111161) (max 3.0497472809556196)))
    (max_drawdown_pct
     ((mean 12.11291909738202) (stdev 4.0489648129222191)
      (min 4.2018663700072159) (max 24.025116688596494)))
    (calmar_ratio
     ((mean 0.89389071221889682) (stdev 1.7116048113202751)
      (min -0.97574020795636163) (max 7.538337464357765)))
    (cagr_pct
     ((mean 7.77662259580537) (stdev 13.401350213276752)
      (min -16.637358338806784) (max 40.876278674241973)))
    (avg_holding_days
     ((mean 34.928529223395977) (stdev 12.888476672684098) (min 19)
      (max 69.451612903225808))))
   ((variant_label catastrophic_stop_pct=0.0)
    (total_return_pct
     ((mean 7.8922248445378109) (stdev 13.701943563243885) (min -16.62697474)
      (max 40.843236710000035)))
    (sharpe_ratio
     ((mean 0.49416868034422) (stdev 0.92181264035101251)
      (min -1.4697858986111161) (max 3.0497472809556196)))
    (max_drawdown_pct
     ((mean 12.30845206358136) (stdev 3.9958784556256339)
      (min 4.2018663700072159) (max 24.025116688596494)))
    (calmar_ratio
     ((mean 0.91173287169807737) (stdev 1.7244326277033644)
      (min -0.97574020795636163) (max 7.538337464357765)))
    (cagr_pct
     ((mean 7.8984010209263227) (stdev 13.712344188350448)
      (min -16.637358338806784) (max 40.876278674241973)))
    (avg_holding_days
     ((mean 35.3930390525478) (stdev 12.843995816219545) (min 19)
      (max 69.451612903225808))))
   ((variant_label catastrophic_stop_pct=0.10)
    (total_return_pct
     ((mean 7.7705621210762725) (stdev 13.391159047482921) (min -16.62697474)
      (max 40.843236710000035)))
    (sharpe_ratio
     ((mean 0.49177450147199669) (stdev 0.90881911197750775)
      (min -1.4697858986111161) (max 3.0497472809556196)))
    (max_drawdown_pct
     ((mean 12.11291909738202) (stdev 4.0489648129222191)
      (min 4.2018663700072159) (max 24.025116688596494)))
    (calmar_ratio
     ((mean 0.89389071221889682) (stdev 1.7116048113202751)
      (min -0.97574020795636163) (max 7.538337464357765)))
    (cagr_pct
     ((mean 7.77662259580537) (stdev 13.401350213276752)
      (min -16.637358338806784) (max 40.876278674241973)))
    (avg_holding_days
     ((mean 34.928529223395977) (stdev 12.888476672684098) (min 19)
      (max 69.451612903225808))))))
 (sensitivity
  (((variant_label catastrophic_stop_pct=0.0) (sharpe_wins 5) (calmar_wins 4)
    (total_return_wins 4) (max_drawdown_wins 1))
   ((variant_label catastrophic_stop_pct=0.10) (sharpe_wins 0)
    (calmar_wins 0) (total_return_wins 0) (max_drawdown_wins 0))))
 (verdicts
  ((catastrophic_stop_pct=0.0
    (Fail (wins 5) (n 26) (worst_fold fold-002)
     (worst_gap 0.24903332940033215)
     (reason
      "M-threshold miss: 5 wins < 14 required; worst fold fold-002 trails by 0.2490 > \206\148=0.0000")))
   (catastrophic_stop_pct=0.10
    (Fail (wins 0) (n 26) (worst_fold fold-000) (worst_gap 0)
     (reason "M-threshold miss: 0 wins < 14 required"))))))
