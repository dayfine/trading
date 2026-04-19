# Status: backtest-scale

## Last updated: 2026-04-19

## Status
READY_FOR_REVIEW — detailed implementation plan at `dev/plans/backtest-tiered-loader-2026-04-19.md`. Awaiting human review before 3a implementation is dispatched.

## Interface stable
N/A — implementation not yet started; plan decomposes Step 3 into 8 increments (3a–3h) each with its own interface.

## Open PR
—

## Blocked on
- Human review of `dev/plans/backtest-tiered-loader-2026-04-19.md` — §Open questions need resolution before 3f implementation (parity ε, shadow-screener refactor scope, broad-scenario selection).
- PR #396 (parent plan) merged; PR #419 (Step 2 tracing) merged 2026-04-19 — A/B trace infrastructure available for 3d/3g/3h.

## Goal

Tier-aware bar loader. Backtest working set scales with actively tracked symbols (~20-200), not inventory (10k+). Today's loader materializes all inventory bars; step 3 introduces three data-shape tiers so Memory budget becomes ~29 MB vs today's >7 GB.

## Scope

See `dev/plans/backtest-scale-optimization-2026-04-17.md` §Step 3 for the overall spec and `dev/plans/backtest-tiered-loader-2026-04-19.md` for the detailed, increment-level implementation plan. Summary:

1. **Three tiers defined as types, not subsets.**
   - `Metadata.t` — all inventory (~10k) — last_close, sector, cap, 30d_avg_volume
   - `Summary.t` — sector-ranked subset (~2k) — 30w MA, RS line, stage heuristic, ATR
   - `Full.t` — breakout candidates + held positions (~20-200) — complete OHLCV

2. **`Bar_loader` module** with `promote : t -> symbols:string list -> to_:tier -> t`. Screener cascade calls promote as symbols advance through stages. Demotion on exit/liquidation frees Full-tier memory.

3. **Runner flag `loader_strategy = Legacy | Tiered`.** Default `Legacy` at merge time. Acceptance gate = parity test on golden-small scenario (diffs trade count / total P&L / final portfolio value / each pinned metric within float ε). Merge blocked until parity holds.

4. **Post-merge ramp:** flip default to `Tiered` in a tiny follow-up PR after a few weeks; retire `Legacy` in the one after.

## Scope boundary

Do NOT touch in this track:
- Strategy, screener cascade logic (orchestrate calls, don't rewrite)
- Incremental indicators (separate axis; likely unnecessary once tiers cut the 10k loop)
- Parallel backtest workers (orthogonal)

Build alongside existing `Bar_history` — don't modify it.

## Branch
`feat/backtest-tiered-loader`

## Ownership
`feat-backtest` agent (architectural scope). See `.claude/agents/feat-backtest.md`.

## Increments (from `backtest-tiered-loader-2026-04-19.md`)

| # | Name | Scope | Size est. |
|---|---|---|---|
| 3a | Metadata tier | `Bar_loader` types + Metadata loader + tests | ~180 |
| 3b | Summary tier | `Summary.t` + summary_compute + promote/demote | ~220 |
| 3c | Full tier | `Full.t` + promotion/demotion semantics | ~150 |
| 3d | Tracer phases | `Promote_summary`/`Promote_full`/`Demote` in `Trace.Phase.t` | ~120 |
| 3e | Runner flag plumbing | `loader_strategy` on Runner + Scenario + CLI | ~150 |
| 3f | Tiered runner path | `_run_tiered_backtest` + shadow screener adapter | ~300 |
| 3g | Parity acceptance test | merge gate on `smoke/tiered-loader-parity.sexp` | ~200 |
| 3h | Nightly A/B comparison | GHA workflow + compare script | ~100 |

3a→3g are the merge-gate increments; 3h is a post-merge follow-on (tracked here for continuity).

## References

- Detailed implementation plan: `dev/plans/backtest-tiered-loader-2026-04-19.md`
- Parent plan: `dev/plans/backtest-scale-optimization-2026-04-17.md` (PR #396)
- Engineering design: `docs/design/eng-design-4-simulation-tuning.md` — note that tier-aware loading is a pragmatic optimization over the design, not a change to the DATA_SOURCE abstraction
- Prerequisite: PR #419 (per-phase tracing) — merged

## Size estimate

~500-800 lines total for 3a-3g (merge gate). Per increment: see table above. Nightly A/B (3h) is ~100 additional lines, post-merge.

## Next Steps

1. Human reviews `dev/plans/backtest-tiered-loader-2026-04-19.md` and resolves §Open questions (ε threshold, scenario selection, screener-refactor scope, module placement, demotion semantics).
2. On approval, orchestrator dispatches `feat-backtest` to implement 3a.
3. Each subsequent GHA run picks up the next increment.

## QC

overall_qc: PENDING
structural_qc: PENDING
behavioral_qc: PENDING

Reviewers when work lands:
- qc-structural — module boundaries between tiers; `Bar_history` untouched; parity test runs both strategies.
- qc-behavioral — does strategy output (trades, metrics) actually match Legacy within ε? Any regression is a behavior bug, not a perf win.
