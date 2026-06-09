((date 2026-06-09) (slug stage3-force-exit-off-confirmation-grid)
 (hypothesis
  "Promotion-confirmation grid (.claude/rules/promotion-confirmation.md) for the INCONCLUSIVE-POSITIVE enable_stage3_force_exit=false lever (2026-06-09-stage3-force-exit-off-top3000). Re-run the on/off surface across 3 independent period x universe contexts incl. a deep pre-2009 macro regime; promote the default flip ONLY if force_exit_off beats baseline (frontier/positive-DSR) in a strong majority (>=2/3) and is never badly dominated.")
 (base_scenario "GRID: A=top-3000-2011 2011-2026 (existing 2x2); B=sp500-historical-2000 510sym 2000-2010 deep (dot-com+GFC, CSV mode); C=top-1000-2011 2011-2026 (snapshot mode)")
 (window_id grid-3cell-period-x-universe-forkperfold)
 (baseline_label baseline)
 (variants
  (;; --- Cell A: top-3000 2011-2026 (the cell that produced the ACCEPT-candidate) ---
   ((label cellA-top3000-baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.64281770518313874) (mean_calmar 1.3816425612264558)
       (mean_return_pct 12.950175847379974)
       (mean_max_drawdown_pct 14.790393995098752)))))
   ((label cellA-top3000-force_exit_off) (config_hash "")
    (aggregate
     (((mean_sharpe 0.67908431692581472) (mean_calmar 1.6307899577087506)
       (mean_return_pct 13.071462363117345)
       (mean_max_drawdown_pct 14.73842200757595)))))
   ;; --- Cell B: deep 2000-2010 sp500-historical-510 (dot-com + GFC) ---
   ;; force_exit_off is BIT-IDENTICAL to baseline across all 11 folds: the
   ;; Stage-3 force-exit never altered an exit in the deep regime (the trailing
   ;; stop + macro gate exit first). Non-degenerate (real per-fold returns).
   ((label cellB-deep-baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.884115046372353) (mean_calmar 2.2618865908391808)
       (mean_return_pct 17.892751465317033)
       (mean_max_drawdown_pct 11.32)))))
   ((label cellB-deep-force_exit_off) (config_hash "")
    (aggregate
     (((mean_sharpe 0.884115046372353) (mean_calmar 2.2618865908391808)
       (mean_return_pct 17.892751465317033)
       (mean_max_drawdown_pct 11.32)))))
   ;; --- Cell C: top-1000 2011-2026 (same period as A, narrower universe) ---
   ;; REVERSES A: force_exit_off is slightly WORSE. Only 2/15 folds differ
   ;; (fold-001, fold-007); both marginally favor baseline on Sharpe. 0/15
   ;; Sharpe wins (gate FAIL). MaxDD marginally better for off.
   ((label cellC-top1000-baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.41761141111846156) (mean_calmar 0.72190172239545525)
       (mean_return_pct 10.044878216488893)
       (mean_max_drawdown_pct 18.68)))))
   ((label cellC-top1000-force_exit_off) (config_hash "")
    (aggregate
     (((mean_sharpe 0.39447715529364852) (mean_calmar 0.71075311628189286)
       (mean_return_pct 10.027909100488893)
       (mean_max_drawdown_pct 18.26)))))))
 (verdict Reject)
 (notes
  "REJECT for promotion - keep enable_stage3_force_exit DEFAULT-ON. The lever does NOT generalize across the grid. force_exit_off wins only 1 of 3 cells (need >=2/3 strong majority): Cell A (top-3000) it dominates on all 4 aggregate axes, BUT that edge rests on only ~1/15 differing folds (fat-tail-concentrated, per the source 2x2). Cell B (deep dot-com+GFC, sp500-510) it is a complete NO-OP - bit-identical to baseline across all 11 folds, i.e. the S3 force-exit never fired differently in a bear-heavy regime (trailing stop + macro gate exit first). Cell C (top-1000, SAME 2011-2026 period as A, narrower universe) it REVERSES: slightly worse Sharpe (0.394 vs 0.418), Calmar (0.711 vs 0.722), DSR (0.9268 vs 0.9378), 0/15 Sharpe wins; only 2/15 folds even differ and both lean baseline. The Cell-A win is therefore top-3000-breadth-SPECIFIC + fat-tail-concentrated - the exact single-context-winner pattern this grid exists to catch, and the same breadth-reversal signature that sank the laggard re-check (top-1000 reversed vs top-3000). Mechanism stays default-on; force_exit_off remains a default-off axis (experiment-flag-discipline R3 unsatisfied: no grid-robust ACCEPT). Artifacts: dev/experiments/stage3-force-exit-grid-2026-06-09/, dev/notes/stage3-force-exit-grid-2026-06-09.md. Supersedes the promotion path opened by 2026-06-09-stage3-force-exit-off-top3000 (that entry's INCONCLUSIVE-POSITIVE stands as the single-surface record; this grid is its confirmation outcome = do-not-promote)."))
