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

## P0 next session — finish/merge PR #1725
1. **Confirm CI green + merge** #1725 (was red on `test_weinstein_backtest`; re-pinned
   + pushed a61470b3). If CI surfaces another breadth-coupled code test, re-pin it the
   same way (run vs `TRADING_DATA_DIR=test_data`, `--no-emit-all-eligible` for speed,
   capture actuals, ±15% bands / exact pins). It touches a `.ml` test → run qc-structural.
2. **Deferred: heavy-tier golden re-pin (snapshot mode).** The top-1000/3000
   `goldens-broad/*` (6), `goldens-custom-universe-scenarios/*` (2), `perf-sweep/bull-3y`,
   `goldens-broad/sp500-30y-capacity-1996` also shift but **OOM/crawl in CSV mode** —
   they need a snapshot-mode re-pin. Mostly perf-tier:4 (local-release-gate, non-blocking)
   + perf-tier:3 custom-universe. Build snapshots for those universes, run, re-pin.
   The `all_eligible` diagnostic is the per-scenario time sink — always pass
   `--no-emit-all-eligible` for re-pin runs.

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
