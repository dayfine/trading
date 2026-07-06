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
   ((variant_label r10)
    (total_return_pct
     ((mean 12.182179376923072) (stdev 18.4280163046143)
      (min -12.292363200000045) (max 45.305616579999985)))
    (sharpe_ratio
     ((mean 0.41340286667604204) (stdev 0.57445303944825477)
      (min -0.33493030934743895) (max 1.4590453312680411)))
    (max_drawdown_pct
     ((mean 16.018929057684762) (stdev 4.0808358229262618)
      (min 9.939656289286134) (max 21.89892975475566)))
    (calmar_ratio
     ((mean 0.45141533014845631) (stdev 0.66400758682714489)
      (min -0.31396201827726866) (max 1.7531576334315242)))
    (cagr_pct
     ((mean 5.5993356293466459) (stdev 8.5813773338686659)
      (min -6.3518511600446086) (max 20.558206076757468)))
    (avg_holding_days
     ((mean 45.948049682626738) (stdev 9.1120375265197211)
      (min 31.628318584070797) (max 66.833333333333329))))
   ((variant_label r20)
    (total_return_pct
     ((mean 16.825346661999994) (stdev 15.761927020975937)
      (min -4.3371911699999819) (max 56.078402919999981)))
    (sharpe_ratio
     ((mean 0.62049874969584906) (stdev 0.44315949707324914)
      (min -0.044791863861764092) (max 1.292658037482155)))
    (max_drawdown_pct
     ((mean 13.200440617863508) (stdev 4.1266495930694171)
      (min 6.8957394238174654) (max 21.392683592788305)))
    (calmar_ratio
     ((mean 0.70583851630544148) (stdev 0.64796963944704167)
      (min -0.10270312529614362) (max 2.1103787825748772)))
    (cagr_pct
     ((mean 7.8763167496992157) (stdev 7.1009045624595144)
      (min -2.19411900639509) (max 24.950391014252382)))
    (avg_holding_days
     ((mean 49.070724926641368) (stdev 11.185025722668021)
      (min 28.584905660377359) (max 71.044444444444451))))
   ((variant_label r30)
    (total_return_pct
     ((mean 12.734340717692303) (stdev 18.064351253402688)
      (min -15.533396719999962) (max 48.800874420000007)))
    (sharpe_ratio
     ((mean 0.44138858905239353) (stdev 0.71436509399726222)
      (min -1.1513650500061217) (max 1.4904535621726629)))
    (max_drawdown_pct
     ((mean 13.43981148068063) (stdev 4.1026871970553751)
      (min 7.3934244101250757) (max 20.524014949897783)))
    (calmar_ratio
     ((mean 0.6085105837615733) (stdev 0.79523196998455792)
      (min -0.39515885153049335) (max 2.09702367068668)))
    (cagr_pct
     ((mean 5.8720568545631107) (stdev 8.4273712235381115)
      (min -8.0995988532683754) (max 22.000568139876385)))
    (avg_holding_days
     ((mean 46.302866030094734) (stdev 9.6597470551687987)
      (min 34.86904761904762) (max 68.71875))))))
 (sensitivity
  (((variant_label r10) (sharpe_wins 4) (calmar_wins 4) (total_return_wins 3)
    (max_drawdown_wins 6))
   ((variant_label r20) (sharpe_wins 6) (calmar_wins 6) (total_return_wins 5)
    (max_drawdown_wins 9))
   ((variant_label r30) (sharpe_wins 4) (calmar_wins 4) (total_return_wins 2)
    (max_drawdown_wins 9))))
 (verdicts
  ((r10
    (Fail (wins 4) (n 13) (worst_fold fold-009)
     (worst_gap 0.69562758287646886)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-009 trails by 0.6956 > \206\148=0.3000")))
   (r20
    (Fail (wins 6) (n 13) (worst_fold fold-001)
     (worst_gap 0.39925116752251988)
     (reason
      "M-threshold miss: 6 wins < 7 required; worst fold fold-001 trails by 0.3993 > \206\148=0.3000")))
   (r30
    (Fail (wins 4) (n 13) (worst_fold fold-003)
     (worst_gap 0.79244724245780573)
     (reason
      "M-threshold miss: 4 wins < 7 required; worst fold fold-003 trails by 0.7924 > \206\148=0.3000"))))))
