---
name: project_build_snapshots_incremental_clobbers_manifest
description: "build_snapshots.exe -incremental rewrote manifest.sexp with ONLY the symbols processed in that run (a 1-symbol GSPC.INDX top-up left a 2,208-snap warehouse with a 1-entry manifest; the runner enumerates via the manifest, so the warehouse read as empty). Issue #2669 — FIXED by PR #2724 (2026-09-08): the incremental path now merges into the pre-run manifest, so the 'never top up with -incremental' rule is superseded. Keep the manifest-vs-.snap count tripwire; a full non-incremental rebuild over a superset universe is still how you prune symbols or re-derive markers."
metadata:
  type: project
  modified: 2026-09-08
---

**What happened (2026-09-04).** Built `/tmp/snap_top3000_2019` (2,208 snaps)
and `/tmp/snap_top3000_2009` (2,032) from the CSV store, then ran a
`-incremental` pass over a one-symbol universe to add the `GSPC.INDX`
benchmark snap. The log said `wrote 1 entries to manifest.sexp` — the
manifest was REPLACED, not merged; both warehouses were unusable
(`Bar_source_resolver` reads `manifest.sexp` to enumerate symbols).
Filed as **#2669**.

**SUPERSEDED IN PART — 2026-09-08, PR #2724.** The defect itself is fixed:
`-incremental` now MERGES this run's entries into the pre-run manifest
instead of replacing it, so a partial-universe top-up keeps every untouched
symbol (an entry whose `.snap` is gone is dropped; a pre-run manifest under
a different `schema_hash` is refused whole; both are logged). **The
"never top up with `-incremental`" workaround below no longer applies** —
a one-symbol top-up over an existing warehouse is now the supported shape,
and the ~12–22-min full non-incremental rebuild per vintage is no longer
required just to add a benchmark ticker. Everything else here still stands,
in particular the manifest-vs-`.snap` count tripwire (it catches a partial
build, not only this bug) and the superset-file shape recipe (a full
rebuild is still the way to PRUNE symbols and to re-derive `active_through`
markers across the whole warehouse — a carried entry keeps the marker its
own build derived).

**Rules.**
- ~~Never top up a warehouse with `-incremental` over a partial universe.
  Rebuild non-incrementally over a **superset** universe file.~~
  **Superseded by #2724** (see above): `-incremental` over a partial
  universe is safe. A full non-incremental rebuild over a superset file
  remains the way to prune symbols or re-derive markers warehouse-wide.
- The composition files (`goldens-custom-universe/composition/top-3000-<v>.sexp`)
  are NOT the plain `(Pinned (...))` shape (they carry per-symbol metadata and
  an `aggregate_period_return` tail); build the superset by extracting
  `(symbol X)` and emitting `(Pinned ( ((symbol X) (sector "Unknown")) ... ((symbol GSPC.INDX) (sector "Index")) ))`
  — the shape the 2000-vintage warehouse was built from
  (`/tmp/sweeps/wr-universe-superset.sexp`).
- Core `Command` exes take single-dash flags (`-universe-path`); `--` dies in 1 s.
- Check `grep -c '(symbol ' <dir>/manifest.sexp` against the `.snap` count
  before pointing any chain at a warehouse.

**Vintage warehouse build recipe (works):** pinned worktree exe,
`-universe-path <superset.sexp> -csv-data-dir /workspaces/trading-1/data
-output-dir /tmp/snap_top3000_<v> -benchmark-symbol GSPC.INDX -start-date
<v-1>-01-01 -end-date <today>`; ~12 min for 2,200 names, ~22 min for the
2009 vintage. `-emit-weekly-sidetable` is a deprecated no-op (the `.weekly`
side-tables are always written).

Related: [[project_warehouse_vintage_coverage]], [[project_snapshot_format_v2]].
