((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 19.918805991794873) (stdev 20.552697389865784)
      (min -10.199166533333331) (max 71.993923839999979)))
    (sharpe_ratio
     ((mean 0.5968746113084944) (stdev 0.49408679374788878)
      (min -0.4213376555946925) (max 1.2963294973210586)))
    (max_drawdown_pct
     ((mean 15.357873569718073) (stdev 4.7373143310461954)
      (min 8.8999857341691513) (max 24.754721911378184)))
    (calmar_ratio
     ((mean 0.68270632982270452) (stdev 0.59647308213233163)
      (min -0.221983542682911) (max 1.6920034601780185)))
    (cagr_pct
     ((mean 9.1647918270166837) (stdev 9.10521112370989)
      (min -5.2401894300441505) (max 31.170812129033166)))
    (avg_holding_days
     ((mean 44.399331599752557) (stdev 9.32544055982073)
      (min 33.333333333333336) (max 62.584905660377359))))
   ((variant_label w2)
    (total_return_pct
     ((mean 18.763953073815991) (stdev 26.8793487148151)
      (min -13.323555730000033) (max 85.734118060000014)))
    (sharpe_ratio
     ((mean 0.56512977832134426) (stdev 0.70916061485824866)
      (min -0.43074177588267321) (max 1.7062067512969989)))
    (max_drawdown_pct
     ((mean 16.297307739639816) (stdev 5.4776277614190629)
      (min 8.5903068709559882) (max 28.17973493865939)))
    (calmar_ratio
     ((mean 0.72620070004897608) (stdev 0.93792839447470022)
      (min -0.29862363027375821) (max 2.5176857210927488)))
    (cagr_pct
     ((mean 8.3891826918290828) (stdev 11.856418419250282)
      (min -6.9043739727443825) (max 36.313205344612733)))
    (avg_holding_days
     ((mean 42.835028733085331) (stdev 9.5583972886896351)
      (min 28.724637681159422) (max 59.836363636363636))))
   ((variant_label w6)
    (total_return_pct
     ((mean 21.623479238027624) (stdev 27.178365133817486)
      (min -18.446941523333312) (max 94.7817662276923)))
    (sharpe_ratio
     ((mean 0.588420631117596) (stdev 0.65402753072661168)
      (min -0.940428533670849) (max 1.5598143046829678)))
    (max_drawdown_pct
     ((mean 16.470812369595226) (stdev 7.0319073807611643)
      (min 7.3224830618595815) (max 28.657277856293206)))
    (calmar_ratio
     ((mean 0.80139569110968278) (stdev 0.83185220655150116)
      (min -0.33890907354884753) (max 2.474874400771037)))
    (cagr_pct
     ((mean 9.7094464896109862) (stdev 11.775497617005737)
      (min -9.69957427589433) (max 39.596108009154605)))
    (avg_holding_days
     ((mean 46.3562146845319) (stdev 9.9341638663126428)
      (min 34.042735042735046) (max 60.266666666666666))))
   ((variant_label w8)
    (total_return_pct
     ((mean 15.949380914615395) (stdev 28.979554818811415)
      (min -27.929529269999996) (max 86.669572510000037)))
    (sharpe_ratio
     ((mean 0.40498672678997516) (stdev 0.810407421763823)
      (min -1.3604321162741784) (max 1.4846477331913441)))
    (max_drawdown_pct
     ((mean 17.793672814134371) (stdev 8.1648087348855078)
      (min 7.8393872877059438) (max 38.114965169999991)))
    (calmar_ratio
     ((mean 0.5916283421073063) (stdev 0.80876944816476148)
      (min -0.4607010070465109) (max 2.5309013377081229)))
    (cagr_pct
     ((mean 6.9346747544036607) (stdev 13.219442277854577)
      (min -15.11519289183304) (max 36.656281727017806)))
    (avg_holding_days
     ((mean 46.223424805555169) (stdev 9.8535263220176539)
      (min 30.778761061946902) (max 60.5))))))
 (sensitivity
  (((variant_label w2) (sharpe_wins 5) (calmar_wins 6) (total_return_wins 7)
    (max_drawdown_wins 6))
   ((variant_label w6) (sharpe_wins 6) (calmar_wins 8) (total_return_wins 7)
    (max_drawdown_wins 6))
   ((variant_label w8) (sharpe_wins 5) (calmar_wins 4) (total_return_wins 5)
    (max_drawdown_wins 5))))
 (verdicts
  ((w2
    (Fail (wins 5) (n 13) (worst_fold fold-000)
     (worst_gap 0.51515524712494876)
     (reason
      "M-threshold miss: 5 wins < 7 required; worst fold fold-000 trails by 0.5152 > \206\148=0.3000")))
   (w6
    (Fail (wins 6) (n 13) (worst_fold fold-011)
     (worst_gap 0.5190908780761565)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-011 trails by 0.5191 > \206\148=0.3000")))
   (w8
    (Fail (wins 5) (n 13) (worst_fold fold-012)
     (worst_gap 1.0212305821131298)
     (reason
      "M-threshold miss: 5 wins < 7 required; worst fold fold-012 trails by 1.0212 > \206\148=0.3000"))))))
