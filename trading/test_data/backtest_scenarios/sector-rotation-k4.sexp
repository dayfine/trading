;; perf-tier: research
;; perf-tier-rationale: Sector-rotation Weinstein stage-timing reference strategy
;; (long/flat), INVESTOR preset (30-week MA), K=4 — hold the top-4 strongest
;; Stage-2 SPDR sector ETF ranked by RS vs SPY. 12-symbol universe (11 sectors +
;; SPY benchmark), so the run is fast despite the long 2009-2025 window. NOT a
;; pinned golden — wide expected bands; this is a direction-finding / selection
;; diagnostic (the multi-symbol generalization of spy-investor.sexp).
;;
;; Strategy: [Sector_rotation_weinstein (k 4) (ma_period_weeks 30)] — see
;; [trading/trading/weinstein/strategy/lib/sector_rotation_weinstein_strategy.mli].
;; Each Friday it classifies every tradable sector ETF's own 30wk-MA stage,
;; keeps the Stage-2 names, ranks them by RS vs SPY, and holds the top-4:
;;   - enters the top-4 Stage-2 sectors (cash split equally across open slots) when a slot is open,
;;   - exits a held sector when it leaves the top-4 set or rolls to Stage 3/4, or
;;   - exits on a Weinstein trailing-stop hit (checked every day).
;; Long/flat only — no shorting, no macro gate, no portfolio-risk sizing. SPY is
;; the RS benchmark and is never traded. The spine (Stage-2-only entry, Stage
;; 3/4 exit, stop below base, RS for selection) is faithful.
((name "sector-rotation-k4")
 (description "Sector-rotation Weinstein investor preset (30wk MA, long/flat), K=1 — top-4 Stage-2 SPDR sectors by RS vs SPY, 2009-06-01 to 2025-12-31.")
 (period ((start_date 2009-06-01) (end_date 2025-12-31)))
 (universe_path "universes/spdr-sectors-11-plus-spy.sexp")
 (universe_size 12)
 (config_overrides ())
 (strategy (Sector_rotation_weinstein (k 4) (ma_period_weeks 30)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max  500.0)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 5000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
