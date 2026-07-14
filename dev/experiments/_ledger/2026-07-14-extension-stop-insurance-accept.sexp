((date 2026-07-14)
 (slug extension-stop-insurance-accept)
 (hypothesis
  "extension_stop (trigger_ratio 2.0 x WMA30, trail_pct 0.25; PR #1934, default-off) is acceptable as ARMED tail-insurance for the record convention + live weekly-review: it banks parabolic blow-off tops without killing the let-winners-run on-ramp. Basis = INSURANCE ACCEPTANCE (armed-vs-off event-level record pair, precedent #1695 catastrophic_stop), NOT fold-Sharpe WF-CV: the mechanism fires at ~1% event rate (8 firings / 26y / ~1,200 trades), so WF-CV is structurally powerless on it (2026-07-11 screen, project_extension_stop_screen_no_build).")
 (base_scenario "staging-honest-tradeable-ext/top3000-2000-2026-honest-tradeable-ext.sexp (dedup-v2 warehouse /tmp/snap_top3000_1998_2026_dedup_v2)")
 (window_id record-pair-top3000-2000-2026-dedup-v2-basis)
 (baseline_label extstop-off)
 (variants
  (((label extstop-off)
    (config_hash top3000-2000-2026-ht-dedup-v2-baseline)
    (aggregate
     ((sharpe 0.68) (cagr_pct 14.4) (maxdd_pct 40.9) (mtm_return_pct 3407.0)
      (realized_pnl_musd 10.4) (trades 1171))))
   ((label extstop-armed-2.0-0.25)
    (config_hash top3000-2000-2026-ht-dedup-v2-EXTSTOP-ARMED)
    (aggregate
     ((sharpe 0.82) (cagr_pct 17.7) (maxdd_pct 32.3) (mtm_return_pct 7455.0)
      (realized_pnl_musd 66.8) (trades 1190))))))
 (verdict Accept)
 (notes
  "ACCEPT(insurance-arming): every one of the 8 firings in 26y banked a parabolic top (+89% to +5,196%) — AXTI 2026-05-30 $59.0M realized (vs riding $140->$70 to a $24M open mark in baseline), DDD at its Feb-2021 peak, BFX Nov-2020, four dot-com-era names Mar-Apr 2000. ZERO premature on-ramp kills: the 2.0x trigger only arms parabolics and the 25% trail survived the AXTI April shakeout (screen-pinned width; 0.10-0.20 are on-ramp killers per the 2026-07-11 event screen). Left tail: MaxDD 40.9->32.3. Realized/mark composition flips from $10.4M/$24.6M (mark-heavy) to $66.8M/$9.0M (banked). CAVEATS stated: single path; AXTI ~88% of the realized delta. SP500 ROBUSTNESS CELL (2026-07-14): armed-vs-off pair on sp500-as-of-2000 PIT (515 names, same honest-tradeable dials, 2000-2026) is BIT-IDENTICAL (328.3% / 840 trades / Sharpe 0.685 / MaxDD 25.9% both legs; trades.csv + actual.sexp diff-clean; 0 extension_stop exits) — the 2.0x trigger NEVER arms on large-caps in 26y. Reading: the mechanism engages only in the broad-universe parabolic tail (where the AXTI-class monsters live) and is exactly do-no-harm everywhere else — the desired insurance shape (no premature kills anywhere, upside only where parabolics exist). Not a top-3000-specific HARM artifact: it cannot hurt where it never fires. Cell artifacts: trading/dev/backtest/scenarios-2026-07-14-001917 + extstop-sp500-cell-2026-07-14/scenarios. COMBINED with reject_declining_ma_long_entry (#1775): effects ADDITIVE (Run D = A+B: Sharpe 0.83, CAGR 18.0, MaxDD 32.3, realized $70.9M; 2026-07-13 armed-run matrix). CONFIRMING EVIDENCE for reject_declining_ma on this basis: +213pp MTM / +$0.7M realized / DD unchanged; removes exactly 4 entries (AIR 2020-03-14 COVID-waterfall, DO_old 2018, AKS 2018, MOD 2019); validator V8 4->PASS when armed — mechanism/validator cross-confirm; consistent with its 2026-06-28 grid verdict (Reject GLOBAL flip / ARM-FOR-BROAD, do-no-harm in 39/39 folds). ARMING SCOPE per user 07-14 alignment: NO code-default flips (experiment-flag R1 defaults stay no-op); both dials armed via explicit config in (1) the record-convention staged scenario and (2) the live weekly-review config. Promotion-PR citation of record for flag-discipline R3. Artifacts: dev/notes/armed-run-matrix-2026-07-13.md; run dirs trading/dev/backtest/scenarios-2026-07-13-{052958,170900,182717,194522}; memory project_extension_stop_acceptance."))
