# Next-session priorities — 2026-06-21 PM (handoff)

**Supersedes** `next-session-priorities-2026-06-21.md` + `overnight-plan-2026-06-21.md`.
Overnight autonomous run (user AFK). Check main CI green first
(`.claude/rules/session-rampup.md`). All work below shipped as merged PRs +
FINDINGS docs; no main breakage.

## TL;DR — the thesis got reshaped (read this)

The honest answer to **"do we have a strat that beats S&P?"** is now precise:
**Yes over full cycles, but ONLY via crash-protection — it lags badly in bulls.**

- **Engine (Cell-E, top-3000, 1998-26, current code): +1100% vs S&P-price +599%**
  — like-for-like (sim values on `close_price`, no dividends either side). MaxDD
  **48.3%**, Sharpe 0.54. (The cached **+1552%/35.9%** headline was optimistic —
  RETIRED; current code is +1100%/48%.)
- **The edge is 100% crash-protection:** 1998-2008 engine **+421% vs S&P −7%**
  (+428pp alpha); 2009-26 bull engine **+130% vs S&P +631%** (lags −501pp). Any
  eval window without a crash shows the strat LOSING to S&P.
- Records: `dev/backtest/engine-edge-1998-2026/FINDINGS.md` (#1679).

## What shipped overnight (all merged)

1. **#1678 — short line CLOSED.** Loosened `short_min_price 17→5`: 36 shorts vs
   37 → **supply-gated, not price-gated**; net −\$50k/28y, lottery-shaped, 2008
   2/7 win. Name-level shorts are NOT a dependable bear hedge → the barbell floor
   is. (`dev/backtest/short-supply-screen-2026-06-21/FINDINGS.md`)
2. **#1679 — engine-edge + barbell frontier (the centerpiece).** Honest engine
   vs S&P + the correct-window barbell weight surface + the regime decomposition.
3. **#1682 — 10wk-MA dial = NO-BUILD.** Tried Weinstein's faithful 10wk trader MA
   to fix the bull-lag: +25,602% full / +4207% bull — but **Sharpe collapsed
   0.54→0.21**, one trade realized **+\$209M**, 76% of NAV in open positions =
   capacity-infeasible MTM mirage. Bull-lag is **structural**, not MA-dialable.
   (`dev/backtest/engine-edge-1998-2026/PHASE-C-ma-period.md`)
4. **#1672 — issue queued:** migrate the one pinned 2000-26 spec → 1998-26.
5. **#1683 — deployable barbell overlay BUILT** (sleeve orchestration, default-off,
   no core edits, 19 tests incl. blend.awk bit-exact). **3 gates: qc-structural
   APPROVED + qc-behavioral APPROVED (5/5); CI was finishing at handoff — verify
   `gh pr checks 1683` and merge if green.** Module:
   `trading/trading/backtest/barbell/`.

## The barbell answer (correct-window frontier, 1998-26)

| floor w | return | Sharpe | MaxDD | note |
|---|---|---|---|---|
| 0.00 | 1100% | 0.54 | 48.3% | pure engine |
| **0.30** | **965%** | 0.61 | 38.6% | **light insurance — keeps ~90% of return** |
| **0.40** | **904%** | 0.63 | 35.0% | hits the ~36% DD target |
| 0.70 | 696% | 0.66 | 23.6% | Sharpe/Calmar max — but a regime artifact |
| 1.00 | 478% | 0.57 | 24.3% | pure floor |

**Every weight ≤0.65 beats S&P (+599%).** The Sharpe-optimal 0.70 is a
**regime-averaging artifact** (crash decade → pure engine best; bull → pure floor
best; no fixed weight optimal in both). **Recommended deployable weight: LIGHT
floor 0.30-0.40** — keeps most of the S&P-beating return, cuts the 48% DD to
35-39%, lifts Sharpe. NOT 70/30. (Earlier "70/30 robust" #1670/#1673 was on
weak-engine windows; on the strong-engine window 70/30 gives up too much return.)

## P0 NEXT — decisions for you + the obvious next steps

1. **Pick the deployment weight** (your call — mandate-driven): light floor
   0.30-0.40 (keep edge, modest DD relief) vs heavier 0.50-0.70 (max risk-adjusted,
   give up return). The overlay (#1683) takes it as a config param — nothing
   hardcoded.
2. **Finish the overlay's end-to-end wiring** (`[non-blocking]`, the feat-agent's
   one flagged follow-up): #1683 delivered config + blend core + runner
   orchestration + tests, but the `scenario_runner` call-site flag + the two
   thunk-builders that feed real leg backtests are not yet wired. Small,
   well-scoped feat-backtest follow-up → makes the barbell runnable end-to-end.
3. **Set expectations:** this strategy underperforms S&P in sustained bulls. Its
   mandate is full-cycle outperformance via crash avoidance. If that's not the
   mandate, the barbell floor (or just index-timing) is the better core.

## Open / lower-priority threads
- **Capacity-capped engine** (only if curious): the 10wk MTM mirage suggests
  re-measuring the engine with a per-name %-ADV position cap — the realistic edge
  is capacity-bounded. The 30wk book was already capacity-clean
  (`project_trade_realism_liquidity`), so this mainly matters if chasing more
  return via faster MA, which the NO-BUILD says not to.
- **Migration #1672** — the one pinned 2000-26 spec → 1998-26 (re-pin goldens).

## Guardrail status (unchanged, reinforced)
Live class = structural diversification layers (barbell). Confirmed dead/avoid:
winner/loser-touching levers (9 now, +short-sleeve +vol-stop), entry/cascade/short
selection, stop/sizing knobs, **and now MA-period speed-up (MTM mirage)**. The
engine's edge is crash-protection; don't chase bull-upside via tail-catching dials.

## State
- Main green through all merges; 0 feature PRs open except #1683 (QC-clear, CI
  finishing). Memory updated (deep re-pin, correct-window barbell, MA-mirage,
  short supply-gated). /tmp warehouses + agent worktrees cleaned.
