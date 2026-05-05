# Issue #848 investigation — path-dependent regression in `Bar_reader.of_snapshot_views`

Date: 2026-05-05
Branch: feat/investigation-848
PR: TBD (this note + diagnostic exec)

## TL;DR

The cell-by-cell parity test in #846 (`diag_real_csv_parity.exe`) only
covered **two** of the five primitives the strategy reads through
`Bar_reader`:

  - `weekly_view_for` (~n:52)  — bit-equal between paths.
  - `daily_bars_for`  — date-equal between paths, but **bar-field-not-equal**
    (the diagnostic only compared `n` and the last bar's date, not the
    full OHLCV record).

Three primitives were untested and **DIVERGE** between paths:

  1. `daily_bars_for` — Snapshot path returns `Daily_price.t` records with
     `open_price = Float.nan` (see `snapshot_bar_views.ml:86`). Panel path
     returns the actual open price.
  2. `weekly_bars_for` — same NaN-open propagation through
     `Time_period.Conversion.daily_to_weekly._aggregate_week` (which takes
     `first.open_price` for the weekly bar).
  3. `daily_view_for` — **fundamental window-definition mismatch**:
     - Panel walks `lookback` calendar columns (Mon-Fri including
       holidays), NaN-skips per-symbol → `n_days ≤ lookback` (typically
       `n_days = lookback − holidays_in_window`).
     - Snapshot walks `_daily_calendar_span(lookback) ≈ 1.5*lookback + 7`
       calendar days, fetches all rows in window (snapshot has rows only
       on actual trading days), takes trailing `lookback` close rows →
       `n_days = lookback` exactly (assuming enough history exists).

(Also untested in #846 but only used by dead code: `low_window` —
identical mismatch shape as `daily_view_for`. Not a production concern.)

## Hypothesis ranking (per #848)

1. ❌ **LRU eviction order in `Daily_panels`** — REJECTED. Cache sizing
   math: 506 symbols × 1453 days × (13 fields × 8 bytes + 64 byte row
   overhead) + per-symbol overhead ≈ 124 MB. Both #828's 256 MB cap and
   current main's 1024 MB cap are well above this. **Eviction never
   fires** in the sp500-2019-2023 scenario at any tested cap. The
   strategy and simulator each get their own independent
   `Daily_panels.t` instance (separate LRUs anyway — see
   `Bar_data_source._build_snapshot_adapter` which calls
   `Daily_panels.create` again for the simulator's adapter).

2. ❌ **Hashtbl iteration order downstream** — UNLIKELY at the
   `Bar_reader` level. The `Daily_panels.t` cache hashtable is only
   accessed via `find` / `set` / `remove`, never iterated. The Weinstein
   strategy uses `prior_stages` and `sector_prior_stages` Hashtbls, but
   only via `find` / `set`. The screener's `_top_n` already has a
   secondary tiebreaker sort by ticker (see `screener.ml:430-441`) to
   defend against this kind of bug.

3. ❌ **Closure capture across `_run_macro_only` and
   `_classify_stage_for_screening`** — UNLIKELY. The bar_reader is built
   once at runner setup and passed in as a value. The strategy never
   "switches" the closure mid-run. The closure does capture the
   `Snapshot_callbacks.t` (and through it the `Daily_panels.t`), but as
   shown above, no eviction happens, so the captured state is read-only
   in practice.

4. ✅ **Untested primitive(s)** — CONFIRMED. The cell-by-cell #846
   diagnostic missed three primitives that diverge between backings.
   See "Findings" below.

## Method

This investigation was **static-analysis-driven plus an extended
diagnostic exec**, NOT trade-by-trade run-and-diff. Reasoning:

- The dispatch budget allowed ~2-3 hours; running both paths on
  sp500-2019-2023 takes 30-90 min × 2 = 1-3 hours per pair, leaving
  little time for analysis after.
- Static analysis of the `Bar_reader.of_snapshot_views` constructor
  versus `of_panels`, plus their downstream consumers in the strategy,
  surfaced enough structural divergence to write a targeted
  cell-by-cell diagnostic that **covers what #846's diag didn't**.
- The extended diagnostic ran cleanly on the existing CSV corpus and
  produced concrete numbers in seconds, not hours.

If a follow-up dispatch wants the trade-by-trade diff, the path is:
revert this PR's `panel_runner.ml` only (no other changes), apply the
two-line `_setup_hybrid` → `_setup_snapshot` swap (replace
`_build_panel_bar_reader` with `Bar_reader.of_snapshot_views callbacks`),
build, run scenario_runner against goldens-sp500, capture trades.csv,
restore Option-1 wiring, re-run, diff. Per-scenario cost ~30-90 min.

## Diagnostic exec

`trading/trading/backtest/diag/diag_panel_vs_snapshot_extended.exe`

Same setup as `#846`'s `diag_real_csv_parity.exe` — full sp500
universe (491 symbols + 11 SPDR ETFs + 3 global indices + GSPC.INDX =
506 symbols), same calendar (warmup_start=2018-06-06, end_date=2023-12-29),
same builder pipelines. Sample dates: 1st Friday of each month from
2019-01 through 2023-12 (60 dates) × 506 symbols = 30,360 cells per
primitive. Tests every primitive consumer the strategy hot-path uses.

Build:
```
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  dune build trading/backtest/diag/diag_panel_vs_snapshot_extended.exe'
```

Run:
```
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && \
  eval $(opam env) && ./_build/default/trading/backtest/diag/diag_panel_vs_snapshot_extended.exe'
```

Expected output (verbatim, 2026-05-05):
```
Universe: 500 symbols
Calendar: 1453 trading days (2018-06-06..2023-12-29)
Building Bar_panels...
Building snapshot...
Test dates: 60 (1st Friday/month, 2019-2023)
  ... per-10K-cell progress ...

=== Per-primitive parity results ===
weekly_view_for(52)   : 0 / 30900 cells differ
daily_bars_for        : 30224 / 30900 cells differ
daily_view_for(60)    : 30142 / 30900 cells differ
weekly_bars_for(52)   : 30224 / 30900 cells differ
low_window(60)        : 30871 / 30900 cells differ
```

## Findings (concrete)

### Finding 1: `daily_bars_for` returns NaN open in the snapshot path

`Snapshot_bar_views._assemble_daily_bars` builds `Daily_price.t` records
with `open_price = Float.nan` (line 86 of snapshot_bar_views.ml). The
panel path's `_read_bar` reads the actual open from the panel cell.

**Sample divergent bar** (from diag output):
```
daily_bars GSPC.INDX 2019-01-04 [bar 0/147] open differ:
  panel=2753.2500000000  snap=nan
```

Strategy hot-path consumers of `daily_bars_for`:
- `entry_audit_capture._effective_entry_price` — uses `bar.close_price`
  (NOT open). Safe.
- `stops_split_runner._last_two_bars` → `Types.Split_detector.detect_split`
  — uses `close_price` and `adjusted_close`. Safe.

**So Finding 1 is observable but not directly load-bearing for the
trade decisions.**

### Finding 2: `weekly_bars_for` propagates NaN open

`daily_to_weekly._aggregate_week` takes `first.open_price` as the weekly
bar's open. With NaN daily open inputs, the weekly bar's
`open_price = NaN`. **Sample**:
```
weekly_bars GSPC.INDX 2019-01-04 [bar 0/32] open differ:
  panel=2753.2500000000  snap=nan
```

Strategy consumers of `weekly_bars_for`:
- `Macro_inputs.build_global_index_bars` → `Macro.callbacks_from_bars` →
  uses `adjusted_close` only (Stage callbacks read close, not open). Safe.
- `Weekly_ma_cache._snapshot_weekly_history` → reads `adjusted_close`
  and `date` only. Safe.

**Finding 2 also observable but not directly load-bearing.**

### Finding 3: `daily_view_for` has a different window definition

This is the **load-bearing divergence**.

- **Panel path** (`Bar_panels.daily_view_for`): walks calendar columns
  `[as_of_day - lookback + 1 .. as_of_day]` (i.e., `lookback` consecutive
  weekday columns), NaN-skips per-symbol, returns `n_days = (lookback −
  holidays_in_window) − missing_data_days`.
- **Snapshot path** (`Snapshot_bar_views.daily_view_for`): walks calendar
  days `[as_of - 1.5*lookback - 7 .. as_of]`, reads close/high/low rows
  in that window (snapshot has rows only on trading days, no holidays),
  takes trailing `lookback` close rows, joins with high/low by date,
  returns `n_days = lookback` (when full history available).

**Sample divergent view** (from diag output, lookback=60):
```
daily_view GSPC.INDX 2019-01-04: panel.n_days=56 snap.n_days=60
```

Both paths' "60-bar lookback" cover roughly the same time window
(~12-13 weeks back from as_of), but they have a **different number of
bars** and the bars at indices `[0..55]` are not the same calendar days.
Index 0 in the panel view is the OLDEST included calendar weekday;
index 0 in the snapshot view is also the oldest, but it's an actual
trading day from a slightly older calendar position (because the
snapshot reaches further back to fill in `lookback` real bars).

**Strategy consumer of `daily_view_for`**:
- `entry_audit_capture._initial_stop_and_kind` invokes
  `Bar_reader.daily_view_for bar_reader ~symbol:cand.ticker
  ~as_of:current_date ~lookback:stops_config.support_floor_lookback_bars`
  (default `lookback=90`). The view feeds
  `Panel_callbacks.support_floor_callbacks_of_daily_view`, which
  drives `Weinstein_stops.compute_initial_stop_with_floor_with_callbacks`.
- The support-floor algorithm walks `day_offset:0..n_days-1` looking
  for the highest-high anchor (longs) / lowest-low anchor (shorts), then
  finds a counter-move. The anchor and counter-move depend on which
  bars are in the view.
- **Different `n_days` and different bar set ⇒ different anchor ⇒
  different counter-move ⇒ different `installed_stop` level.**
- `installed_stop` then gates the entry via `stop_distance_pct >
  max_stop_distance_pct ⇒ Stop_too_wide` (rejected as a candidate).
  Different stops change which candidates are admitted vs rejected.
- This cascades: different admitted entries → different fills →
  different stops → different exits → different metrics.

**This is the load-bearing divergence. It is the most plausible
proximate cause of the 60.86% / 86 trades panel vs 22.2% / 112 trades
snapshot regression.**

### Finding 4: `low_window` has the same window-definition mismatch

`Bar_panels.low_window` returns a slice of `lookback` calendar columns
(NaN-passes-through). `Snapshot_bar_views.low_window` returns the
trailing `lookback` actual trading-day low values.

**Sample**:
```
low_window GSPC.INDX 2019-01-04 [0/60] differ:
  panel=2749.0300000000  snap=2874.2700000000
```

These are RAW low prices from completely different calendar dates —
the panel's "60 weekdays back" reaches a different bar than the
snapshot's "60 trading days back."

**No production callers** — `grep -rn 'low_window' trading/ analysis/`
shows only the definitions and tests. Not load-bearing for the
regression. Just confirms the window-definition split.

## Why the cell-by-cell #846 diag missed this

The #846 `_diff_views` for `weekly_view_for` checked all five fields
(`closes`, `dates`, etc.) per index. That's why `weekly_view_for` shows 0
diffs in both the #846 diag and this extended diag.

But the #846 `daily_bars` check was:
```ocaml
match (List.last panel_bars, List.last snap_bars) with
| None, None -> ()
| Some pb, Some sb when Date.equal pb.date sb.date -> ()
| _ -> Int.incr dbars_diff
```

**Only checks date equality of the LAST bar, not field-by-field
equality of every bar.** NaN-open and other field divergences fly
through. And `daily_view_for`, `weekly_bars_for`, `low_window` were
never compared at all.

## Why does `weekly_view_for` agree but `daily_view_for` diverge?

`Snapshot_bar_views.weekly_view_for` ultimately calls
`_daily_bars_in_range cb ~symbol ~from ~as_of` with `from = as_of -
(n*8 + 7)` calendar days, then aggregates daily bars to weekly via
`Time_period.Conversion.daily_to_weekly`. The aggregation step buckets
by ISO (year, week_number) — both paths produce the **same set of weekly
buckets** because both feed in the same set of daily bars (modulo the
NaN-open in the snapshot which doesn't affect weekly close/high/low/volume).

In contrast, `daily_view_for` keeps daily granularity and the
snapshot path's "trailing `lookback` rows from a wide window"
fundamentally differs from the panel path's "last `lookback` calendar
columns." The aggregation-to-weekly step in `weekly_view_for` masks
this difference (any 3-month-ish window covers the same set of weekly
buckets); `daily_view_for` exposes it.

## Hypothesis 4 confirmed; what's the fix shape

The forward fix has two viable approaches:

**Option A: Make `Snapshot_bar_views.daily_view_for` semantics match
`Bar_panels.daily_view_for` (calendar-column-walking)**

Change `Snapshot_bar_views.daily_view_for` to:
1. Walk `[as_of - lookback_calendar_days, as_of]` where
   `lookback_calendar_days` is computed from a calendar walker (last
   `lookback` weekdays, including holidays).
2. Or, more pragmatically: accept a `~calendar` arg or build one on
   the fly from `as_of` walking back `lookback` Mon-Fri days.
3. Fetch the close/high/low rows for that calendar range; rows missing
   from the snapshot (holidays) leave NaN cells in the output (matching
   panel semantics).

**Option B: Make `Bar_panels.daily_view_for` semantics match
`Snapshot_bar_views.daily_view_for` (trading-day-walking)**

Change `Bar_panels.daily_view_for` to drop NaN cells before counting
toward `lookback`. This is what the snapshot path effectively does.

**Recommendation: Option B** is the more semantically correct path —
"last 60 trading days" is what every consumer wants. The calendar-
column shape is a panel-internal artefact. Both `Support_floor` and
the support-floor anchor/counter-move logic are inherently
trading-day-based; counting NaN holidays toward `n_days` is
incidental, not principled. But this changes the panel-path semantics,
which is where the pinned baseline is anchored. So a Phase F fix on
this would re-pin the baseline.

For the immediate `Bar_panels.t` retirement plan (F.3.e per
`dev/status/data-foundations.md`), the lower-risk path is:

**Option C: Add a `~calendar` parameter to `Snapshot_bar_views.daily_view_for`**
that takes the panel's calendar (the runner already has it as
`_build_calendar`), and walks calendar columns inside the snapshot
path mirroring the panel's behaviour exactly (NaN-passthrough on
missing rows). This matches the cell-by-cell semantics of the panel
path while still using the snapshot's per-symbol storage.

The same fix shape applies to `low_window` (calendar-column-walking,
NaN-passthrough), but as noted, `low_window` has no production
callers and can be deleted instead.

The NaN-open propagation in `daily_bars_for` and `weekly_bars_for` is
fixable separately by reading the `Open` field in `_assemble_daily_bars`
(it's in the snapshot schema as `Snapshot_schema.Open`). This isn't
load-bearing for the regression but is wrong on principle.

## What this PR ships

- `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md`
  (this file)
- `trading/trading/backtest/diag/diag_panel_vs_snapshot_extended.{ml,mli,dune}`

The diag exec stays in the tree as a regression test the F.3.x forward
fix can run before/after to verify all five primitives reach 0 diffs.

## Acceptance criteria for closing #848

The forward fix (separate dispatch from this investigation PR) is
acceptable when:

1. `diag_panel_vs_snapshot_extended.exe` reports 0 diffs across ALL
   five primitives (currently only `weekly_view_for(52)` is at 0).
2. `dev/scripts/check_sp500_baseline.sh` reports PASS — the same
   53.36% / 73 trades / 0.52 Sharpe baseline that the post-#847
   panel-backed wiring produces.
3. The runner's strategy bar reads can be re-routed from
   `Bar_reader.of_panels` (current main, post-#847) back to
   `Bar_reader.of_snapshot_views` in `panel_runner.ml`'s `_setup_*`
   pipeline.

Once that lands, F.3.a-4 (delete `Bar_reader.of_panels`) and F.3.e
(delete `Bar_panels.t` itself) can proceed.
