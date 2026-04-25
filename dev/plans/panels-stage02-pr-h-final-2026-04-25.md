# Plan: PR-H — Bar_panels reader migration + Bar_history deletion (2026-04-25)

## Status

In progress on `feat/panels-stage02-pr-h-final`. Stacks on PR-G
(`feat/panels-stage02-pr-g-stops-support-floor`).

## Goal

Final PR in the Stage 2 sequence. Port the 6 known `Bar_history`
reader sites to construct callback bundles from `Bar_panels`,
delete `Bar_history`, drop the Friday-cycle bar seeding, and
tighten the panel-loader parity gate so it actually exercises the
panel code path.

## Reality check

Dispatch nominally targets ~400 LOC. Realistic estimate is closer
to 1000–1500 LOC because:

- The Tiered runner currently seeds bars via `Bar_history.seed`
  on Full-tier promotions every Friday. To delete `Bar_history`,
  the Tiered path must populate `Bar_panels` instead — which means
  building OHLCV panels in the Tiered path (today only Panel_runner
  does that).
- 6 reader sites × signature changes propagate through 3 ml/mli
  files apiece (macro_inputs, stops_runner, weinstein_strategy)
  plus their tests.
- 4 test files reference `Bar_history` directly
  (test_weinstein_strategy, test_stops_runner, test_macro_inputs,
  test_runner_tiered_cycle) plus test_bar_history itself (delete).

## Sequenced approach (one commit per step)

### Step 1: Plumb `Bar_panels` through strategy + reader callbacks

a. Change `Weinstein_strategy.make`'s `?bar_history:Bar_history.t`
   parameter to `?bar_panels:Bar_panels.t`. Strategy state holds
   a `Bar_panels.t option`.

b. Switch the 6 reader sites to read from `Bar_panels`:
   - `macro_inputs.ml:28,39` — replace
     `Bar_history.weekly_bars_for bar_history ~symbol ~n` with
     `Bar_panels.weekly_bars_for bar_panels ~symbol ~n ~as_of_day`.
     Need to thread `as_of_day` through `build_global_index_bars`
     and `build_sector_map`.
   - `stops_runner.ml:11` — same change.
   - `weinstein_strategy.ml:110` (entry stop) — replace
     `Bar_history.daily_bars_for` with
     `Bar_panels.daily_bars_for ~as_of_day` (constructed from
     `current_date`).
   - `weinstein_strategy.ml:220` — `weekly_bars_for` swap.
   - `weinstein_strategy.ml:284,314` — same.

c. The `as_of_day` is computed by looking up `current_date` in the
   panel's calendar via a small internal helper inside the
   strategy closure.

### Step 2: Update Panel_runner to construct Bar_panels and pass to strategy

a. `Panel_runner._build_strategy` constructs a `Bar_panels.t` via
   `Bar_panels.create ~ohlcv ~calendar`, threads it as
   `~bar_panels` into `Weinstein_strategy.make`.

b. Tiered_runner needs to ALSO build `Ohlcv_panels` + `Bar_panels`
   so the Tiered path keeps working. Add a sibling helper
   `_build_panels` shared with Panel_runner. Both runners now
   build panels; the only difference is whether the Panel wrapper
   (with its panel-backed get_indicator) is in the loop.

### Step 3: Remove the Tiered_strategy_wrapper Friday-seed cycle

a. Once panels are populated by the runner, the Friday cycle's
   bar-seeding role evaporates. Delete `_run_friday_cycle`,
   `_promote_universe_to_full`, `_seed_from_full`,
   `_seed_one_symbol`, `_truncate_bars`.

b. The wrapper still has other responsibilities:
   - Demote on close (`_demote_closed`) — keep, still useful for
     loader bookkeeping.
   - Promote new entries to Full
     (`_promote_new_entries`) — keep.
   - `_throttled_get_price` — keep; it's a separate concern from
     bar seeding.
   - Stop log recording — keep.

c. Drop `bar_history` from `Tiered_strategy_wrapper.config`.

### Step 4: Reader-site parity test

Add `test_panels_reader_parity.ml` in `weinstein/strategy/test`:
runs ONE small synthetic scenario against both:
- The Bar_history-backed `Weinstein_strategy.make ~bar_history`
- The Bar_panels-backed `Weinstein_strategy.make ~bar_panels`

Asserts trade list bit-identical via composed matchers.

This MUST be added BEFORE deleting Bar_history, so it runs and
verifies the swap was clean. After Bar_history is deleted, this
test gets removed (the Bar_panels mode is the only mode).

### Step 5: Delete Bar_history

a. Remove `Bar_history` field from strategy + Tiered wrapper +
   Panel runner.

b. Remove `bar_history.ml`/`mli` and `test_bar_history.ml`.

c. Update remaining tests.

### Step 6: Tighten panel-loader parity gate

a. Replace sampled-step PV check with full per-step PV bit-equality.

b. Add second scenario fixture (smoke or goldens-small).

c. Compare full `round_trips` lists structurally, not just count.

## Decisions deferred

- **Volume/Resistance reshape (option b in dispatch)**: handled by
  `Stock_analysis.analyze_with_callbacks` reconstructing the bar
  list internally from panels for those subroutines. Documented in
  `.mli`. The `bars_for_volume_resistance` parameter stays as the
  external surface; panel-backed callers just pass the same panel-
  reconstructed list through.

- **Macro int-then-float A-D fold**: PR-H continues to use
  `Macro.callbacks_from_bars` (which already does the int-then-float
  fold in `_build_cumulative_ad_array`). PR-H builds the `ad_bars`
  list once from panel reads (or, equivalently, accepts ad_bars as
  a runner-level input — which is what the strategy already does
  via `?ad_bars`). No semantic change.

## Risks

- **R1: Tiered runner panel construction**: The Tiered path's
  Bar_loader is independent of Ohlcv_panels. Building both adds
  CPU + memory cost to Tiered runs. Mitigation: this is exactly
  the point — once Bar_history is deleted, the Bar_loader Full
  tier becomes redundant for strategy reads (it's only used for
  stop_log + new-entry promote bookkeeping). Stage 3 will remove
  Bar_loader entirely.

- **R2: Parity drift**: float arithmetic in panel reads must match
  bar-list reads. Bar_panels reconstructs `Daily_price.t`
  records with the same field values (volume rounding aside —
  documented), so passing those records through downstream
  `*_callbacks_from_bars` constructors yields bit-identical
  callbacks. The reader-site parity test in Step 4 catches any
  drift before Bar_history deletion.

- **R3: Scope creep**: Steps 5-6 may push the PR over the size
  budget. If steps 1-4 already constitute >800 LOC, defer Step 6
  (parity gate strengthening) to a sibling PR.

## Out of scope

- Stage 3 (collapse Bar_loader tier system).
- Stage 4 (weekly cadence panels).
- Adding `Support_floor_panel` / `Macro_panels.cumulative_ad`.
- Volume/Resistance reshape (deferred via option (b) above).
