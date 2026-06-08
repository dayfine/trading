((fold_count 29) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 7.1987705289616892) (stdev 22.21253166977047)
      (min -27.899477600000004) (max 52.619978059999994)))
    (sharpe_ratio
     ((mean 0.23167632051829135) (stdev 0.94591734942621541)
      (min -1.5637099318654424) (max 1.7082595116169219)))
    (max_drawdown_pct
     ((mean 17.249561992681162) (stdev 11.761684821963476)
      (min 5.9250491756103383) (max 60.847317221705524)))
    (calmar_ratio
     ((mean 0.71435097220646593) (stdev 1.3922160970726285)
      (min -0.90635754431941862) (max 4.0426810406361806)))
    (cagr_pct
     ((mean 7.2054001947701343) (stdev 22.228875837152284)
      (min -27.91562970989855) (max 52.664179529975726)))
    (avg_holding_days
     ((mean 34.373510496212262) (stdev 8.9441366036095591)
      (min 10.666666666666666) (max 46.282051282051285))))
   ((variant_label enable_laggard_rotation=false)
    (total_return_pct
     ((mean 14.184478595965519) (stdev 34.58287729175651)
      (min -26.780105679999988) (max 152.933537)))
    (sharpe_ratio
     ((mean 0.36764323877932314) (stdev 0.95049515874476243)
      (min -1.6563203593200788) (max 1.9405532610602971)))
    (max_drawdown_pct
     ((mean 18.19801775776407) (stdev 13.063212895909428)
      (min 6.34093689650346) (max 60.650410320538448)))
    (calmar_ratio
     ((mean 0.763475548413255) (stdev 1.3608472500878357)
      (min -0.85908257487270612) (max 4.9112418430959375)))
    (cagr_pct
     ((mean 14.197854143714748) (stdev 34.615387590993009)
      (min -26.795736108896907) (max 153.09434928944557)))
    (avg_holding_days
     ((mean 43.32917274553698) (stdev 21.649597761361303) (min 12.75)
      (max 94))))))
 (sensitivity
  (((variant_label enable_laggard_rotation=false) (sharpe_wins 15)
    (calmar_wins 15) (total_return_wins 16) (max_drawdown_wins 15))))
 (verdicts
  ((enable_laggard_rotation=false
    (Fail (wins 15) (n 29) (worst_fold fold-007)
     (worst_gap 1.3154710944515597)
     (reason
      "\206\148-threshold miss: fold fold-007 trails by 1.3155 > \206\148=0.2000"))))))
