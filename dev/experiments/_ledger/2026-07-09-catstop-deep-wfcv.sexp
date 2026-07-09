((date 2026-07-09)
 (slug catstop-deep-wfcv)
 (hypothesis
  "catastrophic_stop_pct=0.10 (fast-crash absolute stop, default Fast_v arming) has distributed deep-bear value (per the 2026-07-09 P1a screen: 2001-02 +5.9%, 2008 +3.1% path-compounded) that survives per-fold evaluation, justifying a promotion-grid conversation")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_id wfcv-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label catastrophic_stop_pct=0.0)
    (config_hash catstop-off-deep-2000-2026-364basis)
    (aggregate
     ((sharpe_mean 0.494) (calmar_mean 0.912) (maxdd_mean 12.31)
      (return_mean 7.89) (pareto_frontier yes) (deflated_sharpe 0.9969))))
   ((label catastrophic_stop_pct=0.10)
    (config_hash catstop-on-deep-2000-2026-364basis-parity)
    (aggregate
     ((sharpe_mean 0.492) (calmar_mean 0.894) (maxdd_mean 12.11)
      (return_mean 7.77) (pareto_frontier yes) (deflated_sharpe 0.9973))))))
 (verdict Reject)
 (notes
  "Reject(promotion): fold-honest, catstop 0.10 is a WASH — return mean -0.12pp/yr for MaxDD mean -0.20pp, gate FAIL both directions (fires in only 7/26 folds; ties dominate), worst folds (2025 -16.6%, 2021 DD 24.0) UNTOUCHED so the left tail is not cut. Per-fold: PAYS in declines that KEEP GOING (2002 +3.15pp/DD-2.66, 2008 +2.11pp/DD-2.49), COSTS in V-recoveries (2020 -5.24pp, 2003 -2.44pp) -> same continue-vs-recover discrimination gap as the arming-speed whipsaw (2026-06-22-arming-speed-wfcv) and fast-v-min-rate REJECT. KEY methodology why: the P1a screen's +15.2pp 'distributed deep value' was PATH-COMPOUNDING on a single 11y path; independent annual folds price the mechanism at ~-0.12pp/yr — compounded-path screens systematically flatter crash-exit mechanisms. PARITY: the 0.10 axis cell is bit-identical to baseline in all 26 folds — first nested stops_config.* key-path axis validated through Overlay_validator. FORWARD: catstop stays a default-off tail-insurance dial (trader-preset candidate, not a global default); the continue-vs-recover discriminator is the P1b circuit-breaker design's job (asymmetric re-entry targets the 2020-shaped cost, slow-grind exit the 2002/2008-shaped pay). 364 basis. Artifacts: dev/backtest/catstop-deep-wfcv-2026-07-09/.")
 )
