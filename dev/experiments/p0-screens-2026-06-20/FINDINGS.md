# P0 lens-screens — FINDINGS (in progress)

Deep 1998-2026 top-3000 PIT-1998 Cell-E. Grade horizon 26w. See `PLAN.md`.
Batch run output: `dev/backtest/scenarios-2026-06-20-062510/`.
**Status: COMPLETE. Both levers → NO-BUILD (keep default-off as axes).**

## Baselines (graded; reused from prior sessions)

### P0b vol-scaled-stop baseline (mult=0, OFF) — long-only deep `scenarios-2026-06-18-232354`
Top-level: return **+1934.5%** · CAGR 11.22 · Sharpe **0.61** · MaxDD **48.65** ·
Calmar 0.23 · Ulcer 15.82 · 1061 round-trips · win 33.0% · final PV $20.3M.
`stop_loss` insurance (n=746): upside-foregone **+29.9%** vs disaster-dodged
**−19.5%** → net value-add **−6.2%**, dodge-rate 36%. *This asymmetry (forgoes
1.5× more than it saves) is the whipsaw the vol-scaled stop must shrink.*

### P0a short-sleeve baseline (fraction=0, OFF) — long-short deep `scenarios-2026-06-19-065941`
(short_side ON, margin ON, short_min_price 17 — only `short_sleeve_fraction`
differs in variants.) Top-level: return **+1662.9%** · CAGR 10.66 · Sharpe
**0.57** · MaxDD **36.87** · Calmar **0.29** · Ulcer 14.42 · 1164 round-trips ·
win 32.3% · final PV $17.6M.
*Note: the unfunded short leg (37 shorts reached / 28y) already trades return
(1934→1663) + Sharpe (0.61→0.57) for MaxDD (48.65→36.87) + Calmar (0.23→0.29) vs
long-only. P0a question: does FUNDING the sleeve extend that DD-offset, or churn?*

## P0b — vol-scaled stop variants (vs volstop-OFF baseline)

| mult | return% | CAGR | Sharpe | MaxDD | Calmar | Ulcer | n stops | stop upside-foregone | stop disaster-dodged | stop net-VA |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 (base) | 1934.5 | 11.22 | 0.61 | 48.65 | 0.23 | 15.82 | 746 | +29.9% | −19.5% | −6.2% |
| 1.0 | **820.4** | 8.15 | 0.47 | 40.60 | 0.20 | **22.24** | 643 | +268%* | −19.9% | −16.2% |
| 1.5 | **1206.2** | 9.50 | 0.56 | 32.25 | **0.29** | **13.57** | 527 | +183%* | −20.5% | −7.6% |
| 2.0 | **241.6** | 4.43 | 0.34 | 35.92 | 0.12 | 16.60 | 465 | +218%* | −19.2% | _ |

### P0b VERDICT — NO-BUILD (keep default-off as axis)

Every mult **reduces return** vs baseline (1934 → 820 / 1206 / 242) and **lowers
Sharpe** (0.61 → 0.47 / 0.56 / 0.34); the outcome is **non-monotonic** (1.0 bad,
1.5 best-ish, 2.0 catastrophic) = path-dependent, not a stable response surface.
The widening floor *does* fire fewer stops monotonically (746→643→527→465) — the
mechanic works — but it does **not** fix the whipsaw the screen targeted:

1. **Per-decision stop quality got WORSE, not better.** The lens's core question
   was "does upside-foregone shrink while disaster-dodged holds?" Answer: NO.
   stop_loss net value-add **worsened** (−6.2% → −7.6% at mult=1.5); disaster-
   dodged barely moved (−19.5→−20.5); upside-foregone means are outlier-blown
   (+183/+218%, but p90 cont +44/+41.6 ≈ baseline +41.4 — body unchanged). Same
   asymmetry the weekly-close #1655 lever also failed to fix.
2. **mult=1.5's DD "win" is just less risk-taking, not a free lunch.** Calmar
   0.29 / Ulcer 13.6 / MaxDD 32.3 all beat baseline — but bought with **−38% of
   total return** and a **lower Sharpe**. On the scale-free risk-adjusted measure
   it is worse; the smoother equity is the mechanical result of holding fewer
   stops and taking less risk, obtainable more cleanly via exposure/sizing.
3. **Same fat-tail tax** (`project_edge_is_the_fat_tail`): a wider stop holds
   losers deeper (mult=1.0 Ulcer ↑ to 22.2) and perturbs winner capture; the
   strategy's edge is the let-winners-run tail, and a structural stop-widening
   knob taxes it. Non-monotonicity is the signature.

**Decision:** no-build (do not escalate to WF-CV). Keep `vol_scaled_stop_atr_mult`
default-off as an axis. The stop-whipsaw problem is real but neither weekly-close
(#1655) nor vol-scaling fixes the per-decision asymmetry — the foregone upside is
the fat-tail recovery itself, so any stop that fires less still gives it up when
it does fire. The honest read: **the strategy's stop cost is structural, not a
tuning miss.**

\* outlier-blown means (see mult=1.0 note); read distribution body (p90), not mean.

\* mean upside-foregone +268% is **outlier-blown** (a few post-exit moonshots);
the distribution body is ~unchanged (p90 cont +41.3 vs baseline +41.4) — read it
as not-robust, not a 9× real shift (`screen-rigor`: distribution not point-est).

**mult=1.0 read (clearly worse):** return **halved** (1934→820), Sharpe ↓
(0.61→0.47), Calmar ↓ (0.23→0.20), **Ulcer ↑** (15.8→22.2 = more time
underwater). n_stops dropped 746→643 (the wider ATR floor does fire less, as
designed) — but the wider stop **holds losers deeper** (Ulcer up) *and* disrupts
fat-tail winner capture (return halved). MaxDD nominally lower (48.65→40.60) but
that single-trough number is contradicted by the Ulcer/return collapse. Net: the
wider stop taxes the engine, exactly the `project_edge_is_the_fat_tail` failure
mode for a holding-discipline lever that loosens too far.

**Read:** does upside-foregone shrink while disaster-dodged ~holds, n_stops drop
(fewer whipsaws), and MaxDD/Calmar/Ulcer improve — distribution-robustly?

## P0a — short-sleeve variants (vs sleeve-OFF baseline)

| sleeve | return% | CAGR | Sharpe | MaxDD | Calmar | Ulcer | n short trades | short win% | short net PnL$ |
|---|---|---|---|---|---|---|---|---|---|
| 0 (base) | 1662.9 | 10.66 | 0.57 | 36.87 | 0.29 | 14.42 | 37 | _ | _ |
| 0.10 | **1477.9** | 10.23 | 0.55 | **38.79** | 0.26 | 15.47 | 36 | 30.6% | **−$676k** |
| 0.20 | **2018.9** | 11.38 | 0.63 | **31.05** | **0.37** | 12.41 | 37 | 21.6% | **−$424k** |
| 0.30 | **375.2** | 5.66 | 0.37 | 36.98 | 0.15 | 15.34 | 44 | 25.0% | **−$481k** |

### P0a VERDICT — NO-BUILD (keep default-off as axis)

The sleeve sweep is **wildly non-monotonic** — return 1663 (base) → 1478 (0.10) →
2019 (0.20) → **375 (0.30)** — with shorts **losing at every fraction**
(−$424k…−$676k, 21–31% win) and **never meaningfully unlocked** (36/37/37/44 vs
37 baseline). Three transferable conclusions:

1. **The crowd-out-by-cash diagnosis is wrong.** Funding a reserved short budget
   does not increase shorts reached. Shorts are gated by *candidate supply*
   (Stage-4 short signals + the `short_min_price 17` floor), not cash. The
   `project_short_funnel_crowded_out` "1662 offered / 37 entered" read mistook a
   supply ceiling for a cash ceiling.
2. **There is no offsetting leg to fund.** The short trades lose money in every
   cell, so reserving capital for them is pure drag — the (c) symptom, confirmed.
3. **Reserved cash taxes the fat-tail long engine.** The non-monotonicity is
   path-dependent perturbation of which/when longs are bought; at 0.30 the
   reservation starves the let-winners-run engine and return **craters to 375%**.
   This is `project_edge_is_the_fat_tail` again: a capital-reservation mechanism
   that pulls capital off the tail-generating longs taxes the tail. The 0.20
   "win" is a lucky path, not a robust edge.

**Decision:** no-build (do not escalate to WF-CV). Keep `short_sleeve_fraction`
default-off as an axis. The real short-side lever, if any, is *supply* (loosen
`short_min_price` / Stage-4 short admission), not cash budgeting — and even that
must first show shorts can be made *profitable*, which this screen says they are
not in the current config.

**sleeve=0.20 read (better top-level, but NOT from shorts):** return 2019,
Sharpe 0.63, MaxDD 31.1, Calmar 0.37 — beats both the sleeve-OFF baseline AND
long-only. BUT shorts **still lose** (37 shorts, 21.6% win, −$424k) and **still
only 37 reached** (sleeve does not unlock more shorts at any fraction tested).
So the improvement is **not** the short leg paying off — it's a cash-drag
side-effect: reserving 20% cash reshuffles which/when longs get bought in a
fat-tailed book. **Non-monotonic** vs 0.10 (worse) → path-dependent artifact, not
a robust edge (`screen-rigor`: distribution/robustness, not one path). The
mechanism's stated thesis (shorts add an offsetting leg) is contradicted at every
fraction.

**sleeve=0.10 read (worse on every axis):** return ↓ (1663→1478), Sharpe ↓
(0.57→0.55), MaxDD ↑ (36.9→38.8, *worse* DD), Calmar ↓ (0.29→0.26), Ulcer ↑.
Critically: **shorts reached did NOT increase** (36 vs 37) — funding the
reserved sleeve did not unlock more shorts, so the diagnosed "crowd-out by cash"
(`project_short_funnel_crowded_out`) is **contradicted**: shorts are gated by
candidate *supply* (Stage-4 short signals / short_min_price 17 filter), not cash
budget. The shorts that do trade **lose** (−$676k net, 30.6% win) → reserved
capital is pure drag with no offsetting payoff = the (c) symptom. Pending 0.20/0.30
to confirm the knob doesn't rescue it.

**Read:** with more shorts reached, does MaxDD drop further / Calmar rise (real
offset), or do shorts churn ~breakeven (reserved capital = drag → return falls
with no DD payoff)?

## Combined verdict — both P0 levers NO-BUILD

Neither lever earns a WF-CV surface. Both are **no-build decisions** (per
`screen-rigor`: a lens screen rejects *prioritization*, not the mechanism — both
stay default-off as axes; only WF-CV could "reject" them, and neither warrants
that spend given the screen).

**The shared why — both re-derive `project_edge_is_the_fat_tail`:**
- **Short sleeve** reserves capital *away from* the tail-generating long book for
  a short leg that loses at every fraction and is supply-gated (never unlocked).
  Capital pulled off the tail = tax on the tail (return craters at 0.30).
- **Vol-scaled stop** widens the stop floor, which holds losers deeper and
  perturbs winner capture; it reduces return at every setting and doesn't fix the
  per-decision whipsaw — because the foregone upside *is* the fat-tail recovery.

Both are **winner/loser-touching mechanisms** — the class
`edge_is_the_fat_tail` says keeps getting rejected. This is the 7th/8th
re-derivation. **Forward guidance:** stop screening capital-reservation and
stop-widening levers; the live class remains **diversification LAYERS that don't
touch the long tail** — the P1 barbell (SPY-timing floor + Cell-E engine NAV
blend, `project_barbell_on_stocks`) is the next lever, taken to a promotion grid.

**Two corrections to standing beliefs, recorded:**
1. `project_short_funnel_crowded_out` mis-diagnosed a *supply* ceiling as a
   *cash* ceiling. Shorts are gated by Stage-4 signal supply + `short_min_price`,
   not budget — funding a reserved sleeve does not unlock more shorts.
2. The stop-whipsaw cost (`project_weekly_close_stop_lever`) is **structural, not
   a tuning miss** — two faithful stop dials (weekly-close, vol-scaled) both fail
   to improve the per-decision asymmetry. The foregone upside is the recovery
   itself.
