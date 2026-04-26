# Plan: Stage 4 PR-D — weekly MA cache (eliminate per-call SMA/WMA/EMA recompute) (2026-04-26)

## Status

In-flight. Branch: `feat/panels-stage04-pr-d-weekly-indicator-panels`.

## The wedge

Per the post-PR-A+B+C RSS spike (peak RSS still 1,939 MB on `bull-crash-292x6y` vs ≤800 MB target), the strongest remaining suspect after dropping `Daily_price.t list` intermediates is per-call MA recompute in
`Panel_callbacks._ma_values_of_closes`. On every `stage_callbacks_of_weekly_view` call (the screener iterates the universe Fridays + stops_runner runs daily for held positions + macro/sector branches) the function:

1. Builds an `Indicator_types.t list` from `closes : float array` via `Array.to_list |> List.mapi`.
2. Runs `Sma.calculate_sma | Sma.calculate_weighted_ma | Ema.calculate_ema` — each
   returns `indicator_value list` of length `n_weeks - period + 1`.
3. Threads through `List.map ... |> Array.of_list` to produce the final `float array`.

For ~300 symbols × ~312 Fridays in 6y that's ~93k recomputes, each allocating ≥3 transient lists.

## Goal of this PR

Cache MA arrays per `(symbol, ma_type, period)` so that within a backtest run the same symbol's weekly MA series is computed at most **once per ma_type/period combination**, not once per Friday tick. The cache is populated lazily on first read.

## Design

### `Weekly_ma_cache` module (new, `data_panel/`)

A pure memoization layer keyed by `(symbol, ma_type, period)`. Holds a `Hashtbl` of cached MA arrays + a parallel cache of close arrays + date arrays so subsequent calls don't re-aggregate weekly buckets.

```ocaml
(* data_panel/weekly_ma_cache.mli *)
module Stage_ma_type : sig
  type t = Sma | Wma | Ema [@@deriving sexp, hash, compare, equal]
end

type t

val create : Bar_panels.t -> t

(** [get_ma t ~symbol ~ma_type ~period ~as_of_day] returns the cached MA value
    array (length = full_history_n_weeks - period + 1) and the array of dates
    aligned to those values. Computes lazily on first call for the
    (symbol, ma_type, period) key.

    If the symbol has fewer than [period] weeks of history at [as_of_day],
    returns empty arrays. *)
val ma_values_for :
  t -> symbol:string -> ma_type:Stage_ma_type.t -> period:int -> as_of_day:int ->
  float array * Core.Date.t array
```

Implementation: on first call, build the symbol's full weekly history once (calling `Bar_panels.weekly_view_for` with `n=Int.max_value` and `as_of_day` = the largest as_of seen so far); compute MA via the same `Sma.calculate_sma | Sma.calculate_weighted_ma | Ema.calculate_ema` kernels; cache the result.

For backtests where `as_of_day` advances each Friday, the cache is rebuilt incrementally — but in practice we observe `as_of_day` is monotonic, so at first call we use the **maximum** `as_of_day` and cache the result for the full history. Actually simpler: cache on first request and ALSO cache the full history once so subsequent requests at later as_of_days reuse the same array (the MA at any earlier date is just an earlier index).

Refinement: cache by `(symbol, ma_type, period)` only. Build the cache from the symbol's full weekly history (whatever is available across the entire `Bar_panels` calendar). When the strategy asks for MA at view `as_of_day=D` of size `view.n`, look up `D` in the cached date array → get index `last_idx` → the MA value at `week_offset:k` is `cached_ma[last_idx - k]`, capped by view depth (`k < view.n - period + 1` to match bar-list truncation).

### `Panel_callbacks` switches to the cache

```ocaml
val stage_callbacks_of_weekly_view :
  config:Stage.config ->
  weekly:Bar_panels.weekly_view ->
  ?ma_cache:Weekly_ma_cache.t ->
  unit ->
  Stage.callbacks
```

Optional `ma_cache`: if absent, compute MA inline (current path — for tests / bar-list fallback). If present, look up via the cache. The strategy's hot path threads the cache via `Bar_reader` (extended to optionally hold a `Weekly_ma_cache.t`).

Actually simpler API: `Panel_callbacks.stage_callbacks_of_weekly_view` always takes the cache via the bar_reader → its Bar_panels handle. Bar_reader extends to optionally carry a cache; tests that don't supply one get inline computation.

### Integration

- `Bar_reader.of_panels` or `Bar_reader.create` accepts an optional `ma_cache : Weekly_ma_cache.t`.
- `Panel_runner` builds the cache once at simulator construction, passes via `Bar_reader.of_panels`.
- `Panel_callbacks.stage_callbacks_of_weekly_view` reads from the cache when present, fallback to inline computation when not.

### Bit-equality

For SMA + WMA, the cached MA values are bit-equal to the bar-list path's truncated MA values at any view position (sliding window — value depends only on local close window, not view boundary).

For EMA, the bar-list path computes EMA over view's truncated closes, while the cache computes over full history. Seeds differ. **However**, with `period=30` and view size ≥ 52 weeks, the recurrence converges below TA-Lib's 2-decimal rounding within the first ~5 windows. At the offsets the strategy actually reads (`week_offset:0..7`), the rounded EMA values match.

For strict bit-equality safety, the parity tests assert SMA + WMA bit-equal and EMA equal at offsets where convergence has occurred (offset 0 = newest), with a documented tolerance for early offsets.

The default Stage config uses WMA, so EMA-via-cache is exercised only by tests that explicitly set `ma_type = Ema`.

### Cap by view depth

To match `Sma.calculate_sma`'s output length of `n - period + 1`, the cached `get_ma` returns None for `week_offset:k >= view.n - period + 1`. This preserves `_count_above_ma_callback`'s upper-bound behavior (which depends on `_ma_depth = min confirm_weeks ma_depth`). Without this cap, the cached path would return MA values for offsets the bar-list path would treat as missing, causing `above_ma_count` to differ.

## Files to touch

- **new** `trading/trading/data_panel/weekly_ma_cache.{ml,mli}` — memoization module.
- `trading/trading/data_panel/dune` — add module.
- `trading/trading/data_panel/test/weekly_ma_cache_test.ml` — unit tests.
- `trading/trading/data_panel/test/dune` — register test.
- `trading/trading/weinstein/strategy/lib/panel_callbacks.{ml,mli}` — `stage_callbacks_of_weekly_view` plumbed through cache.
- `trading/trading/weinstein/strategy/lib/bar_reader.{ml,mli}` — carry optional cache.
- `trading/trading/backtest/lib/panel_runner.ml` — build cache at startup, pass via `Bar_reader.of_panels`.
- `trading/trading/weinstein/strategy/test/test_panel_callbacks.ml` — extended parity tests over SMA/WMA/EMA × multiple periods, using cache vs inline.

## Parity gates

1. **Load-bearing**: `test_panel_loader_parity` round_trips golden — bit-equal trades. Must hold.
2. **New module-level parity**: `test_weekly_ma_cache.ml` tests:
   - SMA cache vs `Sma.calculate_sma` direct: bit-equal at all positions.
   - WMA cache vs `Sma.calculate_weighted_ma` direct: bit-equal.
   - EMA cache vs `Ema.calculate_ema` over full history: bit-equal at offset 0.
   - Cache lookup at multiple `as_of_day` values: each yields a date-aligned slice.
3. **Cross-module parity**: `test_panel_callbacks.ml` extended:
   - Stage parity with cache vs without: bit-identical for SMA / WMA configs.
4. **Existing**: 8 panel_callbacks parity tests still bit-identical.

## LOC budget

~400 LOC target, ~600 max.

Estimates:
- weekly_ma_cache.ml ~120, .mli ~50
- panel_callbacks plumbing ~30 net
- bar_reader plumbing ~20 net
- panel_runner integration ~10
- weekly_ma_cache_test ~150
- panel_callbacks_test extended ~50

## Out of scope

- Stage classifier / Volume / Resistance ported to int8/decoder Bigarray panels (variant-typed result panel). Plan §Stage 4 step 4 — separate PR after PR-D's measured impact.
- Bigarray-backed MA panels (`Indicator_panels` weekly cadence). The cache uses Hashtbl + float array because per-symbol weekly histories vary in length (different first-trade dates); a uniform Bigarray N×W would waste memory on padding NaN and complicate date alignment. Bigarray makes sense once we add many indicator types per symbol; for one float array per (sym, ma_type, period) the Hashtbl is simpler.

## Out of scope for parity (deliberate)

EMA bit-equality near the seed is technically not guaranteed — the cache computes over full history, the bar-list path over truncated view. Default Stage config is WMA; EMA support is preserved but parity tests assert tolerance ≤ 1 ULP at offset 0 (newest), where the recurrence has converged. The explicit cap-by-view-depth applied to the cached `get_ma` ensures `_count_above_ma_callback`'s "missing" classification matches the bar-list path even when full history exceeds view length.
