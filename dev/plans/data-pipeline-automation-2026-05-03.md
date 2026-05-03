# Data Pipeline Automation — Checkpointing + Incremental Refresh + Audit (2026-05-03)

Date: 2026-05-03. New track. Local-only automation for the long-running data
pipeline (snapshot corpus build, backtest runs). Owns the `data-pipeline-automation`
track under `data-foundations`.

Authority: this plan; companion to `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md`
(historical universe), `dev/plans/m7-data-and-tuning-2026-05-02.md` §M7.0 Track 1
(Norgate), and `.claude/agents/ops-data.md` (operational dispatch).

## Status / Why

**NOT STARTED.**

Two pieces of user feedback (verbatim, this session):

1. *"For these long running process, including both simulation and snapshot
   generation, it could be helpful if they dump checkpoints from time to time,
   so it's easier to gauge process, and potentially recover from failure."*
2. *"GHA doesn't work as we don't check in data directory, but the automation
   should be more comprehensive (and the audit / improvements should be
   ongoing)."*

These map to three concrete gaps in today's pipeline:

| Gap | Today | After |
|---|---|---|
| Snapshot build progress | No log lines until end (~2hr wall, broad×10y, 10,472 symbols) | `progress.sexp` updated every N symbols; tail-able from any shell |
| Snapshot build resume | `--incremental` reads the manifest written **only at the end**; crash mid-run loses everything | Manifest updated atomically per symbol → `--incremental` resumes from any interrupt |
| Local refresh automation | One-shot manual fetch dispatched via `ops-data`; no incremental wrapper | `dev/scripts/build_broad_snapshot_incremental.sh` + freshness audit script |

Why local-only: `data/` is gitignored; GHA runners never have the bar-data
tree. The release-gate workflow already documents the local constraint
(`dev/notes/tier4-release-gate-checklist-2026-04-28.md`). Cron / launchd is
the user's responsibility — this plan ships the building blocks, not the
schedule entries.

Cross-track impact:
- M5.x backtest scenarios pick up faster iteration on broad×10y once
  snapshot rebuild is interruptible.
- M7.0 Track 1 (Norgate) ingestion will reuse the same checkpoint pattern
  when it lands; the manifest-per-symbol contract is vendor-agnostic.
- ops-data dispatch (`.claude/agents/ops-data.md`) gains a `--snapshot-refresh`
  recipe in PR 3.

## Scope

**In:**

- `progress.sexp` emission from `build_snapshots.exe` — atomic append every
  N symbols (default 50), recording total / done / last-symbol / timestamps.
- Per-symbol manifest update — `Snapshot_manifest.update_for_symbol`
  rewrites `manifest.sexp` after each `.snap` file lands. Resume becomes
  free.
- `dev/scripts/build_broad_snapshot_incremental.sh` — wrapper invoking
  `build_snapshots.exe --incremental` with `--max-wall <duration>` so a
  single cron tick doesn't run forever. Default 60min wall; the wrapper
  respects checkpoint state across invocations.
- `dev/scripts/check_snapshot_freshness.sh` — reports per-symbol staleness
  (CSV mtime > snapshot mtime → stale). Usable as a pre-flight gate before
  release-gate scenarios.
- ops-data dispatch entry-point: a paragraph in `.claude/agents/ops-data.md`
  documenting `--snapshot-refresh` use cases.
- A note doc covering local cron / launchd patterns (PR 4) so the user can
  wire the wrapper into their schedule.

**Out:**

- `cron` / launchd plist files themselves — user-side concern; per-host.
- GHA workflow integration — `data/` is gitignored; this is local-only by
  design.
- Backtest *progress streaming* (Friday-by-Friday TUI). Plan covers basic
  `progress.sexp` only; richer dashboards deferred.
- Norgate-specific resume logic. Manifest update is vendor-agnostic; the
  Norgate ingest CLI (M7.0 Track 1) reuses the contract when it ships.
- Schema versioning for `progress.sexp`. The format is stable per the .mli
  contract; if it needs to evolve, a `version` field can be added.

## Architecture

### Data flow today (broken on interrupt)

```
build_snapshots.exe
  ├─ load universe sexp
  ├─ for each symbol s:
  │    ├─ read CSV, run pipeline
  │    └─ write <out>/s.snap                 ← per-symbol durable
  └─ write <out>/manifest.sexp               ← END of run only ✗
```

If the process is killed at symbol 8000/10472, all 8000 `.snap` files exist
but the manifest is empty → `--incremental` on restart finds no entries →
re-builds everything from scratch.

### Data flow after PR 1

```
build_snapshots.exe
  ├─ load universe sexp
  ├─ load existing manifest (if --incremental)
  ├─ for each symbol s:
  │    ├─ read CSV, run pipeline
  │    ├─ write <out>/s.snap
  │    └─ Snapshot_manifest.update_for_symbol      ← atomic, per-symbol
  │       (read manifest.sexp, replace s entry, atomic-rename write)
  ├─ every N symbols (default 50):
  │    └─ write <out>/progress.sexp                ← atomic
  └─ done.
```

After interrupt at symbol 8000/10472: restart with `--incremental` → manifest
shows 8000 entries → only 2472 symbols rebuilt.

### Sub-modules

| File | Role |
|---|---|
| `build_snapshots.ml` | Add atomic-per-symbol manifest update; emit `progress.sexp` every N symbols |
| `snapshot_manifest.ml/.mli` | Add `update_for_symbol` function (atomic single-symbol upsert) |
| `dev/scripts/build_broad_snapshot_incremental.sh` | Wrapper: `--max-wall`, `--batch-size`, `--universe`, `--output-dir`, `--dry-run` |
| `dev/scripts/check_snapshot_freshness.sh` | Per-symbol staleness probe; stale = CSV mtime > snapshot mtime; emits a list usable by ops-data |

### Files to touch

PR 1 (this plan):

- `trading/analysis/scripts/build_snapshots/build_snapshots.ml` (extend)
- `trading/analysis/weinstein/snapshot_pipeline/lib/snapshot_manifest.ml/.mli` (extend)
- `trading/analysis/weinstein/snapshot_pipeline/test/test_snapshot_manifest.ml` (extend)
- `dev/scripts/build_broad_snapshot_incremental.sh` (NEW)
- `dev/scripts/check_snapshot_freshness.sh` (NEW)

PR 2: backtest checkpointing
- `trading/analysis/scripts/backtest_runner/backtest_runner.ml` (extend)
  — add `progress.sexp` emission + `--resume-from` flag
- New `Backtest_progress` module under
  `trading/analysis/scripts/backtest_runner/lib/` if reusable

PR 3: ops-data dispatch entry
- `.claude/agents/ops-data.md` (extend §"Data scripts" with snapshot-refresh)
- `dev/notes/data-pipeline-runbook-2026-05-03.md` (NEW) — runbook covering
  freshness probe, incremental rebuild, full rebuild

PR 4: local-cron / launchd recipes
- `dev/notes/local-automation-2026-05-03.md` (NEW) — crontab + launchd
  patterns; user wires their host

## Sub-PRs

Four sub-PRs, ~700 LOC total. Each independently mergeable.

### PR 1 — snapshot build checkpointing + incremental wrapper (~300 LOC, this PR)

See §Acceptance below.

### PR 2 — backtest checkpointing (~250 LOC)

`backtest_runner.exe` extension:

- Emit `progress.sexp` every Friday cycle to the run output directory
  (records: `{cycles_done; total_cycles; last_friday; portfolio_value;
  open_positions; started_at; updated_at}`).
- New `--resume-from <path>` flag — load `progress.sexp` and skip cycles
  prior to `last_friday`. Idempotent on restart.
- Test coverage: 3+ unit tests for the `Backtest_progress` module + smoke
  resume test in the runner.

Acceptance: kill `backtest_runner.exe` mid-run, restart with
`--resume-from <out>/progress.sexp`; the second run completes only the
remaining Fridays and the final ledger matches a non-interrupted reference
run within tolerance.

### PR 3 — ops-data dispatch + runbook (~100 LOC + doc)

Extend `.claude/agents/ops-data.md` with:

- §"Snapshot refresh" subsection (mirrors §"Fetch symbols" / §"Rebuild inventory"
  shapes): "When CSV mtimes have advanced for ≥N symbols, run
  `dev/scripts/build_broad_snapshot_incremental.sh --max-wall 60m`.
  Confirm via `dev/scripts/check_snapshot_freshness.sh`."
- Standard workflow extension: snapshot freshness as a step 6 in the
  fetch+refresh sequence.

`dev/notes/data-pipeline-runbook-2026-05-03.md` (NEW): the canonical runbook.
Covers what to do when the freshness probe reports >5% stale, how to
recover from a partial run, when to fall back to a full rebuild.

### PR 4 — local-cron / launchd recipes (~50 LOC + doc)

`dev/notes/local-automation-2026-05-03.md`: example crontab entry +
launchd plist (macOS) for invoking the incremental wrapper nightly. Warns
against running concurrent invocations (file-lock pattern in PR 1's wrapper
prevents two concurrent runs).

## Open questions

1. **Checkpoint format — sexp vs json.** Choosing sexp for consistency with
   `manifest.sexp` and the existing `Status.status_or` ergonomics. The
   downside is that ad-hoc shell tooling needs `sexp print` (available in
   the dev container) rather than `jq`. Net: sexp wins because the only
   consumers are OCaml + a handful of shell scripts, and we already write
   sexp manifests.
2. **Mid-symbol-build atomicity.** `Snapshot_format.write` is a single
   `Out_channel.write_all` so each `.snap` file is written atomically by
   POSIX semantics on local FS. The risk is `.snap` being written but
   `manifest.sexp` not yet updated → orphan `.snap` file with no manifest
   entry. Resolution in PR 1: write `.snap` first, then update manifest;
   on interrupt, an orphan `.snap` is harmless (re-built next run) and
   `--incremental` correctly skips only symbols whose manifest entry
   matches the current CSV mtime. Manifest writes go via temp file +
   atomic rename to prevent torn writes.
3. **`progress.sexp` write frequency.** Default N=50 (~2.4% of broad×10y);
   trade-off is verbosity vs. write overhead. Each `progress.sexp` write
   is small (~200 bytes); 200 writes over a 2hr run is negligible. Make
   it configurable via `--progress-every <N>` flag.
4. **Backtest-side checkpointing scope.** Sized for PR 2: cycle-level
   only (one entry per Friday). Not bar-level — that would be too
   verbose. Discussion ongoing whether to also dump the full portfolio
   state on interrupt for cross-run replay; deferred until M5.x asks for
   it.
5. **Concurrent rebuild detection.** Two concurrent
   `build_broad_snapshot_incremental.sh` invocations would race on
   manifest writes. PR 1's wrapper takes a flock on
   `<output-dir>/.build.lock`; second invocation exits with code 75
   (POSIX `EX_TEMPFAIL`). Documented in the wrapper's `--help`.

## Acceptance — PR 1 (this PR)

Measurable, end-to-end:

1. **Atomic per-symbol manifest update**: `build_snapshots.exe` calls
   `Snapshot_manifest.update_for_symbol` after each `.snap` write. The
   manifest at `<out>/manifest.sexp` is well-formed at every observable
   moment (atomic rename via temp file).
2. **Resume on interrupt**: a unit test simulates an interrupt mid-run by
   manually invoking `update_for_symbol` for K of N entries, then a
   second `build_snapshots.exe --incremental` run only rebuilds the
   missing N-K. Verified by counting pipeline calls (mocked) or by
   reading the manifest entry count after each invocation.
3. **`progress.sexp` emission**: `build_snapshots.exe --progress-every
   25` writes a `progress.sexp` after every 25th symbol with
   well-formed `{symbols_done; symbols_total; last_completed;
   started_at; updated_at}`. Tail-able mid-run.
4. **`build_broad_snapshot_incremental.sh --dry-run` works**: prints the
   exact `build_snapshots.exe` invocation it would run, without doing
   it. Includes `--max-wall`, `--universe`, `--output-dir`, `--batch-size`
   resolution.
5. **`check_snapshot_freshness.sh` reports correctly**: given a fixture
   manifest with K stale entries (CSV mtime > snapshot manifest's
   `csv_mtime`), reports `K stale / N total`. Exit 0 always; the gate
   is in the wrapper, not the probe.
6. **All tests green**: `dune build && dune runtest` passes; new tests
   under `test_snapshot_manifest.ml` cover the `update_for_symbol`
   function (3+ cases: insert new, replace existing, atomic-rename
   semantics).

## Cross-links

- **Wiki+EODHD historical universe** — `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md`.
  PR-A through PR-D landed today; broad universe coverage is 100%; the
  ~2hr snapshot rebuild is the next bottleneck.
- **Tier-4 release gate checklist** — `dev/notes/tier4-release-gate-checklist-2026-04-28.md`
  notes the local-only constraint and explicitly mentions snapshot
  rebuild as a manual step. After PR 1, the snapshot step becomes
  cron-runnable.
- **ops-data agent** — `.claude/agents/ops-data.md` will gain a
  snapshot-refresh recipe in PR 3.
- **qc-structural A2 boundary** — all feature code lives under
  `analysis/scripts/` and `analysis/weinstein/snapshot_pipeline/`. Wrapper
  + probe scripts are under `dev/scripts/`. No `trading/trading/` writes.
  A2 PASS by construction.
- **qc-behavioral** — pure infra/data-ops PR. CP1–CP4 only; the
  Weinstein-domain S*/L*/C*/T* checklist is NA per
  `.claude/rules/qc-behavioral-authority.md` ("pure infra / harness /
  refactor PR; domain checklist not applicable").
- **No Python** — wrapper + probe scripts are POSIX sh; OCaml-only for
  manifest extension. Per `.claude/rules/no-python.md`.
