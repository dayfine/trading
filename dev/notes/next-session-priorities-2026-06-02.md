# Next-session priorities — 2026-06-02

**Supersedes:** `next-session-priorities-2026-06-01.md` (its P0 — the SPY reference
strategy + trader/investor presets — shipped; see below). This is the forward plan.

## State of the world (2026-06-01 EOD)

Main green. The 2026-06-01 session built the **SPY single-instrument testbed** and
ran the full strategy-mode comparison. Shipped: #1397 (SPY strategy), #1398 (trader/
investor design + `weinstein-faithful-core.md` rule), #1400 (deep-window writeup),
#1401 (`ma_period_weeks` dial — default-off axis), #1402 (mode-comparison writeup).
Deep SPY bars fetched (SPY.US 1993-2026).

### The mode comparison (settled)

| Mode | Bull 2009-2026 (NAV/DD) | Deep 2000-2026 (NAV/DD) |
|---|--:|--:|
| Buy-and-hold SPY | $7.19M / 34% | $4.70M / 55% |
| **Investor (SPY 30wk)** | $4.18M / **18.8%** | **$5.20M / 18.8%** |
| Trader (SPY 10wk) | $2.87M / 27% | $2.73M / 30% |
| **Cell E (SP500 picker)** | ~Sharpe 0.94 (15y) | **$24.8M / 23%** |

Three settled conclusions:
1. **Trader 10wk REJECTED** — strictly worse than 30wk investor on both windows
   (faster MA amplifies whipsaw). The `ma_period_weeks` dial stays a default-off axis.
2. **Investor 30wk = drawdown-insurance sweet spot** — 18.8% MaxDD both regimes,
   beats buy-and-hold over a full cycle (the dot-com + GFC dodges compound).
3. **Selection ≫ timing** — Cell E (multi-symbol picker) made 4.8× the SPY timer
   on the deep window. Stock selection is the bigger lever.

Full record: `dev/notes/spy-mode-comparison-2026-06-01.md`,
`spy-deep-window-2026-05-31.md`, `spy-stage-timing-trades-2026-05-31.md`.
Memory: `project_trader_investor_modes`, `project_spy_reference_strategy`.

## The new lead — Cell E stalled 2020-2026

The most actionable open thread. Cell E (the production multi-symbol config) hit
~$25M by the 2020 COVID period and is **flat-to-down since** (final $24.8M on the
deep run). That mirrors the SPY investor's fast-V whipsaw struggles — the **modern
fast-chop regime hurts the capital-recycler too** (`enable_stage3_force_exit` +
`enable_laggard_rotation` churn in choppy tape). This is where the alpha is leaking.

**The answer is NOT a faster MA** (proven dead on SPY this session). Candidate
investigations, in priority order (all per `weinstein-faithful-core.md` — dials
only, spine intact, test as coherent presets not one-knob grafts):

## P0 · Diagnose the Cell E 2020-2026 stall — ~2h
- Run Cell E on a 2020-2026 sub-window (single backtest) and pull the trade log +
  equity curve. Is the stall (a) whipsaw churn (many small losers in the chop, like
  the SPY 10wk), (b) the laggard-rotation/force-exit mechanics cycling capital
  unproductively, or (c) just SP500 dispersion compressing (mega-cap concentration
  2020-2024 means fewer Stage-2 breakouts to rotate into)?
- The SPY-investor analog already showed (b/c)-flavored behaviour. Use the SPY
  testbed's trade-gap methodology (exit-vs-next-entry) on Cell E's positions.
- This tells us whether the fix is exposure/sizing (regime-aware), rotation tuning,
  or a universe-breadth issue — before investing in any one.

## P1 · The other trader dials, as a coherent package — ~3h (lower confidence)
- This session tested only the MA-period dial (rejected). Weinstein's full trader
  *package* is 10wk + **continuation entries** + **early Stage-3 exit** + **full-size
  sizing**, together — meant for individual stocks, not index timing. On the
  **multi-symbol** strategy (where continuation buys actually apply) test the
  coherent trader preset vs the investor preset on the deep window.
- **Weight this against the evidence:** continuation-buys (#1366) and the MA dial
  both failed; the package may too. But it's the one Weinstein-faithful combination
  never tested *as a whole*. Run the deep cell early; abandon fast if it's a drag.

## P2 · Population-search apparatus infra — ongoing (the long-term direction)
- Per `dev/plans/population-search-2026-05-31.md` + `dev/plans/experiment-platform-2026-05-29.md`:
  population-aware deflation in `rank_variants`, a durable ledger-write CLI, the
  multi-regime battery as a pinned artifact, versioned goal + ledger-rescore. Each
  step independently valuable. The SPY testbed + deep data make the battery real.

## P3 · Deep-history infra — partial
- Deep SPY (1993-2026) + deep SP500 (2000 PIT) exist in the `cost-test` worktree
  (uncommitted, rebuildable via `build_deep_universe.sh`). Build the other PIT
  snapshots' deep bars (2005/2015/2020) when a battery run needs them.

## Backlog
Broader universe (Russell-3000), DSR into the BO tuner, cross-sectional rotation
(`french_weinstein_rotation`) — all deferred behind P0/P1.

## Ramp-up reminders
- **Step 0: main CI green** (`gh run list --branch main --limit 3`). Newest
  priorities = this doc.
- **Code PRs need `gh pr merge --admin --squash`** — branch protection wants an
  approving review; QC posts APPROVED as comments (author==reviewer blocks
  `--approve`). Plain `--squash` silently no-ops. **Confirm `state=MERGED` BEFORE
  deleting the branch** (deleting an open PR's branch closes it unmerged — bit #1401
  this session). (`feedback_admin_merge_qc_comment_prs`.)
- **Before any deep/multi-fold run: purge the Panel_runner /tmp leak**
  (`rm -rf /tmp/panel_runner_csv_snapshot_*`) — orphaned on crash/kill, fills the
  container overlay (`project_panel_runner_tmp_leak`, issue #1393).
- **The `cost-test` worktree holds the deep data** (SPY 1993 + SP500 2000 PIT +
  deep GSPC). Load-bearing for cheap deep re-runs; rebuildable if gone.
- **Feat-agents yielded mid-task twice this session** leaving uncommitted work that
  the harness auto-reclaimed (lost the first attempt). When an agent returns/yields,
  **commit its worktree changes immediately** before anything else.
- **Don't re-test faster MA / trader-10wk** — settled rejected this session.
