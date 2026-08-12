;; perf-tier: 3
;; perf-tier-rationale: ~500-symbol S&P 500 universe over 5 years, same period
;; and universe as [sp500-2019-2023-long-only]; the difference is the ARMED
;; StopLimit entry family. Weekly cadence, ≤2 h budget; measured ~4 min.
;;
;; WHY THIS GOLDEN EXISTS
;;
;; Every other golden runs the DEFAULT entry model, in which the simulator
;; resolves entries to Market fills — see [panel_runner.ml] `_entry_cap_for_sim`,
;; whose own comment states the consequence: "either alone is inert, so the
;; default config keeps Market fills and every existing baseline bit-identical".
;; A Market fill never walks the intraday path. Only a resting stop/limit order
;; does.
;;
;; So the entire armed-StopLimit regime — the family that F2 (`entry_order_ttl_weeks`),
;; F3 (`stop_width_mode`), F5 (`volume_confirm_at_fill`) and the sim-entry
;; fill model are all scoped to — had NO golden coverage at all. Their
;; bit-identity guarantees were verified by unit tests plus default-config
;; goldens, i.e. only where those mechanisms are inert by construction. That
;; structural hole hid a real defect for as long as it existed: the intraday
;; path RNG was unseeded (`Price_path.default_config.seed = None` ->
;; `Random.State.make_self_init ()`), so armed runs returned a different answer
;; every time — four runs of one binary spread 0.774pp on a 6y/302 probe, and
;; ~278pp at 26y/top-3000. Fixed in PR #2279; recorded in
;; dev/notes/backtest-nondeterminism-2026-08-11.md and
;; dev/notes/ladder-v4-read-2026-08-12.md.
;;
;; This scenario closes the hole. It is the ladder v2-core entry stack — a
;; resting StopLimit at the top of the current 4-week trading range, E frozen at
;; the first qualifying breakout (#2241), honest next-open Market-leg fills
;; (#2238), support-floor stop — on the canonical sp500 5-year universe.
;;
;; WHAT IT PROTECTS
;;
;; Chiefly reproducibility: a regression that reintroduces path nondeterminism
;; moves these numbers, and nothing else in the golden suite would notice. It
;; also pins the armed entry stack's behaviour against unintended drift from
;; future work on the sim-entry / stop-width / ticket-TTL surfaces, which is
;; exactly the class of change the 2026-08-11 bisect went looking for and could
;; not measure.
;;
;; BANDS
;;
;; Measured 2026-08-12 on the PR #2279 build with TRADING_DATA_DIR pointed at
;; trading/test_data (CI's committed bar data — the same path every workflow
;; sets), which reproduces CI exactly: the six-year-2018-2023 golden read
;; 79.134696483942491 / 321 trades under that env, dead on its pinned band.
;;
;;   total_return_pct 112.28323995525771   total_trades 240
;;   win_rate 37.916666666666664           sharpe_ratio 1.1045580768778107
;;   max_drawdown_pct 16.984669525908746   avg_holding_days 45.3625
;;   open_positions_value 2,087,639.27     force_liquidations 0
;;
;; Determinism verified on the post-#2279 build under CI's data path: two
;; consecutive runs returned total_return_pct 112.28323995525771 / 240 trades
;; with byte-identical trades.csv. Pre-#2279 the same spec wandered (114.5 /
;; 239, then 112.755 / 241, then 112.670 / 240) — that spread is exactly what
;; this golden now guards against.
;;
;; Bands are ±10%, tighter than the ±15% house default: this run is
;; deterministic, so the only legitimate movement is an intentional behaviour
;; change, which should re-pin rather than slip through a wide band. If a
;; postsubmit run lands outside these bands, do NOT widen them — that is the
;; signal this golden exists to raise.
((name "sp500-2019-2023-armed-stoplimit")
 (description "Armed StopLimit entry stack (ladder v2-core) on the sp500 5-year universe — the entry regime no other golden covers.")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides
  (;; --- the armed StopLimit entry stack (the point of this golden) ---
   ((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((entry_anchor_local_range_weeks 4))
   ((entry_extension_max_pct 2.0))
   ((freeze_entry_at_first_breakout true))
   ((sim_entry_fill_next_open true))
   ;; --- sizing / exit half: the Cell-E standard config, as the other goldens ---
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
   ((stale_exit_after_days (5)))))
 (expected
  ((total_return_pct     ((min 101.05)      (max 123.51)))
   (total_trades         ((min 216)         (max 264)))
   (win_rate             ((min  34.12)      (max  41.71)))
   (sharpe_ratio         ((min   0.994)     (max   1.215)))
   (max_drawdown_pct     ((min  15.29)      (max  18.68)))
   (avg_holding_days     ((min  40.83)      (max  49.90)))
   (open_positions_value ((min 1878875.0)   (max 2296403.0))))))
