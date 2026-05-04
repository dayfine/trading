# Status: hybrid-tier

## Last updated: 2026-05-04

## Status
MERGED — both options shipped; no active work in this track

Phase 1 (measurement infra) merged (#609). Phase 2 was replanned via
PR #611 into two separate plans after Phase 1 results showed the
original 3-tier design wouldn't move RSS. Both options have shipped:

- **Option 1: Engine-layer pooling** — DONE 2026-04-28. Five PRs
  (#618 instrumentation, #626 Scratch type, #628 thread per-tick,
  #632 buffer pool, #633 matrix re-run). β: 4.30 → 3.94 MB/symbol
  (−8%, short of the 1-1.5 plan target). Wall: −36% at 292×6y.
  N=1000×10y now fits 8 GB.
- **Option 2: Daily-snapshot streaming** — DELIVERED via the
  `data-foundations` track's **M5.3 streaming** sequence (Phases
  A–F.2 merged 2026-05-02..03 across PRs
  #779/#781/#782/#786/#790/#791/#792/#793/#797/#800/#802; F.3
  retirement of `Bar_panels.t` in flight as of 2026-05-04 with F.3.a
  COMPLETE via #825/#827/#828/#829). Snapshot mode is now the
  canonical runtime path; tier-4 release-gate at N≥5,000 is
  structurally unblocked. Continuing snapshot work tracked under
  `dev/status/data-foundations.md`.

Track flips to MERGED. Future deliverables route to
`data-foundations` (snapshot infra), `backtest-perf` (release-gate
verification), or open as their own tracks.

Phase 1 results (retained for reference):
`dev/notes/hybrid-tier-phase1-results-2026-04-27.md`. Engine-pool
matrix re-run: `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`.

## Interface stable
NO

Phase 1 is doc + measurement infra only. The hybrid-tier
data-structure interface (`Tiered_panels.t`) is Phase 2 and not
introduced in this track yet. The Phase 1 surface — `Backtest.Gc_trace`
+ `--gc-trace <path>` flag — IS stable: it's an opt-in measurement
plane that won't change behaviour for production runs.

## Goal

Reduce per-loaded-symbol RSS cost (β) from 4.3 MB to ~0.5 MB for
"cold" (uninteresting) symbols by making tier a property of the
strategy working set rather than the data layer. Hot symbols pay full
panel + indicator + position state; cold symbols pay only enough to
decide promotion next Friday.

Master plan: `dev/plans/hybrid-tier-architecture-2026-04-26.md`
(Phases 1–5, ~1,500 LOC across 8–9 PRs over 3–4 weeks).

## Phase 1 plan

`dev/plans/hybrid-tier-phase1-2026-04-26.md` — measurement-only.
Two empirical experiments (load-vs-activity decomposition + GC
phase-boundary snapshots) gate the Phase 2 data-structure work.

## Open work

- **`feat/hybrid-tier-phase1-measurement`** (current branch) —
  - `Gc_trace` module (`trading/trading/backtest/lib/gc_trace.{ml,mli}`)
    capturing `Gc.stat` snapshots at coarse phase boundaries (start,
    after universe load, after macro load, after fill, after
    teardown, end), output as CSV.
  - `--gc-trace <path>` flag on `backtest_runner.exe`. Composes with
    `--trace` and `--memtrace`. Opt-in; default off.
  - Two experiment scenarios under
    `trading/test_data/backtest_scenarios/goldens-hybrid-tier-experiment/`:
    - `sp500-default.sexp` (no overrides; control).
    - `sp500-no-candidates.sexp` (`screening_config` candidate caps
      zeroed to drop active-N to zero while preserving load-N).
  - Experiment note: `dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md`
    — setup, methodology, interpretation framework, initial
    recommendation. Empirical RSS measurements pending — the note
    documents the decision tree before the runs land so the
    interpretation doesn't drift after the fact.

## Out of scope (Phase 2+)

- `Tiered_panels.t` and the cold/warm/hot record types (Phase 2 in
  master plan, ~600 LOC, 3–4 PRs).
- Promotion / demotion logic + streaming CSV reader for Cold tier
  (Phase 3).
- `Stop_log` / `Trace` / `prior_stages` accumulation hygiene for
  Cold/Warm symbols (Phase 4).
- N=5,000 spike validation (Phase 5).

## Follow-up

- **Per-Friday `Gc.stat` snapshots inside `Simulator.run`.** Phase 1
  task description asks for this, but it requires an engine-layer hook
  outside backtest-infra's scope. If Experiment B at the coarse phase
  boundaries proves ambiguous (similar growth across `macro_done →
  fill_done`), open a Phase 1.5 PR that adds an optional callback to
  `Simulator.config` and routes it through to the backtest runner.
- **Decision: 2-tier vs 3-tier** depends on Experiment A outcome.
  Recommendation framework documented in the experiment note; landed
  before the runs to keep the analysis honest.

## Completed

_(Phase 1 in flight.)_

## References

- Master plan: `dev/plans/hybrid-tier-architecture-2026-04-26.md`
- Phase 1 plan: `dev/plans/hybrid-tier-phase1-2026-04-26.md`
- Experiment note: `dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md`
- Source data: `dev/notes/panels-memtrace-postA-2026-04-26.md`,
  `dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`,
  `dev/notes/sp500-golden-baseline-2026-04-26.md`.
