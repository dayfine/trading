# Next-session priorities — 2026-06-24 (handoff)

**Supersedes** `next-session-priorities-2026-06-23.md`. The A-D-default flip (P0
of the prior handoff) is **done**: P0a perf fix merged, the flip earned a
confirmation-grid ACCEPT, and the flip PR is up.

## Done this session
- **P0a — A-D macro O(n²) perf fix: MERGED #1722** (commit b2f5a03). Prefix-sum
  cache (`Ad_series_cache`), O(log n)/tick, bit-identical (parity test), full CI+QC.
  One detour: the GHA cron closed the PR mid-rework; reopened + drove it through.
- **P0b — A-D-live default flip: PR #1725** (`feat/ad-default-flip`).
  - Corrected the mechanism: `skip_ad_breadth` already defaulted false; the flip =
    commit synthetic post-2020 breadth tail into `test_data/breadth/` + re-pin
    shifted goldens. **Non-blocking** (perf-tier:1 all ≤2020).
  - Caught that the flip rested on ONE scenario; per user direction ("grid first")
    ran a **confirmation grid** (A-D-live vs inert, longshort, sp500-2000/2010/2015
    × deep/post-GFC/recent) → **3/3 PROMOTE**, ledger ACCEPT
    (`dev/experiments/_ledger/2026-06-23-ad-default-flip-confirmation-grid.sexp`).
  - The transferable *why*: A-D breadth's edge is **short-timing** — helps longshort,
    costs return in long-only bull windows (re-pinned honestly).
  - Re-pinned (feasible CSV tier): `goldens-small/{six-year-2018-2023,bull-crash-2015-2020}`,
    `goldens-sp500/{sp500-2019-2023,-long-only}`, `goldens-sp500-historical/sp500-2010-2026`,
    + engine test `test_weinstein_backtest` (6y: 30/27→29/26).
  - Full record: `dev/backtest/ad-grid-2026-06-23/STATUS.md`, memory `project_ad_default_flip`.

**UPDATE 2026-06-24 (later this same session):** #1725 MERGED; the "heavy-tier
re-pin" was investigated to root cause and turned into a tracked decision — see P0
below. P1/P2 unchanged.

## P0 next session — broad-golden complete-data (issue #1729, decision C) — DISPATCHABLE
The heavy top-1000/3000 `goldens-broad/*` + `goldens-custom-universe/*` goldens
were found to measure **survivor subsets**: `test_data` covers only 462/1000 of
top-1000-2014 (data/ 514, warehouse 3017); the runner silently skips missing
symbols → survivorship-inflated, data-path-dependent numbers (decade: 227% on
test_data-CSV vs 95% on the complete warehouse). NOT an A-D-live effect; pre-existing.
**Decision C (recorded, #1731):** GHA does NOT host the 2 GB warehouse; broad goldens
stay **local-only** (already fail-on-missing in GHA = intentional signal) and are
**rebuildable locally** via existing tooling. Full design + rebuild recipe:
`dev/plans/broad-golden-complete-data-2026-06-24.md`. Remaining sub-tasks (both
dispatchable, NOT interactive):
1. **Re-pin runnable cells (top-1000/500) to warehouse complete-universe numbers**
   (decade ≈ 95%). Recipe: `scenario_runner --snapshot-dir /tmp/snap_top3000_1998_2026
   --no-emit-all-eligible`. ⚠ Warehouse is ephemeral `/tmp` (2 GB) — if lost, rebuild
   via `build_broad_snapshot_incremental.sh` (needs top-3000 EODHD fetch first).
2. **Top-3000 cells** (`tier4-broad-10y`, `weinstein-full-pool`) — blocked on the
   snapshot memory crash (`project_panel_runner_memory_ceiling`; fork-per-cell /
   `SNAPSHOT_CACHE_MB`). Separate engineering fix.

The merged flip (#1725) is sound (grid ran vs complete data/; sp500/small re-pins
consistent-source). This is cleanup, not a flip correction.

## P1 — decline-character mechanisms on the A-D-live basis (from prior handoff)
Now that A-D is live by default, re-run the A-D-inert WF-CVs on the live basis:
`neutral_blocks_shorts` (faithfulness flip still on the table), `fast_v_arm_on_rate_alone`
(#1708) + `fast_v_min_rate_pct` (#1716) arming surface. See `project_decline_character_builds`.

## P2 — barbell weight cert (unchanged) — needs weight mandate.

## Operational notes
- Local `data/` (gitignored) has the validated synthetic breadth 1998–2026 +
  731-name PIT bars; `data/breadth/synthetic_*.csv` is the source copied into test_data.
- A second orchestrator run (#1724) advanced main this session; main green.
- Scenario runner writes output under the dune-root `trading/dev/backtest/scenarios-*`
  (not repo-root) when cwd=trading — `find` accordingly.
