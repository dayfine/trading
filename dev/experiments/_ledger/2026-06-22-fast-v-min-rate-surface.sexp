((date 2026-06-22)
 (slug fast-v-min-rate-surface)
 (hypothesis
  "raising fast_v_min_rate_pct above the 0.08 default suppresses the arming-speed whipsaw (2010/2011 choppy corrections) while keeping the fast-V crash catch (2020/2018), improving the arming-speed mechanism")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-catstop-armon.sexp")
 (window_id wfcv-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label fast_v_min_rate_pct=0.12)
    (config_hash fvmr-0.12-catstop10-armon-deep)
    (aggregate ((sharpe_mean 0.666) (calmar_mean 1.332) (maxdd_mean 11.06) (pareto_frontier no) (deflated_sharpe 0.9999))))
   ((label fast_v_min_rate_pct=0.16)
    (config_hash fvmr-0.16-catstop10-armon-deep)
    (aggregate ((sharpe_mean 0.664) (calmar_mean 1.331) (maxdd_mean 11.10) (pareto_frontier no) (deflated_sharpe 0.9999))))))
 (verdict Reject)
 (notes
  "REJECT the threshold-tuning lever; 0.08 (existing default) is Pareto-optimal. See dev/backtest/fast-v-min-rate-surface-2026-06-22/. Higher thresholds (0.12/0.16) are strictly dominated. Per-fold: raising the threshold DID suppress the whipsaw (2010 11.35->12.12, 2011 -9.80->-8.61) but ALSO killed the crash catch (2018-Q4 9.84->8.62, 2020-V 9.96->6.93 reverts to gap-down). KEY why: the whipsaw and the catch ride the SAME 4-week rate signal — arming early (low threshold) catches the 2020-V before its gap-down AND fires on recovering 2010/2011 dips; raising the bar delays arming uniformly so it skips false-positives but arrives too late for the real crash. Catch-speed and whipsaw-immunity are one dial pulled opposite ways; no rate threshold gives both. To separate crash-that-keeps-falling from dip-that-recovers needs a DIFFERENT signal = the A-D breadth lead (Decline_character's inert A-D leg, Build 0). This surface is concrete evidence that Build 0 is the unlock for arming-speed, NOT threshold tuning. fast_v_arm_on_rate_alone stays weak default-off ACCEPT at 0.08, unchanged. Records the dead-end so it is not re-attempted.")
 )
