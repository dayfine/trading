# Memtrace post-PR-A — allocation hotspots on `bull-crash-292x6y` (2026-04-26)

Captured the memtrace CTF on the post-Stage-4.5-PR-A panel build to
attribute the remaining ~1.86 GB peak RSS at N=292 T=6y.

## Setup

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 \
    --override "((universe_cap (292)))" \
    --memtrace /tmp/panel-292x6y.ctf
```

- Sampling rate: `1e-4` (one in 10,000 allocations sampled).
- CTF size: 57 MB.
- Run wall: 4:16.43.
- Peak RSS (with memtrace overhead): 1,866 MB (matches post-PR-A
  matrix without the trace).
- Exit 0.

## Tooling caveat

`memtrace_viewer` (the Jane Street GUI) wouldn't install on this opam
switch — its dep solver demands `js_of_ocaml < 5.7.0` which conflicts
with the project's OCaml 5.3 base. Same conflict for `memtrace_hotspots`
and `memtrace_flamegraph` — both fail at runtime with `malformed trace:
monotone timestamps`. Workaround: use `memtrace_dump_trace` (textual
event stream) and aggregate manually with `awk`.

The hand-rolled aggregation reports **cumulative bytes allocated by
proximate-app-frame** (the rightmost frame in each stack that isn't
in `Stdlib`/`Base__`/`Core__`/`Stdio__`/`Caml`/`Sexplib`/`Bytes`). It
captures allocation volume, not retention; high-volume short-lived
allocations are still listed even though they don't show up in peak
RSS.

## Top allocators (post-app-frame aggregation)

```
        bytes  sampled_count  app_frame
     25272240             6  Data_panel__Ohlcv_panels._make_nan_panel
     25272240             6  Data_panel__Indicator_panels._make_nan_panel
     14574656        910733  Trading_simulation_data__Price_cache.get_prices.(fun)
      4183712          1034  Trading_engine__Price_path._decide_high_first_directional
      3347608          2085  Backtest__Panel_strategy_wrapper._calendar_index.(fun)
      1561880        195235  Trading_engine__Price_path._sample_standard_normal
      1463808         84951  Trading_engine__Price_path._sample_student_t.sum_squares
       822464          1172  Data_panel__Bar_panels._weekly_view_from_panel
       631152         39513  Trading_engine__Price_path._append_segment
       562360         45902  Trading_engine__Price_path._generate_bridge_segment.generate_points
       501624         14271  Csv__Csv_storage._read_next_line
       481832         27040  Csv__Parser.parse_line
       316544         19800  Trading_engine__Engine.update_market.(fun)
       315408          6642  Weinstein_strategy__Panel_callbacks._aligned_arrays
       213896           538  Data_panel__Bar_panels.weekly_view_for.take
        55080          3296  Sma._compute_window_value
        42632           142  Weinstein_strategy__Weekly_ma_cache._compute_ma_array
```

## Findings

### 1. Bigarray panels are the only confirmed long-lived bulk

`Ohlcv_panels._make_nan_panel` × 6 + `Indicator_panels._make_nan_panel`
× 6 = **~50 MB** at this scale. Live for the whole run. Matches the
fixed cost α ≈ 86 MB from the matrix.

### 2. `Price_cache.get_prices.(fun)` — extreme call frequency, suspect

**910,733 sampled allocations** at sample rate 1e-4 → estimated
~9 billion real allocations in a 4-minute run. Each is small (~16
bytes / 2 words on average); they're clearly short-lived (the
trace shows `collect` events shortly after most). But the **call
frequency is suspicious** — this dwarfs every other allocator by a
factor of 1,000×.

Quick math: 9 billion calls / 4 minutes / 240 seconds ≈ **38 million
calls per second**. For N_loaded=307 symbols × T=1715 trading days =
527K (symbol, day) cells, that's ~17,000 `get_prices` calls per
(symbol, day). Per-bar lookups are not unusual, but 17,000 per cell
suggests the inner-loop calls `get_prices` per *something* much
finer than per-bar.

This is a **CPU hotspot**, not necessarily an RSS hotspot — most of
those allocations are quickly collected. But it's worth a code
inspection: `Price_cache.get_prices` should be a hashtable lookup
returning a cached value, not allocating per call. If it's
allocating a closure/option/tuple per call, that's the wedge.

**Action**: `grep -n "get_prices" trading/trading/simulation/data/lib/`
and inspect the implementation.

### 3. `Price_path._decide_high_first_directional` — kilobyte-per-call

1,034 sampled calls × ~4 KB/call = ~4 MB cumulative. Each call
allocates kilobytes — likely an array or list of synthesized
intra-day price points. Engine-level (`Trading_engine`), not
strategy.

If the engine generates synthetic price paths per bar (seems likely
given the surrounding `_sample_standard_normal` / `_sample_student_t`
hotspots), this is per-day per-symbol and accumulates. Could
contribute to per-symbol RSS slope.

**Action**: inspect `trading/trading/engine/price_path/` for
opportunities to reuse buffers across calls.

### 4. `Panel_callbacks._aligned_arrays` — modest but per-call

6,642 sampled calls × ~50 bytes = 315 KB cumulative. Builds the
date-aligned arrays for Rs callbacks. Per-symbol-per-Friday allocation;
could pool the buffers since the dates / closes / benchmark closes
arrays have predictable max sizes.

### 5. Ohlcv_panels reads + indicator computations don't show up

Nothing from `Stage.classify_with_callbacks`, `Sma.calculate_sma`,
`Ema.calculate_ema`, `Atr.calculate`, `Rsi.calculate` is in the top
20. PR-D's `Weekly_ma_cache._compute_ma_array` is at 42 KB / 142
calls — done once per (symbol, ma_type) at startup; small.

The data-panels Stage 4 work (PR-A through PR-D) genuinely eliminated
the per-symbol indicator allocation cost it was supposed to.

## Hypothesis on the residual β = 5.12 MB / symbol

The dominant per-symbol cost on small-302 is **NOT** in the strategy
hot path (`_screen_universe`, `Stock_analysis`, `Panel_callbacks`) —
PR-A through PR-D ruled those out. The memtrace points elsewhere:

- `Price_cache.get_prices.(fun)` — high-frequency allocator; even
  if individually short-lived, the GC promotion latency under that
  rate could account for many MB of major-heap "in flight" at any
  given moment.
- `Price_path._decide_high_first_directional` + sister `_sample_*` —
  intra-day price-path generation. If these allocate per-day-per-symbol
  and aren't reused across days, accumulates ~`(per_day_alloc × T_days × N_symbols)`
  in major heap until next GC compaction.

Both live in the **simulation / engine layer**, not the strategy layer.
That's why every Stage 4 PR (which targeted the strategy's per-symbol
work) failed to move the needle.

## Recommendation

### Next investigation

1. **Read `Trading_simulation_data__Price_cache.get_prices.(fun)` and
   trace why it's called ~17,000× per (symbol, day).** If it's
   allocating per call (closure / option / tuple), refactor to
   return `int_option` / unboxed primitives. If the call frequency
   itself is the bug (e.g. caller iterates more than necessary), fix
   the caller.

2. **Read `Trading_engine__Price_path` module.** Specifically
   `_decide_high_first_directional`, `_sample_standard_normal`,
   `_sample_student_t`, `_append_segment`, `_generate_bridge_segment`.
   The 4 KB per call hint at array allocation. Buffer pooling across
   calls is the likely fix.

3. **If neither of the above moves β meaningfully**, run a second
   memtrace at 5× higher sampling rate (`5e-4`) with retention
   tracking enabled (`Memtrace.start_tracing ~report_exn`?) to get
   alloc/free pairs and compute actual peak retention per callsite.

### Stage 4.5 plan revision

PR-B (sector pre-filter) was the next step in the lazy-tier cascade.
**Demote it to optional / not-now** — the matrix and memtrace both
suggest the wedge is in simulation/engine, not in the screener
cascade. PR-B would compound on PR-A's modest impact but doesn't
hit the load-bearing residency.

Open a new mini-plan for the simulation/engine optimisation track
once the code reading above identifies the specific fix.

### Stage 4 status

The architectural Stage 4 work is **functionally complete**: panels
replace the tier system, Bar_history is gone, callbacks replace list
intermediates, weekly aggregation is single-pass, Stage MA is
panel-cached. The 46% RSS reduction (3,468 → 1,861 MB) is real.

The remaining ≤ 800 MB target requires cross-cutting work in the
simulation / engine layer that's outside the Stage 4 scope. Treat the
data-panels track as **DONE** at this RSS level for the day-to-day
backtest workload at N=292; revisit when the simulation/engine
optimisation lands.

## References

- Spike progression: `dev/notes/panels-rss-spike-{,postB,postC,postD}-*.md`
- Matrix progression: `dev/notes/panels-rss-matrix-{,postA-}2026-04-26.md`
- Stage 4.5 plan: `dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md`
- CTF file: `/tmp/panel-292x6y.ctf` (57 MB, in container `trading-1-dev`)
- Code to inspect:
  - `trading/trading/simulation/data/lib/price_cache.ml`
  - `trading/trading/engine/price_path/lib/price_path.ml`
  - `trading/trading/weinstein/strategy/lib/panel_callbacks.ml`
    (`_aligned_arrays`)
