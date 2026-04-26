# Plan: Stage 4 PR-B — reshape Volume + Resistance for callbacks; drop `bars_for_volume_resistance` (2026-04-26)

## Status

In-flight. Branch: `feat/panels-stage04-pr-b-volume-resistance-callbacks`.

## The wedge

PR-A (#584) wired panel-shaped callbacks through every strategy call
site (Stage / Rs / Sector / Macro / Stops support-floor / Stock_analysis
Stage+Rs branches). One residual remained:
`Stock_analysis.analyze_with_callbacks` still took
`bars_for_volume_resistance : Daily_price.t list` because
`Volume.analyze_breakout` and `Resistance.analyze` had not yet been
reshaped. On every Friday tick the strategy reconstructed a
`Daily_price.t list` for each surviving stock just to feed those two
callees — a per-symbol allocation the panel-mode hot path can't afford
at release-gate scale.

## Goal of this PR

Reshape the two remaining bar-list callees:

1. `Volume.analyze_breakout ~bars ~event_idx` →
   `Volume.analyze_breakout_with_callbacks ~callbacks ~event_offset`
   plus a thin bar-list wrapper.
2. `Resistance.analyze ~bars ~breakout_price ~as_of_date` →
   `Resistance.analyze_with_callbacks ~callbacks ~breakout_price
    ~as_of_date` plus a thin bar-list wrapper.
3. Drop the `bars_for_volume_resistance` parameter from
   `Stock_analysis.analyze_with_callbacks`. Bundle `Volume.callbacks` and
   `Resistance.callbacks` into the existing `Stock_analysis.callbacks`
   record (alongside the nested Stage / Rs callbacks already there).
4. Wire `Panel_callbacks.volume_callbacks_of_weekly_view` and
   `Panel_callbacks.resistance_callbacks_of_weekly_view` into
   `stock_analysis_callbacks_of_weekly_views`. The strategy's
   `_screen_universe` no longer materialises any `Daily_price.t list`.

## Approach

### Volume

Volume.analyze_breakout reads the event bar's volume + the prior
`lookback_bars` volumes. Add:

```ocaml
type callbacks = {
  get_volume : week_offset:int -> float option;
}
```

`week_offset:0` is the newest bar; `event_offset` (passed to the new
entry point) is the offset of the event bar; the analyzer reads volumes
at offsets `event_offset+1 .. event_offset+lookback_bars` for the
baseline.

The bar-list wrapper computes `event_offset = bars_len - 1 - event_idx`
and delegates. Bit-identical to the original.

### Resistance

Resistance.analyze reads the entire bar history (last
`virgin_lookback_bars` for the virgin check, last `chart_lookback_bars`
for zone density). Each bar contributes `high_price`, `low_price`,
`date`. Add:

```ocaml
type callbacks = {
  get_high : bar_offset:int -> float option;
  get_low : bar_offset:int -> float option;
  get_date : bar_offset:int -> Date.t option;
  n_bars : int;
}
```

`bar_offset:0` = newest; `n_bars` bounds the walk so the analyzer can
take `min lookback n_bars` for both the virgin and chart windows.

The implementation walks offsets directly into a bucket Hashtbl,
matching the bar-list path's per-bucket "max date" semantics by tracking
a running max as it accumulates.

### Stock_analysis

`Stock_analysis.callbacks` gains two fields:

```ocaml
type callbacks = {
  ...; (* existing get_high / get_volume / stage / rs *)
  volume : Volume.callbacks;
  resistance : Resistance.callbacks;
}
```

`callbacks_from_bars` builds them via the new `*.callbacks_from_bars`
constructors. `analyze_with_callbacks` drops `bars_for_volume_resistance`
and feeds the nested callbacks into the new
`Volume.analyze_breakout_with_callbacks` and
`Resistance.analyze_with_callbacks`.

### Panel_callbacks

Two new constructors:

```ocaml
val volume_callbacks_of_weekly_view :
  weekly:Bar_panels.weekly_view -> Volume.callbacks

val resistance_callbacks_of_weekly_view :
  weekly:Bar_panels.weekly_view -> Resistance.callbacks
```

Both index directly into the view's float arrays — no bar materialisation.
`stock_analysis_callbacks_of_weekly_views` calls both, returning the
full `Stock_analysis.callbacks` bundle from a weekly view alone.

### Strategy

`weinstein_strategy.ml::_screen_universe` drops the
`bars_for_volume_resistance = Bar_reader.weekly_bars_for ...` line and
the `bars_for_volume_resistance:` argument to
`Stock_analysis.analyze_with_callbacks`. Per-tick allocation eliminated.

## Parity gates

1. **Load-bearing**: `test_panel_loader_parity` round_trips golden —
   bit-equal trades. Held.
2. **New module-level parity**: 5 new tests in `test_volume.ml`
   (Strong / Adequate / Weak / Insufficient-history / event-at-max-index)
   plus 5 in `test_resistance.ml` (Virgin / Clean / Heavy / Moderate /
   chart-window-filtering). Each builds external `callbacks` via the
   public `callbacks_from_bars` and asserts bit-identical results.
3. **Cross-module parity**: 2 new tests in
   `test_panel_callbacks.ml` (Volume + Resistance) build `callbacks`
   from a `weekly_view` and from a bar list, run `*.analyze_with_callbacks`
   on both, and assert bit-identity.
4. **Existing**: 16 `test_stock_analysis` tests (8 parity + 8
   pre-existing) still pass with the new bundle shape — confirms the
   wrapper rewiring preserved behaviour for all existing call sites.

## LOC budget

~600 LOC target, ~800 max.

Actual delta:
- Volume: +56 net (mli +35, ml +21)
- Resistance: +69 net (mli +14, ml +55)
- Stock_analysis: +13 net (mli +14, ml -1) — bundle additions, drop param
- Panel_callbacks: +28 net
- Weinstein_strategy: -16 net (delete bars_for_volume_resistance line)
- Tests: +95 net (volume +60, resistance +95, panel_callbacks +90,
  stock_analysis -3)

~340 LOC production, ~245 LOC tests.

## Out of scope (PR-C/D)

- `Ohlcv_weekly_panels` + Friday rollup (PR-C)
- Port stage classifier / volume / resistance to indicator kernels (PR-D)
- RSS spike re-run on `bull-crash-292x6y` to measure RSS impact (separate
  dispatch — local devcontainer wall budget)
