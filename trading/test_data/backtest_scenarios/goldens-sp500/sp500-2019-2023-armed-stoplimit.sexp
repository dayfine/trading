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
;; resting StopLimit at the top of the current 4-week trading range, E frozen
;; at the first qualifying breakout (#2241), support-floor stop — on the
;; canonical sp500 5-year universe. [sim_entry_fill_next_open] (#2238,
;; "honest next-open Market-leg fills") is also set below to match the
;; intended production config, but it is a NO-OP in this specific scenario:
;; every entry here resolves to StopLimit via [enable_sim_entry_stoplimit],
;; and that flag only changes fill semantics for Market-entry orders (see
;; [_entry_cap_for_sim] in panel_runner.ml). It does not contribute to the
;; behaviour this golden measures — see the inline comment at its config
;; site below.
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
;; BAND ARITHMETIC (tightened 2026-08-13 — the original ±10% pins were wide
;; enough that a recurrence of the pre-#2279 wander would sail through
;; undetected; ±10% around 112.28 spans [101.05, 123.51], well outside even
;; 114.5):
;;
;;   total_return_pct: center 112.28323995525771, band ±1.5 percentage points
;;   -> [110.78323995525771, 113.78323995525771]. Matches this directory's
;;   tightest existing convention for a claimed-deterministic run
;;   ([sp500-2019-2023-bah-brk-b.sexp]'s ±1.5pp scheme).
;;
;;   total_trades: pinned to exactly 240 via a half-trade buffer
;;   -> [239.5, 240.5], the same integer-pin idiom the BAH goldens use for
;;   their 0-round-trip pin ([(min 0) (max 0.5)]).
;;
;; Coverage against the three pre-#2279 draws: (114.5, 239) fails BOTH fields
;; (114.5 > 113.78 and 239 < 239.5); (112.755, 241) fails the trades field
;; (241 > 240.5) even though its return sits inside the return band; (112.670,
;; 240) is the one draw that slips through both fields — its return sits only
;; 0.39pp below the deterministic center and its trade count matches exactly,
;; so it is honestly the smallest and least distinguishable of the three
;; wanders. Two of the three documented pre-fix draws now fail the pins
;; outright; catching the third would require asserting near-exact
;; floating-point equality, which is out of scope for a range-pinned golden.
;;
;; The remaining metrics (win_rate, sharpe_ratio, max_drawdown_pct,
;; avg_holding_days, open_positions_value) keep their original ±10% bands —
;; no pre-#2279 wander data was captured for them, so tightening them here
;; would be inventing precision this golden cannot back up.
;;
;; wall_seconds is pinned [100, 1500], mirroring [sp500-2019-2023.sexp]'s
;; convention. This golden is the entry-path-heaviest scenario in the suite
;; — every entry walks the intraday path — so it is the golden most exposed
;; to a performance regression there; measured ~4 min locally (see the
;; perf-tier rationale above), comfortably inside this band. Sized to catch
;; only a catastrophic (~2x+) slowdown, not routine CI-vs-local variance.
;;
;; If a postsubmit run lands outside these bands, do NOT widen them — that is
;; the signal this golden exists to raise.
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
   ;; NO-OP in this config: every entry above already resolves to StopLimit
   ;; (enable_sim_entry_stoplimit), and this flag only changes fill
   ;; semantics for Market-entry orders (see _entry_cap_for_sim in
   ;; panel_runner.ml). Set here to match the intended production config,
   ;; not because it does anything to this scenario's numbers.
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
 ;; Cost-model overlay (PR #1260 wiring). See goldens-small/bull-crash-2015-2020.sexp
 ;; for the full rationale. [retail_default] with per_trade=0 is byte-equal
 ;; to [None] under current wiring; spread / per_share activate once
 ;; [Cost_model.to_engine_costs] is wired into [Panel_runner].
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ;; Re-pinned 2026-08-24 for the book-faithful stops basis (PR #2530:
  ;; initial_stop_buffer 1.0 + reset_anchor_on_stalled_cycle default-on;
  ;; user-directed #2486; ledger 2026-08-24-stops-basis-book-faithful).
  ;; ±15% around new-basis actuals at c7660cac3 (dev/experiments/record-baseline-2026-08-24/).
  ((total_return_pct ((min 79.765) (max 107.917)))
   (total_trades ((min 145.35) (max 196.65)))
   (win_rate ((min 30.3216) (max 41.0234)))
   (sharpe_ratio ((min 0.809249) (max 1.09487)))
   (max_drawdown_pct ((min 19.4754) (max 26.3491)))
   (avg_holding_days ((min 55.0561) (max 74.4877)))
   (open_positions_value ((min 1.60793e+06) (max 2.17544e+06)))
   (wall_seconds         ((min 100.0)       (max 1500.0))))))
