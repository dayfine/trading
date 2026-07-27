((date 2026-07-26) (slug leverage-dawn-surface)
 (hypothesis
  "P1b regime-dependency memo (dev/notes/regime-dependency-evaluation-2026-07-24.md): a LAGGING dawn label (index weekly-MA flip-up age <= max_age) conditioning the long book's initial margin requirement could capture part of the 46x hindsight bound (realistic-label chained estimate ~15x) that unconditional leverage (M4 REJECT) forfeits -- amplifying only post-bear dawns where the fat tail clusters, at cash-account requirement elsewhere. Mechanism #2077 (default-off, funded end-to-end after the B1 permissive-funding rework: entry walk gates WHEN to lever, simulator runs permissive so levered fills create real long_margin_debit priced at 8%/yr + 0.30 maintenance).")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention on /tmp/snap_top3000_dedup_v5thin (promoted-bundle defaults, HEAD 96c4c5f)")
 (window_id margin-m4-broad-13x2y-2000-2026)
 (baseline_label baseline)
 (variants
  (((label "dawn req=0.90 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.623) (mean_calmar 0.920) (mean_return_pct 59.37)
       (mean_max_drawdown_pct 24.55)))))
   ((label "dawn req=0.90 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.620) (mean_calmar 0.862) (mean_return_pct 59.70)
       (mean_max_drawdown_pct 26.13)))))
   ((label "dawn req=0.85 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.596) (mean_calmar 0.887) (mean_return_pct 62.39)
       (mean_max_drawdown_pct 30.44)))))
   ((label "dawn req=0.85 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.536) (mean_calmar 0.859) (mean_return_pct 63.94)
       (mean_max_drawdown_pct 33.86)))))
   ((label "dawn req=0.75 age<=52w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.525) (mean_calmar 0.773) (mean_return_pct 75.54)
       (mean_max_drawdown_pct 40.04)))))
   ((label "dawn req=0.75 age<=78w") (config_hash "")
    (aggregate
     (((mean_sharpe 0.510) (mean_return_pct 74.00)
       (mean_max_drawdown_pct 42.00)))))
   ((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.766) (mean_calmar 1.123) (mean_return_pct 34.63)
       (mean_max_drawdown_pct 17.71)))))))
 (verdict Reject)
 (notes
  "REJECT dawn-conditional leverage at every tested (req, age) cell: 3-4/13 Sharpe wins (gate >=7), worst folds trail by 0.73-1.02. Sharpe degrades MONOTONICALLY in dawn aggressiveness (.766 baseline -> .62 @0.90 -> .54-.60 @0.85 -> .51-.53 @0.75) while MaxDD balloons 17.7 -> 24.5-42. Mean return does rise (34.6 -> 59-76, confirming the P1b screen's wealth signal is real) but sigma explodes (37 -> 87-161): the label buys wealth, not risk-adjusted return. FALSIFIER FIRED: fold-012 (2024-25 melt-up-lag false-dawn) is decisively negative in 5/6 arms -- worst cell -19.8%/DD 56.8/Sharpe -0.10 vs baseline +39.4/15.3/0.90; the 2023 MA-flip-up labeled 2024 a dawn and levered into melt-up chop, exactly the P1b-named leak. EVEN THE MONSTER FOLD LOSES RISK-ADJUSTED: fold-010 (2020-21) returns 297-579% vs baseline 134 but at DD 32-46 vs 13.1 and Sharpe 1.49-1.66 vs 2.01 -- dawn windows carry the same whipsaw premium as everywhere else, and levering the premium costs more Sharpe than levering the tail earns. WHY (transferable): a lagging regime label cannot separate dawn-TAIL from dawn-CHOP; within-window composition is the same premium+monster mix as the whole sample, so conditional leverage inherits unconditional leverage's asymmetric-amplification failure, only diluted. This closes the P1b program's sole surviving payload: the fat tail cannot be scaled even regime-conditionally. Regime-conditioning of deployment intensity joins the reject family (unconditional leverage M4, cash-reserve, regime-switch barbell). Mechanism stays default-off as a searchable axis; no grid, no default flips. FUNDING INTEGRITY: all arms diverge strongly from baseline (no 0.0000 gaps) -- the B1 fix is confirmed live at surface level. OPEN INTEGRITY NOTE: this run's baseline aggregate (.766/34.6/17.7) drifts from the M4 surface's baseline (.827/36.2/14.1) on nominally the same spec+warehouse -- code moved 7ef57ed2->96c4c5f between runs; relative comparisons within each run stand, but the drift source (suspect list: #2085 exit-visibility, #2081) should be identified before the next surface reuses cached baselines. Report .sweep-output/leverage-dawn-surface/walk_forward_report.md; spec test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp; P1b memo dev/notes/regime-dependency-evaluation-2026-07-24.md."))
