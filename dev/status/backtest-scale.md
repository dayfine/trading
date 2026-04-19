# Status: backtest-scale

## Last updated: 2026-04-19

## Status
READY_FOR_REVIEW

Plan `dev/plans/backtest-tiered-loader-2026-04-19.md` reviewed + open questions resolved (2026-04-19). 3a (Metadata) merged; 3b-i (Summary_compute) merged; 3b-ii (Summary tier wiring) merged as #445; 3c (Full tier) at #447 (awaiting merge; QC APPROVED run-4). 3d (tracer phases) is the next increment.

## Interface stable
NO

All three tier getters now return their proper typed option: `get_metadata : Metadata.t option`, `get_summary : Summary.t option`, `get_full : Full.t option`. Core `Bar_loader.create` / `promote` / `demote` / `tier_of` / `stats` signatures remain stable; `create` gained optional `?full_config` in 3c. Remaining churn will come from 3d (tracer phase plumbing may add an optional trace arg to `create`), 3e (runner wiring), and 3f (tiered runner path).

## Open PR
- #447 — feat/backtest-tiered-loader-3c-full-tier — 3c based on main, QC APPROVED run-4, awaiting human merge.

## Blocked on
- None. 3d depends on 3c merging.

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

1. QC review of 3c (feat/backtest-tiered-loader-3c-full-tier head).
2. Dispatch 3d — tracer phases. Extends `Trace.Phase.t` with `Promote_summary`, `Promote_full`, `Demote`; plumbs trace emission through `Bar_loader.promote` / `demote`. Acceptance: run `scenario_runner --parallel 3` with trace enabled under a `Tiered` loader_strategy and confirm 3 distinct `trace-<scenario>.sexp` files appear with per-phase data. ~120 lines per plan §3d.
3. Subsequent increments 3e–3g follow per plan §Dependency graph.

## Completed

- **3c — Full tier + promotion semantics** (2026-04-19). Adds
  `Full.t = { symbol; bars; as_of }` and a thin `Full_compute` pure
  module mirroring `Summary_compute`'s shape. `promote ~to_:Full_tier`
  cascades through Summary (→ Metadata), then loads a bounded OHLCV
  tail (`full_config.tail_days = 1800` default, ~7 years) via the
  shared `_load_bars_tail` helper — now parameterized on `tail_days`
  so Summary's 250-day window and Full's 1800-day window share the
  same CSV path. `get_full` returns `Full.t option`. Demotion
  semantics per plan §Resolutions #6: Full → Summary keeps Summary
  scalars and drops bars; Full → Metadata drops both higher tiers.
  `Types.Daily_price.t` has no sexp converters, so `Full.t` derives
  `show, eq` only (documented in the mli). `Bar_history`,
  `Weinstein_strategy`, `Simulator`, `Price_cache`, and `Screener`
  untouched (plan §Out of scope).
  - Files: `bar_loader/{bar_loader.mli,bar_loader.ml,full_compute.mli,full_compute.ml}`
    + `bar_loader/test/{dune,test_full.ml,test_metadata.ml}` (dropped
    the now-obsolete `full_promotion_unimplemented` test on metadata).
  - Verify: `dev/lib/run-in-env.sh dune build trading/backtest/bar_loader && dev/lib/run-in-env.sh dune runtest trading/backtest/bar_loader --force` — 7 Metadata + 12 Summary_compute + 8 Summary + 8 Full = 35 tests pass.

- **3b-ii — Summary tier wiring + integration tests** (2026-04-19).
  Wires `Summary_compute` (from 3b-i) into `Bar_loader`. Adds
  `Summary.t` record on per-symbol entries. `promote ~to_:Summary_tier`
  auto-promotes through Metadata, reads a bounded 250-day daily-bar
  tail via `Csv_storage` (bypassing `Price_cache` so raw bars don't
  leak into the shared cache), computes scalars via
  `Summary_compute.compute_values`, then drops the bars. Benchmark
  bars lazy-loaded and cached on the loader. `get_summary` returns
  `Summary.t option`. Insufficient history leaves the symbol at
  Metadata tier. Demote to Metadata drops Summary scalars.

- **3b-i — Summary_compute pure indicator helpers** (merged, PR #444).

- **3a — Metadata tier + types scaffold** (2026-04-19). New library at
  `trading/trading/backtest/bar_loader/`. Exposes the full
  `Metadata_tier | Summary_tier | Full_tier` variant up front so
  3b/3c don't churn it. `Metadata.t` carries sector + last_close;
  `market_cap` and `avg_vol_30d` stay `float option = None` until a
  consumer needs them (plan §Risks #4). `promote ~to_:Metadata_tier`
  reads the last bar ≤ `as_of` via the existing `Price_cache` and
  joins a caller-supplied sector table — idempotent, surfaces
  per-symbol errors without inserting failed symbols.
  - Files: `bar_loader/{dune,bar_loader.mli,bar_loader.ml}` +
    `bar_loader/test/{dune,test_metadata.ml}`.

## QC

overall_qc: APPROVED (3c — structural + behavioral, 2026-04-19)
structural_qc: APPROVED (3c, 2026-04-19 — dev/reviews/backtest-scale-3c.md)
behavioral_qc: APPROVED (3c, 2026-04-19 — data-loading increment; no strategy behavior change; tier-shape + demote/promote invariants verified against plan §Resolutions #6. Parity acceptance gate arrives with 3g — dev/reviews/backtest-scale-3c.md)

Reviewers when work lands:
- qc-structural — module boundaries between tiers; `Bar_history` untouched; parity test runs both strategies.
- qc-behavioral — does strategy output (trades, metrics) actually match Legacy within ε? Any regression is a behavior bug, not a perf win.
