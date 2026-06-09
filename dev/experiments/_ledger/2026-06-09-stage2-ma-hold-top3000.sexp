((date 2026-06-09) (slug stage2-ma-hold-top3000)
 (hypothesis
  "Does the chart-validated Stage-2 MA-hold classifier refinement (hold S2 while price>=MA) improve the strategy on broad top-3000 WF-CV?")
 (base_scenario "goldens-custom-universe/composition/top-3000-2011 (PIT)")
 (window_id wf-2011-2026-365-365-15fold-top3000-2x2-forkperfold)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.64281770518313874) (mean_calmar 1.3816425612264558)
       (mean_return_pct 12.950175847379974)
       (mean_max_drawdown_pct 14.790393995098752)))))
   ((label enable_stage3_force_exit=true__enable_stage2_ma_hold=false)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.64281770518313874) (mean_calmar 1.3816425612264558)
       (mean_return_pct 12.950175847379974)
       (mean_max_drawdown_pct 14.790393995098752)))))
   ((label enable_stage3_force_exit=true__enable_stage2_ma_hold=true)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.48570609483795746) (mean_calmar 1.354390444506872)
       (mean_return_pct 10.508354709585092)
       (mean_max_drawdown_pct 14.847173350329793)))))
   ((label enable_stage3_force_exit=false__enable_stage2_ma_hold=false)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.67908431692581472) (mean_calmar 1.6307899577087506)
       (mean_return_pct 13.071462363117345)
       (mean_max_drawdown_pct 14.73842200757595)))))
   ((label enable_stage3_force_exit=false__enable_stage2_ma_hold=true)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.45684989319278591) (mean_calmar 1.2991960986810773)
       (mean_return_pct 9.214691949886566)
       (mean_max_drawdown_pct 14.787875733307981)))))))
 (verdict Reject)
 (notes
  "REJECT. enable_stage2_ma_hold DEGRADES the strategy despite cleaning the stage chart visually: Sharpe 0.643->0.486 (force_exit on) / 0.679->0.457 (force_exit off), lower Calmar + DSR (0.96/0.94 vs 0.996), off the Pareto frontier, fails Fold_gate. Visual stage-coherence does NOT translate to better returns (holding S2 through pullbacks keeps positions/eligibility that should rotate). Stays default-off. Companion: stage3-force-exit-off-top3000 (the promising lever from the same 2x2). Diagnosis: project_stage_chart_visual_diagnostic; run /tmp/sweeps/stage2x2."))
