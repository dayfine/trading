# Plan: columnar data shape — Bigarray panels supersede the tier system (2026-04-25)

## Status

**Pre-design proposal.** Supersedes
`dev/plans/incremental-summary-state-2026-04-25.md` (PR #551 merged
2026-04-25) if accepted. Nothing has been built yet; the only sunk cost
in the older plan is the plan document itself plus the empty
`dev/status/incremental-indicators.md` track row in #552.

## The lacuna in the original design

The Weinstein design docs (`docs/design/weinstein-trading-system-v2.md`,
`docs/design/codebase-assessment.md`, `docs/design/eng-design-{1..4}-*.md`)
specify behaviour and component boundaries — what each module does, who
calls whom, what config knobs exist. They are silent on **the in-memory
shape of the data flowing through**. The implementation defaulted to the
shape OCaml encourages: per-symbol records, lists of bars, Hashtbl
indices.

That default is the wrong choice for time-series at scale. OHLCV +
derived indicators are naturally a 3-D matrix — symbols × days × {OHLCV
+ indicator columns} — and every operation the strategy performs is
either a rolling reduction over a column or a cross-section read across
symbols on a given day. That is exactly what NumPy / pandas / Owl excel
at, and what per-symbol scalar OCaml is worst at.

This plan asks: what does the codebase look like if we name the shape
correctly?

## Today's shape (per-symbol scalar)

```
Bar_loader:
  Metadata_tier : (string, Metadata.t) Hashtbl    — last close + sector per symbol
  Summary_tier  : (string, Summary.t)  Hashtbl    — derived scalars (ma_30w, atr, rs)
  Full_tier     : (string, Full.t)     Hashtbl    — Full.bars : Daily_price.t list

Strategy state:
  Bar_history   : (string, Daily_price.t list)    — parallel per-symbol bar lists
  (indicator state recomputed on demand by walking lists)
```

Each universe symbol carries:
- a Hashtbl entry in Metadata + Summary + Full (when promoted)
- a Hashtbl entry in Bar_history with its own list copy
- per-bar Daily_price.t records on the OCaml heap (~120 B each with
  header overhead)
- indicator computations done by walking those lists per tick

For 5000 symbols × 10y at the release-gate target:
- Raw OHLCV in `Full.bars` lists: 5000 × 2520 × 120 B ≈ **1.5 GB**
- `Bar_history` parallel lists: another **1.5 GB**
- Hashtbl + record overhead: ~50–100 MB
- List.filter / weekly-aggregation intermediates: highly variable
- Total observed: 12–22 GB extrapolated (per
  `dev/notes/bull-crash-sweep-2026-04-25.md`)

The +95% Tiered RSS gap measured against Legacy is structural: post-#519
the Friday cycle promotes EVERY universe symbol to Full + seeds
Bar_history, so the parallel cache is real for every symbol every week.

## Proposed shape: columnar panels

```
Symbol_index    : bijection string ↔ int over the universe (size N)

Ohlcv_panels    : 5 Bigarray.Array2.t of shape N × T (one per OHLCV field)
                  Open_panel, High_panel, Low_panel, Close_panel, Volume_panel
                  Layout: C, float64. Each ~80 MB at N=5000 T=2520.

Indicator_panel : Bigarray.Array2.t of shape N × T per indicator
                  EMA_50, MA_30W, ATR_14, RSI_14, RS_line_52W, ...
                  Float-valued: Bigarray.Array2.float64.
                  Variant-valued (e.g. Stage): Bigarray.Array2.int8_unsigned with a
                    decoder.

Cursor          : current tick index t : int

Strategy reads via the existing `get_indicator_fn` interface. Implementation
becomes a single Bigarray.Array2.unsafe_get — O(1), no allocation, no walk.
```

Total bars store at N=5000 T=10y: **5 × 80 MB = 400 MB**, contiguous,
malloc'd outside the OCaml heap (Bigarray backing buffers don't go
through the GC).

### Why split OHLCV into 5 panels rather than one N×T×5

Two layout choices:
- **Combined `[N; T; 5]` C-layout**: same-symbol same-day fields
  contiguous. Bad for the cross-section "today's close for all symbols"
  reads that drive the indicator advance loop (stride = 5×T).
- **Combined `[5; T; N]` F-layout**: cross-section contiguous, but
  bounded-window reads for a single symbol (e.g. support-floor lookup)
  become strided.
- **5 separate `Close_panel : N × T`, `Open_panel : N × T`, …**: best of
  both. Cross-section read = one panel's column. Window read for one
  symbol = one panel's row slice. Same total bytes. Costs only 5
  Bigarray handles.

Recommend separate panels per field. The OHLCV bundle was a useful unit
when bars were heap records; it stops being a unit once bars are
columns.

### Symbol_index and universe-set churn

```ocaml
module Symbol_index : sig
  type t
  val create : universe:string list -> t
  val to_row : t -> string -> int option
  val of_row : t -> int -> string
  val n : t -> int
end
```

Backtest case: universe is fixed at backtest construction (from
sectors.csv + universe_cap). N is fixed for the run. New symbols cannot
appear mid-backtest because the universe was decided up front; symbols
that didn't trade yet on a given day have NaN / sentinel values in their
panel cells.

Live case: universe rebalance triggers a panel rebuild (rare event, ~per
month at most). Symbol_index changes; old panels are copied into new
panels at the matching rows; new symbols start with NaN, get filled
forward from CSV during the rebalance step. This is genuinely awkward
but the awkwardness is bounded — a known quarterly-or-so event, not
something the per-tick path needs to handle.

Defer live-mode panel-rebuild handling to a separate sub-design once
backtest works.

### Cadence (Daily / Weekly / Monthly)

`get_indicator_fn` takes a `Types.Cadence.t`. Two clean options:
- Maintain a parallel `Ohlcv_weekly_panel : N × W × 5` where W is the
  number of weeks in the range. Daily tick on the last trading day of
  the week appends a row.
- Compute weekly indicators directly from the daily panel by reading
  every 5th row. Simpler but the "week boundary" logic (incl. holidays)
  has to live in each weekly indicator's step.

Recommend: separate weekly panel. Weekly indicator panels write into
weekly cadence; the daily-tick wrapper does one panel append per Friday.
Holidays are handled once at the daily→weekly boundary, not in each
indicator.

### Tick advance loop

```ocaml
val advance_tick :
  Bar_panels.t ->
  today_data:(string, Types.Daily_price.t) Hashtbl.t ->
  date:Date.t ->
  unit
(* Writes today's row into Open/High/Low/Close/Volume panels.
   For each registered indicator: calls indicator.advance ~today_row
   which reads the close-row + indicator's prior-row state and writes the
   new value to its indicator panel.
   On Friday: also appends the week's row to weekly panels and runs
   weekly indicator advance.
   No allocations on the hot path. *)
```

Strategy's `on_market_close` callback receives a `get_indicator` closure
backed by `Bigarray.Array2.unsafe_get panel ~row:(Symbol_index.to_row
sym) ~col:t`. O(1), zero allocation per read.

### Indicator implementation interface

```ocaml
module type INDICATOR_KERNEL = sig
  type config
  val name : string
  val cadence : Types.Cadence.t
  val warmup : int
  (* Step over the cross-section: for each symbol row r, read the input
     panels at column t-1 + the new value at column t, write to output
     panel at column t. *)
  val advance :
    config ->
    inputs:Bigarray.Array2.float64 array ->   (* e.g. [|close_panel|] *)
    output:Bigarray.Array2.float64 ->
    t:int ->
    unit
end
```

The kernel sees the panels directly, not records. This is where SIMD
auto-vectorization can kick in (the OCaml compiler emits tight loops
over Bigarray that LLVM-style optimizers vectorize well; opportunity for
hand-written `Bigstring.unsafe_set_int64` if needed).

A registry maps indicator-name + period + cadence to a kernel + output
panel.

### What collapses (concrete file-by-file)

- **`trading/trading/backtest/bar_loader/`** — entire Tier system
  becomes a thin "load CSV → fill panel" module (~150 LOC). No
  Metadata/Summary/Full distinction. No `Promote_*` operations. No tier
  state machine. **`bar_loader.ml`/`mli`/`full_compute.ml`/
  `summary_compute.ml`/`shadow_screener.ml` all delete or shrink ≥80%.**
- **`tiered_strategy_wrapper.ml` Friday cycle** — disappears. No
  promotion, nothing to orchestrate. The wrapper's only job becomes
  "advance the panel" which is now a one-liner.
- **`Bar_history` in strategy** — stops existing as a parallel data
  structure. The 6 reader sites become panel reads:
  - `macro_inputs.ml:28,39` — read MA_index_panel / MA_sector_panel
  - `stops_runner.ml:11`, `weinstein_strategy.ml:190,284` — read MA_30W_panel
  - `weinstein_strategy.ml:100` (support floor, the hard case) — read
    a 90-day window from `Low_panel` directly via `Bigarray.Array2.sub_left`,
    no copy
- **`Strategy_wrapper.ml`** — its job of seeding/maintaining
  `Bar_history` per position evaporates.
- **The +95% Tiered RSS gap** — structurally impossible. There is no
  parallel cache to hold; `Close_panel` IS the cache, and there's only
  one of it.
- **`loader_strategy = Tiered | Legacy` flag** — meaningless after
  migration; deleted in step 5. The "Tiered flip" decision goes away.
- **The ~600 KB / symbol per-Friday Promote_full cost** — gone. No
  promotion, no Full-tier seeding, no Bar_history population.

### What stays scalar

These are intrinsically per-position / per-order, with text-keyed state
(status, fills, P&L). Vectorizing them adds complexity for no gain:

- **`Trading_portfolio.Portfolio`** — per-position records, mutable
  cash/positions. Stays as-is.
- **`Trading_orders.Order`** — per-order lifecycle. Stays.
- **`Trading_engine`** — fill simulation, commission. Stays.
- **`Position` / `Position.transition`** — per-position state machine.
  Stays.
- **Stop-loss state** — per-position trailing stop value. Stays
  scalar; reads indicator value via `get_indicator`.
- **Round-trip metrics, P&L accounting** — per-trade. Stay.

The boundary is sharp: **historical and derived market data is
columnar; account state is scalar.** This matches reality — there are
many days × many symbols of data, but only a few open positions at any
time.

## Bigarray vs Owl

**Recommendation: Bigarray (stdlib).**

| Dimension | Bigarray | Owl |
|---|---|---|
| Deps | none | openblas + lapacke + eigen + nontrivial install matrix |
| Compile time impact | zero | substantial |
| Storage layout | exactly what we need | same underlying Bigarray |
| Cross-section ops | hand-written (10–30 LOC per indicator) | built-in (slicing, broadcasts) |
| Rolling EMA / Wilder | hand-written (~20 LOC each) | not built-in either way |
| Dataframe (named columns) | not provided | `Owl_dataframe` available |
| GC interaction | backing buffer outside OCaml heap | same |
| Maturity | stdlib — never breaks | active development; some API churn |

The win is in the data layout, not the API. Indicator kernels are
~20–30 lines each (EMA, Wilder smoothing, ATR, RSI, RS line are all
tight loops with O(1) state). Hand-writing them in pure OCaml +
Bigarray is preferable to pulling Owl's transitive deps for ~200 lines
of helper code.

Reconsider Owl if the screener cascade or backtest tooling later wants
named-column dataframes (Owl_dataframe), or matrix-algebra signals
(covariance, regression). At that point Owl can be added incrementally
on top of the panel infra; the panels are already Bigarray-shaped so
they pass to Owl with zero conversion.

## Memory and CPU expectations

### Memory at the release-gate target (N=5000, T=10y = 2520 trading days)

| Component | Bytes | Notes |
|---|---:|---|
| 5 OHLCV panels | 504 MB | 5 × 5000 × 2520 × 8 |
| 6 daily indicator panels (EMA_50, MA_30W, ATR_14, RSI_14, Stage_int8, Vol_MA) | ~500 MB | 5 × 100 MB + Stage at 12.5 MB |
| 2 weekly indicator panels (MA_30W_weekly, RS_line_52W_weekly) | 40 MB | 5000 × 520 weeks × 8 × 2 |
| Symbol_index, cursors, registry | < 1 MB | |
| Position / order / portfolio scalar state | < 10 MB | bounded by open-position count |
| **Total panel residency** | **~1.05 GB** | bounded, no growth from List.filter intermediates |
| Linux RSS at backtest end | ~1.2 GB | + glibc slabs, OCaml runtime |

Compare to today's 12–22 GB extrapolated. **~10× memory reduction at
release-gate scale.**

Earlier ticks have less resident memory because Bigarray malloc is
page-mapped; cells only become resident when written. RSS grows
linearly with t, not stepwise on Friday.

### CPU

Indicator advance per tick is a tight loop over N symbols of one
Bigarray column. At N=5000:
- EMA: ~5 µs (5000 × 4 ops)
- Wilder smoothing: ~10 µs
- Stage classify (depends on EMA + slope + above/below): ~30 µs
- All daily indicators per tick: ~150 µs
- 2520 ticks: ~400 ms total indicator time

Compare to today's 600+ s wall on bull-crash 1000 stocks × 6y. The
bottleneck moves from indicator computation to CSV loading + strategy
decision logic.

### Cold start

CSV loading still happens once per symbol up front (warmup window) +
incrementally per tick. Could be parallelized with Domainslib later; not
in MVP.

For the 5000-symbol case, warmup CSV load = 5000 reads × ~10 ms each =
~50 s sequentially. Acceptable for a release-gate run; parallel CSV
load is a tier-2 optimization later.

## Migration sequencing

Five stages, each independently mergeable, each with a parity gate
against the existing scalar implementation. Total ~2000 LOC.

### Stage 0: spike + benchmark (~300 LOC, 1–2 days)

Build:
- `trading/trading/data_panel/` new top-level module
- `Symbol_index`, `Ohlcv_panels` (5 Bigarrays + load-from-CSV)
- One indicator: `EMA_kernel` + parity-test against
  `Analysis_indicators.EMA.calculate_ema`

Gate: byte-identical EMA values on a 100-symbol 1y test fixture; RSS
< 50% of current scalar implementation at N=300 T=6y on bull-crash
goldens.

Decision point: if parity gate fails (FP drift > 1 ULP) or RSS gain
< 30%, abort the migration and revisit.

### Stage 1: panel-backed `get_indicator` (~500 LOC, 2–3 days)

Wire the strategy's `get_indicator` callback to read from indicator
panels. Keep `Bar_history` alive (still feeding indicator computation
for non-ported indicators). Port indicators: EMA, SMA, ATR, RSI.

Gate: all `goldens-small/*` PV-identical to ≤ $0.01 vs main; trade lists
bit-identical; perf-sweep N=300 T=6y RSS Tiered drop ≥ 30% vs main.

Branch: `feat/panels-stage01-get-indicator` (no stack — single PR).

### Stage 2: replace `Bar_history` reads with panel views (~400 LOC, 2–3 days)

The 6 `Bar_history` readers (macro_inputs ×2, stops_runner ×1,
weinstein_strategy ×3) port to panel reads. The hard one
(weinstein_strategy.ml:100, support-floor 90-day window) becomes a
`Bigarray.Array2.sub_left Low_panel ~pos:(t-90) ~len:90` — zero copy.

Once the last reader is ported, delete `Bar_history` from strategy
state. The wrapper's seeding code in `tiered_strategy_wrapper.ml` /
`strategy_wrapper.ml` deletes with it.

Gate: same as Stage 1. Memory drop should land hard here — expected
RSS Tiered N=1000 T=3y drops from 3.83 GB → ~600 MB.

Branch: `feat/panels-stage02-no-bar-history`.

### Stage 3: collapse Bar_loader tier system (~400 LOC, 2 days)

Delete:
- `Summary` tier + `Summary_compute` (now in indicator panels)
- `Full` tier + `Full_compute` (now in OHLCV panels)
- `Shadow_screener` (cascade now reads indicator panels directly)
- `tiered_strategy_wrapper.ml` Friday cycle
- The `Promote_metadata`, `Promote_summary`, `Promote_full`,
  `Demote` `Trace.Phase.t` variants

Replace with:
- `Bar_panels.t` = 5 OHLCV + indicator panels + symbol_index
- A simple "load this date's bars from cache, write to panels" advance

Gate: same. The `loader_strategy = Tiered | Legacy` flag goes away.
There's only one path now.

Branch: `feat/panels-stage03-tier-collapse`. Big PR — touches many call
sites — but mostly deletions.

### Stage 4: weekly cadence + remaining indicators (~300 LOC, 2 days)

Add `Ohlcv_weekly_panels` + Friday-rollup. Port `MA_30W` weekly,
`RS_line_52W` weekly, Stage classifier, Volume confirmation, Resistance.

Gate: golden parity. By end of stage 4, every indicator the strategy
reads goes through panels.

Branch: `feat/panels-stage04-weekly`.

### Stage 5: live-mode universe-rebalance (~150 LOC, 1 day)

Implement panel-rebuild on universe change. Backtest never exercises
this; only matters once live mode lands. Could defer further.

Branch: `feat/panels-stage05-live`.

### Total

~2000 LOC, 5 PRs over ~10 working days. Each stage has a clear gate; if
any stage fails its parity gate the prior stages still merged are
useful in their own right (Stage 1 alone gives the indicator
abstraction; Stage 2 alone gives the memory win).

## Risks

### R1: floating-point parity (high)

Vector kernel summation order may differ from scalar walk order. EMA
seed in particular: `α·new + (1-α)·prev` is associative, but if the
warmup average uses `Array.fold` vs `List.fold` the rounding differs by
1–2 ULP per accumulation. After 2520 ticks compounded, drift can be
visible.

Mitigation:
- Stage-0 parity test must run BOTH the bit-identical and the
  tolerance ≤ 1e-9 cases. If 1 ULP drift compounds beyond tolerance, the
  vector kernel must replicate the scalar summation order exactly (uses
  same fold direction, same warmup window slicing).
- Golden gate is end-to-end PV; if PV agrees within $0.01 on a
  $1M starting portfolio, indicator drift is below the strategy's signal
  threshold and we accept it.
- If golden gate fails, the indicator with the largest scalar-vs-vector
  delta is the suspect; isolate via per-indicator delta histograms.

### R2: hidden Bar_history readers (medium)

The 6 known reader sites are the audit from
`dev/notes/bar-history-readers-2026-04-24.md`. There may be others added
since (e.g. macro readers in sector code). Stage 2 must re-audit before
deleting Bar_history.

Mitigation: a `git grep "Bar_history\."` sweep at start of stage 2; the
type system catches any reader I missed once Bar_history's `.mli` is
deleted.

### R3: symbol-set churn in live mode (low for backtest, deferred)

Backtest universe is fixed; not an issue. Live mode rebalance will
require a panel copy + new symbol_index. Deferred to stage 5.

### R4: Bigarray cross-cutting bugs (low)

Bigarray is well-tested stdlib code, but stride math is error-prone.
Mitigation: dedicated test suite for `Symbol_index.to_row` and
panel-slice operations before any indicator uses them.

### R5: code review surface (medium)

Stage 3 is a large deletion PR touching many files. Reviewer may struggle
to verify nothing semantic is lost.

Mitigation: Stage 3's PR description must include a side-by-side mapping
of the deleted tier-system functions to their panel-system replacement.
Reviewer verifies the mapping is complete, then the deletion is safe by
construction.

## Relationship to the incremental-indicators plan (#551)

Most of the incremental-indicators plan is reusable here at the
*indicator-kernel* level:

- The `INDICATOR` functor signature (init / step / read) collapses to
  the panel-kernel signature (config, advance over panel column). Same
  shape, different storage.
- The parity-test functor (Test_make_indicator_table) becomes the
  panel parity test. Same shape.
- The indicator porting order (EMA → SMA → ATR → RSI → Stage → Volume →
  Resistance) is preserved, just into panels instead of per-symbol
  Hashtbls.

What's superseded:
- The plan's "tiered indicator computation" (cheap-then-hard cascade
  with Bar_history kept alive for the hard cases) is unnecessary —
  panels make all indicators uniformly cheap. The whole tier concept
  goes away rather than being re-aimed.
- Steps 10–12 (strategy cutover from `Bar_history.weekly_bars_for` to
  `get_indicator`) are simpler in the panel model — no per-symbol state
  to plumb.
- The rollback flag `summary_compute_mode = Batch | Incremental` is
  unnecessary; panels are the only path.

If accepted, supersede #551's plan with this one as
`dev/plans/columnar-data-shape-2026-04-25.md`. Mark #551's plan with a
"SUPERSEDED" header. Update the `incremental-indicators` status track
to point at the new plan, or rename it to `data-panels`.

## Decision items for the human

1. **Direction**: pursue the columnar redesign instead of the
   incremental-indicators plan? Or keep incremental as the near-term
   fix and treat columnar as a Phase 2?

2. **Scope of the spike (Stage 0)**: 1 indicator (EMA) is enough to
   prove the parity story; should we also build the OHLCV panel
   serialization (mmap snapshot for warmup) to test the cold-start
   story at the same time?

3. **Bigarray vs Owl**: confirm Bigarray. Owl revisitable if
   dataframe ergonomics later become important.

4. **Migration sequencing**: 5 stages spread across feat-backtest as
   single owner, or split (stages 0–3 to feat-backtest, stage 4 to
   feat-weinstein since it touches weinstein/* indicator modules)?

5. **Live-mode handling**: defer stage 5 until live mode lands, or
   implement up front to keep the panel design honest about the
   hard case?

6. **What to do with #551's plan**: mark superseded? Delete? Keep as
   historical record showing the path-not-taken?

## What's NOT in this plan

- Domain parallelism for CSV loading or indicator advance. Available
  later via Domainslib but not needed for MVP.
- Mmap'd panel snapshots for cold-start. Possible follow-up after
  stage 5; backtest replay would mmap a panel dump in O(milliseconds)
  vs O(seconds) of CSV reload.
- Owl_dataframe for screener cascade. Reconsider after panels land.
- Live-trading panel rebuild on universe change. Sketched in stage 5,
  not specified in detail.
- Migration of the existing perf scenario catalog (#550) to use
  panel-aware metrics. Same scenario files apply; only the
  `perf_expected` thresholds need updating once panels land.

## Appendix: why this wasn't obvious from the start

The original design docs were written before any backtest had been run
at scale. At small scale (300 stocks × 6 months), per-symbol
list-of-bars works fine — memory is sub-100 MB, walk costs are
sub-second. The shape question only becomes pressing when you push to
release-gate scale (5000 stocks × 10 years) and watch the per-symbol
overhead compound into the +95% Tiered gap.

The lesson generalizes: data-shape questions deserve a dedicated
engineering design doc alongside the behaviour and component design.
For this project, the missing doc is this one. For future projects:
write the data-shape doc first, before component boundaries get drawn —
because component boundaries that assume the wrong shape are very
expensive to redraw.
