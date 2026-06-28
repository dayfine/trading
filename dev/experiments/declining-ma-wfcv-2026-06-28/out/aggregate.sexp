((fold_count 13) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 16.00524143572979) (stdev 21.998108536935618)
      (min -26.910190666666672) (max 51.548159126153806)))
    (sharpe_ratio
     ((mean 0.4501787837911389) (stdev 0.6320873511957239)
      (min -1.0039098227078678) (max 1.4165552585545342)))
    (max_drawdown_pct
     ((mean 17.642595633223102) (stdev 8.12964781678399)
      (min 6.8830191534615128) (max 35.577866579999991)))
    (calmar_ratio
     ((mean 0.60646115916299759) (stdev 0.81544721883778748)
      (min -0.40854022629409037) (max 2.7712959709683869)))
    (cagr_pct
     ((mean 7.2457187723521219) (stdev 10.418458396468479)
      (min -14.516599463438617) (max 23.122426238857074)))
    (avg_holding_days
     ((mean 40.670809111104511) (stdev 7.6357466873375133)
      (min 28.094594594594593) (max 52.615384615384613))))
   ((variant_label declining_ma_gate_on)
    (total_return_pct
     ((mean 17.813101653836302) (stdev 22.697017954516607)
      (min -26.910190666666672) (max 62.33145123153848)))
    (sharpe_ratio
     ((mean 0.49460477222071969) (stdev 0.60745441416635038)
      (min -1.0039098227078678) (max 1.4165552585545342)))
    (max_drawdown_pct
     ((mean 17.182037275636027) (stdev 7.79856494214024)
      (min 6.8830191534615128) (max 35.577866579999991)))
    (calmar_ratio
     ((mean 0.6610618420332266) (stdev 0.81331824168096922)
      (min -0.40854022629409037) (max 2.7712959709683869)))
    (cagr_pct
     ((mean 8.072602584806118) (stdev 10.567676520341671)
      (min -14.516599463438617) (max 27.430501223639236)))
    (avg_holding_days
     ((mean 40.7074229510096) (stdev 7.5435365944146255)
      (min 28.094594594594593) (max 52.615384615384613))))))
 (sensitivity
  (((variant_label declining_ma_gate_on) (sharpe_wins 2) (calmar_wins 2)
    (total_return_wins 2) (max_drawdown_wins 2))))
 (verdicts
  ((declining_ma_gate_on
    (Fail (wins 2) (n 13) (worst_fold fold-000) (worst_gap 0)
     (reason "M-threshold miss: 2 wins < 7 required"))))))
