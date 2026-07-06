# Early-Stage2 admission window (`early_stage2_max_weeks`) — WF-CV verdict: REJECT alternatives; ≤4 validated (2026-07-06)

**Ledger:** `dev/experiments/_ledger/2026-07-06-early-stage2-window-surface.sexp`
**Mechanism:** #1862 (`Screener.config.early_stage2_max_weeks`, default 4 = prior hardcoded behaviour)
**Spec + artifacts:** `dev/experiments/early-stage2-window-2026-07-05/` (spec, `out_top3000/`, `run.log`)
**Origin:** P2 from `next-session-priorities-2026-07-02.md`, deferred from #1818.

## Setup

Broad-only surface (top-3000 PIT-2000, the decisive cell for entry-admission
levers), 2000–2026, 13×2y non-overlapping folds, production caps + catstop,
long-only + stage3-force-exit + laggard-rotation. Variants:
`early_stage2_max_weeks ∈ {2, 4=baseline, 6, 8}`. Gate: Sharpe, m=7/n=13,
worst_delta 0.30. Snapshot mode, fork-per-fold, ~8h wall, 52 fold-runs, zero
failures.

## Result — all three alternatives FAIL the gate

| Variant | Sharpe μ±σ | Return% μ±σ | MaxDD% μ | Calmar μ | Sharpe wins | worst-fold gap |
|---|---|---|---|---|---|---|
| **baseline (4)** | **0.597 ± 0.494** | 19.9 ± 20.6 | **15.4** | 0.683 | — | — |
| w2 | 0.565 ± 0.709 | 18.8 ± 26.9 | 16.3 | 0.726 | 5/13 | f000 0.515 |
| w6 | 0.588 ± 0.654 | 21.6 ± 27.2 | 16.5 | **0.801** | 6/13 | f011 0.519 |
| w8 | 0.405 ± 0.810 | 16.0 ± 29.0 | 17.8 | 0.592 | 5/13 | f012 1.021 |

No DSR step needed: **no variant exceeds baseline raw mean Sharpe** — there is
no candidate to deflate. Baseline also has the lowest dispersion on every
metric.

## The transferable WHYs

1. **Widening = stale-entry admission, and the damage is regime-concentrated.**
   Bear/chop folds degrade monotonically with window width — fold-011 (2022):
   baseline −0.42 → w6 −0.94 → w8 −1.36; fold-012 (2024–25): baseline +0.11 →
   w8 −0.91. A name 5–8 weeks into Stage 2 that the screener hasn't already
   bought is a later, more-extended entry with a worse stop structure exactly
   when the regime cracks. In bull folds the extra names DO add return (w6
   return mean 21.6 vs 19.9; Calmar wins 8/13) — but the bear tax dominates
   the risk-adjusted aggregate.
2. **Entry-breadth is not universe-breadth.** `project_edge_is_the_fat_tail`
   favors breadth of *fresh opportunities* (more symbols, more markets).
   Widening the admission window manufactures breadth from *staler entries of
   the same opportunities* — late-chasing wearing a breadth costume. This
   sharpens the lever-classification question from "does it touch winners?" to
   "does it add fresh opportunities, or stale entries?"
3. **Tightening starves.** w2 shows weeks-3–4 admissions carry real edge
   (fold-000 dot-com: +5.4% → −7.9%; σ(Sharpe) 0.71 vs baseline 0.49).
   Freshest-only isn't purer — it shrinks the funnel and raises dispersion.
4. **The book's fresh-breakout discipline is the empirical sweet spot** on
   26 years of broad data. Second consecutive surface where a Weinstein dial
   proved load-bearing (after volume-1.5× in the continuation-add surface).
   Rare *positive* result shape: the probe validated the incumbent default
   rather than merely rejecting variants.

## Forward guidance

- `early_stage2_max_weeks` stays **4**. Keep as a searchable axis for coherent
  **preset bundles** only (trader/investor presets per
  `weinstein-faithful-core.md`) — do NOT re-sweep standalone.
- w6's Calmar-mean win (0.801) + 8/13 Calmar wins is real but bear-fold-fragile;
  any "w6 + bear gate" idea is a regime-gate graft (rejected class). Stop.

## Ops notes

- One false start: `TRADING_DATA_DIR` must be passed via `docker exec -e` (or
  exported inside the launched shell) — otherwise the base scenario's relative
  `universe_path` resolves against `/workspaces/trading-1/data` and the run
  dies at fold dispatch with `Sys_error … No such file or directory`.
- `write_ledger_entry.exe` does NOT regenerate `index.sexp`; the index row was
  appended by hand (no CLI exists — small harness gap).
