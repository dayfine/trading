;; perf-tier: 1
;; perf-tier-rationale: identical cost profile to panel-golden-2019-full (same 7-symbol union, same ~8-month window) — the schedule only narrows the candidate set, it stages the same bars. Well under the per-PR <=2 min budget. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 1.
;;
;; Scheduled counterpart of [smoke/panel-golden-2019-full.sexp] — the ONE
;; committed scenario that carries a non-empty [universe_schedule], so CI
;; exercises the dated point-in-time membership seam end to end.
;;
;; What it pins:
;;   - the seam itself: [Scenario.universe_schedule] -> [Universe_schedule.load]
;;     -> [Backtest.Runner.run_backtest ?universe_membership_at] (#2816). Before
;;     this scenario existed, no committed spec took that branch, so a
;;     regression in the wiring would have shown up only in unit tests.
;;   - D2 dating: the entry dated [d_i] governs [d_i <= d < d_(i+1)], so a
;;     symbol dropped on 2019-05-06 is still a candidate on 2019-05-04.
;;   - D4 held-through-dropout: AAPL (entered 2019-05-04, exits 2019-05-08) and
;;     JPM (entered 2019-05-04, exits 2019-05-10) leave the universe mid-hold
;;     and still exit normally, bit-equal to the unscheduled golden.
;;   - the staging union: both lists' symbols must price for the whole window
;;     (via [Universe_schedule.union_sector_map]), or the held-through-dropout
;;     positions would lose their bars.
;;
;; Everything else is a verbatim copy of [smoke/panel-golden-2019-full.sexp]:
;; same period, same [universe_path], same [expected] block. That is deliberate
;; — the only difference between the two goldens must be attributable to the
;; schedule. [universe_path] is IGNORED for membership while
;; [universe_schedule] is non-empty; it is kept so the two specs stay diffable
;; and so the spec still resolves on a runner that rejects schedules.
;;
;; This is the CI counterpart of
;; [trading/backtest/scenarios/test/test_universe_schedule_e2e.ml], which builds
;; the same two-list schedule in a temp dir at test time and asserts the live
;; round-trips. Here the lists are committed fixtures and the run is a golden,
;; so the seam is covered by the perf smoke and the panel-golden gate too.
;;
;; See dev/plans/pit-universe-migration-2026-09-14.md step 6.
((name "panel-golden-2019-schedule")
 (description "Panel-mode golden parity under a dated universe schedule")
 (period ((start_date 2019-05-01) (end_date 2020-01-03)))
 (universe_path "universes/parity-7sym.sexp")
 (universe_schedule
  ((2019-05-01 "universes/parity-7sym-2019-05-01.sexp")
   (2019-05-06 "universes/parity-4sym-2019-05-06.sexp")))
 (universe_size 7)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -20.0)  (max 40.0)))
   (total_trades       ((min 0)      (max 20)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -5.0)   (max 10.0)))
   (max_drawdown_pct   ((min 0.0)    (max 40.0)))
   (avg_holding_days   ((min 0.0)    (max 200.0))))))
