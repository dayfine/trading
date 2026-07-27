((date 2026-07-27) (slug leverage-dawn-clean-rerun)
 (hypothesis
  "Integrity addendum to 2026-07-26-leverage-dawn-surface (issue #2108): the 07-26 run executed from the parent workspace while that tree was mutated mid-run (jj snapshots / git-head import inside the run window), leaving baseline folds 000-008 irreproducible from committed state. This re-run repeats the identical surface (same spec test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp, same v5thin warehouse, cache 1024) from a PINNED worktree at 96c4c5ff8 per the new sweep-hygiene pinned-worktree rule, to re-certify the P1b-closing REJECT on clean evidence.")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention on /tmp/snap_top3000_dedup_v5thin (promoted-bundle defaults, pinned worktree @ 96c4c5ff8, run 2026-07-27 03:33-10:33Z)")
 (window_id margin-m4-broad-13x2y-2000-2026)
 (baseline_label baseline)
 (variants
  (((label "dawn req=0.90 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.616) (mean_calmar 1.114) (mean_return_pct 60.14)
       (mean_max_drawdown_pct 22.71)))))
   ((label "dawn req=0.90 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.619) (mean_calmar 1.058) (mean_return_pct 59.71)
       (mean_max_drawdown_pct 23.83)))))
   ((label "dawn req=0.85 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.555) (mean_calmar 0.919) (mean_return_pct 61.65)
       (mean_max_drawdown_pct 30.65)))))
   ((label "dawn req=0.85 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.525) (mean_calmar 0.952) (mean_return_pct 66.67)
       (mean_max_drawdown_pct 33.61)))))
   ((label "dawn req=0.75 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.494) (mean_calmar 0.772) (mean_return_pct 76.58)
       (mean_max_drawdown_pct 42.82)))))
   ((label "dawn req=0.75 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.437) (mean_calmar 0.598) (mean_return_pct 63.29)
       (mean_max_drawdown_pct 44.88)))))
   ((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.827) (mean_calmar 1.309) (mean_return_pct 36.17)
       (mean_max_drawdown_pct 14.05)))))))
 (verdict Reject)
 (notes
  "REJECT RE-CERTIFIED on clean evidence; the P1b closure stands. Baseline is 13/13 fold-level BIT-IDENTICAL to the M4 surface baseline (.827/36.17/14.05) -- cross-run parity fully restored by the pinned-worktree hygiene fix, confirming the 07-26 drift was environmental (mid-run workspace mutation), not code. Dawn cells on clean folds: Sharpe degrades monotonically in dawn aggressiveness (.827 -> .616/.619 @0.90 -> .555/.525 @0.85 -> .494/.437 @0.75) while MaxDD balloons 14.05 -> 22.7-44.9; mean return rises (36 -> 60-77) but sigma explodes (39 -> 94-168) -- wealth-as-variance, same shape as the contaminated read. Fold gate: best cell 5/13 Sharpe wins (need >=7), all six cells FAIL. Named falsifier fold-012 (2024-25 melt-up false dawn) fires in ALL arms: every dawn cell trails baseline Sharpe .901 (range -0.100 @0.85x78 with DD 56.8, to .811); monster fold-010 (2020-21) returns 297-579% vs 134 but Sharpe 1.49-1.66 vs 2.009 and DD 32-46 vs 13.1 -- even the best dawn window loses risk-adjusted. All qualitative claims of the 07-26 entry survive; its numeric aggregates for dawn cells were mildly perturbed (e.g. .623 -> .616 @0.90x52) and its baseline (.766) was contaminated -- NEVER cite the 07-26 baseline; the baseline of record is .827. Transferable why unchanged: a lagging dawn label cannot split dawn-tail from dawn-chop; conditional leverage inherits unconditional leverage's asymmetric amplification. Mechanism stays default-off as an axis; no grid, no default flips. Hygiene provenance: run tree pinned + immutable for the duration, flock single-instance, disk-guarded; report /tmp/sweeps/leverage-dawn-v2-clean/walk_forward_report.md; root-cause record dev/notes/leverage-dawn-surface-results-2026-07-26.md \\u00a7Integrity addendum + issue #2108."))
