;; suppress_warmup_trading off/on as a WF-CV axis, top-1000-2000, 2002-2024.
;; Annual folds → the 2008/2009 folds' warmups straddle the GFC (the #1549 class).
((base_scenario "/workspaces/trading-1/.claude/worktrees/runner-main/dev/experiments/warmup-comparison-2026-06-12/wfcv/base_top1000_2000.sexp")
 (window_spec
  (Rolling
   ((start_date 2002-01-01)(end_date 2024-01-01)(train_days 0)(test_days 365)(step_days 365))))
 (axes
  ((axes (((flag suppress_warmup_trading) (values (true))))) (expansion Cartesian)))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 11) (n 22) (worst_delta 0.30))))
