((date 2026-06-09) (slug laggard-broad-recheck-top3000)
 (hypothesis
  "laggard-rotation candidate-supply-sensitivity: does the top-1000 reversal (disabling looked better) hold on the broadest top-3000 PIT, or was it fat-tail noise?")
 (base_scenario "goldens-custom-universe/composition/top-3000-2011 (PIT)")
 (window_id wf-2011-2026-365-365-15fold-top3000-snapshot-forkperfold)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.64281770518313874) (mean_calmar 1.3816425612264558)
       (mean_return_pct 12.950175847379974)
       (mean_max_drawdown_pct 14.790393995098752)))))
   ((label enable_laggard_rotation=false) (config_hash "")
    (aggregate
     (((mean_sharpe 0.4890418412942758) (mean_calmar 1.2949295516897255)
       (mean_return_pct 9.9079609736363654)
       (mean_max_drawdown_pct 16.509850913755358)))))))
 (verdict Reject)
 (notes
  "CONFIRMATION of the SP500 laggard verdict on the BROADEST universe; REFUTES the top-1000 apparent reversal. On top-3000 (15 WF folds, fork-per-fold #1494), laggard-ON baseline DOMINATES laggard-OFF: Sharpe 0.643 vs 0.489, Calmar 1.382 vs 1.295, MaxDD 14.79 vs 16.51 (lower=better), DSR 0.9988 vs 0.9886; laggard-OFF is OFF the Pareto frontier and wins only 6/15 folds. The top-1000 reversal (2026-06-09-laggard-broad-recheck, disabling looked better on mean) was fat-tail noise (one +153pp fold), not a breadth effect. Laggard rotation is robustly beneficial across SP500 + top-3000 -> keep ON. (Gate SKIPPED: spec gate n=14 vs generated 15; verdict rests on the Pareto+DSR ranking, which is unambiguous.) See dev/notes/laggard-broad-recheck-2026-06-09.md."))
