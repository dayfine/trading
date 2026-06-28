((date 2026-06-28) (slug declining-ma-gate-grid)
 (hypothesis
  "reject_declining_ma_long_entry (PR #1775, default-off): drop long candidates whose stage-classification MA direction is Declining at entry — a misclassified Stage-2 (counter-trend bounce in a Stage-4 downtrend; the COO/WBA/DBD drawdown-driver pattern surfaced by the 2026-06-27 entry-quality audit: declining-MA longs win ~13% / -0.1% avg vs ~34% / +2.6% for rising-MA). A faithful tightening of the Stage-2-only buy rule toward the book's rising-MA definition. Promotion-confirmation grid: does it beat baseline (or do-no-harm) across 3 universe cells over the macro-diverse 2000-2026 window (dot-com + GFC) — i.e. is it promotable to a GLOBAL default?")
 (base_scenario "GRID 3-cell x 2-variant (off/on), 2000-2026, 2y non-overlapping folds (13), fork-per-fold: A=top-3000 PIT-1998 (warehouse), B=sp500-515 PIT-2000 (CSV), C=top-1000 PIT-1998 (warehouse). Cell-E long-only.")
 (window_id grid-3cell-universe-wfcv-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (;; --- Cell A: top-3000 (broad) — the gate MEANINGFULLY helps, never hurts ---
   ((label cellA-top3000-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.4502) (mean_calmar 0.6065) (mean_return_pct 16.005) (mean_max_drawdown_pct 17.643)))))
   ((label cellA-top3000-gate_on) (config_hash "")
    (aggregate (((mean_sharpe 0.4946) (mean_calmar 0.6611) (mean_return_pct 17.813) (mean_max_drawdown_pct 17.182)))))
   ;; --- Cell B: sp500-515 (large-cap) — INERT (do-no-harm) ---
   ((label cellB-sp500-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.7258) (mean_calmar 0.0) (mean_return_pct 0.0) (mean_max_drawdown_pct 0.0)))))
   ((label cellB-sp500-gate_on) (config_hash "")
    (aggregate (((mean_sharpe 0.7254) (mean_calmar 0.0) (mean_return_pct 0.0) (mean_max_drawdown_pct 0.0)))))
   ;; --- Cell C: top-1000 (mid-cap) — ~INERT (do-no-harm) ---
   ((label cellC-top1000-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.6531) (mean_calmar 0.0) (mean_return_pct 0.0) (mean_max_drawdown_pct 0.0)))))
   ((label cellC-top1000-gate_on) (config_hash "")
    (aggregate (((mean_sharpe 0.6536) (mean_calmar 0.0) (mean_return_pct 0.0) (mean_max_drawdown_pct 0.0)))))))
 (verdict Reject)
 (notes
  "REJECT for GLOBAL default-flip; KEEP default-off and ARM FOR BROAD. The benefit is UNIVERSE-SPECIFIC and concentrates in the broad tail. Per-cell win/tie/loss (Sharpe, 13 folds): Cell A top-3000 = 2 WINS / 11 ties / 0 losses (worst_gap 0), mean Sharpe 0.450->0.495 (+0.045), Calmar 0.606->0.661, return 16.0->17.8%, MaxDD 17.6->17.2% -- meaningfully better, the wins are the fast-crash folds (2018-19 flipped -0.25->+0.21 Sharpe; 2020-21 +0.11) where dead-cat-bounce buys cluster. Cell B sp500-515 = 0 wins / 12 ties / 1 negligible loss (worst_gap -0.006), mean 0.726->0.725: essentially a NO-OP -- survivor-tinted large-caps barely contain the misclassified Stage-4-bounce/junk entries. Cell C top-1000 = 1 tiny win / 11 ties / 1 negligible loss (worst_gap -0.0003), mean 0.653->0.654: ~NO-OP. So the gate is DO-NO-HARM across all 39 folds (worst gap anywhere -0.006) but only HELPS on the broad universe -> fails promotion-confirmation's 'beats baseline in a strong majority of cells' (1 of 3) -> no global default flip (a global flip would re-pin all universes' goldens for an inert change on 2 of 3). The misclassified entries live in the small/deep/delisting TAIL only the top-3000 contains. RECOMMENDATION: keep reject_declining_ma_long_entry default-off; ARM it (=true) in BROAD-universe configs/presets where it is validated do-no-harm + fast-crash insurance. First clear instance of a BREADTH-DEPENDENT strategy knob (cf. concentration 0.30: project_deep_goldens_conservative_vs_default) -> motivates a universe-tier 'broad preset' (docs/design/broad-preset). CAVEAT: the single-window broad remeasure showed +126pp/-8pp-DD but that was ~all terminal MTM (realized -$0.78M, project_broad_universe_790_mtm_inflated); the WF-CV fold-means (13 end-dates) are the honest signal and confirm a small REAL do-no-harm + fast-crash benefit, not the MTM headline. Artifacts: dev/experiments/declining-ma-wfcv-2026-06-28/ (spec/base/aggregate/reports for all 3 cells). Mechanism: PR #1775 (default-off, both QC APPROVED)."))
