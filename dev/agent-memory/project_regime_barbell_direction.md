---
name: project_regime_barbell_direction
description: "2026-06-26 finding (DIRECTION TO UNDERSTAND, not a verdict): the strategy's edge is regime-conditional — WINS when SPY down/turbulent (2000+36,2002+18.5,2008 -11.6 vs SPY -36.8,2022+20.6), LOSES in melt-ups (2019,2021,2023,2024 -44pp). A realizable annual MA-barbell (bull→hold SPY, bear→run strategy) compounds +1295% vs SPY +874% vs strategy +622%. Next session = UNDERSTAND why + map options, NOT build/test."
metadata:
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

Per-year long-only broad (top-3000 PIT-1998, 0.14) vs SPY total return, 1999-2026:
strategy WINS in down/turbulent years (2000 +36pp, 2001 +18, 2002 +18.5, **2008
−11.6% vs SPY −36.8% = +25pp**, 2009 +16.5, 2022 +20.6) and LOSES in strong bulls
(2017 −11.5, 2019 −16.2, 2021 −15, 2023 −27.7, **2024 −43.6**). Textbook
Weinstein/trend: defensive in bears (stage-4 exits, cash), whipsawed/cash-dragged
in melt-ups.

**Realizable macro-barbell beats both legs.** Switch on last year-end SPY 30-week-MA
state (NO lookahead): bull→hold SPY, bear→run strategy. Compounded 1999-2026:
strategy +622% / SPY +874% / **MA-barbell +1295%** / contemporaneous-cheat +3450% /
perfect-foresight +7785%. The barbell fixes the strategy's bull-lag (hold SPY) while
keeping its bear-defense.

**Reconciles with "regime-gating is dead" ([[project_next_lever_decision_grading]]):**
prior regime-gating toggled strategy on/off (strategy vs CASH); this barbell's bull
leg is **SPY not cash** — that's the difference. Also consistent with
[[project_factor_lens_regime_governs_edge]] (realized edge ~ forward index DD r=−0.79).

**STATUS = single-path screen, NOT a verdict** (per [[project_mechanism_validation_rigor]]).
Caveats: edge concentrated in the big bears (2008/dot-com) → regime-dependent, a
bull-only window likely shows the barbell LOSING; the lagging annual signal misses
the FIRST bear year (2000, 2022) and overstays recoveries (2003, 2019, 2023).

**User directive 2026-06-26:** next session = DERIVE UNDERSTANDING + explore options/
directions, do NOT jump to a strategy change or WF-CV. Plan:
`dev/notes/next-session-priorities-2026-06-27.md`. Threads: (A) characterize/attribute
the regime-edge + real-time detectability; (B) decision quality / missed-trades / scoring
faithfulness (#1/#4 — score already known anti-predictive); (C) is the short leg's value
regime-conditional (precondition for macro long-short #3/#5; static long-short adds
nothing per [[project_liquidity_realism_overlay]]); (D) ops: PIT-vs-live universe
liquidity audit (#6) + margin-safety doc (#7). Data: equity curve
`dev/backtest/scenarios-2026-06-27-034110`, SPY `data/S/Y/SPY`,
`dev/backtest/DEEP_RESULTS.md`. Unifies user asks #2/#3/#5.

---
**UNDERSTANDING SESSION 2026-06-27** (analysis-only, committed long-only deep run;
note: `dev/notes/regime-edge-understanding-2026-06-27.md`):
- **Bear-edge is BROAD, not 2008-dependent** (corrects the caveat above): edge=LO−SPY
  POSITIVE in ALL 6 down-SPY years — 2000 +36, 2001 +18, 2002 +18.5, 2008 +25.2,
  2018 +6.3, 2022 +20.6 (mean +20.8pp). Sign universal across all 4 bear types;
  MAGNITUDE scales with bear depth (deep +20-36, mild 2018 +6). corr(edge, SPYret)=−0.59.
- **Bull-lag is STRUCTURAL under-participation, NOT losses.** Worst lag years avgpnl
  still +1% while SPY +25% (2024 +1.1 vs +24.9; 2023 +0.8 vs +26.2). Causes ranked:
  (1) cash cap min_cash0.30 + max_long_exp0.70 = ≤70% equity → ≥7.5pp drag/melt-up-yr
  (config-forced); (2) whipsaw — exits 68% stop_loss/30% laggard, stop% 54-77% in lags;
  (3) breakout-with-stop caps per-name upside. = `project_accuracy_is_unreachable...`
  dead-end → fix is a diversifying LAYER (barbell), not entry tuning.
- **Bull-year is BIMODAL** (refinement): WINS post-bear dawns (1999 +27, 2004 +19,
  2009 +16, 2013, 2015), LOSES mature melt-ups (2010 −24, 2016 −27, 2023 −28, 2024 −44).
  Real regime axis ≈ {mature-bull→SPY, recovery→strategy, bear→strategy}.
- **Detectability:** strategy's ENDOGENOUS macro gate already nails deep bears
  (2001/02/08 ~90%+ bearish), correctly quiet in clean melt-ups (2017/20/21/23/24=0%),
  but MISSES fast/mild bears (2018 12%, 2022 41%, 2000 39%) + false-pos in flat chop
  (1998 51%, 2011 61%, 2015 41%). Annual-SPY-MA (doc's signal) is coarser → overstay
  cells. Hard cells for BOTH = turns + fast bears (= barbell error cells). Grid must
  stress turns/fast-bears, deep bears are easy.
- MFE/MAE POPULATED in this run (1288 recs) — give-back/near-miss analysis unblocked.
- Thread C (short-by-regime) BLOCKED: committed long-short = summary .sexp only, no
  per-trade; needs 1 liq-armed long-short run emitting trades.csv. Low priority
  (long-only+721 ≈ armed-LS+774 → short adds ~0 net; only bear-specific value open).
- Options menu (NOT a build): bull leg=SPY (cash-gating dead); bear leg=strategy;
  signal candidates {annual SPY-MA / monthly-MA / endogenous macro gate / A-D breadth};
  cadence annual→overstays. Promotion still needs default-off→WF-CV→bear-inclusive grid.
