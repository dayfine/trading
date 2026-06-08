((date 2026-06-09) (slug laggard-broad-recheck)
 (hypothesis
  "laggard-rotation was REJECTED on SP500 (<=506 syms, disabling hurts) but is candidate-supply-sensitive, so its sign may flip on a broader universe")
 (base_scenario "goldens-custom-universe/composition/top-1000-2011 (PIT)")
 (window_id wf-2011-2026-365-182-29fold-top1000-snapshot)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.23167632051829135) (mean_calmar 0.71435097220646593)
       (mean_return_pct 7.1987705289616892)
       (mean_max_drawdown_pct 17.249561992681162)))))
   ((label enable_laggard_rotation=false) (config_hash "")
    (aggregate
     (((mean_sharpe 0.36764323877932314) (mean_calmar 0.763475548413255)
       (mean_return_pct 14.184478595965519)
       (mean_max_drawdown_pct 18.19801775776407)))))))
 (verdict Inconclusive)
 (notes
  "Direction REVERSES vs SP500: on top-1000 disabling laggard has higher mean Sharpe (0.368 vs 0.232), Calmar, return (+7pp), DSR (0.995 vs 0.854); both on Pareto frontier. BUT Fold_gate=FAIL (15/29 wins, worst fold-007 gap 1.32>0.20) and the edge is fat-tail-driven (return sigma 22->35; fold-020 +153pp vs +53pp). Not a clean accept to flip the laggard default; keep ON. Breadth-sensitivity confirmed in direction. top-3000 confirmation blocked by container VMTracker/OOM catch-22. See dev/notes/laggard-broad-recheck-2026-06-09.md."))
