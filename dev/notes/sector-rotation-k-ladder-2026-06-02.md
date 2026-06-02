# Sector-rotation K-ladder — layer attribution (bull + deep)

**Date:** 2026-06-02 session. **Strategy:** `Sector_rotation_weinstein` (PR #1419) —
long/flat, holds the top-K Stage-2 SPDR sector ETFs ranked by RS vs SPY, per-symbol
Weinstein trailing stops, **no macro gate / no screener** (deliberately stripped to
isolate the *selection* layer). The multi-symbol generalization of SPY-only (#1397).

This is P0 of `next-session-priorities-2026-06-02-PM2.md` — the "sectors" rung of the
research ladder. Each K adds one knob so effect attributes to a layer.

## Result tables

Two windows, same configs. **Trustworthy metrics: total-return / Sharpe / MaxDD /
Calmar (NAV-curve, post-#1019 fix) and avg-win% / avg-loss% (per closed trade).**
Round-trip profit-factor and round-trip win-rate are distorted by large *open*
positions for the low-turnover runs (SPY-only holds one multi-year winner) — do not
rank on them.

### Bull-only (2009-06-01 → 2025-12-31)

| Strategy | Return | Sharpe | MaxDD | Calmar | win/loss size | Win% | Trips |
|---|--:|--:|--:|--:|--:|--:|--:|
| BAH-SPY | 619% | 0.77 | 34.0% | 0.37 | — | — | 0 |
| **SPY-only** (no selection) | 337% | 0.76 | **18.8%** | **0.48** | **7.5×** (24.5/−3.3) | 10% | 10 |
| Sector k=1 | 74% | 0.29 | 28.7% | 0.12 | 0.93× (3.3/−3.5) | 48% | 198 |
| **Sector k=3** | 440% | 0.74 | 28.3% | 0.36 | 1.53× (5.4/−3.6) | 43% | 290 |
| Sector k=4 | 203% | 0.52 | 28.1% | 0.23 | 1.71× (6.6/−3.9) | 37% | 301 |

### Deep (2000-01-03 → 2025-12-31, includes dot-com bust + GFC)

| Strategy | Return | Sharpe | MaxDD | Calmar | win/loss size | Win% | Trips |
|---|--:|--:|--:|--:|--:|--:|--:|
| BAH-SPY | 370% | 0.40 | **55.3%** | 0.11 | — | — | 0 |
| **SPY-only** (no selection) | 420% | 0.60 | **18.8%** | **0.35** | **7.6×** (24.0/−3.2) | 47% | 19 |
| Sector k=1 | −0.0% | 0.07 | 53.8% | −0.00 | 0.96× (3.4/−3.5) | 49% | 275 |
| **Sector k=3** | 528% | 0.56 | 32.3% | 0.23 | 1.55× (5.4/−3.5) | 43% | 429 |
| Sector k=4 | 216% | 0.38 | 30.1% | 0.15 | 1.73× (6.4/−3.7) | 41% | 442 |

(Deep window covers 9 of 11 ETFs from 1999; XLRE joins 2015, XLC 2018 via
`Daily_price.active_through`. No macro gate ⇒ no GSPC-golden-floor starvation.)

## What attributes to which layer — REGIME-ROBUST

**1. Drawdown defense comes from the index stage-timing (SPY-only), NOT from
selection.** SPY-only's MaxDD is **18.8% in BOTH windows** — it dodged the dot-com
bust *and* the GFC (BAH ate 55% there) and still out-returned BAH (420% vs 370%) on
the deep window. This is the Weinstein thesis working exactly as written: Stage-4
exits skip the deep bears. It is the most regime-robust number in the whole study.

**2. Sector selection buys RETURN + frequency, at a DRAWDOWN cost.** Going from 1
instrument (SPY) to top-K sectors *worsens* drawdown defense (MaxDD 18.8% → 28-32%,
Calmar 0.35-0.48 → 0.23-0.36) because sectors are more volatile than the index — even
Stage-2-timed, holding them through a bear incurs more DD than holding the smoothed
index. What selection adds is more trades, more total return, and a **regime-stable
~1.5× per-trade win/loss-size asymmetry** (1.53× bull, 1.55× deep at k=3).

**3. K=3 is the concentration sweet spot, in both regimes.** Calmar ordering is
identical bull and deep: **k=3 > k=4 > k=1**. k=3 sector rotation *dominates
buy-and-hold* on every risk metric in both windows (deep: Calmar 0.23>0.11, MaxDD
32<55, Sharpe 0.56>0.40, return 528>370). k=4 dilutes the return; k=1 is a disaster.

**4. K=1 sector rotation is DEAD — confirmed by the deep window.** Deep k=1: ~0%
return, 53.8% MaxDD, **negative** win/loss asymmetry (0.96×). A single rotating sector
churns (275 trips, ~44d holds) and gets shredded in bears. It is *not* the "closest
analog to SPY-only" we hoped — SPY-only wins because the *index* is a uniquely smooth
trender; no single rotating sector is. Do not revive K=1 sector rotation.

## Verdict against the LOCKED objective (drawdown-defense / win≫loss)

- **SPY-only (index stage-timing) is the drawdown-defense champion, robust across
  regimes** — Calmar 0.35-0.48, MaxDD 18.8% through two 50%+ bears, 7.5× win/loss
  asymmetry. By the locked objective it is the best single strategy found to date.
- **Sector k=3 is a strong, bankable RETURN engine** that beats buy-and-hold on every
  risk metric in both regimes, with a regime-stable 1.5× asymmetry and **zero
  penny-stock / liquidity risk** (clean ETFs) — unlike the 2026-06-02 top-3000 broad
  result, which was flattered by thin micro-cap fills. But it is *not* a
  drawdown-defense improvement over SPY-only; it trades DD for return.

The two are **complementary layers, not competitors**: SPY-only = DD floor; sector
k=3 = return/breadth. Neither dominates the other on all axes.

## Macro-gate result (#1422) — TESTED, and it works in both regimes

The macro gate (`enable_macro_gate`, default-off dial added in #1422) re-adds Weinstein
spine item 6: on any Friday where **SPY itself is in Stage 4**, no new sector entries
open and every held sector is force-flat. Ran it on sector-k3, both windows:

| sector-k3 | Return | Sharpe | MaxDD | Calmar | win/loss |
|---|--:|--:|--:|--:|--:|
| Bull gate-off | 440% | 0.74 | 28.3% | 0.36 | 1.53× |
| **Bull gate-ON** | 367% | 0.72 | **23.4%** | **0.40** | 1.59× |
| Deep gate-off | 528% | 0.56 | 32.3% | 0.23 | 1.55× |
| **Deep gate-ON** | 548% | 0.61 | **28.6%** | **0.26** | 1.64× |

- **Cuts MaxDD in both windows** (bull −4.9pp → 23.4%, deep −3.7pp → 28.6%) and **raises
  Calmar in both** (0.36→0.40, 0.23→0.26). Per-trade asymmetry improves slightly too
  (1.5→1.6×).
- **Deep window: a strict Pareto win** — *more* return (548>528), *less* DD (28.6<32.3),
  *higher* Sharpe (0.61>0.56). Bull: trades ~73pp return for the DD cut, net Calmar up.
- **It improves BOTH windows consistently** — the signature of a real effect, unlike the
  three rejected mechanisms (continuation / early-admission / hysteresis), each of which
  won one window and lost another. This is a strong ACCEPT candidate.
- **But it does NOT close the gap to the SPY floor (18.8%).** The gate narrows the excess
  DD by ~⅓-½, not all of it: sectors stay more volatile than the index because the gate
  only fires once SPY has *already* rolled to Stage 4 — sectors still draw down in the
  lead-in lag and within Stage-2/3 chop the index smooths over. Selection-volatility is
  intrinsic; the gate caps the tail, it doesn't erase the body.

**Promotion status:** this is 2 windows on ONE universe — not yet the ≥3-context grid
(`promotion-confirmation.md`) needed to flip a default. (The module is a testbed with no
production default to flip, so nothing is gated on it shipping.) Recommendation: **keep
the gate as a faithful dial and treat gate-ON as the preferred sector config** (Calmar
0.40 bull / 0.26 deep, the best sector numbers found); add a different-universe grid cell
before any cross-strategy promotion.

## SPY-core + sector-satellite barbell — TESTED (blend analysis), THESIS CONFIRMED
The gate caps the tail but can't reach the 18.8% floor (the floor comes from *being* the
index, not timing it). Tested the mechanical combination: a **50/50 continuously-
rebalanced blend** of the SPY-only floor + the gate-ON sector-k3 engine, by blending their
daily equity curves (no new module — the two sleeves were run separately and their NAV
series combined; `/tmp/blend.awk`, 50/50 daily-rebalanced).

| | Return | MaxDD | CAGR | Calmar | Sharpe |
|---|--:|--:|--:|--:|--:|
| **Bull** SPY-only | 322% | **18.8%** | 8.8% | 0.47 | |
| Bull sector-k3 (gate-on) | 339% | 23.4% | 9.0% | 0.38 | |
| **Bull BLEND 50/50** | **341%** | **19.8%** | 9.0% | **0.46** | 0.81 |
| **Deep** SPY-only | 420% | **18.8%** | 6.3% | 0.34 | |
| Deep sector-k3 (gate-on) | 551% | 28.6% | 7.2% | 0.25 | |
| **Deep BLEND 50/50** | **503%** | **22.2%** | 6.9% | **0.31** | 0.67 |

**The barbell is the best of both layers, regime-robustly:**
- It keeps ~the sector engine's **return** (bull 341% ≥ *both* sleeves via the rebalancing
  bonus of two low-correlation sleeves; deep 503%, capturing ~64% of the SPY→sector return
  uplift) while pulling **MaxDD most of the way back to the floor** (bull 23.4→**19.8%**,
  deep 28.6→**22.2%**).
- **Blend Calmar ≈ the SPY-only champion in both windows** (bull 0.46 vs 0.47; deep 0.31
  vs 0.34) **and beats sector-k3 in both** (0.38 / 0.25). The diversification works because
  the SPY core is defensive precisely when the sector sleeve chops — they don't draw down
  together.

This validates the whole layer story: **DD floor (SPY core) + return engine (gate-ON
sector-k3) compose into a strategy with the floor's risk profile and the engine's return.**

**Caveat:** continuously-rebalanced daily is an idealized upper bound (frictionless, no
rebalance cost). A real module would rebalance monthly/quarterly and capture most—not
all—of the benefit. The blend also assumes 50/50 fixed capital; a tuned weight (e.g.
60/40 core/satellite) is an open knob.

### → NEXT (supervised build): two-sleeve meta-strategy module
The blend is post-hoc; a live/backtestable version needs a **meta-strategy that runs both
sub-strategies on split capital**. The simulator runs ONE `STRATEGY` today, so this is a
design-heavy change — left for a supervised session. Build-ready spec:
- New `Barbell_strategy` (or `Blended_strategy`) implementing `STRATEGY`, parameterised by
  a list of `(weight, sub_strategy_choice)` and a rebalance cadence. It instantiates each
  sub-strategy with its slice of capital, routes `on_market_close` to each over a
  Portfolio_view *partition*, and merges their transitions. The hard part is capital
  partitioning + rebalancing across sub-portfolios within the existing single-portfolio
  simulator — decide whether to (a) run two simulators and blend NAV (cheap, matches this
  analysis, no intra-sleeve rebalance) or (b) a true shared-portfolio meta-strategy (real
  rebalancing, more faithful, more work). Recommend (a) first as a `Scenario`-level
  "blend" runner that post-processes two scenario NAVs — it reproduces this result exactly
  and is far cheaper than (b).
- Then sweep the core/satellite weight (50/50, 60/40, 40/60) on the bull+deep grid, and add
  a different-universe cell for the macro-gate promotion grid.

## Repro
Scenarios committed on main (#1419): `test_data/backtest_scenarios/sector-rotation-k{1,3,4}.sexp`
(bull). Deep variants + BAH baseline were ad-hoc (`_secrot_deep/`, start 2000-01-03);
re-derive by `sed`-ing the start date. Universe
`universes/spdr-sectors-11-plus-spy.sexp` (12 sym: 11 sectors + SPY benchmark, SPY not
traded). Run: `scenario_runner --dir <dir> --fixtures-root test_data/backtest_scenarios
--parallel 5 --no-emit-all-eligible`.
