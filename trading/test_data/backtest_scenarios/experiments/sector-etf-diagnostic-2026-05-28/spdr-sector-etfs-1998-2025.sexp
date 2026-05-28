;; perf-tier: research
;; perf-tier-rationale: Strategic diagnostic — does Weinstein stage analysis
;; applied to ONLY the 11 SPDR sector ETFs beat BAH SPY over 1998-2025?
;; One-off experiment; not in the postsubmit rotation. Companion BAH-SPY
;; benchmark over the same window lives in `bah-spy-1998-2025.sexp` in
;; this directory.
;;
;; **Motivation** (per the diagnostic dispatch prompt, 2026-05-28):
;;
;; Three rounds of v8 BO tuning design have each revealed structural
;; problems with the score formula. The reframe: maybe the 11-knob
;; continuous-parameter space simply does not contain a config that
;; meaningfully beats SPY on the broad-universe surface. Before another
;; tuning round, ask a sharper diagnostic question: does the Weinstein
;; mechanic extract sector-rotation alpha at all?
;;
;;   - If verdict BEAT (>= +1 pp CAGR over BAH SPY): sector rotation has
;;     real alpha; next step is to filter individual-stock screening to
;;     currently-winning sectors.
;;   - If verdict LOSE (<= -1 pp CAGR): the Weinstein mechanic does not
;;     extract sector-level alpha, which suggests stock-level alpha may
;;     be similarly absent. Big strategic implication that revisits the
;;     `project_strategic_pivot_broader_first.md` backlog before more
;;     tuning work.
;;
;; **Universe**: 11 SPDR sector ETFs (XLB, XLC, XLE, XLF, XLI, XLK, XLP,
;; XLRE, XLU, XLV, XLY) — one per GICS sector. Late-inception ETFs
;; (XLRE 2015-10-08; XLC 2018-06-19) enter the tradable universe at their
;; first-bar date via the NaN-tolerance path in
;; `Csv_snapshot_builder._read_one_symbol` (no per-fold pruning needed at
;; this scale). See `spdr-sector-etfs.universe.sexp` for the inception
;; matrix.
;;
;; **Window**: 1998-12-22 (first XLK/XLF bar — the SPDR Select Sector
;; family launched this day) -> 2026-04-14 (last available bar in
;; `data/` as of the diagnostic). This is ~27.3 years — the longest
;; honest backtest the available data supports for this universe.
;;
;; **Config**: Cell-E baseline (canonical config across all goldens
;; since 2026-05-11 promotion). Identical to
;; `goldens-sp500-historical/sp500-1998-2026.sexp`'s config_overrides
;; block. Pinning to Cell-E (not the v7-iter42 BO winner) isolates the
;; UNIVERSE effect from the parameter effect — this experiment is asking
;; "does the mechanic work on this universe?", not "is iter42 better on
;; this universe?". A follow-up could sweep parameters on this universe
;; if the Cell-E result is non-degenerate.
;;
;; **Cost model**: 5 bps bid-ask, $0 commission (retail flat-fee profile)
;; — same overlay as the sp500-2010-2026 / sp500-1998-2026 historicals.
;; At Cell-E's expected ~50-100 trades over 27 years, cost drag is ~5 bps
;; * (turns / year) = trivial; the universe + window are the load-bearing
;; variables.
;;
;; **Initial cash**: $1,000,000 (Backtest.Runner default constant; not a
;; per-scenario knob today — see `runner.ml:13`). The brief asked for
;; $100k for "matches other scenarios" parity, but every historical
;; scenario on this surface uses the $1M default; lowering it here would
;; introduce a position-sizing scaling effect (per memory
;; `feedback_position_count_capital_scaling.md`) that confounds the
;; universe-effect diagnostic. Documented in the report.
;;
;; **Expected ranges**: deliberately WIDE — this is a research scenario
;; whose entire purpose is to surface the result. Tight bands defeat the
;; experiment.
((name "spdr-sector-etfs-1998-2025")
 (description
   "Strategic diagnostic — Weinstein stage analysis applied to ONLY the 11 SPDR sector ETFs over ~27 years (1998-12-22 to 2026-04-14). Cell-E config. Companion BAH-SPY benchmark in the same dir.")
 (period ((start_date 1998-12-22) (end_date 2026-04-14)))
 (universe_path "universes/sector-etf-diagnostic/spdr-sector-etfs.sexp")
 (universe_size 11)
 ;; Cell-E config — identical to sp500-1998-2026.sexp + sp500-2010-2026.sexp.
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 ;; Research bands — catch only catastrophic crashes / NaN sentinels.
 ;; The diagnostic is decided by the comparison in the companion report,
 ;; not by per-scenario band success.
 (expected
  ((total_return_pct  ((min -90.0)  (max 5000.0)))
   (total_trades      ((min   0.0)  (max  10000.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 3650.0)))
   (wall_seconds      ((min   1.0)  (max 14400.0))))))
