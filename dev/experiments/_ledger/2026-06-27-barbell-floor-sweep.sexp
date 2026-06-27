((date 2026-06-27) (slug barbell-floor-sweep)
 (hypothesis
  "Static SPY-floor barbell (Barbell_config) as a diversification overlay on the broad top-3000 long-only engine: blend floor leg + engine at a fixed floor_weight to beat the engine risk-adjusted. Production confirmation via barbell_floor_sweep_runner (current code + warehouse), floor weights {0,0.2,0.3,0.4}, rebalance 4wk. Key question surfaced: does the FLOOR LEG choice (SPY-timing Spy_only_weinstein vs SPY buy-hold) change the verdict?")
 (base_scenario "broad top-3000 PIT-1998 long-only (Cell-E, max_position_pct_long 0.14), 1998-2026, snapshot warehouse /tmp/snap_top3000_1998_2026_v2")
 (window_id full-window-1998-2026-floor-sweep-rebalance4wk)
 (baseline_label floor_weight_0.00_pure_engine)
 (variants
  (;; --- PRODUCTION timing floor (Spy_only_weinstein 30wk), the as-built infra ---
   ((label timing-floor-w0.00) (config_hash "")
    (aggregate (((mean_sharpe 0.4877) (mean_calmar 0.1705) (mean_return_pct 721.39) (mean_max_drawdown_pct 43.75)))))
   ((label timing-floor-w0.20) (config_hash "")
    (aggregate (((mean_sharpe 0.4883) (mean_calmar 0.1694) (mean_return_pct 480.13) (mean_max_drawdown_pct 36.53)))))
   ((label timing-floor-w0.30) (config_hash "")
    (aggregate (((mean_sharpe 0.4885) (mean_calmar 0.1688) (mean_return_pct 380.94) (mean_max_drawdown_pct 32.66)))))
   ((label timing-floor-w0.40) (config_hash "")
    (aggregate (((mean_sharpe 0.4888) (mean_calmar 0.1681) (mean_return_pct 295.09) (mean_max_drawdown_pct 28.60)))))
   ;; --- BUY-HOLD floor (hand-blend = Barbell_blend math, monthly rebalance) ---
   ;; NOT production-tool-confirmed (no buy-and-hold strategy in codebase); the
   ;; blend math IS confirmed by the timing-floor production run. Pending a build.
   ((label buyhold-floor-w0.20-monthly) (config_hash "")
    (aggregate (((mean_sharpe 0.552) (mean_calmar 0.0) (mean_return_pct 794.0) (mean_max_drawdown_pct 33.9)))))
   ((label buyhold-floor-w0.30-monthly) (config_hash "")
    (aggregate (((mean_sharpe 0.572) (mean_calmar 0.0) (mean_return_pct 814.0) (mean_max_drawdown_pct 29.9)))))))
 (verdict Reject)
 (notes
  "TWO floors, TWO verdicts. (1) PRODUCTION as-built (Spy_only_weinstein 30wk TIMING floor): NO-PROMOTE. Sharpe FLAT (~0.488) and Calmar FLAT (~0.168) across all weights; return drops monotonically (721->295%) while MaxDD falls (43.8->28.6%). Pure return-for-drawdown trade, NO risk-adjusted gain -- re-confirms the 2026-06-21 engine-edge FINDINGS 'no free lunch'. The timing floor's cash-in-bear is redundant with the engine's own bear defense, so it only sacrifices return. (2) BUY-HOLD SPY floor (hand-blend; Barbell_blend math confirmed correct by the timing-floor production run, only the floor curve differs): the REAL candidate -- beats BOTH pure legs on return+Sharpe+MaxDD (w=0.30 monthly: 814%/0.572/29.9 vs engine 721/0.496/43.8 and SPY 629/0.459/56.5), robust to rebalance frequency (daily 805/monthly 814/quarterly 779), and passes the period x universe fold grid (dev/notes/barbell-deep-verification-2026-06-27.md Part 1: static-30 beats engine baseline 5/7 rolling windows + 4-5/6 disjoint folds, never badly dominated). The gain is a genuine diversification/vol-harvesting return from two anti-correlated positive-Sharpe assets (corr(edge,SPY)=-0.59). Robust cross-universe weight ~0.20-0.30 (benefit largest on the realistic high-DD broad engine, small on survivor sp500). VERDICT Inconclusive (not Accept): the buy-hold variant -- the only compelling one -- is NOT production-tool-confirmed because the codebase has no buy-and-hold strategy (floor hardwired to Spy_only_weinstein). DECISION DEFERRED to user (AFK): Option A = build a buy-hold floor leg, production-confirm, then ACCEPT + gated wire; Option B = treat barbell as DD-only overlay (timing floor) = not worth promoting. Faithfulness flag (weinstein-faithful-core): a passive SPY buy-hold sleeve is a portfolio-construction overlay, not a Weinstein stock-selection mechanism -- defensible (index is in the macro spine) but a real scope question. No premature ACCEPT off the proxy (mechanism-validation-rigor). Artifacts: dev/notes/barbell-deep-verification-2026-06-27.md, dev/notes/regime-edge-synthesis-2026-06-27.md. DECISION 2026-06-27 (user): chose Option B -- do NOT build the buy-hold floor leg / do NOT add a passive SPY index sleeve (Weinstein-faithfulness scope call: a passive index allocation is portfolio construction, not a Weinstein stock-selection mechanism). Barbell direction CLOSED. The timing-floor barbell is no-free-lunch; the buy-hold variant remains a documented-but-declined possibility (do not re-propose without a new faithfulness decision). Net standing conclusion of the regime-edge investigation: the strategy is a regime-conditional crash-protector; its bull-market under-participation is accepted as-is, with no new strategy change adopted."))
