# Status: backtest-scale

## Last updated: 2026-04-19

## Status
READY_FOR_REVIEW

Plan `dev/plans/backtest-tiered-loader-2026-04-19.md` reviewed + open questions resolved (2026-04-19). 3a (Metadata tier) implemented and pushed on `feat/backtest-tiered-loader`; 3b (Summary) is the next increment.

## Interface stable
PARTIAL — 3a landed

`Bar_loader.create` / `promote` / `demote` / `tier_of` / `get_metadata` / `stats` signatures are stable. `get_summary` and `get_full` currently return `unit option` placeholders; their return type becomes `Summary.t option` / `Full.t option` in 3b / 3c respectively.

## Open PR
- feat/backtest-tiered-loader — 3a open at https://github.com/dayfine/trading/pull/new/feat/backtest-tiered-loader (draft, awaiting QC).

## Blocked on
- None. Plan approved; 3a unblocked once #433 merges.

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

1. QC review of 3a (feat/backtest-tiered-loader head).
2. Dispatch 3b — Summary tier. Adds `Summary.t`, `summary_compute.{ml,mli}` (30w MA, ATR, stage heuristic, RS line from bounded bar tail), extends `promote ~to_:Summary_tier` and `get_summary` to return `Summary.t option`. ~220 lines per plan §3b.
3. Subsequent increments 3c–3g follow per plan §Dependency graph.

## Completed

- **3a — Metadata tier + types scaffold** (2026-04-19). New library at
  `trading/trading/backtest/bar_loader/`. Exposes the full
  `Metadata_tier | Summary_tier | Full_tier` variant up front so
  3b/3c don't churn it. `Metadata.t` carries sector + last_close;
  `market_cap` and `avg_vol_30d` stay `float option = None` until a
  consumer needs them (plan §Risks #4). `promote ~to_:Metadata_tier`
  reads the last bar ≤ `as_of` via the existing `Price_cache` and
  joins a caller-supplied sector table — idempotent, surfaces
  per-symbol errors without inserting failed symbols. Higher-tier
  promotes return `Status.Unimplemented`. `Bar_history`,
  `Weinstein_strategy`, `Simulator`, `Price_cache`, and `Screener`
  untouched (plan §Out of scope).
  - Files: `bar_loader/{dune,bar_loader.mli,bar_loader.ml}` +
    `bar_loader/test/{dune,test_metadata.ml}`.
  - Verify: `dev/lib/run-in-env.sh dune build trading/backtest/bar_loader && dev/lib/run-in-env.sh dune runtest trading/backtest/bar_loader/test` — 7 tests pass.

## QC

overall_qc: PENDING (3a ready for review)
structural_qc: PENDING (3a)
behavioral_qc: N/A (3a — no strategy behavior change; parity test arrives with 3g)

Reviewers when work lands:
- qc-structural — module boundaries between tiers; `Bar_history` untouched; parity test runs both strategies.
- qc-behavioral — does strategy output (trades, metrics) actually match Legacy within ε? Any regression is a behavior bug, not a perf win.
