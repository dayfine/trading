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

## Early-admission status going into next session

5-context grid (15y/5y/early SP500 + top-3000 broad + **27y deep, pending**):
**ma=13** beats baseline in every regime tested so far (frictionless + 5bps),
turnover-neutral. ma=10 overfit. The 27y deep grid (dot-com + GFC) is the last
input before the promotion decision.

---

## P0 · Close the deep verdict + make deep-history reproducible — ~1.5h
1. Harvest the 27y grid (command above) → the 5th grid context. Update the
   grid; finalize the ma=13 verdict incl. dot-com + GFC.
2. Append the deep result to the ledger (`early-admission-deep-27y` entry) +
   write `dev/notes/early-admission-deep-2026-05-31.md`.
3. **Commit a `dev/scripts/build_deep_universe.sh`** that rebuilds the 2000-2026
   data end-to-end (build_universe snapshot → fetch via the skill's curl loop →
   extend GSPC). Makes the deep capability a one-command rebuild. (Bars stay
   uncommitted.)

## P1 · ma=13 promotion — ~3-4h — GATED on (deep grid confirms) AND (human go-ahead)
- If ma=13 holds through dot-com + GFC and the flip is approved:
  flip `Stage.default_config.early_admission_ma_period` `None → Some 13` (cite the
  ledger ACCEPT), **re-baseline every affected golden** (5y/15y/custom-universe —
  run each, reset expected ranges), full 3-gate QC + merge.
- Else: record the deep finding, keep default-off, collapse P1 → bump P2/P3.
- **The live-default flip is outward-facing — do NOT execute without the user's nod.**

## P2 · Re-validate prior verdicts on repaired data — ~1.5h
- Re-run exit-timing (#1375) + hysteresis (#1366) surfaces on the GSPC-repaired
  (ideally deep) golden — their REJECTs were measured on the truncated 2017-2026
  window. Confirm they still hold; strip the asterisk from those ledger entries.

## P3 · Deep-history infrastructure — ~1h
- Build the other point-in-time snapshots (2005/2010/2015/2020); check whether the
  `build_universe --change-log` dynamic-membership path can drive a *properly
  rebalanced* point-in-time backtest (vs today's pinned-2000-cohort).

## Backlog (deferred)
Cross-sectional rotation (`french_weinstein_rotation`), Russell-3000 broader
universe, DSR into the BO tuner.

## Session ramp-up reminders
- Main CI green check first. Newest priorities = this doc.
- The `cost-test` worktree + `/tmp/sweeps/ea-deep` are the load-bearing on-disk
  state; harvest before assuming anything was lost.
