# Next-session priorities — 2026-05-31 (8h plan + resume state)

**Supersedes:** `next-session-priorities-2026-05-30-PM2.md`.

## ⚠ RESUME STATE (read first — there is in-flight work on disk)

A long session built the deep-history capability. Key state lives **outside git**:

- **27y deep grid result:** `/tmp/sweeps/ea-deep/` in the container (bind-mounted
  to host `.sweep-output/ea-deep/`). `aggregate.sexp` + `fold_actuals.sexp` land
  there when the run finishes. **Harvest it:**
  ```bash
  docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/.claude/worktrees/cost-test/trading && eval $(opam env) && \
    dune exec --no-build trading/backtest/walk_forward/bin/rank_variants.exe -- \
    --aggregate /tmp/sweeps/ea-deep/aggregate.sexp --fold-actuals /tmp/sweeps/ea-deep/fold_actuals.sexp'
  ```
  The spec: `ea-deep-2000-2026.sexp` ({7,10,13}, Rolling 2000-2026, 52 folds,
  base = the deep scenario below). Confirm early folds (2000-2003) traded
  (non-zero) — if zero, the deep bars didn't load.
- **`cost-test` worktree** (`.claude/worktrees/cost-test/`, created 2026-05-31,
  NOT swept) holds, all **uncommitted**:
  - Deep bars: **502 SP500 symbols, 1999-2026, incl. delistings** (LEH→2008-09,
    BS→2004, YHOO→2017) in its `trading/test_data/<f>/<l>/<SYM>/data.csv`.
  - GSPC.INDX index golden **extended to 1999** (its copy only).
  - Deep scenario `goldens-sp500-historical/sp500-2000-2026.sexp` (universe →
    the 2000 snapshot, period 2000-2026).
  - Costed scenarios `*-costed.sexp` (5bps spread + $0.005/share) — the cost run
    came back cost-NEUTRAL (turnover ~33-35d for all variants).
  - These bars are **huge — do NOT commit them.** They are rebuildable: see
    the `fetch-historical-data` skill (#1385) + the committed 2000 snapshot.
- **Committed durable artifact (this PR):** the point-in-time
  `universes/sp500-historical/sp500-2000-01-01.sexp` (515 names) — the seed for
  rebuilding the deep universe.

If `cost-test` is ever removed, rebuild via P0 below. Nothing else is lost: all
verdicts/ledger/notes are merged (#1383/#1384/#1385).

## What shipped this session

- **#1383** GSPC.INDX 2017-floor FIX (issue #1380 closed) + 15y re-baseline +
  early-admission **ACCEPT** (ledger v2). The index only went to 2017, silently
  truncating every `sp500-2010-2026` experiment to 2017-2026.
- **#1384** `.claude/rules/promotion-confirmation.md` (the confirmation-grid
  protocol) + early-admission 4-context grid → **ma=13 grid-robust; ma=10
  (15y/DSR-1.0 winner) REJECTED as overfit**.
- **#1385** `fetch-historical-data` skill (coverage-check + bulk-fetch workflow).
- Deep-history data built (502 symbols 1999-2026 incl. delistings) → the 27y grid
  (in flight).
- Memory: `project_early_admission_mechanism`, `project_promotion_confirmation_grid`,
  `project_gspc_index_golden_2017_floor`.

## Early-admission status — RESOLVED: do NOT promote (deep test failed)

The 27y deep grid (2000-2026, dot-com + GFC, point-in-time-2000 universe incl.
delistings) **REVERSED the recommendation**: baseline DOMINATES every
early-admission variant and is the only Pareto-frontier cell; ma=13's per-fold
win-rate collapses to 26/51 (~coin flip). The mechanism's post-2009 edge was a
bull-regime artifact. **Verdict: Reject for promotion; mechanism stays
default-off.** Ledger `2026-05-31-early-admission-deep-27y.sexp`; writeup
`dev/notes/early-admission-deep-2026-05-31.md`. **The early-admission thread is
closed** (do not revive the promotion).

---

## P0 · Make deep-history reproducible — DONE (2026-05-31, PR #1388)
- `dev/scripts/build_deep_universe.sh` shipped — one-command rebuild of the
  2000-2026 data (probe → snapshot symbols → parallel EODHD fetch → extend GSPC
  to 1999 → validate). Probe + 3-symbol run validated on host. The 27y deep run
  is now the *default* final cell for any future mechanism's promotion grid.

## P1 · (was the ma=13 promotion) — CANCELLED
The deep test killed it. Next entry-timing candidates from the original gap
(volatility-adjusted MA period; volume/breadth trend-establishment) are still
open — but **the deep finding warns that any "early admission" variant likely
fails the full cycle**; weight that before investing. If pursued, run the deep
cell early.

## P2 · Re-validate prior verdicts on repaired data — DONE (2026-05-31)
- Re-ran the exit-timing 9-cell surface (#1375) on the GSPC-repaired golden
  (the hysteresis #1366 `h2-m02` point is a cell of that surface, so one run
  covered both). All 31 folds now trade (early folds 2010-2016 were zero before);
  baseline Sharpe 0.540→0.6225 on the full window. **Both REJECTs hold and
  strengthen** — every behaviour-changing cell is dominated by baseline.
  Ledger `2026-05-31-exit-timing-hysteresis-revalidated.sexp`; writeup
  `dev/notes/exit-timing-hysteresis-revalidated-2026-05-31.md`. Asterisk removed.

## P3 · Deep-history infrastructure — PARTIAL (2026-05-31)
- DONE (PR #1390): point-in-time snapshots 2005/2015/2020 generated + committed
  (joining 2000 + 2010) — the 5-point regime-battery seed set.
- STILL OPEN: check whether the `build_universe -change-log` dynamic-membership
  path can drive a *properly rebalanced* point-in-time backtest (vs today's
  pinned-cohort). Build deep bars for the new snapshots via
  `build_deep_universe.sh --snapshot <path>` when a multi-regime battery run is
  needed (see `dev/plans/population-search-2026-05-31.md`).

## Backlog (deferred)
Cross-sectional rotation (`french_weinstein_rotation`), Russell-3000 broader
universe, DSR into the BO tuner.

## Session ramp-up reminders
- Main CI green check first. Newest priorities = this doc.
- The `cost-test` worktree + `/tmp/sweeps/ea-deep` are the load-bearing on-disk
  state; harvest before assuming anything was lost.
