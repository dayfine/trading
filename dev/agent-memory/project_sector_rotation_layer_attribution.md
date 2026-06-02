---
name: project_sector_rotation_layer_attribution
description: "Sector-rotation K-ladder + macro-gate results — what each strategy layer buys, regime-robust across bull+deep"
metadata: 
  node_type: memory
  type: project
  originSessionId: d9a90d10-0707-469f-8918-2f1f994527cf
---

Built `Sector_rotation_weinstein` (#1419, top-K Stage-2 SPDR sectors by RS vs
SPY, per-symbol stops) + a default-off `enable_macro_gate` dial (#1422). Ran the
K-ladder + gate grid on **bull (2009-25) AND deep (2000-25, incl dot-com+GFC)**.
Full writeup: `dev/notes/sector-rotation-k-ladder-2026-06-02.md`. Regime-robust
findings (LOCKED objective = drawdown-defense / win≫loss, NOT total return):

1. **Drawdown defense ⟸ index stage-timing (SPY-only #1397), NOT selection.**
   SPY-only MaxDD **18.8% in BOTH windows** (dodged both 50%+ bears; BAH ate
   34/55%), Calmar 0.35-0.48, 7.5× win/loss. The best single strategy by the
   objective. Robust. [[project_spy_reference_strategy]]
2. **Sector selection buys RETURN + frequency at a DD cost.** Sector-k3 beats
   BAH on every risk metric in both regimes (deep: Calmar 0.23>0.11, MaxDD
   32<55), regime-stable 1.5× asymmetry, ZERO penny-stock risk (clean ETFs,
   unlike the liquidity-flattered top-3000 [[project_composition_golden_survivor_bias]]).
   But DD 28-32% > the 18.8% SPY floor — selection is intrinsically more volatile.
3. **K=3 is the sweet spot** (Calmar k=3>k=4>k=1 in BOTH windows). **K=1 sector
   rotation is DEAD** (deep: ~0% ret, 53.8% DD, negative 0.96× asymmetry — churns,
   shredded in bears). Do not revive K=1.
4. **Macro gate (#1422) WORKS** — block buys + force-flat when SPY is Stage 4.
   Cuts sector-k3 MaxDD both windows (bull 28.3→23.4%, deep 32.3→28.6%), raises
   Calmar both (0.36→0.40, 0.23→0.26); deep = strict Pareto win (more ret + less
   DD + higher Sharpe). **Improves BOTH windows consistently** = a real effect,
   unlike the 3 rejected single-window mechanisms. Gate-ON k3 = best sector config.
   Does NOT reach 18.8% floor (gate fires only after SPY already rolled). Not yet
   promoted: needs a different-universe grid cell [[project_promotion_confirmation_grid]].

5. **Barbell CONFIRMED + weight-swept (#1424/#1426).** A continuously-rebalanced
   blend of SPY-only floor + gate-ON sector-k3 engine — the layers **compose**.
   Swept core weight: **70/30 (SPY-core/sector-sat) is the robust optimum and the
   best risk-adjusted config in the whole study.** Bull: 70/30 **strictly dominates**
   pure SPY-only (Calmar 0.488>0.467, MaxDD 18.4%<18.8%, ret 336%>322% — a
   diversification free-lunch from low-correlation sleeves). Deep: 70/30 matches
   pure-SPY Calmar (0.334 vs 0.337) while adding +54pp return for +1.3pp DD. The SPY
   core is defensive exactly when sectors chop → they don't draw down together.
   Caveat: continuously-rebalanced daily = idealized upper bound (free-lunch shrinks
   with rebalance friction).

**STOCK TRANSFER (2026-06-02, this layer story extended to individual stocks).** Ran
the production Weinstein strategy (full Cell E) on a clean, survivor-bias-free **PIT
S&P 500** (`universes/sp500-historical/`, Wikipedia membership-replay incl. index
exits, ~full bar coverage). Result, both regimes (raw close — strategy trades raw
close so BAH is raw too):
- **Selection transfers as a RETURN engine, NOT a risk-adjusted winner.** Bull
  2010-26: 237%/MaxDD 17.5%/Calmar 0.44. Deep 2000-26: **918%**/MaxDD 37%/Calmar 0.25.
- Deep selection DOMINATES buy-and-hold (918% vs BAH 394%, AND 37% DD < BAH's 56%) —
  selection adds a LOT of return. But it pays in drawdown (37% vs SPY-only's 18.8%):
  individual names crash harder than the index.
- **On Calmar (the locked objective), simple SPY index-timing wins BOTH regimes**
  (SPY-only 0.48/0.35 vs production 0.44/0.25). Same barbell decomposition as the
  ETFs: floor (index-timing) = bankable DD edge, selection = return engine on top.
  Return vs risk-adjusted is a MANDATE choice; barbell (~70/30) reconciles.
- CORRECTION banked: the old sp500-2010-2026 pin (341%/Calmar 0.52) was inflated by
  the GSPC-golden 2017-floor making the macro gate degenerate 2010-2017; #1380/#1383
  fixed it → corrected 237%. The golden's bands are STALE (re-pin needed). Local-only
  goldens drift silently. Full writeup: `next-session-priorities-2026-06-03.md`.

**SPY-only (DD floor) and sector-k3/production-selection (return engine) are
complementary layers that COMPOSE; 70/30 barbell is the best config found.**
NEXT P0 (SUPERVISED): a
two-sleeve meta-strategy module — simulator runs ONE STRATEGY today, so it's
design-heavy. Cheap path first: a Scenario-level NAV-blend runner at configurable
weight (reproduces the post-hoc result), target 70/30, re-confirm at monthly/
quarterly cadence + a different-universe cell for the macro-gate promotion grid.
Tool: `/tmp/blendw.awk` (throwaway). Spec in the k-ladder note §"NEXT (supervised build)".
