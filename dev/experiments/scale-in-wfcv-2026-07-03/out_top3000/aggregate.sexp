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
   ((variant_label scale_in_pullback)
    (total_return_pct
     ((mean 20.084017231854038) (stdev 20.105782750984684)
      (min -9.3909638666666346) (max 64.898975430769184)))
    (sharpe_ratio
     ((mean 0.62290368857024447) (stdev 0.52346275852018953)
      (min -0.40908461809126179) (max 1.3834110453449211)))
    (max_drawdown_pct
     ((mean 14.755967230725172) (stdev 5.14932825861048)
      (min 9.2919372798158921) (max 25.258295664710285)))
    (calmar_ratio
     ((mean 0.72658281748941833) (stdev 0.60629935823267223)
      (min -0.20656304886811586) (max 2.0019514722924368)))
    (cagr_pct
     ((mean 9.2472452947497725) (stdev 9.0169029870551221)
      (min -4.8144359059194342) (max 28.434993576799329)))
    (avg_holding_days
     ((mean 40.145194192698554) (stdev 7.80569970548893)
      (min 26.653179190751445) (max 50.7375))))
   ((variant_label scale_in_either_loose)
    (total_return_pct
     ((mean 20.110729192445753) (stdev 17.4072669605132)
      (min -1.7805710466666729) (max 54.735005368461408)))
    (sharpe_ratio
     ((mean 0.66201985494877047) (stdev 0.4634690694093585)
      (min -0.031008282240534289) (max 1.5640418539392058)))
    (max_drawdown_pct
     ((mean 13.892915142946965) (stdev 4.0310110309923717)
      (min 7.9957415159140108) (max 23.83537156064175)))
    (calmar_ratio
     ((mean 0.763275343612188) (stdev 0.63655962285065215)
      (min -0.04807898584800907) (max 2.1962730669667292)))
    (cagr_pct
     ((mean 9.3466115125494991) (stdev 7.78725890572291)
      (min -0.8948940194146382) (max 24.411124284767283)))
    (avg_holding_days
     ((mean 40.422290725688647) (stdev 5.9300422844930694)
      (min 31.189873417721518) (max 50.670588235294119))))))
 (sensitivity
  (((variant_label scale_in_pullback) (sharpe_wins 6) (calmar_wins 6)
    (total_return_wins 6) (max_drawdown_wins 7))
   ((variant_label scale_in_either_loose) (sharpe_wins 6) (calmar_wins 6)
    (total_return_wins 6) (max_drawdown_wins 10))))
 (verdicts
  ((scale_in_pullback
    (Fail (wins 6) (n 13) (worst_fold fold-003)
     (worst_gap 0.70431156115468818)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-003 trails by 0.7043 > \206\148=0.3000")))
   (scale_in_either_loose
    (Fail (wins 6) (n 13) (worst_fold fold-003)
     (worst_gap 0.77466196412808663)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-003 trails by 0.7747 > \206\148=0.3000"))))))
