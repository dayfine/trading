# Tier-4 release-gate — local-only checklist (2026-04-28)

Operational checklist for running the tier-4 perf release-gate at each
release cut. Tracks the procedure laid out in
`dev/notes/session-followups-2026-04-28.md` §2 and the strategy in
`dev/plans/perf-scenario-catalog-2026-04-25.md` §"Release-gate strategy".

## Why local-only

Tier-4 scenarios target the `Full_sector_map` universe sentinel
(~1000 symbols loaded from `data/sectors.csv` + per-symbol bars under
`data/`). GHA runners do not carry a universe-scale EODHD pull, so the
`Full_sector_map` load fails instantly on any GHA invocation.

The runner size itself is fine: per
`dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`, the
post-engine-pool fit projects N=1000×10y to ~5.7 GB peak RSS, comfortably
inside the 8 GB `ubuntu-latest` ceiling. The blocker is purely data
plumbing.

**Decision**: tier-4 runs locally only. The previous GHA workflow
`.github/workflows/perf-release-gate.yml` was removed (run
[25034915781] showed 4/4 instant-FAIL on universe load). If GHA-side
tier-4 ever becomes desirable, the unblock is data plumbing, not
runner sizing — see "GHA workflow status" below.

## When to run

At each release cut, before tagging `vX.Y.0`. Per the perf-catalog plan
§"Frequency expectations":
- Major (vX.0): full tier-4.
- Minor (vX.Y): tier-3 + tier-4 spot checks.
- Patch (vX.Y.Z): tier-2 delta against last release.
- RC / pre-release: same as major.

## Pre-flight

Verify the local data area contains a fresh universe-scale pull:

- `data/sectors.csv` present and up-to-date with the intended universe.
- `data/<symbol>.csv` (or whatever the configured layout is) covering
  every symbol referenced by `sectors.csv`, with bars current through
  the latest scenario `end_date`.

Refresh via the `ops-data` agent or a manual EODHD pull before
proceeding. A stale universe will produce stale benchmark numbers but
won't fail the run — caller responsibility to confirm freshness.

## Invocation

From the repo root, inside the `trading-1-dev` container:

```sh
docker exec -it trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build trading/backtest/scenarios/scenario_runner.exe && \
   cd .. && dev/scripts/perf_tier4_release_gate.sh'
```

Optional overrides (script reads these env vars):
- `PERF_TIER4_TIMEOUT=14400` — drop the per-cell timeout from 8 h to 4 h.
- `PERF_TIER4_OCAMLRUNPARAM=...` — replace the `o=60,s=512k` GC tuning.

The script discovers all scenarios tagged `;; perf-tier: 4` under
`trading/test_data/backtest_scenarios/{goldens-small,goldens-broad,perf-sweep,smoke}/`
and runs each under `/usr/bin/time -f '%M'` with the timeout wrapper.

## Capture

Output lands under `dev/perf/tier4-release-gate-<UTC-timestamp>/`:
- `<scenario>.log` — `scenario_runner` stdout + stderr.
- `<scenario>.peak_rss` — peak RSS in kB (GNU /usr/bin/time `%M`).
- `<scenario>.wall_sec` — real wall-time in seconds.
- `<scenario>.error` — present iff the run failed or timed out.
- `summary.txt` — aggregate PASS/FAIL table; this is the artefact to
  archive against the release tag.

For release archival, copy the run's directory to a tagged location:
`dev/perf/release-vX.Y/tier4-<timestamp>/`. Optional but recommended so
the next release's comparison run has a stable prior snapshot.

## Comparison

Compare current vs. prior release output dirs with the
`release_perf_report` exe:

```sh
docker exec -it trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build trading/backtest/bin/release_perf_report.exe && \
   _build/default/trading/backtest/bin/release_perf_report.exe \
     --current  /workspaces/trading-1/dev/perf/tier4-release-gate-<NEW>/ \
     --previous /workspaces/trading-1/dev/perf/release-v<X.Y-1>/tier4-<...>/'
```

Source: `trading/trading/backtest/bin/release_perf_report.ml`. PR #629
landed the OCaml exe; PR #651 integrated trade-audit ratings into its
output.

## Decision

Go / no-go on the release based on the report:

- **Go**: trading + infra metrics within `(expected ...)` and
  `(perf_expected ...)` ranges in each tier-4 `goldens-broad/*.sexp`.
  Optionally tighten the `expected` ranges in the same commit if the
  variance over the last several runs warrants it.
- **No-go**: any cell outside its declared range. Investigate as
  either (a) genuine regression — block the tag, fix or revert; or
  (b) intentional behavior change — update the ranges with explicit
  justification in the commit message before re-cutting.

## GHA workflow status

`.github/workflows/perf-release-gate.yml` was removed on 2026-04-28
(see PR for this checklist's update). It exited in 0–1s on every run
and produced no useful signal.

If GHA-side tier-4 ever becomes desirable, the unblock is data
plumbing, not runner sizing: either (a) host the universe-scale data
on a runner-accessible volume, or (b) plumb a streaming data source
(`dev/plans/daily-snapshot-streaming-2026-04-27.md`) so the runner
does not need a full local mirror. At that point, reconstruct the
workflow shape from `dev/scripts/perf_tier4_release_gate.sh`.

## SCALE cells (broad × 10y) — revised 2026-05-03 (afternoon)

The N=1000 cells covered above use the CSV-mode loader and run via
`dev/scripts/perf_tier4_release_gate.sh`. The SCALE cell at FULL broad
universe (~10,472 symbols from `data/sectors.csv`) × 10y is tagged
`;; perf-tier: 4-scale` and runs via a separate runner:
`dev/scripts/run_tier4_release_gate.sh`.

Single SCALE cell (the earlier N=5000 / N=10000 sub-cells from #810
were obsoleted — broad sentinel's actual size = ~10k already, no value
in two cap variants):
- `goldens-broad/tier4-broad-10y.sexp`  (10y × full broad, 2014-2023)

Snapshot mode is mandatory: CSV-mode formula upper bound is
~28 GB peak RSS for this cell, far beyond any single runner.
Snapshot mode (Phase E §F3) caps RSS at the configured `max_cache_mb`
(~50-200 MB) — this is what makes it feasible on the 8 GB local box.

### Data coverage gate (BLOCKER as of 2026-05-03)

`data/sectors.csv` lists 10,472 symbols but **only ~5% of them have
local CSV bars on disk** (518/10,472 verified by
`dev/scripts/check_broad_universe_coverage.sh` 2026-05-03 19:00Z).
Running tier4-broad-10y today would produce a ~95%-skipped run with
no measurable trading metrics + RSS that doesn't reflect real load.

**Pre-flight gate** (must hit before running the cell):
```sh
bash dev/scripts/check_broad_universe_coverage.sh --threshold-pct 90
```
Should report `broad-universe-coverage: ≥9425/10472 = ≥90%` and exit 0.

The unblock is **ops-data dispatch**: bulk-fetch the missing ~9,954
symbols via EODHD using the existing `fetch_symbols.exe` against the
sectors-csv-derived list. Estimated wall: 30-60 min depending on
EODHD rate limits. Filed as data-gap entry in
`dev/notes/data-gaps.md` §broad-universe-coverage.

### Pre-flight (post-coverage-fix, in addition to the N=1000 pre-flight above)

- Coverage gate (above) must report ≥90%
- The full-broad snapshot corpus must be pre-built under
  `data/snapshots/<schema-hash>/`. F.2's auto-build path materializes
  this on first invocation but the initial build is multi-minute at
  scale; expect to schedule the corpus build separately from the gate run.
- `expected` ranges in `tier4-broad-10y.sexp` are intentionally
  permissive (BASELINE_PENDING_AFTER_FIRST_RUN). First run produces
  the canonical baseline; tighten ranges via follow-up PR.

### F.3 unblock chain

This SCALE run is the prerequisite for **F.3 deletion of `Bar_panels.t`**
(per `dev/plans/snapshot-engine-phase-f-2026-05-03.md` §F.3):
  1. Coverage ≥90% (ops-data fix)
  2. Snapshot corpus built for full broad
  3. tier4-broad-10y run completes; RSS confirmed cache-bounded ~50-200 MB
  4. F.3 deletion safe to ship

Invocation (dry-run first to confirm discovery):

```sh
docker exec -it trading-1-dev bash -c \
  'cd /workspaces/trading-1 && dev/scripts/run_tier4_release_gate.sh --dry-run'

# When ready:
docker exec -it trading-1-dev bash -c \
  'cd /workspaces/trading-1 && dev/scripts/run_tier4_release_gate.sh'
```

Output dir: `dev/perf/tier4-scale-<UTC-timestamp>/` (separate from the
N=1000 release-gate's `dev/perf/tier4-release-gate-<UTC-timestamp>/`).

## References

- `dev/notes/session-followups-2026-04-28.md` §2 — full problem
  statement that this checklist resolves.
- `dev/plans/perf-scenario-catalog-2026-04-25.md` §"Release-gate
  strategy" — strategy this implements operationally.
- `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md` —
  source for the "8 GB at N=1000 fits" finding (and 24-47 GB
  CSV-mode upper bounds for the SCALE cells).
- `dev/plans/snapshot-engine-phase-f-2026-05-03.md` — F.2 default-flip
  and the cache-bounded snapshot-mode RSS context for SCALE cells.
- `dev/scripts/perf_tier4_release_gate.sh` — the N=1000 runner script.
- `dev/scripts/run_tier4_release_gate.sh` — the N=5000 / N=10000
  SCALE runner script.
- `trading/trading/backtest/bin/release_perf_report.ml` — comparison
  exe (built via `dune build trading/backtest/bin/release_perf_report.exe`).
