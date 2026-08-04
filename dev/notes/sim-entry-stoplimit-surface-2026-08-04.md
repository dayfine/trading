# Sim-entry StopLimit surface — REJECT (2026-08-04)

**Question:** does the honest do-not-chase entry fill model (#2158 Phase 2,
PR #2202: `StopLimit(entry, entry×(1+pct/100))` instead of Market fills,
default-off `enable_sim_entry_stoplimit`) change fold-level risk-adjusted
outcomes vs the historical Market fill model — and at which cap?

**Ledger:** `dev/experiments/_ledger/2026-08-04-sim-entry-stoplimit-surface.sexp`
(verdict **Reject**). Artifacts:
`dev/experiments/stoplimit-entry-wfcv-2026-08-04/` (report, aggregate,
fold_actuals). Spec (committed + test-pinned):
`trading/test_data/walk_forward/sim_entry_stoplimit_31fold_2026_08_04.sexp`.
Run: pinned worktree @`ba3ec93c`, 31 rolling OOS folds sp500 2010-2026
(test=365d step=182d), variants `market` / `cap10` / `cap15` / `cap20`,
~1h50m wall.

## Result — baseline dominates everywhere

| Variant | Sharpe (μ) | Return % (μ) | MaxDD % (μ) | Calmar (μ) | Sharpe wins /31 |
|---|---:|---:|---:|---:|---:|
| **market** (baseline) | **0.789** | **28.7** | **13.4** | **1.564** | — |
| cap10 | 0.525 | 24.8 | 14.6 | 1.147 | 2 |
| cap15 | 0.522 | 24.8 | 14.6 | 1.115 | 2 |
| cap20 | 0.496 | 24.2 | 14.6 | 1.117 | 1 |

Gate (Sharpe m=16/31, worst_delta 0.20): **FAIL all three** — wins 2/2/1,
worst-fold gaps 0.62–0.68. Pareto frontier (Sharpe↑, Calmar↑, MaxDD↓):
baseline **alone**. No DSR needed — the candidates lose raw; deflation only
widens the gap.

## The transferable why

1. **Entry-side fat-tail tax** — 11th confirmation of
   `[[project_edge_is_the_fat_tail]]`, the first on the *entry-fill* side.
   The do-not-chase cap refuses fills precisely on gap-and-go launches, which
   are disproportionately the right-tail seeds. The risk the cap was meant to
   avoid (buying extended entries that then crash) never materialises as
   drawdown relief — MaxDD is flat-to-WORSE with the cap — so the refusal is
   pure lost return. "Missing > chasing" is faithful to the book's letter but
   empirically the missed monsters cost more than the chased losers save.
2. **Cap-insensitivity**: {10, 15, 20}pp are nearly identical (Sharpe
   0.525/0.522/0.496). The harm concentrates in gaps beyond 20pp — the
   monster launches that ALL variants refuse — not in fill-price nuance
   between entry and cap.
3. **Live/sim parity flag (the surface's most valuable output).** Live
   order-gen already ships `StopLimit(E, cap)` tickets (Phase 1 #2171, armed
   at 15pp), while every published backtest/record assumes Market fills. This
   surface measures that divergence: ≈ **−0.26 mean fold Sharpe / −3.9pp mean
   fold return** on sp500 2010-26. The live do-not-chase cap plausibly makes
   live execution *underperform its own backtest basis*. **USER DECISION
   ITEM:** keep the live 15pp cap (execution-honesty: ticket risk display,
   no intraweek gap-chasing) vs relax it (expectancy: the refused gap-throughs
   are the launches that pay). The weekly-cadence live path differs from the
   sim's daily fill model, so the sim number is directional, not exact.

## Forward guidance

- Mechanism stays a **default-off realism axis** — useful for live-parity
  studies, not an alpha lever. No default flip (R3 satisfied by REJECT).
- No further entry-timing / entry-price-condition levers without beating both
  the powered entry-selection null
  (`[[project_entry_selection_closed_powered]]`) and this result.
- Ops gotcha recorded in the spec comment: `walk_forward_runner` loads
  `base_scenario` cwd-relative — run from `test_data/backtest_scenarios/`.
