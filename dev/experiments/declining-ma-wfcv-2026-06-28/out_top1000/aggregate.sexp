((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 19.201428220530062) (stdev 16.9679047372812)
      (min -15.835053170000005) (max 47.744823820000008)))
    (sharpe_ratio
     ((mean 0.65312448282665747) (stdev 0.48937616077105606)
      (min -0.4429109752160682) (max 1.2300199147727318)))
    (max_drawdown_pct
     ((mean 16.477514222212214) (stdev 7.6012818365217747)
      (min 8.7635615557698756) (max 38.079981144238829)))
    (calmar_ratio
     ((mean 0.75552791086754667) (stdev 0.69762816088127466)
      (min -0.21730089457766438) (max 1.8377799596120787)))
    (cagr_pct
     ((mean 8.9203577292301812) (stdev 7.92749353698432)
      (min -8.2639604538725422) (max 21.566577316735327)))
    (avg_holding_days
     ((mean 39.541013316089057) (stdev 7.1517786784071431)
      (min 28.015748031496063) (max 52.641975308641975))))
   ((variant_label declining_ma_gate_on)
    (total_return_pct
     ((mean 19.200475533606987) (stdev 16.994169126646991)
      (min -16.030929209999996) (max 47.744823820000008)))
    (sharpe_ratio
     ((mean 0.653557520122) (stdev 0.48921764290278219)
      (min -0.44320788075463718) (max 1.2300199147727318)))
    (max_drawdown_pct
     ((mean 16.473668161504374) (stdev 7.5894440941548549)
      (min 8.7635615557698756) (max 38.029982355036971)))
    (calmar_ratio
     ((mean 0.75567613131169431) (stdev 0.69771854763182628)
      (min -0.22040060731114069) (max 1.8377799596120787)))
    (cagr_pct
     ((mean 8.9188434377533561) (stdev 7.9435218237316132)
      (min -8.37084382492127) (max 21.566577316735327)))
    (avg_holding_days
     ((mean 39.5539651428442) (stdev 7.1617259075317259) (min 27.8671875)
      (max 52.641975308641975))))))
 (sensitivity
  (((variant_label declining_ma_gate_on) (sharpe_wins 1) (calmar_wins 1)
    (total_return_wins 1) (max_drawdown_wins 1))))
 (verdicts
  ((declining_ma_gate_on
    (Fail (wins 1) (n 13) (worst_fold fold-012)
     (worst_gap 0.00029690553856898116)
     (reason "M-threshold miss: 1 wins < 7 required"))))))
