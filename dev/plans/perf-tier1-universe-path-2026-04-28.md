# Plan: Fix tier-1 smoke universe_path resolution + flip the gate

Date: 2026-04-28
Branch: `fix/perf-tier1-universe-path`
Status file: `dev/status/backtest-perf.md` next-step #4

## Problem

Every tier-1 perf-tier1.yml run since #616 fails 4/4. Reproduction:

```sh
TRADING_DATA_DIR=$(pwd)/trading/test_data dev/scripts/perf_tier1_smoke.sh
```

Symptom (per scenario log):

```
Scenario bull-3m crashed: (Sys_error
  ".../trading/trading/test_data/backtest_scenarios/universes/broad.sexp:
   No such file or directory")
```

Note the doubled `trading/trading/` segment.

## Root cause

`trading/trading/backtest/scenarios/scenario_runner.ml`:

```ocaml
let _fixtures_root () =
  let root = Data_path.default_data_dir () |> Fpath.parent |> Fpath.to_string in
  root ^ "trading/test_data/backtest_scenarios"
```

This was written assuming `Data_path.default_data_dir()` points to the
project's `data/` directory at the repo root (the original devcontainer
`/workspaces/trading-1/data` shape). `Fpath.parent` then gives the repo
root, and `^ "trading/test_data/..."` reaches the fixtures.

But the perf-tier workflows set
`TRADING_DATA_DIR=$GHA_WORKSPACE/trading/test_data`, so:
- `Fpath.parent ".../trading/test_data"` = `".../trading/"`
- `^ "trading/test_data/backtest_scenarios"` = `".../trading/trading/test_data/backtest_scenarios"`  ← doubled!

The same issue affects `_repo_root()` for `_make_output_root()` (writes
to `.../trading/dev/backtest/scenarios-...` instead of `.../dev/backtest/...`),
but that path is only used to write artefacts, so the bug surfaces only
on the universe lookup which fails fast on the first scenario.

## Why this wasn't caught before

`continue-on-error: true` on the workflow step masks the failure. The
step exits non-zero internally, but GHA reports the job as green. The
scenarios actually fail to load their universe and crash. Net: tier-1
gates nothing.

## Fix decision: Option A — explicit `--fixtures-root` flag

Why A over the alternatives:
- **Option B** (resolve relative to scenario file source dir): the
  smoke scripts COPY the scenario into a `_stage_<name>/` dir to use
  the `--dir` entry point. The scenario's own path is the staged copy,
  which has no relationship to the fixtures root. So B would still
  need an extra signal.
- **Option C** (stage universe + sectors.csv alongside): copies a lot
  of data per scenario (the broad universe sexp is small, but the
  pattern leaks beyond just universes — sectors.csv is several MB
  and would need to be staged for every cell). More invasive than A.
- **Option A** (explicit `--fixtures-root`): one flag, one passthrough.
  Smoke scripts already know
  `SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"`
  — just plumb it through. Backwards-compatible: if the flag is
  absent, the runner falls back to a saner default
  (`Data_path.default_data_dir() / "backtest_scenarios"` — same
  shape the test files already use, so they stay green).

## Plan

### Step 1: Add `--fixtures-root` flag to scenario_runner

`trading/trading/backtest/scenarios/scenario_runner.ml`:
- Add `fixtures_root : string option` to `_cli_args`.
- Parse `--fixtures-root <path>`.
- `_fixtures_root` becomes `_fixtures_root args` and returns either the
  CLI value, or — if absent — falls back to the saner
  `Data_path.default_data_dir() / "backtest_scenarios"` shape (same
  as the test files in `test/test_panel_loader_parity.ml` and friends).
  This matches the convention "`TRADING_DATA_DIR` points at
  `trading/test_data`" that perf workflows + tests already use.
- Thread `fixtures_root` through to the child via `_run_scenario_in_child`.

### Step 2: Add a regression test

Extract the `Fixtures_root.resolve` logic to
`scenario_lib/fixtures_root.{ml,mli}` so a unit test can pin it
without forking a process. Add `test_fixtures_root.ml` covering:
- explicit `~fixtures_root` arg returns the path verbatim;
- fallback uses `Data_path.default_data_dir() / "backtest_scenarios"`;
- the doubled-`trading/trading` shape never appears.

### Step 3: Update the three tier scripts

`dev/scripts/perf_tier{1_smoke,2_nightly,3_weekly}.sh`:
- Pass `--fixtures-root "$SCENARIO_ROOT"` to `scenario_runner.exe`.
- Identical change in all three scripts.

### Step 4: Flip continue-on-error on tier-1

`.github/workflows/perf-tier1.yml`:
- `continue-on-error: true` → `false` on the `Run tier-1 perf smoke`
  step.

Tier-2 and tier-3: leave `continue-on-error: true` for now. The
warm-up budgets are not pinned (~10 weeks of nightly data needed for
tier-2 budgets; ~10 cycles for tier-3). Tier-1 is the per-PR gate so
it should be strict; tiers 2/3 remain VISIBILITY-first per the
existing rationale comments in those workflow files.

### Step 5: Set PERF_CATALOG_CHECK_STRICT=1

`trading/devtools/checks/dune`:
- Set `PERF_CATALOG_CHECK_STRICT=1` on the `perf_catalog_check.sh`
  invocation so missing tier tags fail builds.

### Step 6: Local verification

```sh
docker exec -e TRADING_IN_CONTAINER=1 \
  -e TRADING_DATA_DIR=<worktree>/trading/test_data \
  trading-1-dev bash -c \
  'cd <worktree> && dev/scripts/perf_tier1_smoke.sh'
```

Expected: 4/4 PASS.

### Step 7: Update status file + open PR

- `dev/status/backtest-perf.md` next-step #4: mark DONE; add
  Completed entry; update the Status header.

## Out of scope

- Pinning per-cell budgets (after ~10 cycles of real data).
- Tier-4 release-gate scenarios (separate parallel PR).
- Daily-snapshot streaming (P1, separate plan).
- Output-root resolution (`_repo_root()` / `_make_output_root()`):
  the artefact dir lands somewhere weird (under `trading/dev/...`)
  but it's not load-bearing — fixing in this PR would expand scope.
  Tracked as a follow-up note in the Completed entry.
