((date 2026-06-24)
 (slug arming-speed-adlive-wfcv)
 (hypothesis
  "fast_v_arm_on_rate_alone=true becomes promotable on the A-D-LIVE basis: now that Build 0 made the decline-character A-D-lead leg live (default since #1725), the breadth lead separates the genuine fast-V crash catch from the choppy-correction whipsaw that rate-alone could not (the unlock the fast_v_min_rate threshold-surface REJECT pointed to)")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-catstop.sexp")
 (window_id wfcv-adlive-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label fast_v_arm_on_rate_alone=true)
    (config_hash arm-on-rate-true-catstop10-adlive-deep-2000-2026)
    (aggregate
     ((sharpe_mean 0.567) (calmar_mean 1.036) (maxdd_mean 9.83)
      (return_mean 9.36) (pareto_frontier yes) (deflated_sharpe 0.9999))))))
 (verdict Reject)
 (notes
  "NO promote on the A-D-live basis (the hypothesis is rejected; the mechanism keeps its 06-22 weak-ACCEPT-as-axis status). See dev/backtest/arming-speed-adlive-wfcv-2026-06-24/. true is the sole Pareto-frontier member but marginally so (+0.005 Sharpe, -0.12pp MaxDD) and DSR-indistinguishable (0.9999); go/no-go gate FAIL (1/26 Sharpe wins, need 14; worst fold 2010 trails 0.0078). KEY: A-D-live narrowed the knob from 4/26 folds (A-D-inert 06-22) to 2/26 -> it suppressed the 2011 whipsaw (breadth read the dip as recovering = the hypothesis working) BUT also dropped the 2018-Q4 catch (same conservatism), while KEEPING the 2020 catch (+2.33pp/-3.46pp DD) and the 2010 whipsaw (-0.78pp). So the A-D breadth lead is a MARGINAL SELECTIVITY refinement, NOT the decisive catch-vs-whipsaw separator the fast_v_min_rate REJECT hypothesized -> net aggregate flat. Closes that loop: A-D-live is not the arming-speed unlock; the binding limit is that genuine fast-V crashes (2020) are RARE, so the stop's aggregate footprint is ~zero by design. Same meta-pattern as every decline-character mechanism (project_decline_character_builds, project_edge_is_the_fat_tail): faithful narrow-niche tail-RISK insurance -> stays default-off axis (catastrophic_stop_pct armed on Fast_v), never default-on. 24/26 byte-identical folds = deterministic. Fourth time WF-CV/grid corrected a single-window-or-screen hope (cf arming-speed inert, neutral-grid, slow-grind-adlive).")
 )
