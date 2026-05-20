((fold_count 31) (baseline_label cell-E) (metric_label Sharpe)
 (stability
  (((variant_label cell-E)
    (total_return_pct
     ((mean 8.74309493470046) (stdev 17.2782672834372)
      (min -16.152766200000023) (max 44.93604105)))
    (sharpe_ratio
     ((mean 0.5598967065595859) (stdev 1.0642922226910019)
      (min -1.2609365358387516) (max 2.5886104969003845)))
    (max_drawdown_pct
     ((mean 11.980793631554612) (stdev 5.0069974927417551)
      (min 4.7226961812243315) (max 21.963222203750451)))
    (calmar_ratio
     ((mean 1.3095088660657972) (stdev 2.1588729270472076)
      (min -0.88417961402596523) (max 6.8879017406624)))
    (cagr_pct
     ((mean 8.7502314040844649) (stdev 17.291481072353715)
      (min -16.162883176183087) (max 44.972887517815273)))
    (avg_holding_days
     ((mean 33.882434369023656) (stdev 10.396262993410867) (min 19.78125)
      (max 63.114285714285714))))
   ((variant_label v2-winner)
    (total_return_pct
     ((mean 12.635297358110606) (stdev 18.917719915609513)
      (min -15.693699840000027) (max 78.551510810000025)))
    (sharpe_ratio
     ((mean 0.805110404338809) (stdev 1.0369117291520054)
      (min -0.99620767429427171) (max 2.940308556560125)))
    (max_drawdown_pct
     ((mean 10.482078511388522) (stdev 4.3999692029472968)
      (min 4.262473205154671) (max 19.791041860959631)))
    (calmar_ratio
     ((mean 1.8469128731998612) (stdev 2.5972371250032489)
      (min -0.80880707983620415) (max 8.6976285361271444)))
    (cagr_pct
     ((mean 12.645477713420453) (stdev 18.933328132042686)
      (min -15.703556956211495) (max 78.622420470084691)))
    (avg_holding_days
     ((mean 66.288005593308753) (stdev 11.601579555287881)
      (min 43.918032786885249) (max 87.658536585365852))))))
 (sensitivity
  (((variant_label v2-winner) (sharpe_wins 20) (calmar_wins 19)
    (total_return_wins 20) (max_drawdown_wins 21))))
 (verdicts
  ((v2-winner
    (Fail (wins 20) (n 31) (worst_fold "") (worst_gap NAN)
     (reason "fold-pair count mismatch: measured 31, gate expects 30"))))))
