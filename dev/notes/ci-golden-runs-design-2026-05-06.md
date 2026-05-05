# CI Golden Runs Design — 2026-05-06

Investigation and design for running sp500-2019-2023 (and optionally
sp500-2010-2026) as postsubmit/presubmit checks in GitHub Actions.

## Current state (findings)

### Data landscape

- `/data/` holds OHLCV bars for all symbols in `data/<first-char>/<last-char>/<symbol>/data.csv`
- Total `/data/` size: **5.3 GB** (26 letter-prefixed top-level dirs)
- `.gitignore`: `/data/*` is excluded (except `data/sectors.csv` and `data/sectors.meta.sexp`)
- Only 23 symbols are committed under `trading/test_data/` (unit-test fixtures for CI's
  `dune runtest`)

### SP500 universe sizes

- `universes/sp500.sexp`: 500 symbols (5y scenario)
- `universes/sp500-historical/sp500-2010-01-01.sexp`: 510 symbols (15y scenario)
- Unique symbols across both: 717 (217 appear only in the historical universe)
- All 500 sp500.sexp symbols have bar data in `/data/`; 217 of 219 historical-only
  symbols also have data (2 are missing, presumably delisted with no EODHD record)

### Data size measurements (2026-05-06)

| Scope | Full history | Trimmed 2009+ | Trimmed 2016+ |
|-------|-------------|---------------|---------------|
| 500 SP500 symbols | 220 MB | ~84 MB | ~51 MB |
| 217 historical-only symbols | 65 MB | ~23 MB | ~15 MB |
| Combined (717 symbols, both scenarios) | 285 MB | ~107 MB | ~66 MB |

Trimming rationale:
- AAPL (45y of history): 2009+ is 38% of rows; 2016+ is 23%
- Newer SP500 symbols (IPO post-2015): nearly 100% of their rows fall in 2016+
- Historical-only symbols (e.g. AA, 1962–2026): 2009+ is ~27% of rows

The 2009 cutoff (17 years) covers both the 5y scenario (needs ~6y including 30-week MA
lookback) and the 15y scenario (start date 2010-01-01, plus ~1 year lookback).

### Why golden-sp500 scenarios don't run in CI today

The `goldens-sp500/` directory exists with perf-tier: 3 tags, but
`dev/scripts/perf_tier3_weekly.sh` scans only:
`goldens-small / goldens-broad / perf-sweep / smoke`
— NOT `goldens-sp500` or `goldens-sp500-historical`.

Additionally, bar data for those 500+ symbols is not committed, so even if the
discovery were fixed, the runner would silently use NaN panels for all symbols
(line 79 of `ohlcv_panels.ml`: `Ok () (* tolerate missing CSV: row stays NaN *)`).

This means all `goldens-sp500` scenarios have **never run in any CI workflow**.
They are local-only.

### Runtime budget

From `dev/notes/next-session-priorities-2026-05-05.md`:
- `sp500-2019-2023` (5y, 500 sym): ~7–15 min wall time locally (M-series Mac)
- `sp500-2010-2026` (15y, 510 sym): ~7–12 min wall time locally (with #845 panel perf fix)

GHA ubuntu-latest runners are slower than Apple Silicon. Conservative estimates:
- 5y scenario in GHA: ~15–25 min
- 15y scenario in GHA: ~25–45 min
- Total for both: ~40–70 min wall time

GHA limits: 360 min per job on ubuntu-latest. Well within budget.

GHA compute cost (public repo, free minutes tier):
- Public repos: all minutes are free on GitHub-hosted runners
- 5y scenario postsubmit: ~25 min × ~4× merges/day = 100 min/day = ~3000 min/month
- Both scenarios weekly: ~70 min/run × 4 runs/month = 280 min/month
- These are affordable even under the 2000 min/month free private-repo limit (not applicable
  here since the repo is public)

## Storage options (ranked)

### Option A: Plain git (recommended for Phase 1)

Commit trimmed bar data (2009+) for the 500 SP500 symbols under `trading/test_data/`.

**Size**: ~84 MB (trimmed 2009+)
**Pros**: No tooling overhead; works immediately in CI; `git clone` includes the data;
  zero LFS setup; CI jobs just `checkout@v4` and run
**Cons**: Repo size grows by ~84 MB; historical-only symbols add another ~23 MB;
  updating data requires a commit (but EODHD data is append-only so this is monthly
  at most)
**GitHub limit**: GitHub warns at 1 GB repo size; hard limit is 5 GB per file for
  individual files (none of ours exceed 1 MB). Current repo git objects: 6.4 MB.
  After adding 84 MB of CSV data, repo = ~90 MB. Clones become slower but still fast.
**Verdict**: Viable for Phase 1 (5y scenario). Consider LFS if repo exceeds 500 MB.

### Option B: git-lfs

Store bar CSV files in LFS; repo stores pointers.

**Pros**: Keeps main repo lean; well-understood for binary/large files
**Cons**: git-lfs is NOT installed locally or in the devcontainer (`git lfs version` →
  not found); adding it requires devcontainer image update (image.yml rebuild);
  LFS storage is 1 GB free then $5/50GB/month; bandwidth limit is 1 GB/month free
  (public repo CI downloads count); operational complexity (lfs pull in workflows)
**Verdict**: Not recommended for Phase 1. Revisit if repo exceeds 500 MB.

### Option C: Submodule (dayfine/trading-data)

Separate repo for bar data; added as a git submodule.

**Pros**: Clean separation; data updates don't pollute trading-1 history
**Cons**: Every CI job needs `git submodule update --init --recursive`; submodule
  pointer commits add noise; data repo needs separate maintenance; more operational
  overhead than the benefit warrants at this scale
**Verdict**: Not recommended. Over-engineered for 84–107 MB.

### Option D: GHA cache + cron-refreshed download

Download bar data from EODHD API in GHA; cache with `actions/cache`.

**Pros**: No data in repo; always up-to-date
**Cons**: Requires EODHD API key as a GHA secret; API quota cost (~500 symbols ×
  ~6 months of updates = manageable but adds dependency); cache invalidation is
  complex (cache key must include data version); runs fail if cache is cold and API
  is down; adds 2–3 min to cold-run setup time
**Verdict**: Not recommended. Adds external dependency and quota risk.

### Option E: GHA release artifact / tarball

Upload a data tarball to a GitHub release; CI downloads it.

**Pros**: No repo bloat; easy to update independently
**Cons**: Download latency (84 MB tarball = ~1–2 min download on GHA); requires
  token-authenticated download for private release assets (repo is public so this
  is less of an issue); manual update workflow; comparable complexity to LFS
**Verdict**: Not recommended for Phase 1; viable if git size grows uncomfortably.

## Recommended design

### Phase 1: Postsubmit on main only (5y scenario)

Commit trimmed bar data (2009-01-01 onward) for the 500 SP500 symbols.
Add a new `golden-runs-sp500.yml` workflow that runs after every push to main.

**Data commit shape**:
- Destination: `trading/test_data/<first>/<last>/<symbol>/data.csv` (same layout as
  existing test_data fixtures, same format as /data/)
- Cutoff: rows with date >= 2009-01-01 only (covers 5y + 15y scenarios with lookback)
- Size: ~84 MB (500 symbols × ~168 KB average trimmed)
- .gitignore: no change needed (`trading/test_data/` is NOT gitignored)
- EODHD data updates: monthly refresh via ops-data agent + PR; data is append-only

**Workflow shape** (`.github/workflows/golden-runs-sp500.yml`):

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  golden-sp500:
    runs-on: ubuntu-latest
    timeout-minutes: 120
    continue-on-error: true   # visibility-first while soak period runs
    env:
      TRADING_DATA_DIR: ${{ github.workspace }}/trading/test_data
      TRADING_IN_CONTAINER: "1"
    steps:
      - uses: actions/checkout@v4
      - name: Cache _build
        uses: actions/cache@v4
        with:
          path: trading/_build
          key: dune-${{ runner.os }}-${{ hashFiles('...') }}
          restore-keys: dune-${{ runner.os }}-
      - name: Run SP500 5y golden
        run: dev/scripts/golden_sp500_postsubmit.sh
      - name: Publish summary
        if: always()
        run: ... # write to $GITHUB_STEP_SUMMARY
```

**Runner script** (`dev/scripts/golden_sp500_postsubmit.sh`):
- Discovers scenarios with `;; perf-tier: 3` under `goldens-sp500/`
- Runs each via `scenario_runner.exe` with 90 min timeout
- Writes PASS/FAIL table to `dev/perf/golden-sp500-postsubmit-<ts>/summary.txt`
- Mirrors the structure of `perf_tier3_weekly.sh`

**perf_tier3_weekly.sh update** (minor):
- Add `goldens-sp500` to the scan list (line 82 currently excludes it)
- This makes the weekly perf scan also pick up these scenarios once data is committed
- The weekly workflow already has 300 min timeout — adequate

### Phase 2: Presubmit on strategy-touching PRs (future)

After Phase 1 has run for 4+ weeks and established a GHA baseline:

- Add `goldens-sp500` to presubmit with `paths` filter:
  ```yaml
  on:
    pull_request:
      paths:
        - 'trading/trading/backtest/**'
        - 'trading/analysis/weinstein/screener/**'
        - 'trading/trading/weinstein/**'
        - 'trading/test_data/backtest_scenarios/goldens-sp500/**'
  ```
- Gate: `continue-on-error: false` (blocking)
- Timing: 25 min is acceptable for a per-PR check on strategy-touching PRs

### Phase 3: 15y scenario (future)

After Phase 2 is stable:

- Add 217 additional historical-only symbols (trimmed 2009+, ~23 MB)
- Add `goldens-sp500-historical/` to the runner script
- Add `goldens-sp500-historical` discovery to `perf_tier3_weekly.sh`
- 15y scenario runs in the existing weekly slot (postsubmit only, not presubmit —
  too slow for per-PR)

## Implementation plan for Phase 1

### Step 1: Data preparation script

Create `dev/scripts/prepare_ci_data.sh` that:
1. Reads symbols from `trading/test_data/backtest_scenarios/universes/sp500.sexp`
2. For each symbol, finds `/data/<first>/<last>/<symbol>/data.csv`
3. Filters to rows with date >= 2009-01-01
4. Writes to `trading/test_data/<first>/<last>/<symbol>/data.csv`
5. Also copies `data.metadata.sexp` alongside each CSV

This is a one-time setup script (run locally, output committed). It's also useful
for future refreshes when new symbols are added to the SP500 universe.

### Step 2: Runner script

Create `dev/scripts/golden_sp500_postsubmit.sh` (mirrors `perf_tier3_weekly.sh`):
- Scans `goldens-sp500/` for `perf-tier: 3` scenarios
- Uses `TIMEOUT=5400` (90 min per cell)
- Writes to `dev/perf/golden-sp500-postsubmit-<ts>/`

### Step 3: GHA workflow

Create `.github/workflows/golden-runs-sp500.yml`:
- Triggers: `push: branches: [main]` + `workflow_dispatch`
- `continue-on-error: true` (visibility-first for the first month)
- `timeout-minutes: 120`
- Publishes summary to `$GITHUB_STEP_SUMMARY`

### Step 4: perf_tier3_weekly.sh update

Add `goldens-sp500` to the `for sub in ...` loop so the weekly scan also
covers these scenarios (previously omitted by accident).

### Size cap check

Total data to commit: ~84 MB for 500 symbols trimmed 2009+
LOC for scripts + workflow: ~200 LOC
Total well within ≤500 LOC + ≤300 MB committed data scope cap.

## Decision items for user

1. **Cutoff date**: 2009-01-01 covers both 5y and 15y scenarios with margin.
   If the 15y scenario is deferred to Phase 3, we could use 2016-01-01 (~51 MB)
   for Phase 1. Recommend 2009-01-01 to avoid re-trimming when Phase 3 lands.

2. **metadata.sexp**: Each symbol has a `data.metadata.sexp` alongside `data.csv`
   (format: EODHD fetch metadata — date ranges, source, etc.). Should these be
   committed too? They're small (~1 KB each = ~500 KB total) and useful for
   debugging. Recommend: yes, commit them.

3. **continue-on-error**: Start with `true` (non-blocking) for the first month
   while establishing that GHA timing matches local. Flip to `false` after 4
   clean weekly runs with times ≤ 60 min/run. User decides when to flip.

4. **Presubmit timing**: Phase 2 (presubmit on strategy PRs) adds ~25 min to PR
   CI for strategy-touching PRs. User decides whether that's acceptable or whether
   postsubmit-only is sufficient.

## Risk and rollback

- **Data drift**: The committed CSV files are a snapshot. When new EODHD data
  arrives (daily), the CI run uses stale data. This is acceptable — the golden
  is pinned to a fixed universe and fixed expected ranges; the scenario is
  reproducible not real-time. Refresh quarterly or after major data updates.

- **Symbol additions**: If the SP500 universe changes (new symbols added via
  `build_sp500_universe.sh`), the new symbols won't have data in `test_data/`
  until `prepare_ci_data.sh` is re-run and committed. The runner silently skips
  missing symbols (NaN panels), so the scenario still runs — just with fewer
  symbols than expected. Universe size check (`universe_size: 500` in sexp) would
  catch this if it's verified.

- **Size growth**: If the repo grows uncomfortably large (>400 MB), switch to
  git-lfs for the `trading/test_data/[A-Z]/` tree. The CSV format and path layout
  remain unchanged; only the storage backend changes.

- **Rollback**: The data commit is isolated (no code changes). If the approach
  proves unworkable, revert the data commit and update `.gitignore` to exclude
  `trading/test_data/[A-Z]/`.

## Appendix: size verification commands

```bash
# Full SP500 data size
cat trading/test_data/backtest_scenarios/universes/sp500.sexp \
  | grep -o 'symbol [A-Z-]*' | awk '{print $2}' | while read s; do
    first="${s:0:1}"; last="${s: -1}"
    echo "/data/${first}/${last}/${s}"
  done | xargs -I{} du -sh {} 2>/dev/null | sort -h

# Count symbols with data
...
```

## Next steps (if user approves)

1. Run `prepare_ci_data.sh` locally (estimated: 5–10 min wall time for 500 symbols)
2. Verify trimmed data reproduces the golden baseline (`sp500-2019-2023` PASS)
3. Commit data + workflow in a single PR: `harness/ci-golden-runs-postsubmit`
4. Observe first GHA run; measure actual wall time
5. After 4 clean runs: flip `continue-on-error` to `false`
6. File Phase 2 presubmit as a follow-up issue
