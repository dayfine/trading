# Plan: backtest-scale Step 3 — tier-aware bar loader (2026-04-19)

Track: [backtest-scale](../status/backtest-scale.md)
Branch: `feat/backtest-tiered-loader`
Parent plan: `dev/plans/backtest-scale-optimization-2026-04-17.md` §Step 3

## Context

### What the overall plan says

Step 3 of `backtest-scale-optimization-2026-04-17.md` replaces today's "load
every symbol's full OHLCV history up front" loader with a three-tier data
shape so the working set scales with *actively tracked* symbols rather than
*inventory*:

```
Metadata  (all ~10k symbols):  last_close, sector, cap, 30d_avg_volume
                                ~64 B × 10k = 640 KB
Summary   (sector-ranked ~2k): 30w_ma, rs_line, stage_heuristic, atr
                                ~2 KB × 2k = 4 MB
Full      (candidates ~200):   complete OHLCV history (1500+ bars)
                                ~120 KB × 200 = 24 MB

Total working set: ~29 MB vs today's >7 GB
```

The screener cascade calls `Bar_loader.promote` as symbols advance through
stages; demotion on exit frees Full-tier memory.

### Current code surface

The backtest runner today drives symbol loading via the simulator:

1. `Backtest.Runner._load_deps` builds `all_symbols = (index :: universe) @
   sector_etfs @ global_indices`, deduped + sorted.
2. `Backtest.Runner._make_simulator` calls `Simulator.create_deps ~symbols
   ~data_dir ...`. The simulator internally creates a
   `Market_data_adapter` which wraps a lazy `Price_cache`. Bars for a given
   symbol are loaded on first `get_price` call and cached for the rest of the
   run.
3. The Weinstein strategy's `_on_market_close` calls
   `Bar_history.accumulate` once per simulator step over *every* symbol in
   `_all_accumulated_symbols` (primary index :: universe @ sector_etfs @
   global_indices). That call path forces `get_price` on every symbol every
   day, which in turn lazy-loads every symbol's full CSV into
   `Price_cache` and then accumulates a growing `Daily_price.t list` in
   `Bar_history`.

Two concrete memory sinks:

- **`Price_cache`**: O(universe × bars) float records. Once touched, never
  evicted (`get_cached_symbols` is list-only; `clear_cache` is all-or-nothing).
- **`Bar_history`**: O(universe × bars_accumulated_so_far) — grows
  day-by-day as the simulator advances.

Both are keyed on "symbols we ever looked at." The 1,654 → 10,472 universe
jump blew this out.

### Observable measurement surface (step 2 output)

`trading/trading/backtest/lib/trace.{ml,mli}` landed in #419. The runner
already wraps the coarse phases `Load_universe`, `Macro`, `Load_bars`,
`Fill`, `Teardown` via `Trace.record`. For tiered-loader work, the relevant
phase is `Load_bars` — today it wraps `_make_simulator`, which is the cheap
part (creates the adapter). The expensive part is the per-day
`Bar_history.accumulate` inside `Fill`. Step 3 will need to instrument the
per-tier load calls so the A/B harness can attribute memory + time to
specific tiers rather than lumping everything under `Fill`.

### Status file & decisions

`dev/status/backtest-scale.md` locks:

- **Flag-gated rollout** with `loader_strategy = Legacy | Tiered`, default
  `Legacy` at merge. Acceptance gate = automated parity test on a golden-small
  scenario diffing trade count, total P&L, final portfolio value, and each
  pinned metric within float ε.
- **Post-merge ramp**: flip default to `Tiered` in a tiny follow-up PR after a
  few weeks of nightly runs; retire `Legacy` in the PR after that.
- Don't modify `Bar_history` or the simulator/strategy internals — build
  alongside.

## Approach

### Principle: tier is a type, not a subset

A symbol in `Metadata` tier has a `Metadata.t` value and nothing else — no
`Full_bars.t` exists for it until it's been promoted. That makes it a
compile-time error to reach for OHLCV on a symbol that was never promoted to
Full. Matches the plan's "data shape, not symbol subset" decision.

### Module boundary

New library: `trading/trading/backtest/bar_loader/`. Separate from
`Backtest.*` so the dependency arrow is:

```
scenarios/ ──┐
             ▼
bin/  ──▶ Backtest.Runner ──▶ bar_loader ──▶ simulation/data/price_cache
                                              (reused, not forked)
```

Exposes (sketch):

```ocaml
module Metadata : sig
  type t = {
    symbol        : string;
    sector        : string;
    last_close    : float;
    avg_vol_30d   : float;
    market_cap    : float option;  (* optional — not always available *)
  } [@@deriving sexp, show, eq]
end

module Summary : sig
  type t = {
    symbol           : string;
    ma_30w           : float;
    rs_line          : float;
    stage_heuristic  : Weinstein_types.stage;
    atr_14           : float;
    as_of            : Date.t;
  } [@@deriving sexp, show, eq]
end

module Full : sig
  type t = { symbol : string; bars : Types.Daily_price.t list }
  [@@deriving sexp]
end

type tier = Metadata_tier | Summary_tier | Full_tier
[@@deriving show, eq, sexp]

type t
(** Mutable bag of per-symbol tier assignments + computed data.
    Opaque — callers go through [promote]/[get_*]. *)

val create : data_dir:Fpath.t -> universe:string list -> t

val promote :
  t ->
  symbols:string list ->
  to_:tier ->
  as_of:Date.t ->
  unit
(** Move each symbol up to [to_], loading whatever data that tier needs.
    Idempotent for symbols already at >= to_. Demotion is explicit via
    [demote]. *)

val demote : t -> symbols:string list -> to_:tier -> unit
(** Tier-down, freeing the higher-tier data. Calling with [to_:Metadata_tier]
    fully drops Summary/Full caches for those symbols. *)

val tier_of : t -> symbol:string -> tier option

val get_metadata : t -> symbol:string -> Metadata.t option
val get_summary  : t -> symbol:string -> Summary.t option
val get_full     : t -> symbol:string -> Full.t option

val stats : t -> { metadata : int; summary : int; full : int }
(** Current tier counts; used by the tracer / parity harness. *)
```

### How Summary is computed

`Summary.t` is derived from a **bounded tail** of daily bars (30w MA needs 150
trading days; ATR-14 needs 14; RS-line needs benchmark bars). The loader pulls
the last N bars (N = max window, ~210 matching `warmup_days`) from the CSV,
computes the summary struct, and **drops the raw bars**. This is the key
memory win: the 30w-MA stock whose bars we'd otherwise hold all run gets
compressed to a 2 KB record.

Implementation strategy: reuse `Price_cache.get_prices ~end_date ~start_date`
with a date window of `[as_of - 210_days, as_of]`, compute indicators via the
existing `Technical_indicators` / `Stage` / `Rs_line` primitives, store the
scalar outputs, call `Price_cache.clear_cache` on *that one symbol* when done.

Today `Price_cache.clear_cache` is all-or-nothing. We need either (a) a new
`Price_cache.evict ~symbol` primitive or (b) a tier-internal cache separate
from `Price_cache`. Option (b) is cleaner — `bar_loader` maintains its own
per-symbol bar hashtable and never puts the raw bars into `Price_cache` in the
first place. That's the direction the plan increments below take.

### Full tier & promotion trigger

Promotion to Full happens when the screener is about to evaluate a candidate
for entry, OR when a position is opened. Code locations:

- `weinstein_strategy.ml` _run_screen → before
  `_screen_universe ~config.universe`. Today that passes every universe
  ticker through `Stock_analysis.analyze`, which needs weekly bars. Tiered
  version: promote to Summary for the full universe once per week
  (inexpensive — a single derived struct), then `Screener.screen` surfaces
  top candidates, then promote the top N to Full before
  `_make_entry_transition` pulls daily bars via `Bar_history.daily_bars_for`.
- `Stops_runner.update` needs Full tier for every held position. Positions
  are held in `portfolio.positions`; on position-open (CreateEntering
  transition) the runner promotes Full; on position-close (Closed state)
  the runner demotes.

Key observation: the strategy today reads bars from
`Bar_history.{weekly,daily}_bars_for`, not directly from a loader. The
cleanest integration path is to make `Bar_history` itself tier-aware — but
that violates the "don't touch Bar_history" rule. Alternative: the
`Backtest.Runner`-level tier orchestration happens *outside* the strategy, by
selectively gating which symbols get `Bar_history.accumulate` called on them
each day. Below.

### Integration point: strategy wrapper

`trading/trading/backtest/lib/strategy_wrapper.ml` already wraps the Weinstein
strategy for stop-log capture. Extend it (or build a sibling wrapper) so the
wrapper:

1. Before each `on_market_close` call, asks `Bar_loader.t` which symbols are at
   Full tier; passes `get_price` through unchanged for those (i.e. full daily
   history accumulates).
2. For symbols at Summary tier only, returns a `get_price` that either (a)
   returns `None`, suppressing `Bar_history.accumulate` from growing the
   history for them — combined with the screener path reading from
   `Bar_loader.get_summary` instead of the accumulated weekly bars, OR (b)
   returns the last-bar-only (today's close) so existing analysis paths still
   work but don't build out historical buffers.

Option (a) is cleaner but requires the screener to switch to reading summaries
from `Bar_loader` instead of calling `Stock_analysis.analyze` with full weekly
bars. That's a wider strategy change than we want in this track.

Option (b) is the **pragmatic approach**: the strategy stays untouched, but
the wrapper throttles `Bar_history` growth by returning `None` for
non-promoted symbols on days we don't want them accumulated. The Summary
tier's pre-computed indicators are used by a **shadow screener path** we
introduce under the Tiered flag, bypassing `_screen_universe`'s
`Stock_analysis.analyze` call.

This is the riskiest architectural decision in the plan. **Parity test is the
fail-safe** — if the shadow path produces different candidates, the parity
test catches it before merge.

### Legacy vs Tiered flag

```ocaml
(* runner.mli addition *)
type loader_strategy = Legacy | Tiered [@@deriving sexp]

val run_backtest :
  ...existing args... ->
  ?loader_strategy:loader_strategy ->  (* default Legacy *)
  unit ->
  result
```

Scenario file format (`scenario.ml`) gains an optional
`loader_strategy` field, default `Legacy`. Scenarios that opt into Tiered
set it explicitly; the parity harness runs one scenario twice and diffs.

### Parity harness

New test binary at `trading/trading/backtest/test/test_tiered_loader_parity.ml`.
Runs one golden-small scenario with `loader_strategy = Legacy` and then with
`Tiered`, asserts that:

```
trade_count_diff       = 0
final_portfolio_value  within ε (default 0.01, i.e. 1 cent on $1M)
total_pnl              within ε
each pinned metric     within scenario-declared range
```

The scenario is declared in a new file
`trading/test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp` (short
horizon, small universe, deterministic seed). The test is part of
`dune runtest` — merge gate.

### A/B empirical cutover plan

Once parity holds on the small scenario, a separate **empirical comparison
run** uses the step-2 trace infrastructure to confirm memory/time savings
on the real workloads:

1. **Scenarios under test:**
   - `smoke/tiered-loader-parity.sexp` — correctness gate (< 30s runtime,
     both strategies).
   - `goldens-small/six-year-2018-2023.sexp` — representative golden on
     the ~500-symbol small universe. Runs both strategies; compare trace
     output.
   - `goldens-broad/*.sexp` — nightly-only broad-universe scenarios
     (~10k symbols). These are where Tiered is supposed to earn its keep.

2. **Trace phases measured:**
   - `Load_bars` — expected: Legacy materializes ~7 GB adapter+cache up
     front; Tiered loads only Metadata at startup (~640 KB).
   - `Fill` — today's dominant memory consumer due to growing
     `Bar_history`. Tiered should show flat RSS; Legacy should show linear
     growth.
   - New phases (added in increment 3d below): `Promote_summary`,
     `Promote_full`, `Demote` — so the trace attributes the per-week
     promotion work distinctly.

3. **Go/no-go thresholds** (open question — see §Open questions):
   - Parity test: **hard gate**, zero tolerance outside float ε.
   - Memory: Tiered `peak_rss_kb` on broad scenario **< 25% of Legacy**.
     Plan says ~29 MB vs ~7 GB, so 25% is a lenient threshold.
   - Runtime: Tiered wall-clock on broad scenario **≤ Legacy ± 20%**.
     Tiered may do more CSV opens (one per promote), so some slowdown is
     acceptable; large regression would signal a design flaw.

### Rejected alternatives

1. **Modify `Bar_history` directly to support tiering.** Status file
   explicitly forbids. Also: strategy state is in closure; surgery risk is
   high.

2. **Pre-compute summaries at ingest time (offline).** Appealing — summaries
   are a function of historical bars only. But: the pre-compute needs to know
   the scenario's `as_of` date, which varies per scenario. Could do it per
   `goldens-small` scenario once at fetch time, but now the scenario data is
   coupled to the universe sexp. Punt; promoter computes on the fly.

3. **Unified `Bar_loader` subsuming `Price_cache`.** Cleaner long-term but
   adds cross-cutting refactor to this PR. Keep `Price_cache` as the raw-CSV
   layer; `Bar_loader` calls into it for bounded date ranges and owns the
   tiered cache.

4. **Parallel runner process for Legacy vs Tiered in one `dune runtest`
   pass.** Faster for CI but harder to reason about. Plan goes with
   sequential: parity test runs both in one OCaml process, one after the
   other. Each ~30s on smoke; 60s total.

## Increments

Each increment is self-contained: builds, tests pass, mergeable
independently. Line budgets include tests.

### 3a — `Bar_loader` types + Metadata loader

**Scope:** types-only + Metadata tier, no integration with Runner yet.

**Files:**

| Path | Purpose |
|---|---|
| `trading/trading/backtest/bar_loader/dune` | library definition |
| `trading/trading/backtest/bar_loader/bar_loader.mli` | public interface: `t`, `tier`, `Metadata.t`, `create`, `promote` (Metadata-only), `get_metadata`, `stats` |
| `trading/trading/backtest/bar_loader/bar_loader.ml` | implementation: `Metadata` loader reads last-bar from `Price_cache` + sector table passed in |
| `trading/trading/backtest/bar_loader/test/dune` | test binary |
| `trading/trading/backtest/bar_loader/test/test_metadata.ml` | unit tests: create empty, promote 10 symbols, stats, idempotent re-promote, get_metadata returns data |

**Dependencies:** None. Lands first.

**Line budget:** ~180 lines (80 .mli, 60 .ml, 40 tests).

**Verify:** `dune build trading/trading/backtest/bar_loader && dune runtest trading/trading/backtest/bar_loader/test`.

### 3b — Summary tier

**Scope:** add `Summary.t` + summary-tier loader that computes 30w MA, ATR,
stage heuristic, RS line from a bounded CSV tail and drops the raw bars.

**Files:**

| Path | Purpose |
|---|---|
| `bar_loader.mli` / `.ml` | extend: `Summary.t`, promote (Summary_tier), demote to Metadata, get_summary |
| `bar_loader/summary_compute.ml{,i}` | pure compute helpers (30w MA, ATR, stage heuristic from bars) — separate module to keep summary logic testable without a Price_cache |
| `bar_loader/test/test_summary.ml` | unit tests: summary values match hand-computed on fixture bars; demotion frees data (stats() reflects drop); idempotent promotions |

**Dependencies:** 3a merged.

**Line budget:** ~220 lines (90 summary_compute, 60 bar_loader delta, 70 tests).

**Verify:** same `dune runtest` scope.

### 3c — Full tier + promotion semantics

**Scope:** add `Full.t` (raw OHLCV list), promote/demote, symbols-at-tier
queries. No runner integration yet.

**Files:**

| Path | Purpose |
|---|---|
| `bar_loader.mli` / `.ml` | extend: `Full.t`, promote (Full_tier), demote semantics (Full → Summary → Metadata), get_full |
| `bar_loader/test/test_full.ml` | unit tests: promote Summary→Full, demote Full→Summary rebuilds summary scalars, Full→Metadata drops everything |

**Dependencies:** 3b merged.

**Line budget:** ~150 lines.

**Verify:** same.

### 3d — Tracer phases for tier operations

**Scope:** extend `Backtest.Trace.Phase.t` with `Promote_summary`,
`Promote_full`, `Demote`. Plumb through `Bar_loader.promote` so promotions
emit phase records when a trace is active.

**Files:**

| Path | Purpose |
|---|---|
| `trading/trading/backtest/lib/trace.mli` / `.ml` | three new phase variants |
| `bar_loader.ml` | accept optional `?trace` arg on `create`, wrap promote/demote internals |
| `bar_loader/test/test_trace_integration.ml` | tests: promote emits Promote_summary phase; counts match; no-trace path is silent |

**Dependencies:** 3c merged. Also: #419 (already in main, so no coordination
with other agents).

**Line budget:** ~120 lines.

**Rationale for landing now, before runner wiring:** once we plumb into
Runner, we want the trace to already distinguish promote vs demote vs load.
Otherwise the first A/B run gives us undifferentiated numbers.

### 3e — Runner + scenario plumbing for `loader_strategy` flag

**Scope:** add the `Legacy | Tiered` switch to `Backtest.Runner.run_backtest`
and `Scenario.t`. Default `Legacy` — Tiered path still dormant.

**Files:**

| Path | Purpose |
|---|---|
| `trading/trading/backtest/lib/runner.mli` / `.ml` | add `?loader_strategy` param, default `Legacy`; Tiered branch still placeholder |
| `trading/trading/backtest/scenarios/scenario.mli` / `.ml` | add optional `loader_strategy` field to `Scenario.t`; sexp round-trips |
| `bin/backtest_runner.ml` | parse `--loader-strategy {legacy,tiered}` CLI flag |
| `scenarios/test/test_scenario.ml` | tests: sexp round-trip with field absent (defaults Legacy) + present (Tiered) |

**Dependencies:** 3d merged.

**Line budget:** ~150 lines. Pure plumbing.

**Verify:** `dune runtest trading/trading/backtest`.

### 3f — Tiered runner path (skeleton) + shadow screener

**Scope:** the actual Tiered execution path. Runner under
`loader_strategy = Tiered`:

1. Builds `Bar_loader` with universe.
2. Promotes all to Metadata up front (Load_bars phase).
3. Creates the simulator with **only** the "always full" symbols (primary
   index + held positions at boot = none). The simulator's `Price_cache`
   only ever sees these symbols.
4. On each Friday: promotes universe to Summary (Promote_summary); runs a
   shadow screener that reads `Summary.t` directly instead of
   `Stock_analysis.analyze` on weekly bars; promotes top candidates to Full
   (Promote_full); feeds the screener output into
   `Weinstein_strategy.entries_from_candidates`.
5. On CreateEntering transition: promote symbol to Full.
6. On Closed transition: demote symbol to Metadata.

This is the **architecturally largest** increment and will probably need to
be split further during implementation. Ship it behind the `Tiered` flag so
`Legacy` stays the default — the parity test is the only consumer until 3g.

**Files:**

| Path | Purpose |
|---|---|
| `runner.ml` | new `_run_tiered_backtest` path; branches in `run_backtest` on flag |
| `bar_loader/shadow_screener.ml{,i}` | reads `Summary.t` for each symbol, applies screener cascade gates (macro, sector, stage heuristic), returns candidate tickers. Wrapper over existing `Screener.screen` that accepts summaries instead of `Stock_analysis.t` — via an adapter |
| `bar_loader/test/test_shadow_screener.ml` | shadow-screener output matches Legacy `_screen_universe` output on a fixture |

**Dependencies:** 3e merged.

**Line budget:** ~300 lines. Over the ~250 target but contained to one
integration commit. Split further if during implementation it balloons past
~400.

**Open question captured at top of §Open questions:** do we need to make the
screener accept summaries as input (changes `Screener.screen` signature), or
do we build summaries and then synthesize enough of `Stock_analysis.t` to
call the existing `Screener.screen`? The latter is less invasive.
Preference: adapter (latter) in 3f, possibly refactor to summary-native in a
later cleanup PR.

### 3g — Parity acceptance test

**Scope:** end-to-end parity harness. This is the merge gate per
the status file's acceptance criterion.

**Files:**

| Path | Purpose |
|---|---|
| `test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp` | short-window, small-universe scenario (~30 symbols, 6 months) |
| `trading/trading/backtest/test/test_tiered_loader_parity.ml` | runs both strategies on the parity scenario, diffs `result.summary`, `result.round_trips`, `result.steps` (equity curve samples) within ε |
| `trading/trading/backtest/test/dune` | wire the binary |

**Dependencies:** 3f merged.

**Line budget:** ~200 lines.

**Acceptance gate semantics:**
- Hard fail: `trade_count` diff ≠ 0.
- Hard fail: any step's `portfolio_value` diff > $0.01.
- Hard fail: `final_portfolio_value` diff > $0.01.
- Hard fail: pinned metric outside declared range (for EITHER strategy).
- Soft warn (logged, not failing): `peak_rss_kb` of Tiered > 50% of Legacy
  on the parity scenario — would indicate Tiered isn't saving memory.
  Parity scenario is too small to expect full savings; use broad scenario
  in 3h for the real number.

### 3h — Broad-scenario nightly A/B trace comparison

**Scope:** GHA-nightly harness that runs broad goldens under both strategies
and posts a trace diff as an artefact. Not a test (too slow), not a merge
gate — just visibility.

**Files:**

| Path | Purpose |
|---|---|
| `dev/scripts/tiered_loader_ab_compare.sh` | script to run one scenario under both strategies, emit traces, diff via `jq` or a small OCaml helper |
| `.github/workflows/tiered-loader-ab.yml` | nightly workflow; uploads traces as artefacts; fails only on hard parity violation |
| `dev/status/backtest-scale.md` | update "Post-merge ramp" section |

**Dependencies:** 3g merged + default flipped to Tiered in the follow-up PR
(per status file — not in this plan's scope).

**Line budget:** ~100 lines.

**Rationale for including 3h in this plan:** the status file's "post-merge
ramp" is vague. Without nightly A/B data we're guessing when it's safe to
flip the default. This makes the ramp data-driven.

## Dependency graph

```
3a (Metadata)
  └─▶ 3b (Summary)
       └─▶ 3c (Full)
            └─▶ 3d (Trace phases)
                 └─▶ 3e (Runner flag plumbing)
                      └─▶ 3f (Tiered path + shadow screener)
                           └─▶ 3g (Parity test) ← merge gate for default flip
                                └─▶ 3h (Nightly A/B comparison, follow-on)
```

Every increment lands independently (<500 lines, build + tests green). 3g is
the last merge gate within this plan; flipping the default and retiring
Legacy are out-of-scope follow-ups (already captured in status file).

## Files to change (aggregate)

New library + modules:
- `trading/trading/backtest/bar_loader/` (6 files + tests)

Extensions:
- `trading/trading/backtest/lib/trace.{ml,mli}` — 3 new Phase variants
- `trading/trading/backtest/lib/runner.{ml,mli}` — `loader_strategy` param,
  Tiered branch
- `trading/trading/backtest/scenarios/scenario.{ml,mli}` — optional
  `loader_strategy` field
- `trading/trading/backtest/bin/backtest_runner.ml` — CLI flag
- `trading/trading/backtest/test/test_tiered_loader_parity.ml` — parity test

New scenario fixture:
- `trading/test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp`

GHA / devops:
- `dev/scripts/tiered_loader_ab_compare.sh`
- `.github/workflows/tiered-loader-ab.yml`

Status / docs:
- `dev/status/backtest-scale.md` — flip PENDING → IN_PROGRESS on 3a land;
  update `## Completed` after each increment; READY_FOR_REVIEW on 3g
- `dev/status/_index.md` — row update

**Not touched** (per scope):
- `Bar_history`, `Weinstein_strategy` internals, `Simulator`, `Price_cache`,
  `Screener.screen` signature (see §Open questions)

## Risks / unknowns

1. **Shadow screener parity.** The biggest risk: summaries are not
   bit-identical to the `Stock_analysis.analyze → Screener.screen` path. If
   there's a subtle indicator-computation difference, the parity test on a
   small scenario may catch it *sometimes* but not always. Mitigation: the
   parity test runs on a scenario seeded to exercise borderline screener
   decisions (a stock right at the stage 1 → 2 boundary, etc.). Capture in
   §Open questions.

2. **Promotion thrash.** If a screener candidate is promoted to Full on
   Friday and the position opens Monday but closes Friday (5-day round-trip),
   we load + unload 1500 bars for nothing. On a broad scenario with many
   tiny trades this could dominate runtime. Mitigation: `Full.t` has a
   refcount-ish protection (once promoted, stays Full for a week before
   demote is considered). Captured in §Open questions.

3. **Scenario file schema migration.** Adding `loader_strategy` to
   `Scenario.t` is additive (default Legacy), but existing scenarios need to
   round-trip through the new sexp deriver. `[@@sexp.allow_extra_fields]`
   already present — verify it covers the additive case.

4. **Sector_map / metadata source.** Today the sector map comes from
   `data/sectors.csv`. Market cap and avg volume are not in `Daily_price.t`
   — they're in the fetcher output. Two options: (a) include cap/volume in
   `Metadata.t` only when available, treat as `None` otherwise; (b) push
   market cap into `Metadata` via a separate CSV. Go with (a) — the first
   consumer of metadata (screener cascade) only needs sector + last close.
   Cap / avg volume are plumbing for later filters. Captured in §Open
   questions.

5. **Parity test determinism.** The simulator's daily loop processes
   symbols in dictionary order via hashtables — insertion order matters for
   `_position_counter` which generates position IDs. If Legacy and Tiered
   insert symbols in a different order, the parity test will fail on
   `position_id` even when behaviour is identical. Mitigation: sort symbols
   deterministically at every insertion site in the Tiered path; the parity
   test compares behaviour, not IDs.

6. **Trace RSS measurement granularity.** Step 2's `peak_rss_kb` reads
   `/proc/self/status` after each phase — good enough to catch GB-scale
   regressions, not bit-level. Plan relies on this for the soft warn in 3g
   and the nightly comparison in 3h. If RSS granularity proves too noisy,
   fall back to object-count heuristics (`Bar_loader.stats`).

## Open questions (to call out in PR description for human review)

1. **Parity threshold ε — exact value?** Plan proposes $0.01 on
   `portfolio_value` diffs. Is that too loose (hides real differences) or
   too tight (flakes)? Need empirical data from 3g implementation.

2. **Scenario selection for broad A/B (3h).** Status file mentions "a few
   weeks of nightly runs" but doesn't name the scenarios. Proposal: all
   `goldens-broad/*.sexp`. Confirm with human.

3. **Should 3f refactor `Screener.screen` to accept summaries natively?** The
   plan currently goes with an adapter (build synthetic `Stock_analysis.t`
   from `Summary.t`). Native-summary screener is cleaner but widens the
   blast radius. Defer or do in 3f?

4. **`Bar_loader` lives in `trading/trading/backtest/bar_loader/`** — should
   it be a sibling of `lib/` and `scenarios/`, or inside `lib/` itself? Plan
   proposes sibling (own dune library) so test binaries have a clean boundary.
   Confirm.

5. **Is `--parallel N` in scenario_runner compatible with per-run
   Bar_loader?** Each child process gets its own Bar_loader instance
   (fork-based), which is fine. But if the shadow screener writes any shared
   state (trace file), we need per-child trace files. Probably a non-issue
   with current trace output-per-run design; verify during 3d implementation.

6. **Full→Metadata demotion semantics: full drop or keep Summary?** Plan
   says Full→Summary→Metadata. Summary is cheap; keeping it means a
   re-promotion to Full skips the summary recompute. But if the position
   closed on a Friday after a 6-month run, the summary scalars are stale.
   Proposal: Full demote lands at Metadata (full drop), rebuild Summary on
   next promote. Confirms simplest correctness. Document in 3c.

## Acceptance criteria (plan-level)

- [ ] 7 increments land as separate commits, each building + tests passing
- [ ] `loader_strategy = Legacy` remains default at merge time
- [ ] Parity test (3g) passes on `smoke/tiered-loader-parity.sexp` — zero
  trade-count diff, < $0.01 portfolio-value diff, all pinned metrics in range
- [ ] `dune build && dune runtest` green on main after each increment
- [ ] `dev/status/backtest-scale.md` updated after each increment; flipped
  to READY_FOR_REVIEW on 3g land
- [ ] Trace (3d) outputs include `Promote_summary`, `Promote_full`, `Demote`
  phases distinctly on a Tiered run
- [ ] Nightly A/B workflow (3h) produces an artefact on broad scenarios;
  failure mode is parity-violation only, not performance regression (those
  go in the post-merge ramp PR)
- [ ] Status file §Post-merge ramp updated with go/no-go thresholds
  resolved from §Open questions

## Out of scope

- **Flipping the default to `Tiered`** — tiny follow-up PR after a few
  weeks of nightly A/B data confirms parity + savings. Per status file.
- **Retiring `Legacy`** — one PR after the default flip. Per status file.
- **Native-summary `Screener.screen` refactor** (§Open questions #3) — if
  the adapter-based 3f works, defer the refactor.
- **Modifying `Bar_history`, `Weinstein_strategy` internals, `Simulator`,
  `Price_cache`** — status file explicit.
- **Incremental indicators** (EMA/RS/ATR tick-by-tick) — parent plan §Out
  of scope; revisit if 3f profiling shows summary recompute is hot.
- **Parallel backtest workers** — orthogonal axis; parent plan §Out of
  scope.
- **Cross-scenario bar caching** (shared immutable bars across parallel
  tunings) — parent plan §Out of scope.
- **Market cap / avg_volume sourcing** — Metadata keeps them as `float
  option` until a later filter needs them; no new CSV ingestion in this
  plan.
