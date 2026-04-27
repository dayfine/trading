# Status: hybrid-tier

## Last updated: 2026-04-27

## Status
BLOCKED

Phase 1 (measurement infra) **complete and merged** (#609); the
empirical experiments **invalidate the original Phase 2 design**.
Awaiting plan revision / human go-ahead before Phase 2 starts.

Phase 1 results (`dev/notes/hybrid-tier-phase1-results-2026-04-27.md`):

- **Exp A (load-vs-activity)**: RSS-default 2,131 MB ≈ RSS-no-candidates
  2,134 MB (within 0.2%). H_load wins decisively. Strategy/screener/
  position-state hygiene won't move RSS.
- **Exp B (GC phase boundaries)**: all heap growth happens during
  the simulator loop (`fill_done`). Panel build + macro init add
  4K words combined; the major-heap steady state is per-tick engine
  allocations (~10 GB cumulative promoted, 1.4 GB peak resident).
- **Combined**: the wedge is in the engine/simulator per-tick
  allocations, not in the strategy / data-load layer the original
  3-tier hybrid plan targeted. The `Tiered_panels.t` design (Cold/
  Warm/Hot strategy state) **would not move RSS meaningfully**
  given these results.

Two replanning options (see results note §Recommendation):
- **Option 1**: Engine-layer pooling (`Price_path._sample_*` buffer
  reuse). ~600 LOC, scoped, immediate.
- **Option 2**: Daily-snapshot streaming (offline ops-data builds
  per-day cross-sections; runtime mmap's only ±30 days). ~3,000
  LOC, larger payoff at tier-4 release-gate scale.

Recommend Option 1 first, then Option 2 as a separate plan.

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
