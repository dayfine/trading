((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 36.094277093122166) (stdev 42.335631770903596)
      (min -8.839993820000009) (max 146.09703549058818)))
    (sharpe_ratio
     ((mean 0.92283935355048774) (stdev 0.8576714758541133)
      (min -0.33405450971551293) (max 2.8201657949102703)))
    (max_drawdown_pct
     ((mean 14.870256331994401) (stdev 5.13482739179466)
      (min 9.2471852856224661) (max 25.56867552087494)))
    (calmar_ratio
     ((mean 1.4084758237382227) (stdev 1.7440816199335967)
      (min -0.26218442804255904) (max 6.0840627771112654)))
    (cagr_pct
     ((mean 15.52683732762377) (stdev 16.982800407673338)
      (min -4.525276932299704) (max 56.923191288229248)))
    (avg_holding_days
     ((mean 46.62762559660662) (stdev 12.279398477810791)
      (min 27.760869565217391) (max 67.3913043478261))))
   ((variant_label scale_in_pullback)
    (total_return_pct
     ((mean 23.385489335475125) (stdev 24.721405112206771)
      (min -15.505348709999966) (max 71.49746534)))
    (sharpe_ratio
     ((mean 0.7750353860766841) (stdev 0.733274999880344)
      (min -0.52828519297608434) (max 2.3280069250027142)))
    (max_drawdown_pct
     ((mean 14.233820990307215) (stdev 5.8234638546027648)
      (min 7.8052581335430844) (max 24.716274968248939)))
    (calmar_ratio
     ((mean 1.0915506315833368) (stdev 1.2415926447791155)
      (min -0.32751535533526027) (max 3.8785709237819046)))
    (cagr_pct
     ((mean 10.584119273723164) (stdev 10.996998214025798)
      (min -8.0843314291051414) (max 30.981234128036018)))
    (avg_holding_days
     ((mean 42.179947171412167) (stdev 8.9637319706287357) (min 27.72)
      (max 61.120481927710841))))
   ((variant_label scale_in_either)
    (total_return_pct
     ((mean 23.385489335475125) (stdev 24.721405112206771)
      (min -15.505348709999966) (max 71.49746534)))
    (sharpe_ratio
     ((mean 0.7750353860766841) (stdev 0.733274999880344)
      (min -0.52828519297608434) (max 2.3280069250027142)))
    (max_drawdown_pct
     ((mean 14.233820990307215) (stdev 5.8234638546027648)
      (min 7.8052581335430844) (max 24.716274968248939)))
    (calmar_ratio
     ((mean 1.0915506315833368) (stdev 1.2415926447791155)
      (min -0.32751535533526027) (max 3.8785709237819046)))
    (cagr_pct
     ((mean 10.584119273723164) (stdev 10.996998214025798)
      (min -8.0843314291051414) (max 30.981234128036018)))
    (avg_holding_days
     ((mean 42.179947171412167) (stdev 8.9637319706287357) (min 27.72)
      (max 61.120481927710841))))))
 (sensitivity
  (((variant_label scale_in_pullback) (sharpe_wins 5) (calmar_wins 5)
    (total_return_wins 4) (max_drawdown_wins 8))
   ((variant_label scale_in_either) (sharpe_wins 5) (calmar_wins 5)
    (total_return_wins 4) (max_drawdown_wins 8))))
 (verdicts
  ((scale_in_pullback
    (Fail (wins 5) (n 13) (worst_fold fold-002) (worst_gap 1.222139560460846)
     (reason
      "M-threshold miss: 5 wins < 7 required; worst fold fold-002 trails by 1.2221 > \206\148=0.3000")))
   (scale_in_either
    (Fail (wins 5) (n 13) (worst_fold fold-002) (worst_gap 1.222139560460846)
     (reason
      "M-threshold miss: 5 wins < 7 required; worst fold fold-002 trails by 1.2221 > \206\148=0.3000"))))))
