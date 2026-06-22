# `neutral_blocks_shorts` — promotion confirmation GRID (2026-06-22)

The `promotion-confirmation.md` grid for the `neutral_blocks_shorts` mechanism,
which earned a single-cell **ACCEPT** in
`dev/backtest/neutral-blocks-shorts-wfcv-2026-06-22/` (cell 1). The grid re-runs
the same flag axis in a **second, independent (period × universe) cell** before
any default flip.

| cell | universe | window | folds | base |
|---|---|---|---|---|
| 1 (ACCEPT) | sp500-as-of-2000 PIT | 2000-2026 (all-regime) | 26 | deep long-short |
| 2 (this) | sp500-as-of-2010 PIT | 2010-2026 (bull-dominated) | 16 | sp500-2010-2026-longshort golden |

## Cell-2 result — `true` does NOT beat baseline (dominated)

| Variant | Sharpe | Calmar | MaxDD % | Pareto |
|---|---|---|---|---|
| baseline (≡ false) | 0.576 | 1.170 | 11.42 | **yes** |
| neutral_blocks_shorts=true | 0.576 | 1.170 | **11.48** | **no (dominated)** |

`true` is **identical to baseline in 15/16 folds** and marginally **worse** in one:
- **fold-009 (2019):** return 0.42→0.39%, Sharpe 0.095→0.092, MaxDD **8.43→9.39%**,
  Calmar 0.050→0.042. The gate removed a Neutral-tape short that would have
  marginally helped in 2019. Aggregate: Sharpe tied, MaxDD fractionally worse →
  `true` is off the frontier.

## Grid verdict: NO DEFAULT FLIP — keep ACCEPT(mechanism), promote no value

| cell | regime | `true` vs baseline |
|---|---|---|
| 1 (2000-2026) | all-regime incl. dot-com/GFC | **≥** (wins 2003 squeeze-avoidance +9pp, +0.02 Sharpe aggregate) |
| 2 (2010-2026) | clean bull | **≤** (inert 15/16, fractionally worse in 2019; dominated on MaxDD) |

Per the `promotion-confirmation.md` decision rule — *PROMOTE value V only if it
beats baseline in a strong majority of cells AND is never badly dominated* — the
grid **disagrees**: `true` helps in the bear-containing cell and is
inert-or-fractionally-worse in the bull cell. No single value is robust across the
grid, so:

- **`neutral_blocks_shorts` stays default-off + an axis** (ACCEPT-mechanism, no
  value promoted). It is faithful and helpful **in regimes with bad Neutral-tape
  shorts** (post-bottom squeezes like 2003/2010), but in clean bulls it
  occasionally removes a marginally-useful Neutral short. It is a **regime-dependent
  trade, not a free win.**
- This is the grid doing its job: cell 1 alone read as a clean ACCEPT; the second
  cell reveals the regime-dependence and **prevents an over-promotion** — exactly
  the failure mode (`promotion-confirmation.md`, the 2026-05-30 early-admission
  episode) the grid exists to catch.

## Why this is the right call (transferable)

The short leg's value is **regime-governed** ([[project_factor_lens_regime_governs_edge]]):
shorts (and short-gating) pay in sustained/recovering-bear regimes and are a
low-stakes wash in clean bulls. A *static default flip* of a short-gate cannot be
right for both regimes at once. The faithful resolution is to **keep the gate as an
available axis** and, if anything, gate it on a macro-regime signal — not flip it
globally. For now: no flip; the mechanism is recorded, faithful, and ready if a
regime-aware wiring is built later.

Recorded: `dev/experiments/_ledger/2026-06-22-neutral-blocks-shorts-grid.sexp`.

## Caveats
- Cell 2 uses the committed `sp500-2010-2026-longshort` golden base (sp500-as-of-2010,
  16 annual folds) on the now-complete deep `data/` store. Both cells static-universe;
  the qualitative cross-regime split (help-in-bear / wash-in-bull) is the robust
  finding. Evidence: `cell2_walk_forward_report.md` + `cell2_ranking.md`.
