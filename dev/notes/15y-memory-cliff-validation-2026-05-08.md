# 15y memory cliff — validation results (2026-05-08)

Investigation note: `dev/notes/15y-memory-cliff-2026-05-08.md` (PR #987).

## Fixes landed

| PR | Fix | Estimated savings |
|----|-----|-------------------|
| #988 | Fix C — stream `Csv_snapshot_builder` per-symbol | ~195 MB |
| #992 | Fix A — dedupe `Daily_panels` LRU caches | ~330 MB |
| #993 | Fix B — project `step_result.portfolio` to skinny summary | ~3 GB |

Plus:
- #991 — pinned opam-repository commit SHA (permanent ocamlformat skew fix).
- #995 — added missing `*_check.sh` deps to 3 dune test rules (red-main fix surfaced by Fix A merge cache invalidation).

## Validation run

Triggered manually via `golden-runs-sp500-15y.yml` workflow_dispatch on 2026-05-08T15:15:39Z.

- Run URL: https://github.com/dayfine/trading/actions/runs/25563499778
- Scenario: `sp500-2010-2026.sexp` (15-year, 510 symbols, vanilla Weinstein)
- Started: 2026-05-08T15:17:33Z
- Completed: 2026-05-08T16:14:44Z

## Results

| | Pre-fix (CI run 25537688503) | Post-fix (CI run 25563499778) | Change |
|---|---|---|---|
| Peak RSS | 11.4 GB | **1.95 GB** | **5.8× reduction** |
| Wall | 2577s (43 min) | 3426s (57 min) | +33% |
| Outcome | FAIL (OOM kill) | FAIL (scenario assertion) | run completes |
| Status | OOM partway | Full run, exits non-zero on assertion | mem fix works |

## Interpretation

**Q1 memory cliff is fixed.** Peak RSS dropped from 11.4 GB (OOM on 8 GB GHA runner) to 1.95 GB — within a 16 GB headroom. The investigation note's prediction (~900 MB post-fix) was a bit optimistic — actual is ~2 GB, consistent with:

- 5y baseline RSS was 766 MB → 15y at ~2 GB is reasonable scaling for the resident bar panel + final portfolio + bounded step_history.
- Per-step skinny projection makes step_history × time bounded but still O(time × universe-size).

**Wall increased** because the pre-fix run was OOM-killed at 43 min before completing all metrics + writers. The post-fix 57 min represents the full run.

**Outstanding scenario FAIL** is a separate issue — non-zero exit from `scenario_runner` after the run completes. Possible causes:

1. Expected-return assertion in the scenario fixture doesn't match new numbers (skinny projection numerical drift).
2. Stale assertion that was masked by the prior OOM (we never saw a successful 15y run before, so the assertion was never validated).
3. An unrelated bug in 15y scenario tail-end.

The `dev/perf/golden-sp500-postsubmit-*/sp500-2010-2026.log` artefact has the actual scenario error message but isn't uploaded by the workflow. To investigate: run the 15y scenario locally inside container with full stderr capture.

## Follow-up

- Fetch the scenario error log (run locally or upload artefact in workflow).
- Pin a 15y baseline via golden scenario or status entry once the assertion is sorted.
- Q3 (Cell A-E perf measurement) can now resume — 15y memory is no longer a blocker.
- Promote `golden-runs-sp500-15y.yml` from cron back to per-push once 15y reliably completes within budget AND assertion passes.
