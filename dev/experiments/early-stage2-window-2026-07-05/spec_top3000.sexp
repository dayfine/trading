;; Early-Stage2 admission-window WF-CV surface — BROAD-ONLY (top-3000 decisive
;; cell, per the declining-MA / capacity breadth lessons: entry-admission levers
;; read false-null on sp500). P2 from dev/notes/next-session-priorities-2026-07-02.md,
;; deferred from #1818; mechanism #1862 (early_stage2_max_weeks, default 4).
;;
;; Hypothesis: the ≤4-week early-Stage2 admission window is untested vs the
;; 8-week breakout-EVENT lookback. Widening (6, 8) admits more
;; not-yet-extended Stage-2 names = a tail-PRESERVING breadth lever (the
;; favored class per project_edge_is_the_fat_tail); tightening (2) tests
;; whether only the freshest breakouts carry the edge. The Stage1→Stage2
;; transition arm is unconditional at every value — only the fresh-Stage2
;; OR-arm moves.
;;
;; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/early-stage2-window-v1
;;   --snapshot-dir /workspaces/trading-1/dev/data/snapshots/wfcv-top3000-1998
;;   --parallel 1 (fork-per-fold; N=3000 memory). Preflight verified 2026-07-05:
;;   Docker.raw 21G, host 89Gi free, /tmp/sweeps bind-mounted.
((base_scenario "/workspaces/trading-1/dev/experiments/continuation-add-v2-2026-07-05/base_top3000.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01)(end_date 2026-04-30)(train_days 0)(test_days 730)(step_days 730))))
 (variants
  (((label "baseline") (overrides ()))
   ((label "w2")
    (overrides (((screening_config ((early_stage2_max_weeks 2)))))))
   ((label "w6")
    (overrides (((screening_config ((early_stage2_max_weeks 6)))))))
   ((label "w8")
    (overrides (((screening_config ((early_stage2_max_weeks 8)))))))))
 (baseline_label "baseline")
 (gate ((metric Sharpe)(m 7)(n 13)(worst_delta 0.30))))
