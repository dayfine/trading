;; perf-tier: research
;; perf-tier-rationale: SPY-only single-instrument Weinstein stage-timing
;; reference strategy with the Stage-4 SHORT leg enabled (long-short, investor
;; preset 30wk MA). Single-symbol universe (universes/spy-only), so the run is
;; fast despite the long 2009-2026 window. NOT a pinned golden — wide expected
;; bands; this is a direction-finding / risk-defense diagnostic.
;;
;; Strategy: [Spy_only_weinstein (symbol SPY) (ma_period_weeks 30)
;;           (enable_stage4_short true)] — see
;; [trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.mli]. The
;; ONLY dial that differs from the long/flat investor preset (spy-investor.sexp)
;; is [enable_stage4_short]. Each Friday it classifies SPY's own 30wk-MA stage:
;;   - enters LONG (all-cash) when flat and SPY is Stage 2 (above a rising MA),
;;   - goes SHORT (all-cash) when flat and SPY is Stage 4 (below a falling MA),
;;   - exits the long on the Stage 3->4 roll-over / Stage 4 (to flat, then short),
;;   - covers the short when SPY leaves Stage 4 (re-enters Stage 1/2),
;;   - exits/covers on a Weinstein trailing-stop hit (checked every day; the
;;     short stop sits ABOVE entry and ratchets DOWN as price falls).
;;
;; Headline question (drawdown defense): does the short leg LOWER MaxDD vs the
;; long/flat twin (spy-investor.sexp) on the same window+universe? Prior art
;; (sp500-2010-2026-longshort) FAILED this bar — individual-name shorts get
;; squeezed on fast-V bounces and RAISED drawdown. This testbed asks whether
;; shorting a single clean instrument (SPY) in sustained Stage-4 bears does
;; better. Default-off testbed dial — NOT promoted; see
;; [.claude/rules/experiment-flag-discipline.md].
;;
;; SPY data range on disk (committed test_data): 2009-01-02 .. ~2026-05-01 —
;; covers this window. A deeper 1993-2026 SPY (dot-com bust + GFC) is the
;; macro-regime-diverse companion run reported in the PR body, not pinned here.
((name "spy-longshort")
 (description "SPY-only Weinstein long-short investor preset (30wk MA, Stage-4 short leg ON) 2009-06-01 to 2025-12-31 — drawdown-defense diagnostic vs spy-investor (long/flat).")
 (period ((start_date 2009-06-01) (end_date 2025-12-31)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Spy_only_weinstein (symbol SPY) (ma_period_weeks 30) (enable_stage4_short true)))
 (expected
  ((total_return_pct       ((min -90.0)    (max 5000.0)))
   (total_trades           ((min   0.0)    (max  400.0)))
   (win_rate               ((min   0.0)    (max  100.0)))
   (sharpe_ratio           ((min  -2.0)    (max    5.0)))
   (max_drawdown_pct       ((min   0.0)    (max   95.0)))
   (avg_holding_days       ((min   0.0)    (max 5000.0)))
   (wall_seconds           ((min   0.5)    (max 3600.0))))))
