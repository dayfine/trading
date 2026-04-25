# Status: data-panels

## Last updated: 2026-04-25

## Status
PENDING

## Interface stable
N/A — pre-implementation

## Goal

Refactor the backtester's in-memory data shape from per-symbol scalar
(Hashtbl of `Daily_price.t list`) to columnar (Bigarray panels of
shape N × T per OHLCV field, plus per-indicator panels of the same
shape). Collapses the entire `bar_loader/` tier system, the post-#519
Friday cycle, the parallel `Bar_history` structure, and the +95%
Tiered RSS gap — all structurally rather than incrementally. Unblocks
the tier-4 release-gate scenarios (5000 stocks × 10 years, ≤8 GB).

The strategy interface ALREADY has `get_indicator_fn` (per
`strategy_interface.mli:23-24`); panel reads back it with
`Bigarray.Array2.unsafe_get`. No new API surface.

## Plan

`dev/plans/columnar-data-shape-2026-04-25.md` (PR #554) — five-stage
phasing, Bigarray storage backend, parity-gate per stage, decisions
ratified inline.

Supersedes `dev/plans/incremental-summary-state-2026-04-25.md`
(SUPERSEDED, kept as historical record). Reusable pieces (functor
signature, parity-test functor, indicator porting order, Bar_history
reader audit) carry forward.

## Open work

- **PR #554** (this plan, doc-only) — open for human review.

## Five-stage phasing (from the plan)

| Stage | Owner | Scope | Branch | LOC |
|---|---|---|---|---|
| 0 | feat-backtest | Spike: `Symbol_index`, OHLCV panels, EMA kernel, parity test, snapshot serialization | `feat/panels-stage00-spike` | ~450 |
| 1 | feat-backtest | Panel-backed `get_indicator` for EMA/SMA/ATR/RSI; Bar_history kept alive | `feat/panels-stage01-get-indicator` | ~500 |
| 2 | feat-backtest | Replace 6 Bar_history reader sites with panel views; delete Bar_history | `feat/panels-stage02-no-bar-history` | ~400 |
| 3 | feat-backtest | Collapse Bar_loader tier system + Friday cycle | `feat/panels-stage03-tier-collapse` | ~400 |
| 4 | feat-backtest | Weekly cadence panels + remaining indicators (Stage, Volume, Resistance, RS) | `feat/panels-stage04-weekly` | ~300 |
| 5 | feat-backtest | Live-mode universe-rebalance handling (deferred until live mode lands) | `feat/panels-stage05-live` | ~150 |

Total: ~2200 LOC across 6 PRs over ~10 working days. Stage-by-stage
parity gate against existing scalar implementation. Each stage
mergeable independently (Stage 1 alone gives the indicator
abstraction; Stage 2 alone gives the memory win).

## Stage 0 gate criteria (decision point)

If Stage 0 spike fails any of these, abort migration and revisit:

- Byte-identical EMA values OR ≤ 1 ULP drift compounded over 1y with
  end-to-end PV unchanged
- RSS < 50% of current scalar implementation at N=300 T=6y on
  bull-crash goldens (target gain ≥ 30%)
- Snapshot serialization round-trip: bit-identical values, load wall
  < 100 ms at N=1000 T=3y

## Memory targets (from plan §Memory expectations)

| Scale | Today (extrapolated) | Columnar projected |
|---|---:|---:|
| N=292 T=6y bull-crash | L 1.87 / T 3.74 GB | < 800 MB |
| N=1000 T=3y | L 1.83 / T 3.83 GB | < 1.0 GB |
| N=5000 T=10y (release-gate tier 4) | 12-22 GB | ~1.2 GB |

## Ownership

`feat-backtest` agent. All five stages owned by the same agent for
continuity (the indicator porting in stage 4 touches `weinstein/*`
modules but the work is panel-shaped, not strategy logic).

## Branch convention

`feat/panels-stage<NN>-<short-name>`, one per stage. Stages 1+ stack
on each prior stage's branch tip (per orchestrator fresh-stack rule)
since each stage needs the prior stage's types but not its merge.

## Blocked on

- Stage 0 must complete + parity-gate pass before any subsequent
  stage starts. No stages start until human reviews the spike result.

## Blocks

- `backtest-perf` tier-4 release-gate scenarios are blocked on
  Stage 3 (tier collapse) at minimum, ideally Stage 4 (weekly
  cadence). Until then the 5000×10y scenario doesn't fit in 8 GB.

## Decision items (need human or QC sign-off)

All ratified 2026-04-25; see plan §Decisions. None outstanding
pre-Stage 0.

Post-Stage 0 spike result will produce the next decision point: did
parity hold within tolerance, did RSS gain hit the gate, did
snapshot round-trip work? Stages 1+ proceed only on green.

## References

- Plan: `dev/plans/columnar-data-shape-2026-04-25.md` (PR #554)
- Superseded plan: `dev/plans/incremental-summary-state-2026-04-25.md`
  (PR #551 merged; kept as historical record)
- Sibling: `dev/status/backtest-perf.md` — tier 4 release-gate
  scenarios blocked here
- Predecessor: `dev/status/backtest-scale.md` (READY_FOR_REVIEW) —
  bull-crash hypothesis-test sequence that motivated this redesign
- Strategy interface (already exposes `get_indicator_fn`):
  `trading/trading/strategy/lib/strategy_interface.mli:23-24`
- Bar_history reader audit:
  `dev/notes/bar-history-readers-2026-04-24.md` (6 sites)
- Perf findings that motivated this: `dev/notes/bull-crash-sweep-2026-04-25.md`,
  `dev/notes/perf-sweep-2026-04-25.md`
