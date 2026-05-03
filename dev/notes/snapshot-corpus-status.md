# Snapshot Corpus Status

Last updated: 2026-05-03 (initial — no refresh has run yet)
Status: NOT_STARTED
Universe: data/sectors.csv (10,472 symbols)
Output dir: dev/data/snapshots/broad-2014-2023/
Cycles done: 0/10472
ETA: ~2h cold-cache wall (post-#792 writer); ~4 dispatches at --max-wall 30m

## How this file is updated

This ledger is rewritten by every `ops-data` snapshot-refresh dispatch.
The runbook is at `dev/notes/snapshot-corpus-runbook-2026-05-03.md`.

`Status` field values (one of):

- `NOT_STARTED` — output dir does not exist yet; no manifest on disk.
- `PARTIAL` — manifest has some entries but the freshness probe still
  reports `stale% > 5`. The next dispatch resumes at the next pending
  symbol (per-symbol manifest writer, PR 1 / #819).
- `FRESH` — last freshness probe reported `stale% ≤ 5`. Corpus is
  ready for backtest reads.
- `STALE` — the manifest is intact but a CSV refresh has invalidated
  enough symbols to push the probe above threshold. Run the wrapper.

## Last refresh

(none — file initialized 2026-05-03 alongside automation PR 3/4)

<!--
Future entries land here as a level-3 list. Example shape (filled by
ops-data dispatches):

- Started: 2026-05-04T14:00:00Z
- Wall: 28m12s
- Symbols built: 1,243 (cycles 0 → 1243)
- Failures: 2 (csv parse error: <list>)
- Exit code: 124 (max-wall reached)
- Post-probe freshness: 76% stale (was 100%)
- Notes: cold cache; 3 more dispatches at --max-wall 30m to reach FRESH
-->

## History

(empty)
