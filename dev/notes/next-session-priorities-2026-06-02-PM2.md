# Next-session priorities — 2026-06-02-PM2

**Supersedes:** `next-session-priorities-2026-06-02-PM.md` (formerly `-06-03`). The 06-02 / 06-02-PM work (Cell E
stall diagnosis, population-search infra, `neutral_blocks_longs` axis) is done and
**reframed by a bigger finding this session**: a broad universe restores the strategy's
edge. This doc is the forward plan from that.

## The headline this session — BREADTH is the lever

The Cell E 2020-2026 "stall" was an **SP500-concentration artifact, not a strategy
defect.** Running the *identical* Cell E config on a broad universe restored the
win-size ≫ loss-size asymmetry, knob-free:

| 2020-2026 chop, same Cell E config | SP500-506 | **TOP-3000** |
|---|--:|--:|
| **win/loss size ratio** | 1.90× | **3.43×** |
| avg winner | 8.1% | **20.3%** |
| win rate | 35.3% | **32.8%** *(lower!)* |
| **profit factor** | 0.96 | **1.39** |
| **Calmar** | 0.18 | **0.36** |
| MaxDD | 32.3% | 29.9% |

Lower win rate, **2.5× bigger winners**, profit factor net-losing → solidly
profitable — exactly the asymmetry the diagnosis said collapsed post-2020. The narrow
SP500 was starving the picker of trending names; the trends were in the mid/small-caps
it doesn't contain. (Confirmed concentration directly: top-10 winners carried 37% of
winner-$ in 2010-2019 → **51%** in 2020-2026.)

**Caveat — not yet banked at full magnitude:** the top-3000 number is partly flattered
by thin small/micro-cap fills (one winner was a $0.53 penny stock; the biggest winners
skew low-price, where the 5bps cost model is optimistic). The **bankability gate** is a
liquidity-floored re-run (top-1000 by market cap) — it was attempted but **crashed on a
tooling issue** (see below) and must be re-run. Expectation: asymmetry survives but
attenuates (maybe ~2.5-3× vs 1.9×); still a clear win.

## Objective — LOCKED (governs all fitness metrics)

**Risk-adjusted / drawdown defense, operationalized as win-size ≫ loss-size.** Win
rate may be low; the edge is the payoff asymmetry. The fitness metric for every
experiment is **profit factor / Calmar / win-loss ratio**, NOT total return. (This
retroactively justifies the 30wk MA over 10wk, and it's why the broad-universe result —
which *lowers* win rate but triples the payoff ratio — is a win, not a wash.)

## The research ladder — "what mechanism works at which layer"

Each rung adds exactly one knob so we can attribute effect to layer. Matrix:

| universe | long / flat | long-short |
|---|---|---|
| **SPY** (1 instr, no selection) | ✅ DD-insurance floor (18.8% MaxDD, robust bull+deep) | ⚠️ **provisional** — appears to raise DD (32.6%), #1415 |
| **Sectors** (few clean instr) | ✅ **DONE — k=3 beats BAH, but DD 28-32% > SPY floor** (see below) | later |
| **Broad** (many noisy) | ✅ asymmetry restored 3.4× (but liquidity-flattered) | ⚠️ exists, appears to fail DD (squeeze) |

### P0 · Sector-rotation long/flat — ✅ DONE (#1419), full analysis: `sector-rotation-k-ladder-2026-06-02.md`
Built `Sector_rotation_weinstein` (top-K Stage-2 sectors by RS vs SPY, per-symbol stops,
macro gate stripped to isolate selection). Ran the K-ladder on **bull (2009-2025) AND
deep (2000-2025, incl. dot-com + GFC)** — regime-robust attribution:
- **Drawdown defense ⟸ index stage-timing (SPY-only), NOT selection.** SPY-only MaxDD
  **18.8% in BOTH windows** (dodged dot-com + GFC; BAH ate 55%). Still the best single
  strategy by the locked objective. Selection *worsens* DD (sectors more volatile than
  the smoothed index): k=3 DD 28% (bull) / 32% (deep).
- **Sector k=3 = strong bankable RETURN engine** — dominates BAH on every risk metric in
  both regimes (deep: Calmar 0.23>0.11, MaxDD 32<55, Sharpe 0.56>0.40, ret 528>370),
  regime-stable **1.5× win/loss-size asymmetry**, ZERO penny-stock risk (clean ETFs,
  unlike the liquidity-flattered top-3000). But NOT a DD improvement over SPY-only.
- **K=3 is the sweet spot** (Calmar ordering k=3>k=4>k=1 in both windows). **K=1 sector
  rotation is DEAD** (deep: ~0% ret, 53.8% DD, negative 0.96× asymmetry — churns, shredded
  in bears). Do not revive K=1.
- **Conclusion:** SPY-only (DD floor) and sector-k3 (return engine) are **complementary
  layers, not competitors.**

#### → macro gate (#1422) — ✅ DONE, WORKS in both regimes
Added `enable_macro_gate` (default-off dial): when SPY itself is Stage 4, block sector
buys + force flat. Ran on sector-k3, bull + deep:
- **Cuts MaxDD both windows** (bull 28.3→**23.4%**, deep 32.3→**28.6%**), **raises Calmar
  both** (0.36→**0.40**, 0.23→**0.26**). Deep is a **strict Pareto win** (more return,
  less DD, higher Sharpe). Improves BOTH windows consistently — a real effect, unlike the
  3 rejected single-window mechanisms. Gate-ON k3 = best sector config found.
- **Does NOT reach the 18.8% SPY floor** — narrows excess DD ~⅓-½, not all: the gate
  fires only after SPY *already* rolled to Stage 4; sectors stay intrinsically more
  volatile. Promotion needs a different-universe grid cell (`promotion-confirmation.md`);
  testbed has no default to flip. Full result: `sector-rotation-k-ladder-2026-06-02.md`.

#### → barbell (SPY-core + sector-satellite) — ✅ TESTED (blend analysis), CONFIRMED
50/50 continuously-rebalanced blend of SPY-only floor + gate-ON sector-k3 engine
(post-hoc NAV blend, no module yet). **Best of both layers, both regimes:**
- Keeps ~sector return (bull 341% ≥ both sleeves; deep 503%) while pulling MaxDD back
  toward the floor (bull 23.4→**19.8%**, deep 28.6→**22.2%**). **Blend Calmar ≈ the
  SPY-only champion** (bull 0.46 vs 0.47; deep 0.31 vs 0.34) **and beats sector-k3 both**.
  The SPY core is defensive exactly when sectors chop → they don't draw down together.
- Validates the layer story: DD-floor + return-engine **compose**. Full result +
  build-ready module spec: `sector-rotation-k-ladder-2026-06-02.md` §barbell.
- Caveat: continuously-rebalanced daily = idealized upper bound; real module rebalances
  monthly/quarterly. 50/50 weight is an open knob (sweep 60/40, 40/60).

#### → NEXT P0 (SUPERVISED build): two-sleeve meta-strategy module
The blend is post-hoc. A live version needs a meta-strategy running both sub-strategies on
split capital — the simulator runs ONE `STRATEGY` today, so it's design-heavy (left
supervised). Recommended cheap path: a **`Scenario`-level blend runner** that post-processes
two scenario NAVs 50/50 (reproduces this result exactly), before a true shared-portfolio
meta-strategy. Then sweep core/satellite weight + add a different-universe cell for the
macro-gate promotion grid. Spec in the k-ladder note §"NEXT (supervised build)".

### (superseded) original P0 brief · Sector-rotation long/flat (data ready, build it)
- Universe: the 11 SPDR sector ETFs (`spdr-sectors-11.sexp`); deep bars fetched this
  session (originals 1998-12 → 2026; XLRE '15, XLC '18) — **but see "Data state": the
  fetch may have been wiped; re-verify / re-fetch (2 min).**
- **Concentrated sizing** (user's call): hold the top **K=1** strongest Stage-2 sector
  first (closest analog to SPY-only → isolates the *selection* layer), then ramp to
  **K=3-4 at ~25% each** (isolates the *rotation* layer). Do NOT start at Cell E's
  0.14/0.70 sizing — that's wrong for sectors.
- Thesis: sector regimes are persistent (long Stage-2 runs → big winners) and ETFs have
  no single-name blowup tails (shallow losses) → should preserve win≫loss *better* than
  individual names, with far less liquidity risk than the micro-cap broad tail.
- **Prerequisite:** extend `GSPC.INDX` golden back to ~1998 (currently floors at
  2009-01-02) IF the sector strategy uses the macro gate — else the deep folds are
  silently starved (`project_gspc_index_golden_2017_floor`). A dedicated sector-rotation
  module (like SPY-only #1397) may strip the macro gate, in which case GSPC is moot.

### P1 · Top-1000 bankability gate (re-run the crashed test)
Re-fetch the top-1000-2020 symbols (subset of the wiped top-3000) and re-run the
2020-2026 Cell E test — does the 3.4× asymmetry survive a liquidity floor? Serialize
(no concurrent jj agent). This banks (or attenuates) the headline.

### P2 · Long-short — DEDICATED HUMAN SESSION (do not trust the current result)
**The "long-short raises drawdown" result (SPY #1415 + SP500) is PROVISIONAL.** Per
2026-06-02 user judgment: **drawdown/NAV calculation for a short book is error-prone**
(short mark-to-market, margin collateral, borrow accrual, equity-curve reconstruction
when short) and this repo has a NAV-calc bug history. Before any long-short conclusion
is banked: **find worked examples and verify the LS drawdown calc is correct** — a
dedicated human session, not an autonomous run. The squeeze *mechanism* is real (shorts
lose on V-bounces); the DD *magnitude* is not yet trustworthy. The SPY-LS testbed
(#1415, default-off) is the vehicle for that verification.

## Data state (IMPORTANT — read before running)
- **Broad top-3000 bars: WIPED** this session (jj contamination). Re-fetch via
  `ops-data` / `fetch-historical-data` (top-3000-2020 or just top-1000-2020 for the
  gate; ~4 min / ~2 min). Universe snapshots exist:
  `test_data/goldens-custom-universe/composition/top-{1000,3000}-2020.sexp`.
- **Sector ETF deep bars: possibly wiped** (XLK survived an early `@` move; a later
  `jj new main@origin` likely removed them). Re-verify; re-fetch is 2 min (11 symbols).
- Fetched bars land untracked-not-ignored in `test_data/<F>/<L>/<SYM>/`.

## Tooling guardrail (cost us the top-1000 gate this session)
**Never run a `scenario_runner` backtest writing untracked output in the PARENT working
copy while a jj-writing agent (feat-*/qc) is dispatched** — the agent's jj ops move the
shared `@` and wipe the untracked output dir mid-write, crashing the run AND deleting
fetched bars. Serialize, or route data/output OUTSIDE the working copy (`/tmp/sweeps/`).
Consider gitignoring the fetched-bar pattern at session start so jj leaves it alone.
(`feedback_no_parent_backtest_during_jj_agent`, `project_jj_worktree_root_cause`.)

## PRs this session (all merged unless noted)
#1407 (lifetime-trials DSR), #1408 (Cell E stall diagnosis), #1409 (ledger-write CLI),
#1410 (`neutral_blocks_longs` axis), #1411 (priorities reconcile), #1412 (neutral
directional — fragile), **#1415 (SPY long-short testbed, default-off — merging)**.

## Ramp-up reminders
- Step 0: main CI green. Newest priorities = this doc.
- Code PRs: `gh pr merge --admin --squash`; confirm MERGED before deleting branch.
- Serialize backtests vs jj agents (see Tooling guardrail).
