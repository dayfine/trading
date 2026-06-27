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

---
**FULL-THREAD SYNTHESIS 2026-06-27** (all 4 threads run; note:
`dev/notes/regime-edge-synthesis-2026-06-27.md`). **CONCLUSION CHANGES THE
DIRECTION:**
- **TOP LEVER = a STATIC ~30% SPY / 70% engine blend, NOT a dynamic switch.**
  Apples-to-apples daily price-only blend (engine=+721% broad LO vs SPY price):
  static30 = +805% / Sharpe .568 / MaxDD 29.4% — BEATS both pure engine (721/.496/43.8)
  AND pure SPY (629/.459/56.5) in return AND DD AND Sharpe. Sub-window: static30
  Sharpe ≈.56 crash-decade AND ≈.57 bull-decade = regime-STABLE (legs are each
  regime-unstable). Genuine diversification (regime anti-correlation), the one
  Weinstein-faithful lever that diversifies the fat tail instead of taxing it
  ([[project_edge_is_the_fat_tail]]). Mature infra EXISTS (Barbell_config +
  floor-weight sweep); static 70/30 already passed a grid ([[project_barbell_on_stocks]]).
- **DYNAMIC regime-switch DEMOTED (resolves the contradiction).** The 06-26
  priorities-doc's +1295% annual MA-barbell was a BASIS ARTIFACT (div-adj SPY +
  per-year compounding); on consistent basis the annual switch = 749/.528, WORSE
  than static30. Switch value is wildly cadence-fragile (daily 329 dead, monthly
  1077 great, annual 749 meh = overfit/path-luck). The 2026-06-21 engine-edge
  FINDINGS ("fixed light floor beats regime-timing the weight") is VINDICATED;
  consistent with regime-gating-is-dead.
- **A.2 bear-edge BROAD on independent universe:** sp500-515 LO re-run, all 5
  down-SPY yrs positive (mean +16pp), corr(edge,SPY)=−0.735. Not a top-3000 artifact.
- **Thread B = DEAD lever:** give-back 10.3pp (capture only +2.5% of +12.9% peak)
  but structural fat-tail/stop tax, no knob captures net; cash-rationing 97% of
  decisions (16,250 Insufficient_cash skips) but allocation ORDER already ~optimal
  (84% take ≥-top candidate). Binding lever = deployment VOLUME = the barbell.
- **Thread C = DROP #5:** short leg fired 30× in 26y (sp500), total −$640k; even
  2008 LOST −$52k; doesn't pay in bears. Macro-conditional long-short precondition
  FAILS. Keep short mechanics merged, don't pursue as a return lever.
- **NEXT (validate-not-build): take static ~30% SPY barbell (SPY buy-hold leg, not
  SPY-timing floor) through default-off→WF-CV→bear-inclusive confirmation grid on
  floor-weight {0.2,0.3,0.4}.** Docs shipped: docs/design/margin-safety.md (#7),
  #6 universe-vs-gate liquidity gap audited (always-arm entry gate fix).

---
**DEEP VERIFICATION + BROAD SHORT CORRECTION 2026-06-27** (user: do broad-3000 not
sp500; do WF-CV when evidence strong; note: `dev/notes/barbell-deep-verification-2026-06-27.md`):
- **SHORT LEG CORRECTED — shorts DO make money on BROAD** (sp500-515's −$640k was a
  survivorship artifact, too few shortable losers). Broad top-3000 liquidity-armed
  long-short: SHORT 36 trades net **+$554k**; armed LS DOMINATES long-only on ALL 3
  axes (+774 vs +721%, Sharpe .53 vs .49, MaxDD 41.5 vs 43.8). "Short adds nothing"
  (DEEP_RESULTS) was return-only framing. Shorts pay BOTH regimes (bear +$205k/bull
  +$349k) → can't macro-gate (#5 dropped, but KEEP short leg ON). BUT ~100% of net =
  2 fat-tail crash-rides (MPAC_old +$364k shorted-2007-rode-GFC, AMMB +$194k
  dot-com); other 34 trades ~$0. = sparse crash-driven tail-hedge not steady alpha
  ([[project_edge_is_the_fat_tail]]). User's intuition correct; low trade-cnt expected.
- **BARBELL WF-CV/grid PASSES** (period×universe). Fixed-weight blend = no fitted
  param → test = per-fold robustness. static-30 beats engine-baseline Sharpe in 5/7
  rolling-10y + 4-5/6 disjoint folds, NEVER badly dominated; per-fold OPTIMAL weight
  regime-unstable (0→1) so promote the conservative robust compromise not a "best".
  Value = RAISING THE FLOOR (worst-fold Sh +0.10 vs engine −0.43), not the ceiling.
- **Benefit is UNIVERSE-DEPENDENT** (2-cell grid): LARGE on realistic broad/honest
  engine (Sharpe .49, DD 44% → +.07 Sh, −15pp DD) but small/neutral on survivor
  sp500 (engine already Sh .75/DD 26%; s20 best, s30+ slightly hurts). Robust
  cross-universe weight = **~0.20-0.30** (0.20 conservative floor; 0.30 justified on
  broad). Floor-raising universe-robust (2020-26 fold: s30 +.38 vs engine −.18 both).
- Existing infra: Barbell_config(floor_weight,default-off)+Barbell_floor_sweep+
  blend.awk(=my hand-blend). Next build (gated): wire floor_weight 0.20-0.30, confirm
  via real Barbell_runner over the grid. Warehouse /tmp/snap_top3000_1998_2026_v2
  PERSISTS in container (survived 4 days; rebuild via build_snapshots single-dash flags).

---
**PRODUCTION CONFIRMATION — FLOOR-LEG CRUX 2026-06-27** (ran canonical
barbell_floor_sweep_runner; ledger 2026-06-27-barbell-floor-sweep, verdict
Inconclusive; note Part 3):
- **The hand-blend "beats both legs" is FLOOR-LEG-DEPENDENT.** Production tool uses
  Spy_only_weinstein 30wk TIMING floor → Sharpe FLAT ~0.488 + Calmar FLAT ~0.168
  across weights, return drops 721→295% monotonically = pure return-for-DD trade,
  NO risk-adjusted gain (re-confirms 06-21 'no free lunch'). Timing floor's
  cash-in-bear is REDUNDANT with engine's own bear defense → only sacrifices return.
- **Buy-hold SPY floor = the real candidate** (hand-blend, Barbell_blend math
  confirmed by the timing run): beats both legs (w0.30 monthly 814%/0.572/29.9 vs
  engine 721/.496/43.8, SPY 629/.459/56.5), ROBUST to rebalance freq (daily 805/
  monthly 814/qtrly 779 — not a daily artifact), passes the fold grid. Gain = real
  diversification/vol-harvest premium from 2 anti-correlated +Sharpe assets.
- **BUT codebase has NO buy-and-hold strategy** (floor hardwired Spy_only_weinstein)
  → buy-hold variant NOT production-confirmed. NO ledger ACCEPT (avoid proxy
  overclaim). DECISION DEFERRED (user AFK): A=build buy-hold floor leg→confirm→ACCEPT
  +gated wire; B=barbell is DD-only overlay=not worth promoting. Faithfulness flag:
  passive SPY sleeve = portfolio overlay not a Weinstein mechanism (defensible: index
  in macro spine, but a real scope question). Engine here 0.14 conc; prod default 0.30.

---
**DECISION 2026-06-27 (user): Option B — BARBELL CLOSED.** User declined to build a
buy-hold SPY floor leg / add a passive SPY index sleeve (Weinstein-faithfulness: a
passive index allocation is portfolio construction, not a Weinstein stock-selection
mechanism). The barbell direction is CLOSED — do NOT re-propose the SPY-blend
(static or dynamic) without a fresh faithfulness decision. Ledger
2026-06-27-barbell-floor-sweep verdict=Reject. NET STANDING CONCLUSION of the whole
regime-edge investigation: the strategy is a regime-conditional crash-protector;
its bull-market under-participation is ACCEPTED AS-IS; no new strategy change
adopted. Short leg stays available (default-off tail-hedge); entry/exit-timing
levers dead. The 7-item investigation is closed.
