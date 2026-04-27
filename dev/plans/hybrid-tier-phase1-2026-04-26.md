# Plan: hybrid-tier Phase 1 — measurement infra (2026-04-26)

Implementation plan for Phase 1 of
`dev/plans/hybrid-tier-architecture-2026-04-26.md`. Phase 1 is
**measurement-only** — confirm the cost model frames before any
data-structure work.

## Status

IN_PROGRESS — implementation lands in the same session as this plan.

## Approach

Two empirical experiments. Both feed the Phase 2 / 3 / 4 decision in
the master plan §"Phasing".

### Experiment A — load-vs-activity decomposition

Run S&P 500 golden two ways:

1. **`sp500-default`** — wraps the current
   `goldens-sp500/sp500-2019-2023` config (no overrides).
2. **`sp500-no-candidates`** — same period + universe with one
   override that prevents any candidate from being entered:
   `((screening_config ((max_buy_candidates 0) (max_short_candidates 0))))`.

Both run with `OCAMLRUNPARAM=o=60,s=512k`.

Why `max_buy_candidates 0` over `min_grade A_plus`? It's a cleaner
upstream cut: the screener still runs the full cascade (so "did
filter shorten work?" is not the variable being changed), but no
candidates are emitted, which means **no positions are ever entered**
across the run. That zeroes out the `Stop_log` / `Trading_state` /
`Position` accumulation that scales with active N.

Comparison table:

| Variant | Loaded N | Active N (positions opened) | Peak RSS | Wall |
|---|---:|---:|---:|---:|
| `sp500-default` | 506 | ~133 round trips (~10–15 concurrent) | M_default | W_default |
| `sp500-no-candidates` | 506 | 0 | M_filterup | W_filterup |

Decision rule (phrased as the master plan §Phase-1 decision):

- If `M_filterup ≈ M_default` (within 5%): β scales with **loaded N**
  regardless of activity → 3-tier (Cold/Warm/Hot) is the right shape;
  most savings come from Cold-tier residency reduction.
- If `M_filterup < 0.7 · M_default`: β scales with **active N** →
  hybrid tier is still useful but the bigger wedge is per-position
  state hygiene, and a 2-tier (Cold/Hot) shape suffices.
- In between: 2-tier is the simpler bet; revisit in Phase 2.

### Experiment B — phase-boundary `Gc.stat` snapshots

New `--gc-trace <path>` flag on `backtest_runner.exe` writes a CSV of
`Gc.stat` snapshots at each phase boundary the runner has access to.
Output schema:

```
phase,wall_ms,minor_words,promoted_words,major_words,heap_words,top_heap_words
```

Phases captured (lifecycle order):

| Phase | When |
|---|---|
| `start` | Process start, before any backtest work. |
| `load_universe_done` | After resolving sector map / universe list. |
| `macro_done` | After loading AD bars (Macro phase). |
| `fill_done` | After the simulator main loop returns. |
| `teardown_done` | After round-trip extraction. |
| `end` | Just before the runner exits. |

**Scope clarification**: the Phase 1 task asks for snapshots "every
50 Fridays during the simulator loop". That requires hooking inside
`Trading_simulation.Simulator.run`, which is engine-layer code outside
backtest-infra's scope. The proxy: phase boundaries above bracket the
simulator loop (`fill_done` minus `macro_done` is the entire
simulator delta), which still discriminates the three sub-hypotheses
in the task description:

- Stepwise growth at `load_universe_done`/`macro_done` then flat through
  `fill_done` → panels-and-AD-load dominant; hybrid tier wins.
- Steady proportional growth `macro_done → fill_done` → per-tick
  allocations promoted; hybrid tier helps but per-tick code is the
  wedge.
- Stepwise growth concentrated at `fill_done` → either per-Friday
  bundle allocations (hybrid tier directly addresses) OR final
  teardown costs.

A finer per-Friday hook is logged as a follow-up in
`dev/status/hybrid-tier.md` for a future Phase-1.5 PR if Experiment B
is ambiguous.

## Files to touch

- `trading/trading/backtest/lib/gc_trace.{ml,mli}` — new module:
  `type snapshot`, `record`, `write` (CSV). ~80 LOC + ~40 LOC mli.
- `trading/trading/backtest/lib/dune` — register `gc_trace`.
- `trading/trading/backtest/runner_args/backtest_runner_args.{ml,mli}`
  — add `gc_trace_path : string option`. ~20 LOC.
- `trading/trading/backtest/bin/backtest_runner.ml` — wire the flag,
  call `Gc_trace.record` at the listed phase boundaries. ~30 LOC.
- `trading/trading/backtest/bin/dune` — add `trading.backtest.lib`
  if not already exposed (it is — depends on `backtest`).
- `trading/trading/backtest/test/test_backtest_runner_args.ml` — extend
  with `--gc-trace` flag tests. ~50 LOC.
- `trading/trading/backtest/test/test_gc_trace.ml` — unit test for
  snapshot schema + CSV round-trip. ~60 LOC.
- `trading/test_data/backtest_scenarios/goldens-hybrid-tier-experiment/`
  — new dir + `sp500-default.sexp` + `sp500-no-candidates.sexp`.
- `dev/status/hybrid-tier.md` — new track, IN_PROGRESS, references
  master plan + this plan.
- `dev/status/_index.md` — new row for hybrid-tier (allowed since
  this PR introduces a new tracked item; agent file says
  "Exception: if this PR introduces a brand-new tracked work item").
- `dev/notes/hybrid-tier-phase1-cost-model-2026-04-26.md` —
  experiment note: setup, methodology, interpretation framework,
  initial recommendation.

## Out of scope (Phase 2+)

- `Tiered_panels.t` (Phase 2 of master plan).
- Tier promotion / demotion (Phase 3).
- Streaming γ collapse (Phase 4).
- `Bar_panels.t` resizing (left as-is).
- Per-Friday `Gc.stat` snapshots (deferred — needs simulator-level
  hook).
- Stage 4.5 PR-A counter-test infrastructure extensions.

## Verify

```bash
cd /workspaces/trading-1/trading && eval $(opam env)
TRADING_DATA_DIR=$PWD/test_data dune build
dune fmt
dune build @fmt
TRADING_DATA_DIR=$PWD/test_data dune runtest
```

## Recommendation framing for the experiment note

Even before running the experiments, the existing memtrace evidence
(`dev/notes/panels-memtrace-postA-2026-04-26.md`) names the dominant
allocator as `Trading_simulation_data__Price_cache.by_date` Hashtbl
(per-symbol, per-date index) and per-symbol `prior_stages` Hashtbl —
both **scaling with loaded N regardless of activity**. The expected
verdict is therefore:

- Experiment A → `M_filterup ≈ M_default` (within ~10%), confirming
  loaded-N hypothesis.
- Experiment B → most growth at `load_universe_done` / `macro_done`,
  with a steady creep through `fill_done` from per-tick promoted
  closures (the `Price_path._sample_*` 4 KB buffers in memtrace).
- Recommendation → 3-tier (Cold/Warm/Hot) per master plan, since
  Cold-tier residency reduction is the main wedge.

The note will record the actual measurements once the experiments
run; the framework above is the predicate.
