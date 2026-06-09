((date 2026-06-09) (slug stage3-force-exit-off-top3000)
 (hypothesis
  "Chart diagnosis: the Stage-3 force-exit fires on whipsaw-prone topping flags; the trailing stop should drive exits instead. Does disabling enable_stage3_force_exit improve the strategy on broad top-3000 WF-CV?")
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
 (verdict Inconclusive)
 (notes
  "INCONCLUSIVE-POSITIVE (most promising lever to date; first NET-POSITIVE mechanism change on broad universe, and it is a REMOVAL). Disabling enable_stage3_force_exit (defer exits to the trailing stop) is the SOLE Pareto-frontier cell in the 2x2: Sharpe 0.679 vs baseline 0.643, Calmar 1.631 vs 1.382, MaxDD 14.74 vs 14.79, DSR 0.9977 vs 0.9964. Confirms the chart-derived hypothesis that the S3 force-exit adds whipsaw, not protection (likely why the 6 S3-exit-timing dials kept getting REJECTED - they tuned a fundamentally whipsaw-prone exit). BUT per-fold win-count is only 1/15 on Sharpe (gate FAIL) - the aggregate edge is modest + concentrated, not robustly per-fold. Needs a confirmation grid (period x universe, .claude/rules/promotion-confirmation.md) before flipping the default. Do NOT promote yet. ma_hold on top makes it worse (0.457). Run /tmp/sweeps/stage2x2; note dev/notes/stage-2x2-2026-06-09.md."))
