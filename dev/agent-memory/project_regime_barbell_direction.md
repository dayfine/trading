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
