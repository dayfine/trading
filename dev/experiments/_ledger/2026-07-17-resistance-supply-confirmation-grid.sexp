((date 2026-07-17) (slug resistance-supply-confirmation-grid)
 (hypothesis
  "Confirmation grid for w_overhead_supply (follows 2026-07-16-resistance-supply-weight-surface, verdict Inconclusive/boundary): (a) extend the weight axis {45,60} to find the interior on the home surface; (b) re-run the candidate surface on >=2 independent (period x universe x geometry) cells per promotion-confirmation.md. Mechanism ACCEPTs only if positive weight beats baseline across the grid.")
 (base_scenario
  "grid: [broad top-3000 2000-2026 record-convention 13x2y (home)] / [sp500-515 catstop 2000-2026 26x1y] / [broad top-3000 2011-2026 7x2y]; all on 37-col sketch warehouses (dedup-v3 top-3000 certified bit-identical to Run D basis; sp500 v3 built 2026-07-16)")
 (window_id grid-3cell-2026-07-17)
 (baseline_label baseline)
 (variants
  (((label ext-broad-w45) (config_hash "")
    (aggregate
     (((mean_sharpe 0.897) (mean_calmar 1.302) (mean_return_pct 32.61)
       (mean_max_drawdown_pct 14.88)))))
   ((label ext-broad-w60) (config_hash "")
    (aggregate
     (((mean_sharpe 0.772) (mean_calmar 1.173) (mean_return_pct 27.99)
       (mean_max_drawdown_pct 15.22)))))
   ((label sp500-baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.396) (mean_calmar 0.938) (mean_return_pct 6.32)
       (mean_max_drawdown_pct 10.57)))))
   ((label sp500-w15) (config_hash "")
    (aggregate
     (((mean_sharpe 0.623) (mean_calmar 1.240) (mean_return_pct 11.71)
       (mean_max_drawdown_pct 10.67)))))
   ((label sp500-w30) (config_hash "")
    (aggregate
     (((mean_sharpe 0.552) (mean_calmar 1.099) (mean_return_pct 9.19)
       (mean_max_drawdown_pct 10.24)))))
   ((label b2011-baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.619) (mean_calmar 0.845) (mean_return_pct 23.69)
       (mean_max_drawdown_pct 16.56)))))
   ((label b2011-w15) (config_hash "")
    (aggregate
     (((mean_sharpe 0.696) (mean_calmar 0.727) (mean_return_pct 24.96)
       (mean_max_drawdown_pct 16.51)))))
   ((label b2011-w30) (config_hash "")
    (aggregate
     (((mean_sharpe 0.825) (mean_calmar 0.851) (mean_return_pct 29.15)
       (mean_max_drawdown_pct 17.35)))))))
 (verdict Accept)
 (notes
  "GRID 3/3 CONFIRM -- mechanism-level ACCEPT; default flip remains a HUMAN decision (R3). Home surface response curve is a clean concave hump: .691(base) -> .787(15) -> .860(30) -> .897(45) -> .772(60); interior found at w~45, boundary objection resolved. sp500 cell (different universe AND geometry): both weights beat baseline (w15 .623 best, 17/26 Sharpe wins; w30 .552, 15/26); optimum shifts LOWER on the narrow universe (breadth-dependent optimum, capacity-lore pattern). 2011 period cell (post-GFC era only): w30 .825 vs base .619 (4/7 wins) with fold-Sharpe sigma COLLAPSING .566 -> .223 (the consistency gain is the striking part). w=30 is the cross-grid robust value: beats baseline in ALL cells, never dominated badly; w=15 also 3/3 but weaker aggregate; per-cell winners (45 broad / 15 sp500) are NOT the promotable value per the decision rule. Macro-regime diversity: the two 2000-2026 cells span dot-com + GFC; 2011 cell is the bull-heavy favorable check. CAVEATS carried from the 07-16 work: single-path 28y terminal wealth REVERSES (w30 +1,991% vs baseline +7,914%, identical trade count) because the penalty excludes the crash-recovery monster cohort (AXTI-2025 forensic: 97/130 recent weeks overhead at the $2.18 entry; the name became virgin at $11-17 in Dec-2025/Jan-2026 but was permanently inadmissible under early_stage2_max_weeks -- supplied monsters are denied at birth and stale at redemption). PROMOTION DECISION therefore needs the terminal-wealth-distribution lens (rolling-start matrix, many paths) not just fold means; flagged to user. Companion designed levers (track file): virgin-crossing re-admission (recovers AXTI-class access, book-faithful new-high entry), regime softener k x index_supply (state-based only), stale_old_floor axis, RS-laggard metric, supply-located stop insurance. Sweeps: /tmp/sweeps/resist-supply-{ext,sp500,2011}; specs committed under test_data/walk_forward/.")
)
