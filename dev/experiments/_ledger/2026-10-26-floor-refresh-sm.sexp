((date 2026-10-26) (slug floor-refresh-sm)
 (hypothesis
  "Floor-nearest arm SM (pre-registered in dev/experiments/floor-nearest-2026-10-25/README.md §Arm SM, d97f94937): does a monthly top-3000 universe refresh (320 month-end lists, same builder and post-processing as pit-v12) reach the book (liveness: >= 1 SM p0 trade in a symbol outside the yearly list in force), and if live, does median ln(1+R) beat the path-stability null S by spread(S) = 0.2108 without a do-no-harm cost? SM = S with the monthly universe_schedule, 6 cells paired by seed and list perturbation p0-p5, 2019-2024, run tree 3db869d32.")
 (base_scenario
  "floor-nearest-2026-10-25 arm SM: 6 SM cells vs the 6 path-stability S cells, run tree 3db869d32, warehouse /tmp/snap_top3000_pit_v12monthly; all 6 RESULT, 0 excluded, V6 exit 0 (SM p0 vs A p0; each SM pk vs SM p0); liveness SM p0 19/150 closed trades outside the yearly list (all 19 also at the decision; S base rate 0-1 roll-only) -> LIVE")
 (window_id top3000-pitv12-2019-2024-path-stability-6x4)
 (baseline_label seeded-S)
 (variants
  (((label S-median) (config_hash seeded-s0-s5) (aggregate (((mean_sharpe 0.838) (mean_calmar 0.674) (mean_return_pct 180.5) (mean_max_drawdown_pct 23.29)))))
   ((label SM-median) (config_hash seeded-monthly-refresh) (aggregate (((mean_sharpe 0.685) (mean_calmar 0.446) (mean_return_pct 131.3) (mean_max_drawdown_pct 28.79)))))))
 (verdict Inconclusive)
 (notes
  "LIVE; delta median ln(1+R) -0.193 vs bar 0.2108 -> INCONCLUSIVE by rule, no escalation on return; SM beats S in 8/36 cross pairs, median max DD +5.5 pp, Calmar 0.45 vs 0.67. WHY: 70 % of the pooled NAV gap is which arm's cash caught seven tail names (APPS, ADMA, BBWI, MMYT, DXCM, MSTR, GLNG; BBWI refused at the fill for $146 in p1) -- path noise, though traced; 15 % is the entrants' own trades (-$434k pooled): volume-spike names (median breakout volume 4.6x vs 2.5x) that realise worse than what they displace (median ln(1+R) -0.072 vs -0.039; 0 of 123 above +100 %). The entrant tail exists in the lists (18.3 % of > +300 % rows on 8.8 % of member-months) but stops at the funnel: 45 of 60 such names never reach a top-20, 14 that do skip as No_structural_stop / Sized_to_zero, 1 (BMA) is placed. FORWARD: universe breadth is tail-preserving only if the shots reach a slot; the binding gates are the top-20 cut and the structural-stop gate, not list membership; yearly May-31 lists stay the record universe. Writeup: dev/experiments/floor-nearest-2026-10-25/README.md §Results, arm SM."))
