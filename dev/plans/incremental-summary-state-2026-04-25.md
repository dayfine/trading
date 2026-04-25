# Plan: incremental Summary state — push-based per-tick indicators (2026-04-25)

> **SUPERSEDED 2026-04-25** by
> `dev/plans/columnar-data-shape-2026-04-25.md` (PR #554). The
> columnar redesign collapses the same memory cost more
> structurally — Bar_history and the tier system both disappear,
> rather than the tier concept being re-aimed. Reusable pieces of
> this plan (the `INDICATOR` functor signature, the parity-test
> functor, the indicator-by-indicator porting order, the audit of
> Bar_history reader sites) carry forward into the columnar plan's
> stages. This document is preserved as historical record showing
> the path-not-taken and the indicator audit it captured.

## Goal

Replace the current "load full bar history → compute Summary scalars
each Friday" pattern with **incremental rolling state per (symbol,
indicator)** updated O(1) per simulator tick from the existing
`today_data` map. The architectural shift collapses Tier 3's biggest
memory cost AND the per-Friday CPU spike, AND opens the door to the
release-gate scenarios (5000+ stocks × 10 years) that current Tiered
can't fit.

## Why this is the right fix (summary of today's findings)

5 hypothesis tests today (H1 trim, H2 cap, H3 skip-ad-breadth, H7
stream-parse, GC tuning) and the List.filter refactor (#548) ALL
disproved on the bull-crash 2015-2020 baseline. The +95% Tiered RSS
gap is structural, traceable to the post-#519 design choice:
**every Friday, EVERY universe symbol gets promoted to Full + seeded
into Bar_history.** That's the cost of fixing the 30-cap divergence
bug from #517.

The right architectural answer isn't to shrink what's promoted — it's
to **not need the bars at screening time at all.** Most Weinstein
indicators have clean incremental forms; computing them online from
`today_data` per tick eliminates the bar-history retention.

## Audit findings (verbatim from codebase walk)

### Surprise #1: the abstraction already exists

`trading/trading/strategy/lib/strategy_interface.mli` lines 23-24:

```ocaml
type get_indicator_fn =
  string -> indicator_name -> int -> Types.Cadence.t -> float option
```

The `STRATEGY` module type's `on_market_close` already takes a
`get_indicator` parameter. **`Weinstein_strategy` doesn't use it** —
it does its own `Bar_history.weekly_bars_for + Stage.classify`
locally. So the hook is built; the wiring isn't done.

This means the refactor doesn't add new API surface — it populates
existing API.

### Indicator inventory (all batch-shaped today)

`trading/analysis/technical/indicators/`:

| Module | Current API | Incremental form | Notes |
|---|---|---|---|
| `EMA.calculate_ema` | `value list → int → value list` | trivial — `α·new + (1-α)·prev` | O(1) state |
| `SMA.calculate_sma` | `value list → int → value list` | ring buffer of last N | O(N) state, but bounded |
| `SMA.calculate_weighted_ma` | `value list → int → value list` | same as SMA + weight ramp | O(N) state |
| `ATR.atr` | `bars → period → float option` | `(avg_tr, prev_close)` per Wilder | O(1) state |
| `Relative_strength.analyze` | `aligned (price, benchmark) list → ...` | rolling 52w ratio + MA | O(52) state per symbol + benchmark series |
| `Time_period.Conversion.daily_to_weekly` | `bars list → bars list` | bucket on day-of-week | per-symbol "current week accumulator" |

`trading/analysis/weinstein/`:

| Module | Current API | Incremental form |
|---|---|---|
| `Stage.classify` | `bars → stage` | composes MA + slope + above/below count — needs MA + last 6 weekly closes (40 bars worth, bounded) |
| `Volume.compute` | bar window | not audited but likely needs ring buffer of last 30 days for volume_avg comparison |
| `Resistance.*` | bar window | swing-high/low detection — bounded ring buffer |
| `Rs.*` | wraps `Relative_strength` | follows from RS port |

`trading/trading/backtest/bar_loader/summary_compute.{ml,mli}` is
ALREADY the right module shape — it's just batch today (input: bars
list, output: summary_values). Refactor target: same module, new
incremental API.

### Bar_history readers (6 sites, all in strategy code)

From the existing audit (`dev/notes/bar-history-readers-2026-04-24.md`):

1. `macro_inputs.ml:28` — `weekly_bars_for ~n:52` for global indices
2. `macro_inputs.ml:39` — `weekly_bars_for ~n:52` for sector ETFs
3. `stops_runner.ml:11` — `weekly_bars_for ~n:52` for stops MA
4. `weinstein_strategy.ml:100` — `daily_bars_for` for support floor (HARD CASE)
5. `weinstein_strategy.ml:190` — `weekly_bars_for ~n:52` for per-position MA
6. `weinstein_strategy.ml:284` — `weekly_bars_for ~n:52` for primary index

5 of 6 are 52-week MA-style — easy incremental. Site #4 is the
support-floor lookup over 90 daily bars — slightly harder but the
"tier the cheap-then-hard" pattern from your guidance applies cleanly.

### Existing warmup (already a hard requirement)

`runner.ml:18`: `let warmup_days = 210` (= 30 weekly bars × 7 calendar
days). Both Legacy and Tiered runners already prepend this to the
simulation start_date. **No new warmup mechanism needed** — the new
incremental indicators consume the same warmup ticks the existing
batch indicators do, just one tick at a time instead of all at once.

### Strategy entry path summary

`Weinstein_strategy.on_market_close` currently:

1. Reads `Bar_history.weekly_bars_for ~n:52` for primary index → checks if benchmark is bullish
2. For each held position: reads bars → `Stage.classify` for stage + stops
3. For each universe symbol: reads bars → `Stage.classify` + macro inputs → screen
4. Builds candidates + sizing → emits `CreateEntering` transitions

The new path: replaces every `weekly_bars_for ~n:N` with
`get_indicator <symbol> <name> <period> Weekly`. The simulator
maintains incremental state, returns the latest indicator value O(1).

## Architecture

### Three layers (unchanged from today, but populated differently)

```
┌─────────────────────────────────────────────┐
│ Weinstein_strategy.on_market_close          │  ← reads via get_indicator
└─────────────────────────────────────────────┘
                  ↑
                  │  get_indicator : sym → name → period → cadence
                  │
┌─────────────────────────────────────────────┐
│ Indicator_state — incremental rolling state │  ← NEW MODULE
│ per (symbol, indicator, period, cadence)    │
└─────────────────────────────────────────────┘
                  ↑
                  │  step : state → today's OHLC → state
                  │
┌─────────────────────────────────────────────┐
│ Simulator's per-tick today_data : sym → OHLC│  ← already exists
└─────────────────────────────────────────────┘
```

`Indicator_state` is a Hashtbl indexed by `(symbol, indicator, period,
cadence)` to a per-key state record. Each indicator has its own state
shape and `step` function. The wrapper around the simulator calls
`Indicator_state.advance ~today_data` once per tick BEFORE the
strategy runs.

### Generic abstraction (per your "consider generic programming")

```ocaml
(* trading/analysis/technical/indicators/incremental/lib/incremental.mli *)

module type INDICATOR = sig
  type config
  type state
  type value

  val init : config -> state
  val step : state -> Types.Daily_price.t -> state
  val read : state -> value option   (* None if not warm yet *)
end

module Make_indicator_table (I : INDICATOR) : sig
  type t  (* Hashtbl<symbol, I.state> *)
  val create : I.config -> t
  val advance : t -> today_data:(string, Types.Daily_price.t) Hashtbl.t -> unit
  val read : t -> symbol:string -> I.value option
end
```

Each indicator (EMA, SMA, ATR, RS, Stage, Volume, Resistance, ...)
implements `INDICATOR`. The simulator's wrapper calls
`advance ~today_data` per tick on each registered table. Strategy
reads via `get_indicator → table.read`.

This is **the generic structure** — one `INDICATOR` interface, N
indicator implementations, one `Make_indicator_table` functor that
turns each into a per-symbol streaming state. Test harness becomes
parametric too: one `Test_make_indicator_table` functor that
parity-tests "fold over batch" vs "step per tick".

### Tiered indicator computation (per your "easy first, hard on demand")

For the hard cases (support_floor, resistance, volume confirmation):

- The CHEAP incremental signal screens out symbols. E.g. RSI > 50,
  Stage = 2 — fast O(1) reads from `Indicator_state`.
- For symbols passing the cheap screen, **then** call the expensive
  bar-history form. Keep `Bar_history` ALIVE only for the small set
  of "promoted" symbols.

This is exactly today's Bar_loader Metadata → Summary → Full cascade,
re-aimed: **Summary's job becomes "the cheap screening signals that
can be computed incrementally."** Full is reserved for the hard cases
that genuinely need bars.

So the existing tier names stay; the work each tier does shifts.

## Indicator porting order (from cheapest to hardest)

Each step is its own ~150-300 LOC PR with parity tests against the
batch form.

| Step | Indicator | Estimated LOC | Risk |
|---|---|---|---|
| 1 | `Incremental` functor + signature + parity-test functor | ~200 | low — pure type-level scaffolding |
| 2 | `EMA` incremental impl + table | ~120 | low — formula is standard |
| 3 | `SMA` + `WMA` incremental impl + tables | ~180 | low — ring buffer; behavior must match batch on identical input |
| 4 | `ATR(14)` incremental impl + table | ~140 | low — Wilder smoothing is standard |
| 5 | `Daily_to_weekly` aggregator (per-symbol "current week" accumulator) | ~150 | medium — tricky around week boundaries; needs careful day-of-week handling |
| 6 | `Relative_strength.Mansfield` incremental | ~250 | medium — needs benchmark series shared across symbols |
| 7 | `Stage.classify` incremental (composes MA + slope + above-count) | ~200 | medium — multi-input composition |
| 8 | `Summary_compute` rebuilt on top of above | ~150 | medium — drop-in replacement of `compute_values` |
| 9 | Wire `Indicator_state` into the simulator (call `advance` per tick) | ~100 | medium — find the right hook in `runner.ml` / `tiered_runner.ml` |
| 10 | Wire `Weinstein_strategy` to read via `get_indicator` for steps 1-5 (the easy bar-history sites) | ~250 | high — load-bearing parity-test hangs on this |
| 11 | Tiered support_floor + resistance use cheap pre-filter then on-demand bar load | ~300 | high — hard cases; needs careful design to keep parity |
| 12 | Drop the post-#519 promote-all-Friday in `_run_friday_cycle`. Revert to "promote candidates from inner screener" — now safe because inner has all info from `Indicator_state` | ~50 | low — net delete |

**Total: ~2,290 LOC across 12 PRs.** Roughly 2-3 weeks of focused work
if done carefully with parity tests at each step. Every PR is
independently merge-able and behavior-preserving.

## Risk register

### High-risk areas

1. **Daily-to-weekly aggregation incremental form (step 5).** Today's
   `Time_period.Conversion.daily_to_weekly` operates on a complete
   list and emits "include partial week" or not. Incrementally, you
   need a per-symbol "current week so far" accumulator that flushes
   on day-of-week boundary AND emits the in-progress partial week
   when read mid-week. Behaviour must match batch bit-identically
   when the date range is week-aligned, AND when it isn't.
   Mitigation: parametric parity test (any randomly-generated bar
   sequence: batch result == iterative-step result).

2. **Stage.classify incremental composition (step 7).** Today
   `Stage.classify` consumes a list, derives MA slope from
   `MA[lookback_ago]` vs `MA[now]`, derives `above_ma_count` over the
   last 6 weeks. Incrementally this requires keeping not just the
   current MA but a small history of MA values + the last 6 weekly
   closes. State size grows accordingly (small but non-trivial).
   Mitigation: define state shape carefully; parity-test on real bull-
   crash data.

3. **Wiring into Weinstein_strategy (step 10).** This is the load-
   bearing parity-test step. Any minor numerical drift between batch
   and incremental forms (e.g., different floating-point summation
   order) would flip strategy decisions over a 6-year run.
   Mitigation: do step 10 ONLY after every individual indicator
   passes a strict bit-identical parity test in step 1's test
   functor. Adopt explicit summation order in incremental forms
   matching batch (left-to-right fold over chronological bars).

4. **Tiered's `_run_friday_cycle` revert (step 12).** Currently
   promotes ALL universe symbols to Full each Friday. Step 12
   reverses this: only promote Inner-screener-nominated candidates.
   Risk: re-introducing the #517 30-cap-style divergence if Inner's
   nomination logic doesn't see the same indicators it did pre-step-12.
   Mitigation: step 10 must precede step 12. Inner now reads via
   `get_indicator` which is populated for ALL symbols (because
   Indicator_state is updated for everyone every tick — that's the
   incremental cost). So Inner sees full universe at screen time;
   Bar_history only needed for the candidates it picks.

### Medium-risk areas

5. **Initial-condition / warmup correctness.** Today: each indicator
   returns `None` until enough bars have been seen. Incremental:
   each indicator's `read` returns `None` while warming. Need to
   verify the `None` boundary matches between forms (e.g., MA-30w
   batch returns `Some` after 30 weekly bars; incremental should
   too, not 31 or 29).
   Mitigation: parity-test functor checks first-`Some` index.

6. **Memory cost of Indicator_state.** The per-symbol state is small
   (5-10 KB) but multiplied by N. For N=292 it's ~3 MB; for N=5000
   it's ~50 MB. Manageable but visible.
   Mitigation: profile after step 9 lands.

7. **CPU cost of `advance` per tick.** Each tick hits N
   `Hashtbl.replace` calls per indicator × ~6 indicators. For N=292
   that's ~1700 ops per day × 1500 days = 2.5M total. Negligible.
   For N=5000: 7.5M ops × 1500 days = 11M. Still fast (μs each).
   Mitigation: profile after step 9 lands.

### Low-risk

8. **Strategy-level test burden.** Each indicator gets one parity
   test (batch vs incremental). The Tiered/Legacy parity test
   (`test_tiered_loader_parity`) is the load-bearing assertion at
   step 10 and again at step 12.
   Mitigation: parametric `Test_make_indicator_table` functor reduces
   per-indicator test boilerplate to ~30 lines each.

## Phasing recommendation

- **Land steps 1-8 over multiple weeks.** Each is independently
  merge-able; none change strategy behavior (the incremental
  indicators ship as dead code initially).
- **Step 9 (wire `advance` into simulator) is the activation
  switch** — at this point `Indicator_state` is populated but Strategy
  still uses Bar_history. No behavior change but parallel state
  exists. Allows comparing read paths.
- **Step 10 is the cut-over.** Strategy starts reading via
  `get_indicator`. Parity test must be green at end of this step.
- **Step 11 handles the hard cases** (support_floor, resistance) via
  the tier-cheap-then-hard pattern.
- **Step 12 is the cleanup** — revert the post-#519 promote-all and
  reclaim the memory.

## What this WON'T fix

- The Legacy strategy. Legacy uses `Bar_history.accumulate` (one bar
  appended per tick, per symbol). The Bar_history accumulation is
  Legacy's fundamental cost. To address Legacy's RSS too, Legacy
  itself would need to migrate to `get_indicator`. Out of scope for
  this plan; could be a follow-on.
- AD-breadth load. Same path for both strategies; per-day macro
  computation. Could go incremental separately. Out of scope.
- The csv_storage churn for the per-Friday Promote_full cycle —
  obviated by step 12 (no more per-Friday Full-promotion of the
  universe).

## Decisions (ratified 2026-04-25)

1. **Branch convention: one branch per step, merging into main between.**
   12 branches: `feat/incremental-step01-functor`,
   `feat/incremental-step02-ema`, ..., `feat/incremental-step12-revert-promote-all`.
   Each step's parity tests must be green at merge time. Inter-step
   dependencies are linear (step N+1 builds on step N), but each
   landed step is independently revertable.

2. **Owner split:** `feat-backtest` agent ships steps 1-9 (the
   incremental functor + indicator ports + simulator wiring — all
   infrastructure under `trading/analysis/technical/indicators/` and
   `trading/trading/backtest/`). `feat-weinstein` agent ships steps
   10-12 (Weinstein_strategy cut-over, hard-case tiering,
   promote-all revert — under `trading/trading/weinstein/`). The
   handoff is at the end of step 9 — `Indicator_state` is populated
   alongside Bar_history, no behavior change yet, then feat-weinstein
   picks up the strategy migration.

3. **Success metric: the release-gate scenario (5000 stocks × 10y)
   AND reasonable memory at smaller scales.** Two-pronged criteria:
   - **Release-gate (tier 4 from `dev/plans/perf-scenario-catalog-2026-04-25.md`):**
     Tiered ≤8 GB, Legacy ≤6 GB at N=5000, T=10y on
     production-realistic universe (long-history blue chips). This
     is the hard target.
   - **Smaller-scale (tier 2/3):** No regression vs current
     post-#548 baseline at N≤1000. Plan should not make small
     scenarios worse to optimize big ones. Specifically: bull-crash
     2015-2020 at N=292 on /tmp/data-small-302 should drop from
     today's Tiered 3.74 GB to ≤2 GB (extrapolated bound based on
     incremental Summary state size).
   Each step's PR should report numbers against BOTH targets.

4. **Rollback: keep the bar-history path under a config toggle for
   one or two releases.** Specifically:
   - Add `summary_compute_mode : [`Batch | `Incremental]` to
     `Weinstein_strategy.config` (or equivalent place). Default
     flips to `Incremental` at end of step 10.
   - Bar-history path and incremental path coexist for ≥2 releases,
     gated on the config field.
   - **Track the cleanup as an explicit later step (step 13):**
     once incremental has been on by default for ≥2 releases with no
     parity-test escapes in production, drop the toggle + delete the
     batch path code. Add this as a ticking-clock follow-up under
     this plan's § Cleanup section. Don't let dead code linger.

## Cleanup (step 13, scheduled)

After steps 1-12 land + 2 release cycles of stability:

- Drop `summary_compute_mode` config field
- Delete `Bar_history.weekly_bars_for` / `daily_bars_for` callers in
  the strategy hot path (they exist only to support the rollback)
- Delete the legacy `Summary_compute.compute_values` (now-unused
  batch form)
- Update `dev/notes/bar-history-readers-2026-04-24.md` audit to
  reflect the smaller surface

Tracked as a separate item to ensure the toggle doesn't become permanent
technical debt.

## What's NOT in this plan

- Implementation. This is a plan only; no code changes.
- AD-breadth refactor. Same path both strategies; separate concern.
- Csv_storage further optimization. Already streams (#543);
  obviated by step 12 anyway.
- Migration of existing Python perf scripts to OCaml (per
  `feedback_no_more_python.md`). Separate cleanup.
