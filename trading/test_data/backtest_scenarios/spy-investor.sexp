;; perf-tier: research
;; perf-tier-rationale: SPY-only single-instrument Weinstein stage-timing
;; reference strategy (long/flat), INVESTOR preset (30-week MA). Single-symbol
;; universe (universes/spy-only), so the run is fast despite the long 2009-2026
;; window. NOT a pinned golden — wide expected bands; this is a direction-finding
;; / preset-comparison diagnostic.
;;
;; Strategy: [Spy_only_weinstein (symbol SPY) (ma_period_weeks 30)] — see
;; [trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.mli]. The
;; ONLY dial that differs from the trader preset (spy-trader.sexp) is the MA
;; period: 30 weeks here (Weinstein's investor default) vs 10 weeks there. Each
;; Friday it classifies SPY's own 30wk-MA stage and:
;;   - enters (all-cash) when flat and SPY is Stage 2 (above a rising 30wk MA),
;;   - exits to flat on the Stage 3->4 roll-over / Stage 4, or
;;   - exits on a Weinstein trailing-stop hit (checked every day).
;; Long/flat only — no shorting. The spine (Stage-2-only entry, Stage 3/4 exit,
;; stop below base) is identical to the trader preset; only the MA window differs.
((name "spy-investor")
 (description "SPY-only Weinstein investor preset (30wk MA, long/flat) 2009-06-01 to 2025-12-31 — preset comparison vs spy-trader (10wk MA).")
 (period ((start_date 2009-06-01) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Spy_only_weinstein (symbol SPY) (ma_period_weeks 30)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max  200.0)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 5000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
