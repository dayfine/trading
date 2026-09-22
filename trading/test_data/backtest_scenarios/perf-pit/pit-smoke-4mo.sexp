;; LOCAL-ONLY perf cell (issue #2896) -- NOT part of any GHA-discoverable
;; catalog dir (goldens-small/goldens-broad/perf-sweep/smoke), so it carries
;; no [;; perf-tier: N] header and is invisible to perf_catalog_check.sh and
;; every dev/scripts/perf_tier{1,2,3,4}*.sh runner -- see their `for sub in
;; goldens-small goldens-broad perf-sweep smoke ...` discovery loops. This
;; cell requires the `_v11pit` snapshot warehouse at
;; /tmp/snap_top3000_pit_v11pit (tens of GB) inside the trading-1-dev
;; container; that warehouse is never built on GHA. Run it via
;; dev/scripts/perf_pit_smoke.sh from the weekly perf review
;; (.claude/rules/perf-review-weekly.md), not from any CI workflow.
;;
;; Config is the a0-pit-null / t1-topn-40 null (dev/experiments/
;; top-of-funnel-2026-09-21/specs/t1-topn-40.sexp, universe_path /
;; universe_schedule / config_overrides copied verbatim, WITHOUT the
;; screening_config.max_buy_candidates 20 -> 40 override -- this is the
;; unmodified null config). Only the period is narrowed to a 4-month 2020
;; window (per issue #2896's template, `v1-index-veto-smoke.sexp` from
;; dev/experiments/index-stage-veto-2026-09-16/, 27 min at cap 256 -> 6 min
;; at cap 12,000 on 2026-09-20) so the pair of runs (cap 256 vs 12,000) stays
;; a "weekly review" sized cell rather than an hours-long one.
((name "pit-smoke-4mo")
 (description "PIT-warehouse smoke cell: opens the full _v11pit snapshot warehouse (9,364 symbols) over a 4-month 2020 window so the mmap handle cap (SNAPSHOT_MAX_MMAP_HANDLES, #2882) is exercised as intended -- cap 256 forces LRU cycling across the whole universe, cap 12,000 never evicts. Run twice by dev/scripts/perf_pit_smoke.sh; both runs must be byte-identical (deterministic strategy, same salt) so any wall/RSS delta is attributable to cache thrash, not a behaviour change.")
 (period ((start_date 2020-01-01) (end_date 2020-04-30)))
 (universe_path "pit-v11/composition/top-3000-2000.sexp")
 (universe_schedule (
  (1999-05-31 "pit-v11/composition/top-3000-1999.sexp")
  (2000-05-31 "pit-v11/composition/top-3000-2000.sexp")
  (2001-05-31 "pit-v11/composition/top-3000-2001.sexp")
  (2002-05-31 "pit-v11/composition/top-3000-2002.sexp")
  (2003-05-31 "pit-v11/composition/top-3000-2003.sexp")
  (2004-05-31 "pit-v11/composition/top-3000-2004.sexp")
  (2005-05-31 "pit-v11/composition/top-3000-2005.sexp")
  (2006-05-31 "pit-v11/composition/top-3000-2006.sexp")
  (2007-05-31 "pit-v11/composition/top-3000-2007.sexp")
  (2008-05-31 "pit-v11/composition/top-3000-2008.sexp")
  (2009-05-31 "pit-v11/composition/top-3000-2009.sexp")
  (2010-05-31 "pit-v11/composition/top-3000-2010.sexp")
  (2011-05-31 "pit-v11/composition/top-3000-2011.sexp")
  (2012-05-31 "pit-v11/composition/top-3000-2012.sexp")
  (2013-05-31 "pit-v11/composition/top-3000-2013.sexp")
  (2014-05-31 "pit-v11/composition/top-3000-2014.sexp")
  (2015-05-31 "pit-v11/composition/top-3000-2015.sexp")
  (2016-05-31 "pit-v11/composition/top-3000-2016.sexp")
  (2017-05-31 "pit-v11/composition/top-3000-2017.sexp")
  (2018-05-31 "pit-v11/composition/top-3000-2018.sexp")
  (2019-05-31 "pit-v11/composition/top-3000-2019.sexp")
  (2020-05-31 "pit-v11/composition/top-3000-2020.sexp")
  (2021-05-31 "pit-v11/composition/top-3000-2021.sexp")
  (2022-05-31 "pit-v11/composition/top-3000-2022.sexp")
  (2023-05-31 "pit-v11/composition/top-3000-2023.sexp")
  (2024-05-31 "pit-v11/composition/top-3000-2024.sexp")
  (2025-05-31 "pit-v11/composition/top-3000-2025.sexp")
  ))
 (universe_size 3000) ;; per-year membership (PIT schedule); union staged = 10,504
 ;; entry_order_max_rest_weeks pinned at its pre-promotion value 0 (unbounded)
 ;; so this cell stays comparable to the recorded grid1-null / t1-topn-40
 ;; baselines after the default moved 0 -> 26 (PR #2384). Do not drop this pin.
 (config_overrides
  (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
   ((sim_entry_trigger_at_suggested true))
   ((stop_anchor_at_entry_base true))
   ((entry_extension_max_pct 2.0))
   ((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))
   ((macro_config ((breadth_direction ((enabled true))))))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 0) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
