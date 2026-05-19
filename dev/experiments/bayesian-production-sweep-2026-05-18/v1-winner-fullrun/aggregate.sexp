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
      (min -16.162883176183087) (max 44.972887517815273))))
   ((variant_label v1-winner)
    (total_return_pct
     ((mean 11.966332843133637) (stdev 18.093781627662107)
      (min -17.674245330000016) (max 66.021161859999992)))
    (sharpe_ratio
     ((mean 0.79576305908816636) (stdev 1.0776748176120223)
      (min -1.1434311662865473) (max 2.8324301190724763)))
    (max_drawdown_pct
     ((mean 10.569551367237343) (stdev 4.5276895031620716)
      (min 4.1295284063837885) (max 21.810696685591715)))
    (calmar_ratio
     ((mean 1.8372232152206649) (stdev 2.6220963651298237)
      (min -0.8128676869884307) (max 8.952058216880534)))
    (cagr_pct
     ((mean 11.975944965018885) (stdev 18.108157068949467)
      (min -17.685211190310458) (max 66.07881817770722))))))
 (sensitivity
  (((variant_label v1-winner) (sharpe_wins 19) (calmar_wins 18)
    (total_return_wins 17) (max_drawdown_wins 22))))
 (verdicts
  ((v1-winner
    (Fail (wins 19) (n 31) (worst_fold "") (worst_gap NAN)
     (reason "fold-pair count mismatch: measured 31, gate expects 30"))))))
