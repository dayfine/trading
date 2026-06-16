# Window-prune investigation — findings & verdict (2026-06-16)

Follow-up to `ANALYSIS.md` (the cache-thrash root cause). This answers: **can a
cache window-prune make the top-3000 26y matrix fit/fast in the 7.8 GB container,
and what is the real fix?** Investigated the actual read path + snapshot format
end-to-end. Verdict: **a cache-level window-prune is NOT viable with the current
format; the real fixes are RAM or a format upgrade.** Below is the proof, so the
next session doesn't re-derive it.

## What the reads actually do (traced)

- The strategy's hot per-symbol reads are **bounded by an explicit `~lookback` /
  `~n`** (`weekly_view_for`, `daily_view_for`) — the universe scan
  (`weinstein_strategy_screening`) uses `weekly_view_for ~n:config.lookback_bars`
  (≈ 1 year).
- `weekly_bars_for` / `daily_bars_for` always read a **fixed 10-year window**
  (`_bar_list_history_days = 3653`, `snapshot_bar_views.ml`) regardless of `n`
  (`n` only truncates the *output*). Used for held positions + macro + sector
  (tens of symbols), not the 3015-symbol scan.
- `Weekly_ma_cache` (`~n:Int.max_value`) would read 10y, but **`ma_cache` is
  `None` in every backtest constructor** (`bar_reader.ml:17`) — the backtest
  computes the MA inline from the bounded weekly view (`_inline_get_ma`). So the
  `n=max` path does not fire in the backtest.
- **No read scans all-time / full history.** Max lookback any read requests =
  **3653 days (10 y)**, and all backtest reads use `as_of = current frontier`
  (forward sweep, no lookahead). So in principle rows older than
  `frontier − 3653` are never read again → prunable.

## Why the cache window-prune still can't work — the format

The chokepoint is **`Daily_panels._load_symbol_file`**: it loads + decodes the
symbol's **entire file** and caches the full `Snapshot.t array`. The read range
only slices the *returned* rows; it does **not** bound what is cached.

The snapshot file format (`snapshot_format.ml`) is **whole-file sexp**: `read`
does `In_channel.input_all` then `Sexp.of_string payload |> [%of_sexp: Row.t
list]` — the entire payload decodes as one list. **There is no seek / index /
date-range / partial decode.** (The `.mli` notes a future "Phase C upgrade to a
`Bigarray.map_file` payload" — not built.)

This creates a catch-22 for any windowed cache:
- **Keep future rows** (rows newer than the frontier, already in the decoded
  file): no memory win early — at frontier = backtest start the entry still spans
  the whole file. For the first start (2000) of a 26y backtest the peak is the
  full 26y = ~2.95 GB → OOM.
- **Drop future rows** (retain only `[frontier−10y, frontier]`): the next tick's
  read needs newer rows → cache miss → **re-decode the whole file** (no partial
  read) → re-decode every tick × 3015 symbols × ~1370 weeks = catastrophic. Worse
  than today.

Whole-file decode forces "decode once & keep everything" (current, 2.95 GB) or
"re-decode repeatedly" (thrash). A windowed cache needs partial decode, which the
format doesn't support.

## Why column-prune is insufficient (the other obvious lever)

Cache only the columns the backtest reads (OHLCV + Adjusted_close ≈ 6 of the 13
schema fields; the precomputed `EMA_50/SMA_50/ATR_14/RSI_14/Stage/RS_line/
Macro_composite` are recomputed inline, not read in the hot path). But the
per-row cost is `n_fields*8 + _per_row_overhead_bytes(64)` + the OCaml record
overhead (the estimate already undercounts true RSS ~1.6×). Trimming 13→6 fields:
`168 → 112` bytes/row ≈ **1.5×**, not the 3-6× needed. The per-row overhead, not
the field count, dominates. **Insufficient on its own.**

## The hard arithmetic — top-3000 cannot fit 7.8 GB

Working set ≈ 2.95 GB (measured; window-independent). With the `Gc.compact` fix
(#1614, lean parent ~1.3 GB), the max cache that fits 7.8 GB is ~1280-1536
(cache RSS ≈ 1.6× budget ≈ 2-2.5 GB + heap ~2 GB + parent 1.3 GB + page cache
~1.9 GB). That holds **< 1.5 GB of the 2.95 GB working set → still thrashes
(> 50 % miss).** **There is no in-container cache that both holds the working set
and fits.** Confirmed empirically: cache=3072 OOM'd even post-`Gc.compact`.

## The real fixes (ranked)

1. **More Docker RAM → 12-16 GB** (immediate, no code). `cache=4096` holds the
   working set + the fork fits → no thrash → ~50× → 26y matrix ~2-6 h. The
   `Gc.compact` fix (#1614) is the prerequisite that makes this actually fit.
2. **Phase-C snapshot format (`Bigarray.map_file` / indexed-by-date)** — the
   durable fix. Enables partial/range decode, so the cache holds only the hot
   `[frontier−10y, frontier]` window (~1.1 GB for top-3000, or ~130 MB if reads
   were tightened) without re-decode thrash → fits the current 7.8 GB AND speeds
   every broad-universe run. This is the genuine "window-prune," but it lives at
   the format layer, not the cache layer. Larger project (format migration +
   corpus rebuild — already on the roadmap per `snapshot_format.mli`).
3. **Consume precomputed snapshot scalars instead of recomputing from raw
   history** (the user's "summary numbers" instinct). The schema *already stores*
   `Stage`, `RS_line`, `Macro_composite`, `EMA_50`, etc. per row. If the backtest
   read those scalars at the frontier date instead of reading ~1y of raw weekly
   bars + recomputing the MA/stage/RS, the per-symbol read collapses to a handful
   of scalars → tiny working set. Biggest structural win, but it changes the
   compute path (must verify the precomputed values are bit-identical to the
   strategy's inline computation — golden-gated). Worth scoping as its own
   project.

## On the 10-year window (`_bar_list_history_days = 3653`)

It is **over-provisioned and somewhat arbitrary** ("wide enough for any backtest
horizon"). Weinstein decisions need ≤ ~1 y (30-week MA, 52-week RS); the 10 y is
for the held-position / macro `weekly_bars_for`/`daily_bars_for` reads and is far
more than those need either (stops/base/RS < ~2 y). It is **not "too short."**
BUT: **reducing it does not help memory under the current whole-file-load** — the
full file is cached regardless of the read range. It only becomes a live lever
under fix #2 (partial reads) or #3 (summaries). So: don't tune 3653 now; it
matters only once the format/compute path changes.

## What shipped + the progress path

- **#1614 `Gc.compact` before fork** — real, safe, merged. Prevents the
  fork-doubling OOM (parent COW-inheritance); necessary for the RAM path to fit.
  Not sufficient alone (the 2.95 GB working set still exceeds any in-container
  cache).
- **Progress without RAM:** run the matrix on **top-1000** (working set ~1 GB →
  fits cache=1280 no-thrash → completes). Launched the top-1000 2000-26 matrix
  (`/tmp/cell-e-top1000-2000-26y.sexp` over the existing `snap_top3000_2000`
  warehouse, stride 255, cache=1280) to unblock the factor-lens causal analysis.
  top-1000 is a valid regime sample for the deploy-when lens; top-3000 awaits
  RAM (#1) or the format upgrade (#2).
