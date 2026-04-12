# Macro.analyze — Cadence Mismatch Design Note

Last updated: 2026-04-11

## Problem

`Macro.analyze` accepts `ad_bars` (daily) and `index_bars` (weekly) in the same call. The A-D divergence indicator compares them directly via bar-count lookbacks, which is nonsensical because the units don't match.

### The bug

In `_ad_divergence_signal` (`macro/lib/macro.ml:72`):

```ocaml
let lookback = min ad_line_lookback (min n_ad n_idx) in
if lookback < ad_min_bars then (`Neutral, "Insufficient A-D data")
else
  let ad_recent = List.last_exn cum_ad in
  let ad_prior = List.nth_exn cum_ad (n_ad - lookback) in
  let idx_recent = (List.last_exn index_bars).Daily_price.adjusted_close in
  let idx_prior =
    (List.nth_exn index_bars (n_idx - lookback)).Daily_price.adjusted_close
  in
  (* ... compare ad_rising vs idx_rising over "lookback" bars ... *)
```

With `ad_line_lookback = 50` (a config default):
- For the daily `ad_bars` list: 50 bars = ~10 weeks ≈ 2.5 months lookback
- For the weekly `index_bars` list: 50 bars = 50 weeks ≈ 1 year lookback

The function then asks "is the A-D line rising over 2.5 months consistent with the index rising over 1 year?" — that's not the question the divergence indicator should be answering.

### Similar issue in `_compute_momentum_ma`

`momentum_period` is also a bar count, applied to daily ad_bars:

```ocaml
let period = min momentum_period (List.length nets) in
```

Isolated to the A-D list, so not a comparison bug — but the "momentum period" semantics are weekly in the Weinstein book (Ch. 4 refers to weekly momentum), while we're computing it over daily bars.

### Why this wasn't caught earlier

Before #255, `ad_bars` was always `[]` and both indicators returned `Neutral`. The mismatch only surfaces now that real ADL data flows through the pipeline.

## Options

### Option A: Normalize to weekly at the boundary (preferred)

Add a `daily_to_weekly_ad` conversion in `Ad_bars` (or `Macro`) that aggregates daily adv/dec counts into weekly buckets:

```ocaml
type weekly_ad = { date : Date.t; advancing_total : int; declining_total : int }
```

`advancing_total` = sum of daily `advancing` values within the week.

**Pros**:
- Clean, single cadence throughout `Macro.analyze`
- Existing lookback config values (50, 100, etc.) are interpretable as weeks
- Matches the pattern used for price bars (`daily_to_weekly`)

**Cons**:
- Loses intraweek resolution (probably fine — Weinstein is weekly)
- One-time conversion cost at load (trivial)

**Affected code**:
- New aggregator in `Ad_bars` (or `Time_period.Conversion`)
- `Macro.analyze` signature: `ad_bars : ad_bar list` stays the same, just interpret as weekly
- `Weinstein_strategy` loads `Ad_bars` once in the `make` closure (already done), passes to `Macro.analyze`
- Any tests using hand-crafted daily `ad_bar` lists need regeneration

### Option B: Make lookbacks cadence-aware

Split the single `ad_line_lookback` into two fields:

```ocaml
type thresholds = {
  ...
  ad_line_lookback_days : int;   (* applied to ad_bars *)
  index_lookback_weeks : int;    (* applied to index_bars *)
  ...
}
```

**Pros**:
- Preserves daily ad_bars resolution
- Backwards-compatible with existing tests (rename one field, add another)

**Cons**:
- More config surface
- Each indicator needs to be reviewed for "does this param make sense as days or weeks?"
- The divergence comparison is still awkward: "last 50 days of A-D vs last 10 weeks of index" requires careful conversion

### Option C: Resample in the caller

`Weinstein_strategy` converts `ad_bars` to weekly before passing to `Macro.analyze`:

```ocaml
let weekly_ad = Ad_bars.to_weekly daily_ad in
Macro.analyze ~ad_bars:weekly_ad ~index_bars:weekly_index ...
```

Basically Option A but the conversion lives in the strategy, not `Macro` or `Ad_bars`. Same net effect but worse locality — `Macro.analyze` still claims to accept "ad_bars" without specifying cadence.

## Recommendation

**Option A**. Add `Ad_bars.to_weekly : ad_bar list -> ad_bar list` (or define a separate `weekly_ad_bar` type if we want type-level cadence tracking). Update `Macro.analyze` docstring to require weekly cadence for both inputs.

### Migration steps

1. Add `to_weekly` in `Ad_bars` module (or wherever the type lives)
2. Update `Macro.analyze` docstring: "both `ad_bars` and `index_bars` must be weekly-aggregated"
3. Update `Weinstein_strategy._on_market_close` to call `Ad_bars.to_weekly` on the cached daily list once per `make` invocation (or memoize more aggressively)
4. Regenerate test fixtures in `test_macro.ml` that used daily cadences
5. Re-run the macro e2e tests to verify divergence signals still fire correctly

### Test plan

- Unit test `Ad_bars.to_weekly`: 5 daily bars per week aggregate correctly, partial weeks handled, empty input returns empty
- `test_macro.ml` regression: divergence test with weekly ad_bars should produce the same signal as before (since the test data was effectively already weekly)
- `test_macro_e2e.ml`: verify real data passes through without crashing

## Open questions

1. Should `weekly_ad` be a distinct type from `ad_bar` for type safety, or stay the same type with a documented invariant?
2. `_compute_momentum_ma` — is the Weinstein book's "momentum" definition weekly or shorter-timeframe? If weekly, normalization fixes it. If shorter, we might want to keep a daily-cadence internal view.
3. Do we need to backfill the `_build_cum_ad` function to work on weekly-aggregated inputs, or does summing weekly nets match daily cumulative? (Math: `sum_weekly(net) = sum(sum_daily(net))` — they should agree by week boundaries.)

## Status

- **Severity**: Medium — currently produces correct structure but incorrect semantics. Not a crash, but a silent accuracy bug in macro trend detection.
- **Owner**: Follow-up to #255 (strategy-wiring). Can be a small PR after #255 lands.
- **Estimate**: ~100-150 lines including `to_weekly` + tests + signature doc update.
