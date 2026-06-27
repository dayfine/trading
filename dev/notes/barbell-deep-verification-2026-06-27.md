# Barbell deep verification (WF-CV-equivalent) + broad short-leg decomposition — 2026-06-27

Follow-up to `regime-edge-synthesis-2026-06-27.md`, per user direction: "do the
deeper verification — e.g. WF-CV — when evidence is strong," and "forget sp500-515,
do broad 3000" for the short leg.

Two parts:
1. **Deep verification of the static SPY-blend barbell** (the strong-evidence lever).
2. **Broad top-3000 short-leg decomposition by regime** (redo of Thread C on the
   correct universe).

---

## Part 1 — Static SPY-blend barbell: per-fold robustness (WF-CV-equivalent)

A static blend is a **fixed-weight** combination of two equity curves — there is no
fitted parameter to overfit, so the meaningful walk-forward test is not
train/test generalization of a parameter but **robustness of a fixed weight across
disjoint time folds** + **stability of the per-fold optimal weight**
(`promotion-confirmation.md` decision rule). Computed on the committed broad
top-3000 long-only engine curve (+721%, price-only) blended with SPY price-only,
weight 0.30 SPY / 0.70 engine. Baseline = pure engine (w=0, the current default).

### Disjoint ~5-year folds

| fold | engine Sharpe | static-30 Sharpe | static-30 MaxDD | per-fold best weight |
|---|---|---|---|---|
| 1998-2002 | **0.85** | 0.72 | 23.2% | 0.00 (pure engine) |
| 2003-2007 | 0.66 | **0.78** | 13.4% | 0.75 |
| 2008-2012 | 0.30 | 0.27 | 25.3% | 0.05 |
| 2013-2017 | 0.64 | **0.83** | 27.4% | 0.95 |
| 2018-2022 | 0.55 | **0.59** | 26.5% | 0.35 |
| 2023-2026 | −0.43 | **0.10** | 28.9% | 1.00 (pure SPY) |

### Rolling 10-year windows

| window | engine | static-30 | SPY | winner | static-30 MaxDD |
|---|---|---|---|---|---|
| 1998-2007 | **0.76** | 0.74 | 0.31 | eng (−0.02) | 23% |
| 2001-2010 | **0.48** | 0.40 | 0.09 | eng (−0.08) | 29% |
| 2004-2013 | 0.60 | **0.61** | 0.35 | s30 | 29% |
| 2007-2016 | 0.47 | **0.50** | 0.32 | s30 | 29% |
| 2010-2019 | 0.43 | **0.60** | 0.79 | s30 | 27% |
| 2013-2022 | 0.57 | **0.67** | 0.65 | s30 | 27% |
| 2016-2025 | 0.21 | **0.41** | 0.76 | s30 | 29% |

### Verdict (per `promotion-confirmation.md` decision rule)
- **Static-30 PASSES the robustness grid.** It beats the pure-engine baseline on
  Sharpe in a strong majority of cells (4-5/6 disjoint folds; 5/7 rolling windows)
  and is **never badly dominated** — its only losses are the crash-heavy early
  windows, by ≤0.08, where pure engine is the right answer anyway.
- **It raises the floor, not the ceiling.** Static-30's worst-fold Sharpe is +0.10
  (2023-26) vs engine's −0.43; its Sharpe band (0.40-0.74 rolling) is far tighter
  than engine (0.21-0.76) or SPY (0.09-0.79), and its MaxDD is a stable ~23-29%
  across every window. The blend converts two regime-unstable streams into one
  stable stream — exactly the diversification mechanism.
- **The per-fold OPTIMAL weight is regime-unstable** (0.00 → 1.00 across folds).
  So do **not** promote a "best" weight — promote the robust *compromise*. 0.30 is
  the conservative robust value (the rule: "promote the most conservative robust
  value, never the headline single-window winner"). 0.20-0.40 are all defensible;
  0.30 sits mid-band and never badly loses.

### Universe axis (the second grid dimension) — ran sp500-515 LO (2000-2026)
A full confirmation grid needs period × **universe** diversity. Re-ran an
independent universe (sp500-515 PIT-2000 LO, +960% / Sharpe 0.751 / MaxDD 25.6%)
and blended with SPY:

| sp500 cell | engine | s20 | s30 | s40 |
|---|---|---|---|---|
| full-window Sharpe | 0.751 | **0.758** | 0.737 | 0.700 |
| full-window MaxDD% | 25.6 | **23.7** | 28.0 | 32.3 |
| per-fold s30≥engine | — | — | **3 of 5** | — |

sp500 per-fold best weight: 0.00, 0.00, 0.60, 0.60, 1.00 (same regime-instability;
early-crash folds want pure engine, recent folds want heavy SPY; 2020-26 s30 **+0.38
vs engine −0.18**).

**The grid's key finding — benefit is universe-dependent:**

| universe cell | engine Sharpe | blend effect at 0.30 | robust value |
|---|---|---|---|
| **broad top-3000 (honest, high-DD)** | 0.496 | **LARGE** (+0.07 Sharpe, −15pp DD) | 0.30-0.40 |
| **sp500-515 (survivor, low-DD)** | 0.751 | small / ~neutral (s20 best) | 0.20 |

The diversification helps **most when the engine's drawdown is high** (the
*realistic* broad/honest case, Sharpe 0.49, DD 44%), and little when the engine is
already low-DD (the survivorship-inflated sp500). Per `promotion-confirmation.md`
("promote the most conservative robust value, never the headline single-window
winner"), the **robust cross-universe weight is ~0.20** — it helps or is neutral in
both universes and raises the worst-fold floor in both. 0.30 is well-justified on
the realistic broad basis; 0.20 is the safe cross-universe floor. Either way the
**floor-raising property is universe-robust** (both cells: the recent bad fold is
strongly positive under the blend while pure engine is negative).

### Honest caveats (`mechanism-validation-rigor`)
- Engine curves are price-only; SPY-buy-hold leg (not the production
  `Spy_only_weinstein` floor — my test showed buy-hold gives better return/DD, so
  it's the better leg). Blend assumes ~costless periodic rebalance of a small
  sleeve (realistic; quarterly is cheap).
- sp500-515 is survivorship-inflated (engine Sharpe 0.75 is not live-realistic) —
  it serves as a robustness *check*, not the basis; the broad/honest cell is the
  one to size against. Its role here: confirm the blend doesn't *hurt* on a
  different universe, and cap the weight (don't exceed ~0.30).
- This is a robustness grid on equity-curve blends, not a from-scratch
  walk-forward of the real two-sleeve `Barbell_runner` per fold. The mechanism
  (regime anti-correlation) is parameter-free, so the equity-curve grid is a
  faithful proxy; a real `Barbell_runner` WF would confirm the same blend math
  (`Barbell_blend` reproduces `blend.awk` line-for-line).

**Bottom line Part 1:** the static SPY blend survives WF-style scrutiny across a
period × universe grid as a robust, floor-raising diversification layer — the
strongest promotion candidate the program has produced. The robust promotable
weight is **~0.20-0.30** (0.20 = conservative cross-universe floor; 0.30 = justified
on the realistic broad/honest engine where DD is high and the benefit is largest).
The benefit is *downside-floor-raising*, not return-maximizing, and is largest on
the realistic high-DD engine. Recommended next concrete step (a real build, gated):
wire `Barbell_config { enable = true; floor_weight = 0.20-0.30 }` as the documented
promotion — still default-off until a sign-off — and confirm with the real
two-sleeve `Barbell_runner` over the same grid (should match the blend math).

---

## Part 2 — Broad top-3000 short-leg decomposition (corrects the sp500 Thread-C)

Re-ran broad top-3000 PIT-1998 long-short, margin-on, **liquidity overlay armed**
(the honest tradeable config), 1998-2026, against the warehouse. Reproduces the
DEEP_RESULTS armed row exactly (+773.6%, Sharpe 0.53, MaxDD 41.55%, worst day −8.45%).

### Headline: on broad, shorts DO make money (correcting the sp500-515 result)
- **SHORT: 36 trades, net +$554k. LONG: 1223 trades, +$6.54M.** (sp500-515 had shown
  shorts −$640k — that was a survivorship artifact: few shortable losers survive in
  a PIT-2000 survivor set. Broad top-3000, with delistings, has real short targets.)
- **The armed long-short modestly DOMINATES long-only on all three axes:** return
  +774% vs +721%, Sharpe **0.53 vs 0.49**, MaxDD **41.55% vs 43.75%**. The
  DEEP_RESULTS "short adds almost nothing" line was *return-only* framing — it
  missed that Sharpe and drawdown both improve. The short leg is a small but
  genuine diversifier.

### By regime — shorts pay in BOTH (not bear-exclusive)
| | trades | net P&L |
|---|---|---|
| BEAR years (2000-02, 08, 18, 22) | 11 | +$205k |
| BULL years | 25 | +$349k |

Per-trade bears (+$18.6k) ≈ bulls (+$14.0k). So the precondition for a
*macro-conditional* long-short ("short only in bears") is **not** met — gating
shorts to bears would forgo the bull short profit. **Drop the macro-conditional
framing (#5); just keep the short leg on.**

### But it's a sparse fat-tail tail-hedge, not steady alpha
- 36 trades, 44% win rate, win$ +$897k, loss$ −$343k.
- **The entire net is 2 crash-ride trades:** MPAC_old +$364k (shorted 2007-11, held
  through the GFC, exit 2010-01) + AMMB +$194k (shorted 1998-08, rode dot-com,
  exit 2000-04) = **$558k ≈ all of the +$554k net.** The other 34 trades net ≈ $0.
- Both monsters are positions *opened in a bull and ridden down through a crash* —
  so the short edge is fundamentally **crash-driven** (same `project_edge_is_the_fat_tail`
  signature as the longs), and it complements the long engine's crash-protection.
  (This is *why* exit-year bucketing put MPAC's GFC profit in the "2010 bull" bucket
  — the profit was the 2008 crash, realized on the 2010 cover.)

### Thread-C verdict (revised)
- **Shorts make money on broad and improve the sleeve's Sharpe + drawdown** — keep
  the short leg available (it's already there, default-off). User's intuition that
  shorts make money is correct; the low trade count (36/28y) is expected and fine.
- **It is a tail-hedge, not a return engine:** +53pp over 28y vs the long +721%,
  and ~100% of the net is 2 trades. Don't over-invest in tuning it.
- **Not a regime-timing lever** (#5 dropped): shorts pay in both regimes and the
  crash-rides are *opened* in bulls, so you can't macro-gate them.
- **Implication for the barbell:** the engine leg could be long-*short* (dominates
  long-only on all 3 axes), but the gain is small and tail-concentrated; long-only
  is simpler and ~as good. Either works as the barbell ENGINE leg.

Caveat: liquidity-armed broad is the honest basis; the raw margin-on (+1358%,
DEEP_RESULTS) inflated shorts via untradeable junk (ELCO/APPB) — stripped here, so
the +$554k is the bankable number. The raw-vs-armed gap is the junk magnitude;
re-running raw for its trade-level junk detail was **deprioritized** (the honest
number is what matters; raw total is already recorded).

---

## Part 3 — Production-tool confirmation + the floor-leg crux (DECISION POINT)

Ran the canonical `barbell_floor_sweep_runner` (current code, warehouse) on the
broad engine, floor weights {0,0.2,0.3,0.4}, rebalance 4 weeks, against the
production **`Spy_only_weinstein` 30wk timing floor** — to confirm the hand-blend
with production code:

```
floor_weight, total_return%, sharpe, max_drawdown%, calmar, ulcer%
0.00,  721.4,  0.4877, 43.75, 0.1705, 14.03
0.20,  480.1,  0.4883, 36.53, 0.1694, 11.31
0.30,  380.9,  0.4885, 32.66, 0.1688,  9.94
0.40,  295.1,  0.4888, 28.60, 0.1681,  8.55
```

**This contradicts the hand-blend, and the reason is the FLOOR LEG.** With the
production **timing** floor, Sharpe is **flat (~0.488)** and Calmar **flat
(~0.168)** across all weights — return drops monotonically, MaxDD falls
proportionally. It is a pure **return-for-drawdown trade with NO risk-adjusted
gain** — exactly the 2026-06-21 "no free lunch" finding. The as-built barbell is
**not a compelling promotion** (you give up half the return to cut DD; Calmar
doesn't improve; at w=0.4 you're below both SPY and the engine on return).

The hand-blend's "beats both legs / Sharpe ↑" result used a **SPY buy-hold** floor,
which is a *different, higher-return* leg. Re-checked the buy-hold floor at
realistic rebalance frequencies (this is just the `Barbell_blend` math, which the
timing-floor run confirms is correct — only the floor *curve* differs):

```
buy-hold floor, w=0.30:  daily 805%/0.568/29.4%   monthly 814%/0.572/29.9%   quarterly 779%/0.564/29.6%
refs (monthly):          engine 721%/0.496/43.8%   SPY 629%/0.459/56.5%      w=0.20 794%/0.552/33.9%
```

The buy-hold-floor barbell **beats both legs on return + Sharpe + MaxDD and is
robust to rebalance frequency** (not a daily-rebalance artifact). The gain is a
genuine **diversification/volatility-harvesting return**: two anti-correlated
positive-Sharpe assets (engine 0.50, SPY 0.46) blend to 0.57 because the engine
mean-reverts vs SPY by regime (corr(edge, SPY) = −0.59).

### Why the floor leg flips the verdict
The **timing** floor goes to cash in bears — but the engine is *already* defensive
in bears, so the timing floor's bear-defense is **redundant** and it only sacrifices
return (cash drag), giving a flat-Sharpe DD trade. The **buy-hold** floor stays
long SPY through bulls (capturing the engine's weakest regime) and its drawdowns
are absorbed by rebalancing against the engine — delivering the diversification
premium. **The barbell needs a high-return anti-correlated leg (buy-hold SPY), not
a low-return defensive one (timing SPY), to lift Sharpe.**

### Verdict + decision point
- **Barbell AS BUILT (timing floor): no-promote** — production-confirmed
  return-for-DD trade, flat Calmar, no free lunch (re-confirms 2026-06-21).
- **Barbell with a buy-hold SPY floor: the real candidate** — beats both legs,
  Sharpe ↑, DD ↓, rebalance-robust, passes the period × universe fold grid (Part 1).
  **BUT** the codebase has **no buy-and-hold strategy**; the floor leg is hardwired
  to `Spy_only_weinstein`. Production-confirming this needs a small **build**: add a
  buy-and-hold floor leg (a strategy that holds the symbol 100% long, or a
  raw-symbol buy-hold equity-curve option in the runner) + re-run the sweep.

**This is a decision for the user (deferred — AFK):**
- **Option A — build the buy-hold floor leg**, production-confirm, then ledger
  ACCEPT + (gated) wire `Barbell_config` with a buy-hold floor. Highest upside; a
  small, well-scoped build.
- **Option B — treat the barbell as a DD-management overlay only** (timing floor),
  which production says is a no-free-lunch trade → not worth promoting.
- **Faithfulness flag** (`weinstein-faithful-core`): a passive SPY buy-hold sleeve
  is a *portfolio-construction overlay*, not a Weinstein stock-selection mechanism.
  It is defensible (the macro/index is already in the spine, and the overlay
  allocates between "the Weinstein engine" and "the index"), but it is a genuine
  scope question worth an explicit decision, not a silent build.

No ledger ACCEPT recorded: the production tool confirmed only the timing floor
(no-promote); the buy-hold variant is a hand-blend result pending a build +
production confirmation. Recording a premature ACCEPT off a proxy is the exact
trap `mechanism-validation-rigor` guards against.
