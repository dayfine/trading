---
name: project_cell_e_2020_stall_regime
description: Cell E 2020-2026 stall is a payoff-geometry inversion from a two-sided regime change — explains why all 3 timing-knob tweaks failed
metadata: 
  node_type: memory
  type: project
  originSessionId: 07ce7765-f4ab-49f0-a55b-f26515035729
---

The Cell E 2020-2026 "stall" (flat from ~$25M on the deep run) was diagnosed
2026-06-02 (`dev/notes/cell-e-2020-2026-stall-diagnosis-2026-06-02.md`, PR #1408).

**It is a payoff-geometry inversion, NOT a hit-rate decline.** Within the 16y
2010-2026 Cell E run, splitting realized trades at 2020:

| | 2010-2019 | 2020-2026 |
|---|--:|--:|
| win rate | 38.6% | 37.1% (≈flat) |
| avg stop-out loss | −0.96% | **−2.52%** (2.6× deeper) |
| avg winner | +11.26% | **+7.64%** |
| avg winner hold | 106d | **63d** |
| realized **profit factor** | **1.78** | **0.88** |

The edge was never the hit rate (~38% both eras) — it was the asymmetry (tiny
losses, big winners). Post-2020 **both** sides inverted: losers fall 2.6× deeper
(higher vol), winners shrink + shorten across *every* exit channel (post-2020
trends are simply shorter/shallower). The +44% NAV on the fresh-2020 run is
unrealized survivor float; realized PF is 0.88 (net-losing).

**Rules out** (the three stall hypotheses): rotation churn — laggard rotation is
the *healthy* mechanism (+$503k, 69% win, positive nearly every post-2020 year);
idle capital — 43.5 trades/yr; faster-MA — proven dead (`project_trader_investor_modes`).

**Why this explains the 3 prior knob-rejections** (continuation #1366, hysteresis,
early-admission, MA-dial): the two degraded quantities pull stop placement in
*opposite* directions — tighten to cap the −2.52% losers and you shave the +4.3%
trailed winners; loosen to let winners run and post-2020 trends don't extend. Each
rejected knob tuned **one side of a two-sided regime change**. The regime moved,
not the parameters. This is the deep reason behind
`feedback_strategy_mechanic_changes_too_explorative`.

**Lever re-ranking (the actionable output):**
1. **Broad universe** (knob-free, but DATA-GATED) — post-2020 trends may live in
   mid/small-caps the SP500 lacks; a broad-3000 / Russell test might restore the
   winners without any parameter change. Blocker: committed `test_data` is SP500-only
   (broad-3000 coverage ~0%); cost-test worktree has only ~857 deep SP500+delisted
   names, not a breadth expansion. **Needs an EODHD fetch (~2500 symbols) — a planned
   multi-hour task, not autonomous.** Ties to `project_strategic_pivot_broader_first`.
2. **Regime / breadth ENTRY throttle** — gates *entry count* not the stop. Built
   2026-06-02 as the default-off axis `neutral_blocks_longs` (#1410: macro-Neutral
   blocks longs when on). **Directional single-backtest test (#1412): FRAGILE —
   do NOT promote.** Sign flips by universe vintage: fresh sp500-2020 HELPS (PF
   0.96→1.12, MaxDD 32→25%) but the sp500-2010 full-run 2020-segment HURTS (PF
   0.88→0.74); full-window MaxDD rises 17.5→20.4%. Path/universe/capital-state
   dependent = the same single-window fragility that killed the 3 prior knobs. Even
   the "tension-free" throttle doesn't cleanly fix post-2020. Stays default-off; only
   escalate to WF-CV + grid (multi-universe) if a cleaner signal appears.
3. **Stop/sizing redesign — deprioritised**: inherent two-sided tension (the data
   proves it) + the over-explorative flag.

Repro: `scenario_runner --dir dev/backtest/cell-e-stall-diag` (configs inlined in
the diagnosis doc). Cell E config = `goldens-sp500-historical/sp500-2010-2026.sexp`.

## 2026-06-02 RESULT — lever #1 (broad universe) CONFIRMED

Cell E, SAME config, 2020-2026 chop, SP500-506 vs top-3000-2020 broad universe:
win/loss size ratio **1.90× → 3.43×**, avg winner 8.1% → **20.3%**, win rate 35.3% →
**32.8% (lower!)**, profit factor **0.96 → 1.39**, Calmar 0.18 → **0.36**. The breadth
universe **restores the asymmetry knob-free** — the stall WAS SP500 concentration
starving the picker of trends (top-10 winner-$ share 37%→51% post-2020). Caveat:
top-3000 number partly flattered by micro-cap fills (a $0.53 penny-stock winner);
**bankability gate = liquidity-floored top-1000 re-run** (crashed on jj-contamination
2026-06-02, must re-run). Objective LOCKED: drawdown-defense / win≫loss, fitness =
PF/Calmar not return. Breadth (broad universe) is THE lever; long/flat on broad >>
SP500. Handoff: `dev/notes/next-session-priorities-2026-06-02-PM2.md`.

## Long-short — PROVISIONAL, do not bank

SPY long-short (#1415, default-off testbed) and SP500 long-short both APPEAR to RAISE
drawdown vs their long/flat twins (SPY 18.8%→32.6%; squeeze on V-bounces). **But the
LS drawdown/NAV calc is suspect** (short mark-to-market / margin / borrow / equity-curve
reconstruction when short — repo has NAV-bug history). Per user 2026-06-02: verify the
LS DD calc with worked examples in a DEDICATED HUMAN SESSION before trusting the
LS-raises-DD magnitude. Mechanism (shorts lose on fast-V) is real; magnitude is not.

## Breadth lever — CLEAN top-1000 vs top-3000 confirmation (2026-06-06)

Direct A/B, SAME window (covid 2020-01-02..2024-12-31), SAME Cell E config, only the PIT
universe size differs:
- **top-1000-2020** (N=1000): return 41.3% / Sharpe 0.46 / MaxDD 36.1% / Calmar 0.20 / win 33.1% (the migrated golden center).
- **top-3000-2020** (N=3000): return **152.75%** / Sharpe **0.89** / MaxDD **25.53%** / Calmar **0.80** / win 34.6% / PF 1.76.

Tripling breadth: return +3.7×, Sharpe ~2×, **MaxDD DOWN 36→25.5%**, **Calmar UP 4× (0.20→0.80)**,
win-rate ~flat. Same signature as the earlier top-3000-vs-SP500-506 finding (win/loss ratio
and PF rise, DD falls, hit-rate ~flat) — breadth gives more shots at the fat-tailed winners
the strategy is built to ride, and diversifies the drawdown. **Breadth is THE lever**, now
confirmed at the largest PIT scale on a clean same-window A/B. Run via the snapshot streaming
loader (local, ~3 GB RSS) — see [[project-snapshot-streaming-status]] for the perf caveat.
