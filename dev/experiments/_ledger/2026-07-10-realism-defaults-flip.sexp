((date 2026-07-10)
 (slug realism-defaults-flip)
 (hypothesis
  "BASIS CHANGE, not an experiment: flip two Weinstein_strategy.config REALISM defaults ON (user mandate 2026-07-10, explicit sign-off) — liquidity_config.min_entry_dollar_adv 0.0->1e6 (entry gate) and stale_exit_after_days None->Some 5. min_hold_dollar_adv stays 0.0 (default-off; separate evidence pipeline). Faithfulness, not alpha: the simulator must not FILL entries reality could not fill (APPB fake +$540k at ~$9.5k/day ADV; ELCO short-side twin; 81-symbol corrupt/dust class, audit_bars #1900) and must not HOLD ghosts (IN1 marked at its 2005 close for 20 years inside NAV; 5 zombie positions in the deep top-3000 run — issue #1484 / flag #1487). Same class as the warmup 210->364 re-pin (exempt from experiment-flag-discipline R1/R2: harness faithfulness, no mechanism) and the TOTAL-RETURN comparator rule.")
 (base_scenario "goldens-small/bull-crash-2015-2020.sexp (representative shift cell)")
 (window_id realism-defaults-flip-2026-07-10)
 (baseline_label pre-flip)
 (variants
  (((label pre-flip)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.61) (mean_calmar 0.382) (mean_return_pct 54.57)
       (mean_max_drawdown_pct 19.71)))))
   ((label realism-flip)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.562) (mean_calmar 0.347) (mean_return_pct 48.72)
       (mean_max_drawdown_pct 19.72)))))))
 (verdict Accept)
 (notes
  "Realism/faithfulness basis change, not a mechanism promotion (no new flag; two existing default-off dials flip on; exempt from experiment-flag-discipline R1/R2 as with warmup-364). HONEST ledger citation (dev/backtest/liquidity-overlay-wfcv-2026-07-10/FINDINGS.md + the 4y-fold sensitivity that landed 2026-07-11): the ENTRY GATE is a CONSISTENT Sharpe-for-DD realism trade at BOTH horizons (2y: 0.634/0.821 vs baseline 0.654/0.917 while cutting DD; 4y: same shape) — it forgoes some winners at fold level, but the WF metric CREDITS untradeable fake fills as alpha so it cannot arbitrate realizability (estimand caveat). Promoted on faithfulness grounds notwithstanding. The HOLD-EXIT (min_hold 5e5) alpha case is CLOSED as a fold-horizon artifact (its 2y dominance 0.753/1.131 INVERTS at 4y: 0.626 vs baseline 0.719), so min_hold stays 0.0 default — exactly what this flip does. Representative cell above = goldens-small/bull-crash-2015-2020 (302-symbol, the one small cell the gate bites: return 54.6->48.7, Sharpe 0.61->0.562, DD flat — the entry gate drops sub-$1M-ADV small-caps that window once bought). On LIQUID universes the flip is INERT (goldens-small/covid-recovery + six-year re-measured BIT-IDENTICAL). CAVEAT: a STATIC $1M gate is calibrated for ~$1-10M capital; at larger NAV, position-vs-ADV scaling is the real capacity model (documented follow-up, not this change). LEDGER CONSEQUENCE: absolute backtest numbers shift on universes with illiquid/delisted names from this date; RELATIVE verdicts of prior entries stay valid (baseline and variant equally credited fake fills / held ghosts). All affected tight-band goldens re-pinned against their own validator store (per warmup-364 store mapping). Full record + per-golden before/after: the PR body for feat/realism-defaults-flip; code in liquidity_config.{ml,mli} + weinstein_strategy_config.{ml,mli}."))
