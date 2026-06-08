# Laggard-rotation re-check on the broad universe (WF-CV) — 2026-06-09

**Task:** P1 from `next-session-priorities-2026-06-08.md` §"P1" — re-check the
breadth-sensitive ledger verdicts (laggard-rotation, continuation) on the broad
PIT universe, since they may behave differently than on SP500 (≤506 syms). This
note covers **laggard-rotation**.

**Method:** walk-forward CV via the new `--snapshot-dir` WF runner (#1491 —
built + merged this session to make N≥1000 WF-CV tractable). Surface:
`enable_laggard_rotation {false}` vs the Cell-E baseline (laggard ON), on
**top-1000-2011 PIT**, rolling folds (test_days=365, step_days=182, 29 folds),
2011-2026. Snapshot mode, parallel=2. Ranked with `rank_variants` (Pareto +
Deflated Sharpe).

## ⚠ Infra note — top-3000 WF-CV is blocked on this container

The original target was **top-3000**. It is currently **infeasible** on the
7.75 GB container, a hard catch-22:
- **parallel=1** (single long process) hits a **Rosetta `VmTracker slab
  allocator` exhaustion** after ~13 folds (cumulative x86-emulation allocation
  tracking, not RSS) → SIGTRAP.
- **parallel≥2** forks a child per fold (resets the VMTracker) **but two
  concurrent N=3000 folds OOM-kill** a child (SIGKILL) even at
  `SNAPSHOT_CACHE_MB=1024`.

top-1000 (2× SP500) at parallel=2 fits memory and forks cleanly — it is a real
breadth-sensitivity test (500→1000). **top-3000 needs either a larger container
or a batched-WF run (≤6 folds per parallel=1 process, merge fold_actuals); filed
as the follow-up.**

## Result — the verdict direction REVERSES vs SP500

| variant | Sharpe μ ± σ | Calmar μ | Return μ | MaxDD μ | DSR | Pareto |
|---|---|---|---|---|---|---|
| baseline (laggard **ON**) | 0.232 ± 0.95 | 0.714 | 7.20% | 17.25% | 0.854 | frontier |
| laggard **OFF** | **0.368 ± 0.95** | **0.763** | **14.18%** | 18.20% | **0.995** | frontier |

- **Prior SP500 verdict** (`2026-05-29-laggard-disable-retracted`, Reject):
  "laggard rotation HELPS on 500-symbol panels (disabling = −0.08 Sharpe, −9pp
  return); only hurt on a 12-symbol diagnostic." → laggard ON is better on SP500.
- **On top-1000 it reverses:** disabling laggard has **higher** mean Sharpe
  (+0.14), Calmar, return (+7pp), and **higher DSR (0.995 > 0.854)**. Both
  variants sit on the Pareto frontier (laggard-OFF better Sharpe/Calmar/return;
  laggard-ON better MaxDD 17.25 vs 18.20). The candidate-supply-sensitivity
  hypothesis is **supported in direction**.

## …but it is NOT robust — Inconclusive, not an Accept

1. **Fails the OOS gate.** laggard-OFF wins **15/29** folds on Sharpe (a
   coin-flip) and the worst fold (`fold-007`) trails baseline by **1.32 Sharpe**
   ≫ the Δ=0.20 gate → `Fold_gate` = **FAIL**.
2. **The mean edge is fat-tail-driven.** Return σ blows up **22.2 → 34.6**.
   `fold-020` alone is **+152.9%** (laggard-OFF) vs +52.6% (ON), and `fold-026`
   +59.6% vs +17.2%. Strip those one or two folds and the means converge — the
   "improvement" is a handful of monster folds (the same fat-tail signature the
   broad-universe headline showed: `project_broad_universe_790_mtm_inflated`),
   not a broad central-tendency gain.
3. **n_trials is small** (1 variant) so DSR deflation is light; the 0.995 edge
   is modest and not gate-backed.

**Verdict: Inconclusive.** The laggard verdict is **not universe-invariant** —
its sign flips from SP500 (laggard helps) to top-1000 (laggard-off has higher
central Sharpe/DSR), confirming the breadth-sensitivity the §4 audit flagged.
But on top-1000 the flip is gate-failing and fat-tail-driven, so it is **not a
clean ACCEPT to flip the laggard default**. Keep laggard ON as default; record
the reversal; confirm on top-3000 once the infra is unblocked.

## Follow-ups
- **top-3000 WF-CV** (batched parallel=1, or bigger container) — the real test;
  top-1000 is the tractable proxy.
- **continuation-buy** re-check on broad universe (the other breadth-sensitive
  verdict) — not yet run.
- If top-3000 also shows the reversal robustly (gate-pass, not fat-tail-driven),
  reconsider the laggard default via the promotion grid.

## Artifacts
- WF report + aggregate: `dev/experiments/laggard-broad-recheck-2026-06-09/`.
- Spec: `/tmp/wf_laggard_t1k.sexp`; base `/tmp/p1verify_t1k/cell-e-top1000-2011-15y.sexp`.
- Ledger entry: `dev/experiments/_ledger/2026-06-09-laggard-broad-recheck.sexp`.
