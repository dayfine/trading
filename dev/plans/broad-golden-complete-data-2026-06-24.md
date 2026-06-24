# Broad/custom golden complete-data provisioning (B) — 2026-06-24

## Problem
The `goldens-broad/*` and `goldens-custom-universe-scenarios/*` regression
goldens use **delisting-aware PIT universes** (top-1000/3000, top-500), but the
data they run against doesn't contain those universes — so they silently trade
a survivor subset and pin **survivorship-inflated, data-path-dependent** numbers.

Surfaced while completing the A-D-live default flip (#1725): the heavy goldens
shifted, and re-pinning them produced three different answers for the same
scenario (`decade-2014-2023`): old band 105-158%, warehouse-snapshot 95%,
test_data-CSV **227%**. The 2-3× spread is a data-coverage artifact, not strategy
behavior.

## Root cause (measured 2026-06-24)
Coverage of the broad universes in each available store:

| universe | test_data | data/ | warehouse `/tmp/snap_top3000_1998_2026` |
|---|---|---|---|
| top-500-2019  | (subset) | 337/500  | full |
| top-1000-2014 | 462/1000 | 514/1000 | full (3017 syms) |
| top-3000-2019 | (subset) | 582/3000 | full |
| sp500-2010    | 309/510  | 501/510  | full |

- `test_data` is provisioned by `dev/scripts/prepare_ci_data.sh` (default universe
  = `sp500.sexp`), copying bars **from `data/`** into the committed
  `test_data/<first>/<last>/<SYM>/data.csv` store. So test_data is sp500-scoped
  (~650 symbols).
- `data/` itself is also sp500-scoped (731 names: union of sp500 PIT snapshots +
  ETFs + ^GSPC). It does **not** have the full top-1000/3000.
- The backtest runner **silently skips symbols with no bars**, so a broad golden
  run vs test_data (or data/) trades only the ~survivor subset → inflated return,
  understated/peculiar DD, unstable across data sources.
- **Only the warehouse** (`/tmp/snap_top3000_1998_2026`, 3017 symbols,
  delisting-complete) has the full universes. It is **not committed / not
  CI-available**.

## Why it matters
A green-but-inflated golden is worse than a red one: it asserts a false ground
truth (e.g. `decade` "227%" when the real top-1000 number is ~95%) and can't
guard broad-universe regressions — exactly where survivorship and Weinstein
stage-4 short behaviour live. These goldens are non-blocking (perf-tier:3 weekly
+ perf-tier:4 local-release-gate), so this is latent debt, not a CI break.

The merged flip (#1725) is **not** affected: the confirmation grid ran vs `data/`
(near-complete for sp500), and the feasible sp500/small re-pins use a consistent
test_data source (change = real flip effect). This plan is purely about the
broad/custom goldens.

## Options
**A — provision broad bars into committed test_data** (`prepare_ci_data.sh
--universe <broad>`). ✗ Blocked: the source (`data/`) doesn't have the full
universes either; would need a full top-3000 EODHD fetch first, and committing
3000 symbols × ~28y of CSV bloats the repo massively. Reject.

**B — migrate broad goldens to snapshot mode against a CI-provisioned warehouse**
(recommended). Run `perf-tier3/4` + `golden-runs-custom-universe` broad cells with
`scenario_runner --snapshot-dir <warehouse>`. The warehouse already exists locally
(3017 syms, fast). Needs:
  1. Make the warehouse CI-available — cache it as a GHA artifact / build it once
     and restore via `actions/cache` keyed on the universe+date range, or build it
     in a setup job from a complete EODHD pull. (Don't commit the raw `.snap`
     files — too large.)
  2. Wire `--snapshot-dir` into the perf-tier3/4 + custom-universe scripts for the
     broad cells only (sp500 cells stay CSV/test_data).
  3. Fix the **top-3000 snapshot memory crash** (`tier4-broad-10y`,
     `weinstein-full-pool` crashed even in snapshot mode — see
     `project_panel_runner_memory_ceiling`; likely needs fork-per-cell or a
     bigger `SNAPSHOT_CACHE_MB`).
  4. Re-pin every broad/custom cell to its **complete-universe** snapshot number
     (decade ≈ 95%, etc.) — the honest values.

**C — honest scope-down**: redefine the broad goldens' universes to exactly the
symbols test_data covers (complete coverage of a smaller, explicitly-named set).
No new data; honest. ✗ Loses the "broad" character; changes what they measure.
Acceptable fallback if B's CI-warehouse provisioning proves too heavy.

## Recommendation
**B.** Provision the warehouse as a CI cache/artifact, switch the broad cells to
snapshot mode, fix the top-3000 memory crash, re-pin to complete-universe numbers.
Sequence:
1. Decide warehouse CI-provisioning mechanism (cache vs build-job) — the gating
   design choice.
2. Fix the top-3000 snapshot crash (fork-per-cell / cache cap).
3. Wire `--snapshot-dir` into perf-tier3/4 + custom-universe for broad cells.
4. Re-pin all broad/custom cells to snapshot-warehouse A-D-live numbers.

Until then the broad goldens stay un-re-pinned (non-blocking). Do **not** pin them
to test_data-CSV subset numbers — that locks in survivorship inflation.

## Local repro
- Warehouse run (works for top-1000/500, fast): `scenario_runner --dir <stage>
  --snapshot-dir /tmp/snap_top3000_1998_2026 --fixtures-root
  trading/test_data/backtest_scenarios --no-emit-all-eligible` with
  `TRADING_DATA_DIR=test_data` (breadth + universe files). `^GSPC` is stored as
  `GSPC.INDX`; macro gate works (non-zero trades).
- Top-3000 cells crash here (memory) — that's sub-task 2.

See `memory/project_ad_default_flip` for the full A-D-flip context.

Tracking: dayfine/trading#1729
