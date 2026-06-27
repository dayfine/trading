# Regime-edge synthesis — what's most promising/valuable (2026-06-27)

> **OUTCOME UPDATE (2026-06-27):** the #1 recommendation below (static SPY-blend
> barbell) was deep-verified (`barbell-deep-verification-2026-06-27.md`) and then
> **DECLINED by the user (Option B)** — the Sharpe-improving version needs a
> passive SPY buy-hold sleeve, which is portfolio construction, not a Weinstein
> mechanism (`weinstein-faithful-core`). **No new strategy change adopted.** The
> standing conclusion: the strategy is a regime-conditional crash-protector and
> its bull-lag is accepted as-is. Read the rankings below as the *analysis*; the
> *decision* is no-change. Ledger: `2026-06-27-barbell-floor-sweep` = Reject.

**Mandate:** go through all four investigation threads
(`next-session-priorities-2026-06-27.md`), then **synthesize and rank** what's
most promising. Analysis session — the one recommendation it lands on is stated
as a *direction to validate*, not a committed build (still goes through
default-off → WF-CV → bear-inclusive grid before any default flips).

Companion note (Thread-A primitives, per-year table, detectability):
`dev/notes/regime-edge-understanding-2026-06-27.md`. This note adds the decisive
**static-vs-dynamic barbell** experiment, Threads B/C/D, and the ranking.

---

## TL;DR — the ranked answer

1. **MOST PROMISING — a *static* engine+SPY blend (~30% SPY / 70% engine).** On a
   consistent daily price-only basis (1998-2026) it **beats both pure legs in
   return AND cuts drawdown by a third AND lifts Sharpe** — genuine
   diversification from engine/SPY regime anti-correlation, needing *no* regime
   timing. Mature infra already exists (`Barbell_config`, floor-weight sweep) and
   a static 70/30 already cleared a promotion grid. This is the rare lever that
   is *not* a fat-tail tax (`project_edge_is_the_fat_tail`): it adds an
   offsetting return stream rather than touching the engine's winners.
2. **RESOLVED & DEMOTED — the *dynamic* regime-switched barbell.** The
   priorities-doc's +1295% annual MA-barbell does **not** survive an
   apples-to-apples test: the annual switch underperforms the simple static
   blend, and the switch's value is wildly cadence-sensitive (daily dead, monthly
   great, annual meh) — the overfit/path-luck signature. The 2026-06-21 finding
   "fixed light floor beats regime-timing the weight" is **vindicated**.
3. **DEAD LEVERS (confirmed, stop proposing):** entry/exit decision-timing.
   Give-back is large but structural; cash-allocation *order* is already ~optimal;
   bull-lag is structural under-participation, not bad picks. The only deployment
   lever is *how much* capital/SPY to hold — which is the barbell (#1).
4. **KEEP short leg ON, but DROP the macro-*conditional* framing (#5).**
   **CORRECTED on broad top-3000** (the sp500-515 result below was a survivorship
   artifact): shorts net **+$554k** and the armed long-short **dominates long-only
   on all 3 axes** (return +774 vs +721, Sharpe 0.53 vs 0.49, MaxDD 41.5 vs 43.8).
   Shorts pay in *both* regimes (bear +$205k, bull +$349k), so you can't macro-gate
   them — but ~100% of the net is 2 crash-ride fat-tail trades, so it's a sparse
   tail-hedge, not steady alpha. See `barbell-deep-verification-2026-06-27.md` Part 2.

---

## The decisive experiment: static vs dynamic barbell (resolves a contradiction)

Two internal analyses disagreed:
- **2026-06-21** (`dev/backtest/engine-edge-1998-2026/FINDINGS.md`): "the edge is
  100% crash-protection; a fixed 70/30 is optimal in neither regime; **regime-
  timing the weight is the known-dead lever** → deploy a *fixed* light floor 0.30-0.40."
- **2026-06-26** (`next-session-priorities-2026-06-27.md`): a *dynamic* annual
  MA-barbell (bull→SPY, bear→strategy) compounds **+1295%**, beating both pure legs.

I reproduced the blend apples-to-apples on the committed long-only deep engine
curve (`scenarios-2026-06-27-034110/sr-broad-top3000-1998-longonly/equity_curve.csv`,
+721% price-only) vs SPY price-only, regime = SPY > trailing 150-day SMA (≈30wk),
**lagged one trading day (no lookahead)**. Constant-weight blend = `blend.awk`;
dynamic = switch the engine/SPY allocation by the lagged regime at a given cadence.

| strategy | totRet% | Sharpe | MaxDD% | Calmar | Ulcer | avg SPY wt |
|---|---|---|---|---|---|---|
| engine (pure) | 721 | 0.496 | 43.8 | 0.177 | 14.0 | 0.00 |
| SPY buy-hold | 629 | 0.459 | 56.5 | 0.129 | 17.6 | 1.00 |
| **static 30% SPY** | **805** | **0.568** | **29.4** | **0.276** | 10.2 | 0.30 |
| static 50% SPY | 807 | 0.577 | 37.7 | 0.215 | 9.9 | 0.50 |
| static 70% SPY | 763 | 0.546 | 45.4 | 0.174 | 11.9 | 0.70 |
| dyn switch — **daily** | 329 | 0.415 | 36.3 | 0.146 | 12.0 | 0.69 |
| dyn switch — **monthly** | 1077 | 0.631 | 37.7 | 0.241 | 14.6 | 0.69 |
| dyn switch — **annual** (priorities-doc) | 749 | 0.528 | 38.0 | 0.207 | 11.6 | 0.75 |
| dyn annual, soft (70/30 ↔ 30/70) | 817 | 0.587 | 31.9 | 0.256 | 9.6 | 0.60 |

**Readings:**
- **Static 30% SPY is the standout.** +805% > pure engine (+721%) AND > pure SPY
  (+629%), with MaxDD **29.4%** (vs 43.8 / 56.5) and the **best Calmar (0.276)**.
  Two anti-correlated positive-return streams (engine wins bears, SPY wins bulls)
  blended → higher return *and* lower risk. No timing, no signal, no whipsaw.
- **The dynamic annual switch (749 / 0.528) underperforms the static blend
  (805 / 0.568).** The priorities-doc's +1295% was a *basis artifact* (dividend-
  adjusted SPY + per-year compounding + a different engine return); on a
  consistent basis the annual switch is *worse* than holding a fixed 30% SPY.
- **Dynamic timing is fragile, not additive.** daily 329 → annual 749 → monthly
  1077 is non-monotonic and wildly cadence-sensitive. A real edge does not flip
  from worst-of-class to best-of-class as you change the rebalance period; this
  is path-luck. Monthly also assumes costless full-portfolio rotation (12×/yr) —
  real slippage would erode it. **Not promotable.**
- **So: capture the diversification *statically*; do not chase regime-timing.**
  This unifies the two docs — the *diversification* both saw is real and bankable;
  the *timing refinement* is the mirage. (Consistent with
  `project_next_lever_decision_grading`: "regime-gating = SPY-timing, worse.")

### Sub-window robustness — the static blend is regime-STABLE (the clincher)

Same blend on two disjoint windows (the split the 06-21 doc used):

| | 1998-2008 (crash decade) | | | 2009-2026 (bull decade) | |
|---|---|---|---|---|---|
| strat | ret% | Sharpe | MaxDD% | ret% | Sharpe | MaxDD% |
| engine | 205 | **0.651** | 31.6 | 169 | 0.400 | 43.8 |
| SPY buy-hold | −8 | 0.075 | 51.8 | 689 | **0.757** | 34.1 |
| **static 30% SPY** | 129 | **0.560** | 28.3 | 296 | **0.573** | 28.9 |
| static 40% SPY | 105 | 0.500 | 31.8 | 345 | 0.627 | 26.6 |

The point: **static30's Sharpe is ≈0.56 in the crash decade AND ≈0.57 in the bull
decade** — and MaxDD ≈28-29% in both. The two pure legs are each regime-*unstable*
(engine 0.65→0.40, SPY 0.08→0.76); the blend converts them into one regime-*stable*
stream that is good in both. This is exactly the diversification mechanism, and it
holds on *disjoint* sub-windows — far stronger evidence than the cadence-fragile
dynamic switch. It directly answers the 06-21 doc's "optimal in neither regime"
worry: the *fixed* blend isn't trying to win either regime outright, it's
maximizing risk-adjusted return *across* regimes, which it does stably.

Caveats (`mechanism-validation-rigor`): two-window split, not full WF-CV; my
SPY-timing floor reconstruction is cruder than the production `Spy_only_weinstein`
leg (so absolute cross-doc numbers don't reconcile — the *within-series relative*
ranking is the robust object). The static blend's robustness rests on a
*mechanism* (regime anti-correlation), not a fitted parameter, which is why it is
far more likely to survive WF-CV than any timing rule. Promotion still requires
the bear-inclusive confirmation grid.

---

## Thread A — regime edge (linchpin) — see companion note for full detail
- Bear-edge **broad** (all 6 down-SPY years positive, mean +20.8pp; corr(edge,SPY)=−0.59).
- Bull-lag **structural under-participation** (≤70% equity cap + 68%-stop whipsaw),
  not losses. Bimodal: wins post-bear dawns, loses mature melt-ups.
- The barbell experiment above is the actionable conclusion of Thread A.
- **sp500-515 independence check (re-ran, CSV mode):** the regime structure
  replicates on a different universe. Bear years (SPY<0): all 5 positive edge
  (2001 +12.1, 2002 +17.5, 2008 +30.7, 2018 +9.5, 2022 +10.2), mean **+16.0pp**.
  Bull years (n=21): mean **−6.2pp**. **corr(edge, SPY) = −0.735** (even stronger
  than broad's −0.59). Bull-lag is *sharper* here in the 2019-2025 mega-cap melt-up
  (2019 −35, 2021 −28, 2023 −29, 2024 −28). sp500 total +960% / Sharpe 0.74 / MaxDD
  25.6% (higher than broad — survivorship-tinted — but the *regime signature* is
  what replicates). The bear-edge is **not** a top-3000 artifact.

## Thread B — decision quality — DEAD LEVER (confirms priors)
From the committed `trade_audit.sexp` (1288 trades, MFE/MAE populated):
- **Give-back** (peak MFE − realized): ALL trades avg **+2.5% realized of a +12.9%
  peak = 10.3pp give-back**; winners reach +29% peak, exit +16% (capture ~56%);
  laggard 11.8pp, stop_loss 9.7pp. Large — but it is the structural let-winners-
  run + stop-discipline tax that prior WF-CV rejections (weekly-close stop,
  harvest-rotate, stage2-ma-hold) already show **no knob captures net**. Not a lever.
- **Cash-rationing:** **1278 / 1318 entry decisions (97%) were cash-constrained**
  — 16,250 A/B candidates skipped for `Insufficient_cash`. The strategy sees far
  more qualifying breakouts than it can fund (vivid confirmation of the cash-cap
  under-participation in A.1).
- **Allocation *order* is already ~optimal:** in only 13% of decisions did a
  cash-rejected candidate out-score the taken trade; 84% take the ≥-top candidate
  — and score is anti-predictive there anyway (`project_cascade_selection_inversion`).
  Re-ordering is dead.
- **Conclusion:** the binding lever is capital-deployment *volume* (cash floor /
  concentration), not which name or when. That lever **is** the barbell (#1) — how
  much to hold in the engine vs an offsetting leg. Thread B converges on Thread A.

## Thread C — short leg under the regime lens
> **SUPERSEDED — see `barbell-deep-verification-2026-06-27.md` Part 2.** The
> sp500-515 result below was a **survivorship artifact**. On broad top-3000
> (the correct universe) shorts net **+$554k** and the armed long-short
> *dominates* long-only on return + Sharpe + MaxDD; shorts pay in both regimes
> (bear +$205k / bull +$349k). **Keep the short leg on; drop only the
> macro-*conditional* framing** (can't gate trades that pay in both regimes and
> whose wins are crash-rides opened in bulls). The text below is retained for the
> record but is corrected by the broad run.

sp500-515 long-short (margin-on, re-ran): the short leg fired only **30 times in
26 years** (vs 901 longs), total P&L **−$640k** (a loss; longs +$12.3M). By regime:
- **Bears:** 2002 +$35k (4/5 wins) is the *only* paying bear; **2008 LOST −$52k**
  (1/3 wins — shorts got run over in the GFC's V-recoveries); 2001 −$7.5k; 2018 &
  2022 took *zero* shorts. Net bear short P&L ≈ **−$25k**.
- **Bulls:** dominated by idiosyncratic outliers (2009 +$343k, 2015 +$639k, 2024
  −$962k, 2016 −$252k), not a systematic edge.
**The precondition "shorts pay in bears" FAILS**, and n=30 is far too few to time
by regime regardless. Combined with the broad result (long-only +721% ≈ liquidity-
armed long-short +774%, `DEEP_RESULTS.md`), the short leg is not a regime lever.
**Drop the macro-conditional long-short direction (#5).** Caveat: sp500-515 is
survivorship-tinted (fewer shortable losers survive); a broad top-3000 bear
decomposition would have more short targets — but the 2008 loss here (shorts lose
in a fast crash) and the broad net-zero already point the same way. Re-confirming
on broad needs a warehouse rebuild — **deferred** as not cost-effective given the
strong directional signal.

## Thread D — operational / docs (delivered)
- **#7 margin-safety doc** — written: `docs/design/margin-safety.md` + a README
  summary section. Maps every control (Reg-T 150% collateral, FINRA maintenance,
  50bps borrow, $17 short floor, force-liq/halt, liquidity overlay) to broker rules.
- **#6 universe-vs-gate liquidity consistency** — audited: the broad PIT top-3000
  is built by liquidity **rank** (top-N by 60d $-volume) + optional `min_price` /
  `min_avg_dollar_volume` floors, **not** an absolute $-ADV standard equal to the
  overlay's `min_entry_dollar_adv`. With the overlay off (default) the backtest
  admits names the armed-live strategy would gate out, especially in early years.
  Fix (single-source-of-truth preferred): always-arm the entry gate, or add a
  matching universe $-ADV floor. (Recorded in margin-safety.md §5.)

---

## What to do next (for the user — pick one; all are validate-not-build)
- **A (recommended): take the static ~30% SPY barbell into the validation
  pipeline.** Use the existing `Barbell_config` / floor-weight sweep; run the
  bear-inclusive confirmation grid (must span 2000-02 + 2008) on the floor-weight
  surface {0.2, 0.3, 0.4}. The mechanism (anti-correlation) is robust; this is the
  highest-probability promotion the program has had. Note: prefer SPY *buy-hold*
  as the bull leg over the SPY-timing floor — my test shows buy-hold gives better
  return/DD (the timing floor's cash-in-bear is redundant with the engine's own
  bear defense).
- **B: drop the dynamic regime-switch direction.** Resolved as a basis
  artifact + cadence overfit; not worth a build.
- **C: keep short leg ON (corrected on broad).** Armed long-short dominates
  long-only on return + Sharpe + MaxDD (+$554k, both regimes). It's a sparse
  fat-tail tail-hedge (~all net = 2 crash-ride trades), not steady alpha — keep it
  available, don't over-tune it, and drop only the macro-*conditional* (#5) framing.
- **D: ship the docs** — margin-safety doc + README done; fix the universe-vs-gate
  liquidity consistency (always-arm the entry gate) as a small follow-up.

## One-line bottom line
The strategy's edge is regime-conditional crash-protection (broad, corr −0.6 to
−0.7), and the highest-value, most-robust way to use it is the simplest:
**blend ~30% SPY into the engine as a fixed sleeve.** It beats both pure legs and
is the only Weinstein-faithful lever that diversifies the fat tail instead of
taxing it. Dynamic regime-timing and the short leg are both demoted by the data.
