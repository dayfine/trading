# Next-session priorities — 2026-06-01

**Supersedes:** `next-session-priorities-2026-05-31.md` (its P0/P2 shipped; P1
cancelled; P3 partial — see below). Read that doc for the full 2026-05-31
session record; this one is the forward plan.

## State of the world (as of 2026-05-31 EOD)

Main green. The 2026-05-31 session shipped 7 PRs (#1387-#1391, #1394) + issue
#1393. Net effect:

- **Three strategy mechanisms now REJECTED, two of them on deep multi-regime
  data:** early-admission (deep 2000-2026), exit-timing surface (repaired
  2010-2026 **and** deep 2000-2026), stage3 hysteresis (subsumed by exit-timing).
  Pattern: **single-knob tweaks to Weinstein entry/exit timing are a dead end on
  the SP500 universe.** Every one is a bull-regime artifact at best, a net drag at
  worst.
- **Deep-history infra exists and is proven end-to-end:** `build_deep_universe.sh`
  (#1388) + PIT snapshots 2000/2005/2010/2015/2020 (#1386/#1390) + the deep
  exit-timing run (#1394). The 27y deep cell is now a one-command battery cell.
- **The strategic direction is written down:** population search over the
  discrete feature space (`dev/plans/population-search-2026-05-31.md`, #1389),
  gated on a regime-diverse battery + population-aware deflation + a versioned
  goal.

## The fork (needs a human call — do NOT auto-dispatch)

Three mechanism-rejections in a row say the lever is **not** more entry/exit-knob
tweaks. The open question is which direction to invest:

- **(A) Build the population-search apparatus** (the user's 2026-05-31 vision).
  Low-risk infra, high strategic value, and the natural endpoint of the
  experiment-platform program. Concrete sub-steps in P1 below.
- **(B) Broader universe first** (per `project_strategic_pivot_broader_first`) —
  Russell-3000 / top-3000. The rejections are all SP500-specific; mechanisms may
  behave differently on a broader, higher-dispersion universe (early-admission was
  a *return*-booster there, per `project_early_admission_mechanism`).
- **(C) A genuinely different mechanism class** — cross-sectional rotation
  (`french_weinstein_rotation`), not another timing knob. Per
  `feedback_strategy_mechanic_changes_too_explorative` this needs strong basis;
  the autopsy's remaining gap modes are the place to look for it.

Confirm the fork with the user before dispatching. The default lean (mine): **A**
— it's the apparatus that makes B and C *trustworthy*, and it's infra not
strategy-exploration, so it's the safest high-value work to do unsupervised.

## P1 · Population-search apparatus — the buildable, low-risk path toward (A)

Each step is independently valuable even if the full multi-arm engine is never
built; each gates the next. All are infra/tooling (feat-agent dispatchable):

1. **Population-aware deflation in `rank_variants`** — today Deflated Sharpe's
   `n_trials` = one matrix size. Add a `--lifetime-trials N` flag so best-of-N
   deflation counts the whole search's trial budget, not one surface. (Issue this
   first; it's the smallest, and it's the correctness fix that prevents
   parallel search from lying.)
2. **A committed `rank-variants` / `write-ledger` CLI** — the ranking + ledger
   write were done by throwaway exes rebuilt 4× this program
   (`project_promotion_confirmation_grid`). Ship the durable bins so future runs
   don't hand-author sexp. (`rank_variants.exe` already exists and is committed —
   verify it covers the need; the *ledger-write* path is what's missing.)
3. **The multi-regime battery as a fixed artifact** — build deep bars for the
   5 PIT snapshots (`build_deep_universe.sh --snapshot <path>`), define the
   battery (which (universe × period) cells, with ≥1 deep), pin it. This is the
   fitness function the whole apparatus optimizes against.
4. **Versioned goal + ledger-rescore tool** — the goal (metric + battery) as a
   pinned artifact; a tool that re-scores the append-only ledger under a revised
   goal and reports which verdicts flip. (Per #1389 — needed before any
   goal-revision is trustworthy.)

## P2 · Panel_runner /tmp leak fix — issue #1393 (quick infra win)

Per-fold snapshot cleanup works on success but ORPHANS on crash/kill → ENOSPC
filled the container this session (1895 dirs / 53GB). Add an `at_exit` / Fork_pool
teardown that purges `/tmp/panel_runner_csv_snapshot_*` on abnormal exit. Small,
self-contained, dispatchable. Reduces a recurring sweep hazard.
(`project_panel_runner_tmp_leak`.)

## P3 · Deep-history — remaining open

- **Dynamic-membership rebalanced backtest:** check whether
  `build_universe -change-log` can drive a *properly rebalanced* point-in-time
  backtest (vs today's pinned-cohort). The pinned-2000-cohort deep run is a fixed
  survivorship-aware snapshot; a rebalanced one would be more realistic.
- Build deep bars for the 2005/2015/2020 snapshots when a battery run needs them
  (feeds P1.3).

## Backlog (deferred, needs the fork resolved first)

Cross-sectional rotation (`french_weinstein_rotation`), Russell-3000 broader
universe, DSR into the BO tuner.

## Session ramp-up reminders

- **Step 0: main CI green** (`gh run list --branch main --limit 3`). Newest
  priorities = this doc.
- **Before any deep/multi-fold WF run: purge the Panel_runner leak**
  (`docker exec trading-1-dev bash -c 'rm -rf /tmp/panel_runner_csv_snapshot_*'`)
  and check `df -h /tmp` — it fills silently (`project_panel_runner_tmp_leak`).
- Deep bars live **uncommitted** in the `cost-test` worktree (1999-2026 incl.
  delistings) — reusable for cheap deep re-runs; rebuildable via
  `build_deep_universe.sh` if gone.
- Three mechanism-rejections this program say: **don't re-test entry/exit-timing
  knobs.** Any new mechanism must clear the deep cell early.
