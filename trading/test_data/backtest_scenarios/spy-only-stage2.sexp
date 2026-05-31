;; perf-tier: research
;; perf-tier-rationale: SPY-only single-instrument Weinstein stage-timing
;; reference strategy (long/flat). Single-symbol universe (universes/spy-only),
;; so the run is fast despite the long 2009-2026 window. NOT a pinned golden —
;; wide expected bands; this is a direction-finding / headroom diagnostic.
;;
;; Strategy: [Spy_only_weinstein (symbol SPY)] — see
;; [trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.mli].
;; On each Friday it classifies SPY's own 30-week-MA stage and:
;;   - enters (all-cash) when flat and SPY is Stage 2 (above a rising 30wk MA),
;;   - exits to flat on the Stage 3->4 roll-over / Stage 4, or
;;   - exits on a Weinstein trailing-stop hit (checked every day).
;; Long/flat only — no shorting in this first cut.
;;
;; Companion baseline: [goldens-sp500/sp500-2019-2023-bah-spy.sexp] pattern, but
;; over this window run a BAH-SPY scenario on the SAME period + universe to read
;; the alpha/risk-adjusted gap. The Weinstein thesis is that the Stage-4 exits
;; dodge deep drawdowns (a lower MaxDD / higher Sharpe-Calmar), trading some
;; total return for risk-adjusted improvement.
;;
;; SPY data range on disk: 2009-01-02 .. ~2026-05-01 — fully covers this window
;; (warmup begins ~2008-11 via the 210-day prepend, tolerated when bars are
;; absent before 2009-01-02).
((name "spy-only-stage2")
 (description "SPY-only Weinstein stage-timing (long/flat) 2009-06-01 to 2025-12-31 — direction-finding + headroom reference vs BAH-SPY.")
 (period ((start_date 2009-06-01) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Spy_only_weinstein (symbol SPY)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max  200.0)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 5000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
