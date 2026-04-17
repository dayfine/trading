# Plan: backtest scale optimization (two-tier universe + tracing + tier-aware loading)

**Date:** 2026-04-17
**Status:** DRAFT — for human review before dispatch
**Track:** backtest-infra (feat-backtest) + new `backtest-scale` track for step 3

## Motivation

Universe grew 1,654 → 10,472 symbols on 2026-04-16 (sector-map refresh). Docker memory (7.75 GB limit) now blocks local 6-year golden runs; latest scenario-runner follow-up (PR #395) had to reason ranges from semantics instead of measured values.

This plan fixes the immediate symptom (goldens/smokes can't run locally) and the underlying cause (loader materializes all inventory bars, regardless of which symbols the strategy will actually evaluate). Three stacked deliverables, each independently valuable.

## Step 1 — Two-tier universe for scenarios (SMALL)

**Goal:** most scenarios run on a pinned small universe; a couple of scenarios retain the full universe for scale/regression coverage.

**Structure:**

```
test_data/backtest_scenarios/
  universes/
    small.sexp            — ~300 pinned symbols; committed
    broad.sexp            — reference to data/universe.sexp (pointer, not copy)
  goldens-small/          — existing golden scenarios, universe = small.sexp
  goldens-broad/          — ≤3 scenarios, universe = broad.sexp (nightly/GHA only)
  smoke/                  — all universe = small.sexp
```

Pick the 300 small-universe symbols to cover:
- Sector balance (≥10 each across the 11 GICS sectors)
- Stage diversity (Stage 1 bases, Stage 2 breakouts, Stage 3 tops, Stage 4 breakdowns) — sample from 2018-2023 cache
- Liquidity floor (>$500M cap, >500k avg volume) — Weinstein stage-2 candidates are rarely smaller
- A handful of known historical cases (NVDA 2019, MSFT 2020, PYPL 2021, etc.) the backtest should exercise

**Selection approach:** one-shot script under `dev/scripts/pick_small_universe/` that reads `data/universe.sexp`, applies the filters above, stratified-samples to 300. Commit the result; don't re-run in CI.

**Config wiring:** `Scenario.t` gains `universe_path : string` (default `universes/small.sexp`). Runner respects it when loading bars. Existing scenarios migrate to small universe by default; ≤3 goldens opt into broad.

**Size:** ~200 lines (mostly the selection script + scenario config field + schema migration).

**Unblocks:** scenario-runner can pin all 6 scenarios' `unrealized_pnl` ranges from real runs (PR #395 follow-up).

## Step 2 — Per-phase tracing (SMALL)

**Goal:** observable, commit-stable measurements of where memory and time go in a backtest run. Needed before optimizing; otherwise step 3 is flying blind.

**Module:** `trading/trading/backtest/lib/trace.ml{,i}`

```ocaml
module Phase : sig
  type t = Load_universe | Load_bars | Macro | Sector_rank | Rs_rank | Stage_classify
         | Screener | Stop_update | Order_gen | Fill | Teardown
end

type phase_metrics = {
  phase            : Phase.t;
  elapsed_ms       : int;
  symbols_in       : int;
  symbols_out      : int;
  peak_rss_mb      : int option;   (* best-effort via /proc/self/status *)
  bar_loads        : int;
}

val record : Phase.t -> ('a -> 'b) -> 'a -> 'b * phase_metrics
val write  : out_path:string -> phase_metrics list -> unit
```

**Output:** `dev/backtest/traces/<run-id>.sexp`. One sexp per run, not per-bar. Costs ~0 at runtime (only summary counts per phase).

**Integration:** wrap the existing run-loop phases. Non-invasive — if `trace` is `None`, no-op.

**Size:** ~150 lines (module + tests + 6-8 wrap points in runner).

**Unblocks:** step 3 can A/B tier-aware loading against today's baseline with real numbers.

## Step 3 — Tier-aware bar loading (LARGE, gated on steps 1+2)

**Goal:** loader memory scales with actively tracked symbols, not inventory. The strategy only needs full OHLCV for ~20-200 symbols (held positions + active breakout candidates); everything else needs only summary data to pass/fail the sector and RS filters.

**Three tiers:**

```
Metadata  (all ~10k symbols):  last_close, sector, cap, 30d_avg_volume
                                ~64 B × 10k = 640 KB

Summary   (sector-ranked ~2k): 30w_ma, rs_line, stage_heuristic, atr
                                ~2 KB × 2k = 4 MB

Full      (candidates ~200):   complete OHLCV history (1500+ bars)
                                ~120 KB × 200 = 24 MB

Total working set: ~29 MB vs today's >7 GB
```

**Module boundary:** new `Bar_loader` module with:

```ocaml
type tier = Metadata | Summary | Full
val promote : Bar_loader.t -> symbols:string list -> to_:tier -> Bar_loader.t
```

Screener cascade calls `promote` as symbols advance through stages:
- All inventory → Metadata tier (cheap — metadata lives in a single sexp per symbol)
- Top sector survivors → Summary tier (loads N bars per symbol, computes indicators, drops raw bars)
- Breakout candidates + held positions → Full tier (loads everything)

Demotion on exit/liquidation frees Full-tier memory.

**Key design choice:** tier definition is **data shape**, not **symbol subset**. A symbol in Metadata tier has a `Metadata.t` record — no `Full_bars.t` exists for it. Compile-time safety: can't accidentally access OHLCV on a symbol that was never promoted to Full.

**Migration:** introduce alongside existing `Bar_history` (don't modify). Runner gains a `loader_strategy` config — `Legacy` (existing all-at-once) or `Tiered`. Start with `Tiered` opt-in for goldens-small, graduate once tracing (step 2) confirms parity + savings.

**Size:** ~500-800 lines. Split across 2-3 commits if needed:
- Bar_loader types + Metadata/Summary loaders (200 lines)
- Full tier + promotion logic (200 lines)
- Runner integration + screener cascade updates (200-300 lines)
- Tests: synthetic promotions, tier-boundary transitions, memory ceiling (100 lines)

**Separate track:** warrants its own `dev/status/backtest-scale.md` and `feat/backtest-tiered-loader` branch. Not a feat-backtest follow-up — architectural.

## Sequencing

| # | Step | Size | Branch | Unblocks |
|---|---|---|---|---|
| 1 | Two-tier universe | S | `feat/scenarios-small-universe` | PR #395 follow-up + local goldens |
| 2 | Per-phase tracing | S | `feat/backtest-tracing` | step 3 empiricism |
| 3 | Tier-aware loading | L | `feat/backtest-tiered-loader` | real backtests at scale |

Steps 1 and 2 are independent — can parallelize. Step 3 gates on both.

## Out of scope

- Incremental indicators (EMA/RS/ATR tick-by-tick updates). Profiling from step 2 will show whether this matters; likely cheaper to compute summaries once per promotion than to maintain incremental state.
- Parallel backtest workers. Single-process tier-aware loading gets memory under budget; parallelism is a separate axis.
- Cross-scenario bar caching (shared immutable bars across parallel tunings). Useful but orthogonal.
- Changing the sector-map refresh cadence. If inventory is the problem, separate discussion.

## Decisions (resolved 2026-04-17)

1. **Small universe size: ~500 = S&P 500 constituents.** Natural cap on liquid US equities; covers every sector Weinstein cares about. Step 1 sources from cached data if present, otherwise fetches once and commits the sexp.
2. **Broad goldens cadence: nightly on GHA only.** ≤3 scenarios. Not run by the local test target. Results posted as artifacts; escalate to daily summary on regression.
3. **Trace retention:**
   - Raw traces under `dev/backtest/traces/` are **run artifacts** — gitignored, ad-hoc for debugging.
   - For pinned goldens, extend each scenario sexp with an `expected_phase_counts` schema (same pattern PR #395 used for `unrealized_pnl` range). Regression detection = "new trace diverges from pinned expected counts." Tolerance per-phase (e.g. `symbols_out ± 5%`, `elapsed_ms ± 50%` since CI runner timing is noisy).
   - On-demand traces for iterative debugging just work — no retention policy needed.
4. **Tier-3 migration: flag-gated with automated parity test.**
   - Runner config: `loader_strategy = Legacy | Tiered`. Default `Legacy` at merge time.
   - **Acceptance gate** = new test that runs one `golden-small` scenario twice (once each strategy) and diffs trade count, total P&L, final portfolio value, and each pinned metric within float ε. Merge blocked until parity holds.
   - Once parity proven over a few weeks: flip default to `Tiered` in a tiny follow-up PR; retire `Legacy` in the one after.
   - Rationale: flag doubles maintenance briefly, but "trading performance does not regress" is verifiable mechanically instead of by eyeball review.

## Success criteria

- Local `dune runtest trading/backtest/scenarios/test/` completes under 60s on the full suite.
- A golden-small scenario fits in <1 GB Docker memory; a golden-broad scenario fits in <6 GB.
- Trace output shows where any future memory blow-up lives within 30 seconds of reproducing.
