# Snapshot corpus refresh runbook (2026-05-03)

User-facing runbook for keeping the broad-universe daily-snapshot corpus
fresh. Backtests at tier-3 / tier-4 read from this corpus via
`--snapshot-mode --snapshot-dir <output-dir>`; if the corpus lags the
underlying CSV bars, scenario results are silently stale.

This runbook is the canonical companion to the ops-data §"Snapshot corpus
refresh" subsection in `.claude/agents/ops-data.md`. The plan that scopes
the automation work is `dev/plans/data-pipeline-automation-2026-05-03.md`
(this is PR 3/4 of that track; PR 4 will add cron / launchd recipes).

## When to dispatch

Trigger an `ops-data` dispatch with a snapshot-refresh prompt when **any**
of the following apply:

- Broad-universe backtests (tier-3 / tier-4 scale) are about to be run
  and the freshness probe reports `stale% > 5`. Default threshold; tune
  per scenario.
- A first-time corpus build is needed (the output dir does not yet
  exist, or `manifest.sexp` is missing). The wrapper handles a cold
  cache the same as a stale one — it just takes longer.
- A bulk CSV refresh has just completed (e.g. ops-data fetched a
  thousand symbols' bars). The corpus is now stale by construction.
- `dev/notes/snapshot-corpus-status.md` shows `Status: PARTIAL` with a
  recent partial run — pick up where the previous dispatch left off.

Skip if `Status: FRESH` and the last refresh was within the last 24
hours and no CSV refresh has happened since.

## Dispatch prompt template

Paste this (with the placeholders filled in) when asking the orchestrator
to run `ops-data`:

```
Refresh the broad-universe snapshot corpus.

- Universe: <path-to-pinned-universe-sexp>
  (default: bootstrap from data/sectors.csv if no pinned sexp exists)
- Output dir: dev/data/snapshots/broad-2014-2023/
- CSV data dir: data
- Max wall: 30m
- Progress every: 50

Steps:
1. Run dev/scripts/check_snapshot_freshness.sh --output-dir <output-dir>.
   If stale% < 5, record FRESH in dev/notes/snapshot-corpus-status.md
   and exit clean.
2. Otherwise run dev/scripts/build_broad_snapshot_incremental.sh
   with the inputs above.
3. Re-run the freshness probe and append a "Last refresh" block to
   dev/notes/snapshot-corpus-status.md.

Report the final freshness%, exit code, wall time, and whether the
corpus is FRESH or PARTIAL after this dispatch.
```

The dispatch is single-pass: the agent does not loop on the wrapper
within one session. A `--max-wall 30m` ceiling means a cold-cache build
of the full broad×10y corpus (~10,472 symbols, ~2h) takes ~4 dispatches
to complete, each picking up where the previous left off via the
per-symbol manifest writer (PR 1, #819).

## Expected outcomes

| Outcome | Status file value | Next action |
|---|---|---|
| Probe reports `stale% < 5`, no rebuild needed | `FRESH` | None — corpus is good for backtests |
| Wrapper exits 0, post-probe `stale% < 5` | `FRESH` | None — corpus rebuilt to current |
| Wrapper exits 124 (max-wall hit), post-probe `stale% > 5` | `PARTIAL` | Re-dispatch later; resume continues at next symbol |
| Wrapper exits 75 (`EX_TEMPFAIL`, lock held) | unchanged | Wait for the other run to finish; do not run concurrently |
| Wrapper exits 1 (build/setup error) | `STALE` | Inspect `dev/logs/snapshot-build-<date>.log`; fix root cause; re-dispatch |

The wrapper writes `dev/logs/snapshot-build-YYYY-MM-DD.log` on every run;
that file is the source of truth for failure diagnosis.

## Reading `dev/notes/snapshot-corpus-status.md`

The status file is the lightweight ledger updated by every refresh
dispatch. Layout:

- **Header block** — `Last updated`, `Status`, `Universe`, `Output dir`,
  `Cycles done`, `ETA`. The `Status` value is one of `NOT_STARTED`,
  `PARTIAL`, `FRESH`, `STALE`. Use this for at-a-glance assessment.
- **Last refresh** — most recent dispatch outcome: `Started`, `Wall`,
  `Symbols built`, `Failures`, `Exit code`, `Post-probe freshness%`.
- (Optional) **History** — older dispatches, oldest at bottom. Trim if
  the file gets long; the on-disk manifest is the durable source of
  truth.

Bash one-liners that consume this file are not needed; it's primarily
for human inspection. Programmatic consumers should read the manifest
directly via `Snapshot_manifest.read` or the on-disk
`<output-dir>/progress.sexp`.

## Failure-mode quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Probe exits 2 with "manifest not found" | First-time build, or output dir is wrong | Confirm `--output-dir`; if first-time, run the wrapper with no probe gate |
| Probe exits 1 with `stale% > threshold` | Bulk CSV refresh occurred since last build | Run the wrapper |
| Wrapper exits 75 immediately | A previous run is still alive holding `.build.lock` | `ps aux \| grep build_snapshots`; wait or kill the orphan |
| Wrapper exits 1 with "build target not found" | `_build` is stale | `cd trading && eval $(opam env) && dune build analysis/scripts/build_snapshots/` |
| Wrapper exits 124, post-probe still high | Wall budget too small for current backlog | Either raise `--max-wall` for the next dispatch or run more dispatches |

## When to fall back to a full rebuild

Rare. The incremental path handles every common case (CSV refresh,
schema drift, partial completion). Force a full rebuild only when:

- The schema hash changed (`Snapshot_format` evolved). The runtime
  layer refuses to mmap files with the wrong hash, so the manifest is
  effectively invalidated. Delete the output dir and rebuild from
  scratch via the same wrapper.
- The on-disk manifest is corrupt (parse error in
  `Snapshot_manifest.read`). Same fix: delete + rebuild.

A full broad×10y rebuild is ~2h wall under the post-#792 writer
(O(N²)→O(N) speedup). Plan for ~4 × 30min dispatches if you can't
spare an uninterrupted window.

## Future automation (deferred — PR 4 of the track)

PR 4 of `dev/plans/data-pipeline-automation-2026-05-03.md` will add
example crontab entries + launchd plists so the wrapper runs nightly
without explicit dispatch. Until that lands, every refresh is
operator-triggered via this runbook.
