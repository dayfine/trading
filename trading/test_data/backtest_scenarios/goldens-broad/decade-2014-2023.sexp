;; perf-tier: 4
;; perf-tier-rationale: Tier-4 release-gate cell — full decade (2014-2023, ~10y) at N=1000. The flagship "can we run a decade-long backtest at scale?" cell. Per dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md (RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)), projects to ~5.7 GB peak at N=1000×10y — fits the 8 GB ceiling. Run on-demand via `dev/scripts/perf_tier4_release_gate.sh` (see `dev/notes/tier4-release-gate-checklist-2026-04-28.md`) when cutting a release. N>=5000 release-gate stays P1 awaiting daily-snapshot streaming (dev/plans/daily-snapshot-streaming-2026-04-27.md).
;;
;; STATUS: long-only baseline pinned 2026-04-29. Expected ranges are tightened
;; to ±~15% around the canonical long-only baseline measured on 2026-04-29
;; (post-#682 — `enable_short_side = false`). See
;; dev/notes/goldens-broad-long-only-baselines-2026-04-29.md for the run output
;; and reasoning. Re-pin once short-side gaps G1-G4
;; (dev/notes/short-side-gaps-2026-04-29.md) close and the override is reverted.
;;
;; Golden (broad-1000): full 10-year run spanning the post-2014 bull, 2018
;; correction, 2020 COVID crash, 2021 reflation rally, and 2022 bear. Run
;; against the full sector-map with universe_cap=1000. This is the single most
;; demanding cell in the catalog and the canonical "release-shippable"
;; certification: a regression here means the system can't reliably run the
;; longest-window scenario we care about.
;;
;; See bull-crash-2015-2020.sexp for the rationale on universe_cap=1000.
((name "decade-2014-2023")
 (description "10-year decade run spanning multiple regimes (broad-1000 universe)")
 (period ((start_date 2014-01-02) (end_date 2023-12-29)))
 (universe_path "universes/broad.sexp")
 (universe_size 1000)
 ;; enable_short_side disabled 2026-04-29: short-side gaps (G1-G4 in
 ;; dev/notes/short-side-gaps-2026-04-29.md) produce broken metrics on any
 ;; scenario crossing a Bearish-macro window. Until the gaps close, this
 ;; cell runs long-only — see dev/notes/goldens-broad-long-only-baselines-2026-04-29.md.
 ;; Cell E rollout 2026-05-11: applies the new standard strategy config
 ;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior 0.30/0.90/0.10
 ;; default-sized baseline (1582-1627% / 135-145 trades / 94% DD on N=1000).
 ;; Measured 2026-05-12 (Cell E, N=1000 broad, post-#1052/#1053/#1054):
 ;;   total_return_pct  545.37  total_trades 553   win_rate 36.71
 ;;   sharpe_ratio       0.73   max_drawdown 46.29 avg_holding_days  41.18
 ;;   open_positions_value 5,410,009  unrealized_pnl 1,579,384
 ;;   sortino_ratio_annualized 1.27   calmar_ratio 0.44   ulcer_index 16.98
 ;;   force_liquidations_count 4  wall_seconds 1231.51 (local Docker)
 ;; Return cut (concentrated bull run loses to rotation) but MaxDD cut 48pp
 ;; (94 → 46) — much safer. Tolerances ±15%.
 (config_overrides
  (((universe_cap (1000)))
   ((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Re-pinned 2026-05-13 post NAV stale-price fix (#1063). Pre-fix runs
 ;; relied on the silent cash-only NAV collapse in Portfolio_view (when
 ;; get_price=None for a held symbol). Avg-cost fallback there changes
 ;; Peak_tracker / sizing → trade sequence → returns; total_return /
 ;; sharpe / sortino / calmar / open_positions_value shifted lower as
 ;; the strategy now sees realistic-not-spurious NAV. force_liq events
 ;; on this 10y run: 3 (no death-loop signature). Wall on local
 ;; parallel-3 in trading-1-dev: 614s; pin sized to absorb GHA/local
 ;; variance (per perf-tier4 guidance).
 (expected
  ((total_return_pct   ((min 290.0)        (max 410.0)))
   (total_trades       ((min 470)          (max 636)))
   (win_rate           ((min  31.2)        (max  42.2)))
   (sharpe_ratio       ((min   0.50)       (max   0.72)))
   (max_drawdown_pct   ((min  39.4)        (max  53.3)))
   (avg_holding_days   ((min  35.0)        (max  47.0)))
   (open_positions_value ((min 2800000.0)  (max 3900000.0)))
   (sortino_ratio_annualized ((min  0.85)  (max   1.20)))
   (calmar_ratio       ((min   0.30)       (max   0.42)))
   (ulcer_index        ((min  14.43)       (max  21.50)))
   (wall_seconds       ((min 300.0)        (max 1200.0))))))
