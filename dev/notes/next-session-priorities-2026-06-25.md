# Next-session priorities — 2026-06-25 (handoff)

**Supersedes** `next-session-priorities-2026-06-24.md`. All three 06-24 priorities are
**done** (see below); this session added the optimal-strategy / missed-trades lens, which
**redefines the strategic direction**: the gap is capital allocation, not entry selection.

## Done this session (2026-06-24 → 06-25)
- **#1729 broad-golden complete-data — CLOSED.** Sub-task 1 re-pinned runnable top-1000/500
  cells to complete-universe (#1733); sub-task 2 retired the top-3000 "memory-ceiling"
  blocker — top-3000 runs clean in snapshot mode (#1738). Both QC-gated/merged.
- **P1 decline-character — EXHAUSTED.** fast_v arming-speed A-D-live WF-CV → NO-promote
  (#1737); all four mechanisms are faithful narrow-niche tail tools, none promotable. The
  one promotable outcome (A-D macro-gate sharpening) already shipped as the #1725 default flip.
- **P2 barbell — RESOLVED: no floor, pure long-only engine** (#1742). A-D-live weight surface
  + long-short engine: the short leg only buys DD with a return give-up; pure engine keeps
  the upside.
- **Optimal-strategy lens (the "what better trades are we not making" ask) — ANSWERED.**
  Writeup merged: `dev/notes/optimal-lens-insights-2026-06-25.md` (#1745/#1746).
  - **Cascade picks near-optimally** (2019-2023: actual +23.5% vs look-ahead upper bound
    +24.6%, ~1pp pickable gap). Entry-selection is a dead end (3rd independent confirmation).
  - **The misses are `Insufficient_cash` — capacity, not picks.** Winners (JBL +23R, DVN,
    PWR, ODFL…) were identified but unfunded; capital sprayed across 280 churned trades
    (33% win / 23% DD) vs the optimal's 47 (83% / ~0% DD). **Lever = capital allocation /
    turnover, not entry tuning.**
  - Broad **actual** run (first honest complete-top-3000, 1998-2026): **+698.8% / 1145 /
    34.9% / 39.9% DD / 0.50 Sharpe** — broader universe = wider DD + lower risk-adjusted
    return (breadth is a DD/return tradeoff; headline % MTM-inflated).
- **#1743 (snapshot-mode + env-cache for optimal/all-eligible runners) — CI GREEN, PUSHED,
  NEEDS QC + MERGE.** Adds `--snapshot-dir` (read a pre-built top-3000 warehouse instead of
  CSV `data/`) + env-configurable `SNAPSHOT_CACHE_MB`, with a shared `Backtest.Snapshot_world`.
  This is what enabled the broad lens without a 3000-name CSV fetch.

## P0 next session — merge #1743 (immediate, small)
CI is green; it needs the two QC gates (qc-structural + qc-behavioral — **pure infra/tooling
PR**, so qc-behavioral is the generic CP1–CP4, domain checklist NA). Dispatch both
(worktree-isolated, docker), then squash-merge. No backtest should be running when QC is
dispatched (jj-agent vs parent-backtest rule).

## P1 — the capacity levers (NEW strategic direction from the optimal lens)
Entry-selection is settled-dead; the optimal lens says the live lever is the **capital
envelope**. Build each as a **default-off axis** (most are already `Weinstein_strategy.config`
fields) → WF-CV on the sp500-2000 deep basis → confirmation grid (`experiment-gap-closing`):
1. **`min_cash_pct`** (cash floor) — does a lower floor fund more breakout winners, or just add DD?
2. **position-count / `max_position_pct_long`** (concentration) — fewer, larger positions vs ~5 sprayed slots?
3. **laggard-rotation cadence / turnover** — the rotation churn is what exhausts cash; does slower rotation preserve dry powder?
Frame: each gates how broad a universe you can usefully trade (breadth makes the capacity
bottleneck worse — the two findings compound).

## P2 — memory-bound the optimal/all-eligible forward-scan (tooling)
The broad (and deep) **optimal** lenses can't finish: the `forward_table` materializes every
symbol's full per-Friday outlook list in RAM (~4.4M records at top-3000 → **OOM at ~7.1GB**).
Fix is working-set, not speed/cache: stream it (score per-symbol then drop, or window the
Friday calendar). Unblocks the deep + broad missed-trades lenses (re-run after).

## Follow-ups / smaller
- **all-eligible post-step fixtures-root bug:** `Scenario_post_step.emit` resolves the
  universe via `Fixtures_root.resolve()` (→ `data/backtest_scenarios/`) and ignores
  `scenario_runner`'s `--fixtures-root`, so the auto-emit silently fails (swallowed
  `Sys_error`) for any scenario whose universe lives under `test_data/`. Thread
  `--fixtures-root` through. (`optimal_strategy` is unaffected — reads `universe.txt`.)
- Deep/broad optimal lenses: re-run via `--snapshot-dir` once P2 lands.

## Operational notes
- Deep gitignored bar store is **repo-root `data/`** (the runner's `default_data_dir =
  /workspaces/trading-1/data`), NOT `trading/data/` (a path mix-up cost a wrong "data gone"
  call this session). 735 symbols 1998-2026 + `data/breadth/` (A-D-live source) intact.
- Warehouse `/tmp/snap_top3000_1998_2026` (2 GB, 3015 syms, old .snap format, format-detecting
  reader) — ephemeral; rebuild recipe in `dev/plans/broad-golden-complete-data-2026-06-24.md`.
- `scenario_runner`/optimal/all-eligible output roots land under the **dune-root**
  (`trading/dev/backtest/scenarios-*`) when cwd=trading, vs repo-root `dev/backtest/` when
  cwd=repo-root — `find` accordingly.
- Cleared a 20-hour-orphaned QC `dune build @fmt` process this session (was holding the
  build lock). Watch for stale agent processes; consider a cleanup hook.
