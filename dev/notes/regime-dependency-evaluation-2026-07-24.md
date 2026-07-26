# Regime-dependency evaluation (P1b) — decision memo (2026-07-24)

**Mandate** (`next-session-priorities-2026-07-23.md` §P1b, user-directed
07-24): after the M4 leverage REJECT's barbell-shaped fold table, evaluate
whether the system should be macro/regime-DIRECTED. Understanding-first —
read-only screens over existing outputs; no builds, no WF-CV runs. Output:
which payload (if any) earns a **designed** default-off WF-CV surface.

**Data bases:** M4 leverage-surface 13-fold table
(`.sweep-output/margin-m4-surface/walk_forward_report.md`, rolling 730d from
2000-01-01, f000=2000-01 … f012=2024-25/26); the 28y E-capped shorts-on arm
(`scenarios-2026-07-23-162636/top3000-2000-2026-m4p-ecap`, 47 short trades +
`macro_trend.sexp`); the 06-27 barbell adjudication
(`regime-edge-synthesis-2026-06-27.md`). Verdict calibration per
`mechanism-validation-rigor`: everything below is a **prioritization
decision on proxies**, not a mechanism rejection.

---

## 1. Impact screen — payload × regime-label sensitivity

Chained terminal wealth across the 13 folds (product of per-fold returns;
baseline chains to **35.4× ≈ 14.5%/yr**). "Lever" = the priced
`initial_long_margin_req 0.75` (1.33×) shorts-off cell; "shorts" = the
req=1.0 shorts-on cell.

### Payload (a) — regime-conditional leverage 1.33×

| label scenario | levered folds | terminal | vs baseline | maxDD inside levered folds |
|---|---|---:|---:|---:|
| always-on (the rejected cell) | all 13 | 139× | 3.9× | 66% |
| oracle, return-basis (hindsight bound) | f000,001,004,005,006,008,010 | 1,629× | **46.0×** | 64% |
| oracle, Sharpe-basis | f001,005,006,009 | 180× | 5.1× | 66% |
| **dawn label, realistic (incl. 2024 leak)** | f005,006,008,010,012 | 527× | **14.9×** | 64% |
| dawn label, perfect precision (no 2024) | f005,006,008,010 | 617× | 17.4× | 64% |
| dawn + back-half 2002-03 (upper bound) | +f001 | 1,233× | 34.8× | 64% |

The realistic lagging dawn label (time-since-MA-flip-up < ~1.5y, which
catches 2010/2012/2016/2020 but also flags the 2024 melt-up-lag fold) keeps
**~15× of the 46× hindsight bound**. The label-accuracy gradient is steep
but never kills it: even Sharpe-basis oracle (the most conservative
conditioning) is 5×.

**Deflators (all material):**
- **Concentration:** dropping f010 (2020-21, +643 vs +134) alone cuts the
  dawn scenario 14.9× → **4.7×** — one fold is ⅔ of the excess value. The
  levered payload is the same fat-tail concentration structure as
  everything else in this program; n(levered decisions) ≈ 4-6 over 26y.
- **Drawdown price:** levered folds carry 34-64% intra-fold MaxDD *even in
  winning eras* (f005: +17.9% return through a 64.3% DD). Chaining fold
  returns forgives what a continuous path would compound through. The
  investor of the 14.9× scenario lives through ≥ 3 drawdowns ≥ 50%.
- **Whole-fold label assignment:** the screen assigns labels at fold
  granularity; a real weekly signal flips mid-fold and would clip both the
  wins and the losses.
- **2024 falsifier cost:** the leak costs 15% of terminal (17.4→14.9×) in
  this assignment — tolerable *here*, but that is one label error; two
  2024-shaped errors in the next 26y land near the always-on profile.

### Payload (b) — short sleeve (cash-account; leverage-invariant per M4)

| scenario | terminal | vs baseline |
|---|---:|---:|
| always-on (shorts-on cell) | 48.6× | 1.37× |
| **bear-folds-only (f000, f004, f011 — macro-conditioned)** | 41.7× | **1.18×** |
| oracle (hindsight best 6 folds) | 75.0× | 2.12× |

Macro-conditioning the sleeve **destroys value relative to leaving it on**
(1.18× < 1.37×): the paying folds are NOT the bear folds — f007 (2014-15,
commodity/energy Stage-4 collapse, Sharpe +1.12) is the biggest fold win,
while f011 (2022-23 bear) the sleeve *loses* (−.123 Sharpe). This
re-derives the 06-27 Thread-C correction ("shorts pay in both regimes —
can't macro-gate them") on the new promoted-bundle basis.

### Payload (c) — SPY-vs-strategy switch

Already adjudicated 2026-06-27 (`regime-edge-synthesis-2026-06-27.md`): the
+1295% dynamic barbell was a **basis artifact** (dividend-adjusted SPY +
per-year compounding); apples-to-apples the annual switch (749%/0.528)
underperforms a static 30% SPY blend (805%/0.568), and cadence sensitivity
(daily 329 / monthly 1077 / annual 749) is the overfit signature. The
static blend was user-DECLINED (not a Weinstein mechanism). Nothing in the
M4 table reopens this: it is the same lagging-signal family as (a) but with
a far smaller payload (switching un-levered legs ≈ Sharpe-basis oracle at
best). **Stays dead.**

---

## 2. Macro-directed shorts (user sketch: "more / more-aggressive shorts when bearish")

Screened on the 28y shorts-on path (47 short trades) joined to
`macro_trend.sexp` state at entry:

1. **No admission headroom.** 45/47 shorts already enter macro-Bearish;
   the only Neutral entry is the LH phantom (#2059). The binding
   constraint on short admission is **Stage-4 supply + the $1M borrow-ADV
   gate**, not macro state — macro-Bearish and Stage-4-supply-exists are
   nearly the same event. A macro gate (e.g. `neutral_blocks_shorts`)
   would have changed ~1 trade in 26 years; "more shorts when bearish"
   has nothing to unlock on the admission side.
2. **Realized sleeve value is one window.** Clean short P&L (excluding the
   two multi-decade phantom rows, LH −$388k / FARM +$350k — the #2059
   family, which roughly cancel): **+$144k realized over 28y**, win-rate
   13/45, fat-right-tail. By era: **+$428k in f000 (2000-01)** landing on
   ~$1M equity — a ~30-40% equity boost at the compounding root that
   accounts for essentially all of the E-capped arm's MTM gap over
   long-only — and **≈ −$285k net across everything after 2002**. Short
   admission ≈ 0 after 2016 on this path (2 trades 2018-19, none after
   2019-06).
3. **Fold-level short signal is path-reshuffle chaos, not short P&L.**
   The fold deltas sign-invert against the path: f007's +40pp/+1.12-Sharpe
   fold win coincides with the path's shorts *losing* −$136k in 2014-15,
   and f003's −.944 fold loss with the path's shorts *making* +$157k in
   2006-07. With 2-6 shorts per fold and fresh-$1M fold portfolios, the
   deltas are dominated by funding displacement and admission-context
   differences (the cash-reserve "funding-reshuffle chaos" mechanism), so
   the 6/13 shorts-on fold wins cannot be read as hedge attribution.
4. **"More aggressive" = sizing,** and the built inventory already
   expresses every version of the idea as default-off axes:
   `neutral_blocks_shorts` (#1696), the slow-grind gate,
   `fast_v_arm_on_rate_alone` (#1708), M3a borrow gate + maintenance/HTB
   tiers, M3b buy-in stress. Nothing new needs building to test it — and
   the screen says the surface isn't worth running: the mechanism's
   validating events (deep slow-grind bears with short supply) occur ~once
   per 26y sample. Power is unattainable (same structure as the
   extension-stop screen's "~1%/26y = WF-CV powerless" finding).

Item 3 of the mandate (proceeds caution) is confirmed RESOLVED: M4
certified `margin_config.enabled` locks short proceeds as 150% collateral;
any future short config runs margin-armed by convention.

---

## 3. Decision

- **Payload (a) — regime-conditional leverage — EARNS a designed surface
  (the only one).** Disposition exactly as the M4 addendum sketched:
  default-off regime-conditional `initial_long_margin_req` axis on the
  lagging dawn signal (MA-flip-up age), WF-CV + bear-cell confirmation
  grid, **2024 melt-up-lag fold as the named falsifier**. Two design
  constraints from this screen: (i) the surface must include a
  milder rung (e.g. req 0.85-0.90) because the 1.33× DD price (≥50%
  intra-era) is above any promotable bar; (ii) the gate must score
  DD/Sharpe continuously across fold boundaries (fold-reset forgiveness is
  the biggest flattering bias in the 14.9× headline). This is a
  **screen-level green-light to design**, not a build commitment — it goes
  to the user for scheduling, not to this session.
- **Payload (b) — macro-directed shorts — NO surface.** No admission
  headroom, conditioning destroys the sleeve's own fold value (1.18× <
  1.37×), realized value = one 26y-old regime window, fold signal
  chaotic, validating-event rate makes WF-CV powerless. The sleeve stays
  what it is: an available default-off config whose honest description is
  "a 2000-01-shaped slow-bear hedge that has not had a paying regime
  since." No-build **decision** leaning on standing priors
  (no-reversal-timing, edge-is-the-fat-tail) — not a data rejection of
  the hedge mechanism.
- **Payload (c) — SPY-switch — stays dead** per the 06-27 adjudication;
  the new basis adds nothing that reopens it.

**Transferable why:** every regime payload is a bet that a lagging label
can buy the amplified right tail without paying the label's lag twice
(entering late, exiting late). It works on paper only where the payload
itself is tail-concentrated in label-visible eras — which is true for
long leverage (post-bear dawns ARE label-visible) and false for shorts
(their tail is supply-gated and era-idiosyncratic). So: regime-condition
the *deployment intensity* of the long engine if anything; never
regime-condition sparse-tail sleeves.
