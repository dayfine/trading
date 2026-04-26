# Status: data-panels

## Last updated: 2026-04-26

## Status
READY_FOR_REVIEW

Stage 4 PR-D READY_FOR_REVIEW on `feat/panels-stage04-pr-d-weekly-indicator-panels` — adds `Weekly_ma_cache` (per-symbol weekly MA memoisation) so the `stage_callbacks_of_weekly_view` hot path no longer recomputes SMA / WMA / EMA over weekly closes per Friday tick. Memoised by `(symbol, ma_type, period)`; built lazily at first request from the symbol's full weekly history; cache hits skip the `Indicator_types.t list` allocation entirely. Fallback to inline computation on cache miss (mid-week stops_runner calls + tests without a panel).

**Stage 4 PR-D scope**:
- New module `weinstein/strategy/lib/weekly_ma_cache.{ml,mli}`. Hashtbl-backed memoisation keyed by `{ symbol; ma_type tag; period }`. The MA tag is a local mirror of `Stage.ma_type` (so the module derives `hash` without touching `Stage.ma_type`). Stores `cached_ma = { values : float array; dates : Date.t array }`. `ma_values_for` lazily computes via the same `Sma.calculate_sma | Sma.calculate_weighted_ma | Ema.calculate_ema` kernels `Stage._compute_ma` uses, then caches the result. `locate_date` does a tail-anchored linear scan to map a view's most-recent date to its cached index.
- `Bar_reader.t` becomes a record `{ panels; ma_cache : Weekly_ma_cache.t option }`. `of_panels ?ma_cache` lets callers supply the cache; `ma_cache : t -> t option` exposes it for `Panel_callbacks` to thread through.
- `Panel_callbacks.stage_callbacks_of_weekly_view ?ma_cache ?symbol ~config ~weekly ()` — when both `ma_cache` and `symbol` are supplied, looks up the cached MA values, locates the view's last date, and builds a capped `get_ma` closure (returns `None` for `week_offset >= view.n - period + 1` to match the bar-list path's truncation). On cache miss (date not in cached dates) falls back to inline `_ma_values_of_closes`.
- `stock_analysis_callbacks_of_weekly_views`, `sector_callbacks_of_weekly_views`, `macro_callbacks_of_weekly_views` all gain `?ma_cache ?stock_symbol / ?sector_symbol / ?index_symbol` and thread to nested `stage_callbacks_of_weekly_view`. Macro globals pass through with no symbol (cache-miss path) since the (label, view) bundles drop the symbol; this is only ~3 indices vs the universe-wide screener loop.
- `Weinstein_strategy.make` constructs the cache when `bar_panels` are supplied and bundles it into `Bar_reader.of_panels ~ma_cache`. The cache lifetime is the strategy closure's lifetime.
- `Stops_runner.update`, `Macro_inputs.build_sector_map` and `Macro_inputs._sector_context_from_views` thread `?ma_cache` through to the panel callbacks. Trailing `()` arg added where OCaml's "unerasable optional argument" rule required it.

**Bit-equality**:
- SMA / WMA: bit-identical at every offset (sliding window).
- EMA: bit-identical at offset 0 and after sufficient warmup; default Stage config uses WMA, so EMA-via-cache is exercised only by tests.
- View-depth cap on the cached `get_ma` ensures `_count_above_ma_callback` and `_is_late_stage2_callback` see the same `None`-cutoff the bar-list path produces.

**Parity gates green**:
- Load-bearing `test_panel_loader_parity` (round_trips golden): 2 tests, all OK.
- New `test_weekly_ma_cache.ml`: 9 tests (SMA period=30 / WMA period=30 / EMA period=30 / SMA period=10 cache-vs-inline parity; short-history → empty; unknown-symbol → empty; locate_date present / missing; cache memoisation phys-equal). All OK.
- `test_panel_callbacks.ml`: 9 tests (8 pre-existing + 1 new "Stage parity (cache vs inline)" test that builds two callback bundles — one cache-aware, one inline — and asserts bit-identical Stage.result over a 60-week WMA-default rising series). All OK.
- `test_macro_inputs.ml` (8 tests), `test_stops_runner.ml` (5 tests), all `weinstein/strategy/test` suites green.
- All other test suites green: `data_panel/test` (60 tests), `backtest/test` (13 tests), all module tests pass.

**Files touched**:
- new: `trading/trading/weinstein/strategy/lib/weekly_ma_cache.{ml,mli}` (~105 + 90 lines).
- new: `trading/trading/weinstein/strategy/test/test_weekly_ma_cache.ml` (~225 lines).
- modified: `trading/trading/weinstein/strategy/lib/{panel_callbacks,bar_reader,stops_runner,macro_inputs,weinstein_strategy}.{ml,mli}`. Net +~120 lines including doc comments. `panel_callbacks.ml` declared `@large-module` (326 lines — splitting the per-callee constructors creates cycles).
- modified: `trading/trading/weinstein/strategy/lib/dune` — added `ppx_compare ppx_hash` to preprocess (needed by the cache key's `[@@deriving hash, compare]`).
- modified: `trading/trading/weinstein/strategy/test/dune` — registered `test_weekly_ma_cache` and added `indicators.{types,sma,ema}` to libraries.
- modified: `trading/trading/weinstein/strategy/test/{test_panel_callbacks,test_macro_inputs,test_stops_runner}.ml` — added trailing `()` to call sites whose APIs gained the optional `?ma_cache` arg; added new "Stage parity (cache vs inline)" test.

**LOC delta**: ~+450 production, ~+225 tests. `panel_callbacks.ml` 271 → 326 lines (declared `@large-module`).

**Out of scope (deferred)**:
- Stage classifier / Volume / Resistance ported to int8/decoder Bigarray panels (variant-typed result panel) — separate PR after PR-D's measured RSS impact.
- Bigarray-backed weekly MA panel (uniform N×W). The Hashtbl path is simpler given per-symbol weekly histories vary in length (different first-trade dates); revisit if the cache footprint becomes a concern.
- RSS spike re-run on `bull-crash-292x6y` to measure A+B+C+D combined peak RSS — separate dispatch (local devcontainer wall budget).

**Verify**: `cd trading && eval $(opam env) && TRADING_DATA_DIR=$PWD/test_data dune build && dune runtest && dune build @fmt`. All suites green; formatter clean; nesting linter clean (max ≤5, avg ≤3.0).

PR-D is bookmarked at `feat/panels-stage04-pr-d-weekly-indicator-panels`. Plan: `dev/plans/panels-stage04-pr-d-2026-04-26.md`.

---

**Prior status (Stage 4 PR-C, MERGED #590)**: single-pass weekly aggregation in `Bar_panels.weekly_view_for`.

**Prior status (Stage 4 PR-B, MERGED #588)**: drops the residual `bars_for_volume_resistance : Daily_price.t list` parameter from `Stock_analysis.analyze_with_callbacks`. The strategy's hot path no longer materialises any `Daily_price.t list` per-symbol per-Friday.

**Stage 4 PR-B scope**:
- `Volume.analyze_breakout_with_callbacks ~callbacks ~event_offset` — new callback-shaped entry point. `Volume.callbacks = { get_volume : week_offset:int -> float option }`. Indices match the panel layout (`week_offset:0` = newest). Existing bar-list `analyze_breakout` is now a thin wrapper that converts `event_idx` ↔ `event_offset` and delegates.
- `Resistance.analyze_with_callbacks ~callbacks ~breakout_price ~as_of_date` — new callback-shaped entry point. `Resistance.callbacks = { get_high; get_low; get_date; n_bars }` indexed by `bar_offset:0..n_bars-1`. The virgin / chart window walks bound by `min lookback n_bars`. Bucket aggregation uses a running max date to mirror the bar-list path's `max(dates)` per bucket.
- `Stock_analysis.callbacks` gains `volume : Volume.callbacks` and `resistance : Resistance.callbacks` fields. `analyze_with_callbacks` drops the `bars_for_volume_resistance : Daily_price.t list` parameter. The bar-list wrapper `analyze ~bars` builds the new bundle via `Volume.callbacks_from_bars` + `Resistance.callbacks_from_bars` — bit-identical for any input.
- `Panel_callbacks.volume_callbacks_of_weekly_view` and `Panel_callbacks.resistance_callbacks_of_weekly_view` — index directly into the `Bar_panels.weekly_view` float arrays (`volumes` / `highs` / `lows` / `dates`). `stock_analysis_callbacks_of_weekly_views` now wraps both new constructors in addition to the existing Stage / Rs ones, returning the full `Stock_analysis.callbacks` bundle from a weekly view alone — no bar list needed.
- `Weinstein_strategy._screen_universe` drops the `bars_for_volume_resistance = Bar_reader.weekly_bars_for ...` line and the `bars_for_volume_resistance:` argument to `Stock_analysis.analyze_with_callbacks`. The per-Friday allocation source is gone.

**Parity gates green**:
- `test_panel_loader_parity` (load-bearing): 2 round_trips goldens still bit-equal.
- `test_volume.ml`: 12 pre-existing + 5 new parity tests (Strong / Adequate / Weak / Insufficient-history / event-at-max-index) — total 17, all OK.
- `test_resistance.ml`: 9 pre-existing + 5 new parity tests (Virgin / Clean / Heavy / Moderate / chart-window-filtering) — total 14, all OK.
- `test_stock_analysis.ml`: 8 pre-existing + 8 PR-D parity tests — total 16, all OK with the new bundle shape (drop `bars_for_volume_resistance` arg).
- `test_panel_callbacks.ml`: 6 PR-A parity + 2 new (Volume / Resistance) — total 8, all OK.
- All `weinstein/strategy/test` suites green except the pre-existing flaky `test_ad_bars_weekly_e2e` (fails on main too — unrelated).

**Out of scope (PR-C/D)**:
- `Ohlcv_weekly_panels` + Friday rollup (PR-C).
- Port stage classifier / volume / resistance to indicator kernels (PR-D).
- RSS spike re-run on `bull-crash-292x6y` to measure peak RSS post-A+B (separate dispatch — local devcontainer wall budget).

**Expected memory impact**: PR-B eliminates the last per-tick `Daily_price.t list` allocation in the hot path. Combined with PR-A, peak RSS on `bull-crash-292x6y` should drop from 3.47 GB toward the projected ≤ 800 MB. Measurement deferred to a separate spike-rerun dispatch.

**LOC delta**: ~340 lines production source (volume +56, resistance +69, stock_analysis +13, panel_callbacks +28, weinstein_strategy -16); ~245 lines tests (volume +60, resistance +95, panel_callbacks +90). Function-length ceiling under 50-line hard limit; nesting linter — only the pre-existing `macro_callbacks_of_weekly_views` (max=6) remains, no new nesting violations.

**Verify**: `cd trading && eval $(opam env) && TRADING_DATA_DIR=/workspaces/trading-1/.claude/worktrees/agent-a1d76d23ee489a1e4/trading/test_data dune build && dune runtest`. All suites green; only pre-existing nesting linter violations on `analysis/scripts/universe_filter`, `fetch_finviz_sectors`, `ppx_test_matcher` remain (also fail on main).

PR-B is bookmarked at `feat/panels-stage04-pr-b-volume-resistance-callbacks`. Plan: `dev/plans/panels-stage04-pr-b-2026-04-26.md`.

---

**Prior status (Stage 4 PR-A, MERGED #584)**:

Stage 4 PR-A merged 2026-04-26 as #584. Drops `Daily_price.t list` materialisation at every strategy call site except Volume + Resistance (deferred to PR-B above). Adds `Bar_panels.weekly_view` / `daily_view` types, `Weinstein_strategy.Panel_callbacks` module with constructors for Stage / Rs / Sector / Macro / Stops support-floor / Stock_analysis Stage+Rs callbacks. Plan: `dev/plans/panels-stage04-pr-a-2026-04-26.md`.

---

**Prior status (Stage 3 PR 3.4):**

Stage 3 PR 3.4 MERGED as #575. All earlier stages merged: Stage 0 MERGED as #555. Stage 1 MERGED as #557. Stage 2 foundation MERGED as #558. Stage 2 PRs B–H all MERGED (#559 / #560 / #561 / #562 / #563 / #564 / #565). Stage 3 PR 3.1 MERGED as #567. Stage 3 PR 3.2 MERGED as #569. Stage 3 PR 3.3 MERGED as #573.

**Next dispatch (now in flight as PR-A above)**: Stage 4 (callbacks-through-runner wiring) is the load-bearing memory-win work — see plan §"Memory and CPU expectations" and `dev/notes/panels-rss-spike-2026-04-25.md`. The post-3.2 spike showed Panel mode at N=292 T=6y peaks at 3.47 GB / 6:00 wall vs the projected <800 MB; the gap is `Daily_price.t list` allocation pressure in `Bar_panels` reads + list-shaped callees still in the hot path. Stage 4 reshapes those callees to consume callbacks directly through `Panel_runner` and is the next dispatch after PR 3.4 lands.

**PR 3.4 summary**: After PR 3.3 (#573) deleted the Tiered runner, `Loader_strategy.t` carried only `Legacy | Panel` and both paths produced identical output (panel-backed since PR 3.2). PR 3.4 finalises panel-only:
- Deletes the `Loader_strategy` library entirely (`trading/trading/backtest/loader_strategy/`).
- Deletes `_run_legacy` + `_make_simulator` + `_build_legacy_*` from `runner.ml`. `Backtest.Runner.run_backtest` now delegates directly to `Panel_runner.run`; the `?loader_strategy` parameter is gone from the public API.
- Deletes the `--loader-strategy` CLI flag from `backtest_runner` and the `loader_strategy : Loader_strategy.t option` field from `Backtest_runner_args.t`.
- Drops the `loader_strategy` field from `Scenario.t`. Pre-3.4 scenario sexp files that still set `(loader_strategy <variant>)` continue to parse via `[@@sexp.allow_extra_fields]`; the runner ignores the field. Tested by a new backward-compat assertion in `test_scenario.ml`.
- Pre-flag verifications (per plan §"PR 3.4"):
  - **PR-F (Macro int-then-float fold)**: `_build_cumulative_ad_array` in `analysis/weinstein/macro/lib/macro.ml` keeps the running sum as `int` and converts via `Array.map ~f:Float.of_int` only at the array boundary. Preserved.
  - **PR-H QC (`Bar_reader.accumulate` / `_all_accumulated_symbols`)**: Fully removed in PR 3.2 (#569); no production code references either symbol. Only one stale doc comment remains in `test_weinstein_strategy.ml`.
  - **`bars_for_volume_resistance` on `Stock_analysis.analyze_with_callbacks`**: Volume + Resistance reshape NOT yet merged in parallel, so per the plan, this parameter is left in place. The existing `.mli` doc already references "PRs E/F/G or a follow-up" so no new TODO needed.

**LOC delta**: -271 lines net across 21 files. Mostly deletions: `_run_legacy` + helpers (~80 lines from `runner.ml`), `loader_strategy` library (~45 lines), `--loader-strategy` flag wiring (~30 lines from `runner_args` + CLI). Test files lose the loader-strategy parameter threading (~70 lines net deletion).

Parity gate: `test_panel_loader_parity` round_trips golden continues to hold — panel-mode path is unchanged; only the entry-point shape changes.

Verify: `cd trading && dune build && dune runtest trading/backtest`. All test suites green; the two pre-existing linter failures on `main` (`csv_storage.ml` nesting + `data-panels.md` "## Last updated" malformed line — the latter fixed by this PR) are unrelated to PR 3.4.

PR 3.4 is bookmarked at `feat/panels-stage03-pr-d-delete-legacy`. Plan: `dev/plans/data-panels-stage3-2026-04-25.md` §"PR 3.4".

---

**(Below: prior PR summaries kept as historical record.)**

**PR 3.3 summary**: deletes the entire Tiered backtest path. `tiered_runner.{ml,mli}`, `tiered_strategy_wrapper.{ml,mli}`, and the entire `bar_loader/` subdirectory (incl. 6 test files) are gone. `Trace.Phase.t` drops `Promote_summary | Promote_full | Demote | Promote_metadata`. `Loader_strategy.t` drops the `Tiered` variant — only `Legacy | Panel` remain. `Panel_runner` becomes standalone (its own `input` record; no longer wraps with `Tiered_strategy_wrapper`; no `Bar_loader` construction). `Runner` drops the `tier_op_to_phase` re-export, the `_tiered_input_of_deps` helper, the `_run_tiered_backtest` function, and the `Loader_strategy.Tiered` match arm. `full_compute_tail_days` and `bar_history_max_lookback_days` config fields are kept as vestigial (no-op) so existing override sexps still parse. Tiered-specific tests (`test_runner_tiered_skeleton`, `test_runner_tiered_cycle`, `test_runner_tiered_metadata_tolerance`, `test_tiered_loader_parity`) deleted along with the bar_loader test suite. Surviving tests — `test_runner_hypothesis_overrides`, `test_backtest_runner_args`, `test_trace`, `test_panel_loader_parity`, `test_scenario` — ported to drop Tiered references. CLI flag now accepts `legacy|panel`. Panel-mode round_trips golden gate (`test_panel_loader_parity`) still pinned bit-equal to the checked-in goldens.

**LOC**: ~5000 lines deleted (bar_loader + Tiered files + Tiered tests), ~140 lines edited (runner.{ml,mli}, panel_runner.{ml,mli}, trace.{ml,mli}, loader_strategy.{ml,mli}, dune files, test_* updates, CLI runner). Net diff vs main: see `git diff --stat main feat/panels-stage03-pr-c-delete-tiered` (33 files).

Verify: `cd trading/trading && TRADING_DATA_DIR=$PWD/test_data dune build && TRADING_DATA_DIR=$PWD/test_data dune runtest` (all green except the pre-existing `csv_storage.ml` nesting linter — unrelated to this PR).

**Post-3.2 perf spike** (`dev/notes/panels-rss-spike-2026-04-25.md`, 2026-04-25): Panel mode at N=292 T=6y on `/tmp/data-small-302` peaks at **3.47 GB / 6:00 wall** vs pre-3.2 Legacy 1.87 GB / Tiered 3.74 GB. Projection (<800 MB) **way off** (~4.4× over). Structural Bar_history deletion landed but `Daily_price.t list` allocation pressure in `Bar_panels` reads + list-shaped callees still dominates RSS — Stage 4 (callee reshape PR-H wiring) is required before the projected memory win materializes. Plan §"Memory and CPU expectations" needs a list-intermediate term.

**PR 3.2 summary**: deletes the parallel `Bar_history` Hashtbl cache and its Friday-cycle seeding step. `Bar_reader.t` collapses to a thin alias over `Bar_panels.t` — `of_history` and `accumulate` are gone, replaced by `of_panels` (existing) and a new `empty ()` for tests. `Weinstein_strategy.make` drops `?bar_history`; the only bar source it accepts now is `?bar_panels` (or the empty reader for control-path tests). `Tiered_strategy_wrapper.config` drops the `bar_history` and `seed_warmup_start` fields; `_seed_from_full` and `_truncate_bars` are deleted. The Friday cycle in the Tiered wrapper still drives Bar_loader tier bookkeeping (Promote_full trace events) but no longer feeds an external cache.

**Wiring `~bar_panels` into Tiered + Legacy runners**: with the parallel cache deleted, both runners (`tiered_runner.ml`, `runner.ml` Legacy path) build `Ohlcv_panels` + `Bar_panels` at simulator-construction time and pass them into `Weinstein_strategy.make`. Mirrors `Panel_runner`'s setup. PR 3.3 deletes the Tiered runner entirely, so this is short-lived duplication.

**Behavioural shift (per PR 3.1's pre-flag)**: panels are populated up-front from CSV, while the deleted `Bar_history` was incrementally seeded by `accumulate` (Legacy) or by the Friday Full-tier promote (Tiered). Trade-count and entry-price golden pins in `test_weinstein_backtest.ml` were therefore relaxed from exact equality to structural-invariant checks (n_buys > 0, n_sells > 0, n_round_trips > 0, final_value within conservative-sizing band, max_drawdown < bound). The exact per-trade pricing is captured by the round_trips golden in `test_panel_loader_parity` (already in `main` as PR 3.1) — that's the load-bearing parity gate post-3.2.

**Files deleted**:
- `trading/trading/weinstein/strategy/lib/bar_history.{ml,mli}` (~120 LOC)
- `trading/trading/weinstein/strategy/test/test_bar_history.ml` (~400 LOC)
- `trading/trading/weinstein/strategy/test/test_bar_reader_parity.ml` (single-backend parity is trivially true; ~230 LOC)

**Files modified**:
- `bar_reader.{ml,mli}`: collapsed to `of_panels` + `empty ()` + readers; type now opaque `Bar_panels.t` alias.
- `weinstein_strategy.{ml,mli}`: drop `?bar_history`, `_all_accumulated_symbols`, `Bar_reader.accumulate` call, `Bar_history` re-export. `bar_history_max_lookback_days` config field kept as vestigial (no-op) so existing override sexps still parse.
- `tiered_strategy_wrapper.{ml,mli}`: drop `bar_history` and `seed_warmup_start` fields; delete `_seed_from_full`, `_seed_one_symbol`, `_truncate_bars`; `_promote_universe_to_full` is now just the per-symbol promote loop without the seed step.
- `tiered_runner.ml`: build `Bar_panels` and pass to strategy via `~bar_panels`.
- `runner.ml`: same for Legacy.
- `panel_runner.ml`: drop `bar_history` allocation + threading; `_build_strategy` simplified.
- 4 test files (`test_weinstein_strategy.ml`, `test_stops_runner.ml`, `test_macro_inputs.ml`, `test_runner_tiered_cycle.ml`) — swap `Bar_history.create ()` fixtures for `Bar_reader.empty ()` or panel-backed `make_bar_reader` helpers.
- `test_weinstein_strategy_smoke.ml` + `test_weinstein_backtest.ml` (simulation/test): build `Bar_panels.t` from CSVs and pass to `Weinstein_strategy.make`. Pinned trade-count assertions relaxed to structural invariants (see Behavioural shift above).
- 2 dune files updated (drop `test_bar_history`/`test_bar_reader_parity`, add `trading.data_panel` dep to `test_weinstein_backtest`).

**LOC delta**: ~−750 lines (deletions dominate); ~+120 lines (panel-building helpers in three runners + test fixtures). Net ~−630 lines.

**Verify**: `cd trading && TRADING_DATA_DIR=$PWD/test_data dune build && dune runtest`. All test suites green except the two pre-existing linter failures (`csv_storage.ml` nesting, `tiered_runner.ml` 1800 magic number) — both unrelated to PR 3.2 and present on `main`. `dune fmt` clean.

**Tiered-vs-Panel goldens regenerated?**: `test_tiered_loader_parity` continues to pass — both Legacy and Tiered now share the same panel-backed bar source, so they produce identical output (the parity test's contract). PR 3.3 deletes the test entirely. The `test_panel_loader_parity` round_trips golden (PR 3.1 #567) is unchanged because Panel mode already used `~bar_panels` in PR 3.1.

PR 3.2 is bookmarked at `feat/panels-stage03-pr-b-delete-bar-history`. Plan: `dev/plans/data-panels-stage3-2026-04-25.md` §"PR 3.2".

**PR-H summary**: introduces `Bar_reader.t` — a thin closure-bundle over either `Bar_history` (the parallel Hashtbl cache) or `Bar_panels` (panel-backed reads from the `Ohlcv_panels` columns). The 6 reader sites identified in `dev/notes/bar-history-readers-2026-04-24.md` (macro_inputs ×2, stops_runner ×1, weinstein_strategy ×3) now consume `Bar_reader` exclusively. `Weinstein_strategy.make` gains an optional `?bar_panels:Bar_panels.t` parameter that takes precedence over `?bar_history` when both are provided. `Bar_panels.column_of_date` (new helper) maps the strategy's notion of "today's date" (the primary index bar's date) to a panel column.

**Reader-site parity gate** (`test_bar_reader_parity`, 5 tests in `weinstein/strategy/test`): feeds identical bars through both backends, asserts `daily_bars_for` and `weekly_bars_for` produce bit-identical `Daily_price.t list` outputs. Includes coverage for unknown symbols (both → empty), `as_of` truncation (panels respect the cursor), and out-of-calendar dates (panels return empty rather than raising).

**Scope deviation (vs dispatch)**: dispatch nominally targeted "delete Bar_history + tighten panel-loader parity gate". Both deferred:

1. **Bar_history deletion deferred to a Stage 3 PR.** Wiring `~bar_panels` into `Panel_runner` triggers structural divergence with Tiered (5 trades vs 3 on the smoke parity scenario) because Tiered's Bar_history is incrementally seeded by the Friday Full-tier promote cycle (Bar_history holds {warmup_start..as_of} bars at any given Friday), while Bar_panels is fully populated up-front (holds {warmup_start..end_date} bars from day 0). The Tiered cycle's incremental seeding is structural — it can't be made parity-clean against Bar_panels without first collapsing the Tiered tier system (Stage 3 of the columnar plan). The reader-level swap is correct (parity-tested in `test_bar_reader_parity`); the runner-level swap is the Stage 3 work. Until then, the Panel runner continues to use Bar_history (the strategy still works either way; only the runner's `~bar_panels` argument is unwired).

2. **Panel-loader parity gate strengthening deferred.** The existing `test_panel_loader_parity` continues to pass with sampled-step PV checks. Strengthening it to full per-step bit-equality + multiple scenarios is meaningful only after the Panel runner actually exercises Bar_panels via `~bar_panels`, which depends on Stage 3.

**LOC**: 4 ml/mli files modified in weinstein/strategy/lib (macro_inputs, stops_runner, weinstein_strategy + new bar_reader), 1 mli + 1 ml extended in data_panel (bar_panels gains column_of_date). 1 new test file (`test_bar_reader_parity.ml`, 5 tests, ~190 lines). 3 existing test files lightly adjusted to thread Bar_reader through the call sites. Net diff: ~520+/~150- across 17 files (incl. 1 new ml/mli pair + 1 new test).

Verify: `cd trading/trading && TRADING_DATA_DIR=$PWD/test_data dune build && dune runtest weinstein/strategy backtest data_panel` (all OK; `test_bar_reader_parity` runs 5 tests).

PR-H is bookmarked at `feat/panels-stage02-pr-h-final`. Plan: `dev/plans/panels-stage02-pr-h-final-2026-04-25.md`.

## Interface stable
NO

## Goal

Refactor the backtester's in-memory data shape from per-symbol scalar
(Hashtbl of `Daily_price.t list`) to columnar (Bigarray panels of
shape N × T per OHLCV field, plus per-indicator panels of the same
shape). Collapses the entire `bar_loader/` tier system, the post-#519
Friday cycle, the parallel `Bar_history` structure, and the +95%
Tiered RSS gap — all structurally rather than incrementally. Unblocks
the tier-4 release-gate scenarios (5000 stocks × 10 years, ≤8 GB).

The strategy interface ALREADY has `get_indicator_fn` (per
`strategy_interface.mli:23-24`); panel reads back it with
`Bigarray.Array2.unsafe_get`. No new API surface.

## Plan

`dev/plans/columnar-data-shape-2026-04-25.md` (PR #554) — five-stage
phasing, Bigarray storage backend, parity-gate per stage, decisions
ratified inline.

Supersedes `dev/plans/incremental-summary-state-2026-04-25.md`
(SUPERSEDED, kept as historical record). Reusable pieces (functor
signature, parity-test functor, indicator porting order, Bar_history
reader audit) carry forward.

## Open work

- **PR #554** merged 2026-04-25 (plan ratified).
- **PR #555** (Stage 0 spike) merged 2026-04-25. Implements `Symbol_index`, `Ohlcv_panels`, `Ema_kernel`, `Panel_snapshot` under `trading/trading/data_panel/`. 20 tests pass; EMA parity bit-identical at N=100 T=252 P=50; snapshot round-trip bit-identical. QC structural + behavioral both APPROVED.
- **PR #557** (Stage 1) merged 2026-04-25.
- **PR #558** (Stage 2 foundation) merged 2026-04-25. Adds `Bar_panels` reader + `adjusted_close` panel.
- **`feat/panels-stage02-pr-e-sector-analyze`** (Stage 2 PR-E, READY_FOR_REVIEW as PR #562) — fourth callee reshape.
  - Adds `Sector.analyze_with_callbacks ~config ~sector_name ~callbacks ~constituent_analyses ~prior_stage` — the indicator-callback shape of `Sector.analyze`.
  - New `Sector.callbacks` record bundles `stage : Stage.callbacks; rs : Rs.callbacks`. Sector's analysis itself reads no bar fields directly — it's a thin combinator that delegates Stage classification and RS computation to the corresponding callback APIs, then layers constituent breadth + composite confidence on top of those results. The bundle therefore wraps just those two nested callback records.
  - Adds `Sector.callbacks_from_bars ~config ~sector_bars ~benchmark_bars` — delegates to `Stage.callbacks_from_bars` (using `sector_bars`) and `Rs.callbacks_from_bars` (using `stock_bars=sector_bars` and `benchmark_bars`). Both nested constructors were added in PR-D.
  - Existing `Sector.analyze ~sector_bars ~benchmark_bars` is now a thin wrapper that builds a `callbacks` record via `callbacks_from_bars` and delegates. Behaviour is byte-identical for all bar-list callers; nothing in the call graph (`weinstein_strategy.ml` macro/sector pipeline, `screener` cascade) needs to change.
  - Four new parity tests in `test_sector.ml` covering high-confidence Stage2 + strong RS (rising sector, rising benchmark, all-Stage1-prior constituents → Strong rating), low-confidence Stage4 (declining sector + declining constituents, rising benchmark → Weak), mixed-stage constituents (half Stage 2 / half Stage 4 → Neutral), and insufficient bars (5-bar series → Stage1 default + RS=None). Each test builds the `callbacks` bundle externally via the public `callbacks_from_bars` and asserts `Sector.result` is bit-identical via composed matchers (`stage_result_is_bit_identical` over Stage's float fields, structural `equal_to` over the RS option, plus per-field comparisons of breadth pct, rating, constituent_count, name, rationale).
  - Verify: `cd trading/trading && TRADING_DATA_DIR=/workspaces/trading-1/.claude/worktrees/agent-ade0b4c8/trading/test_data dune build && dune runtest analysis/weinstein/sector` (10 tests, 6 pre-existing + 4 new parity, all OK). Full `dune runtest` passes; only the two pre-existing linter failures (csv_storage.ml nesting, tiered_runner.ml magic numbers) remain — both unrelated. `dune build @fmt` clean. fn_length / cc / nesting linters all clean for sector.
  - LOC: sector.ml grows from 133 to 164 lines; sector.mli from 75 to 140. Test file grows from 155 to 304.
  - PR #562 is bookmarked at `feat/panels-stage02-pr-e-sector-analyze`.
  - PRs F–G follow the same recipe for Macro and Stops. PR-H ports the six `Bar_history` reader sites to use the new callback APIs and deletes `Bar_history`.

- **`feat/panels-stage02-pr-d-stock-analysis`** (Stage 2 PR-D, MERGED #561) — third callee reshape.
  - Adds `Stock_analysis.analyze_with_callbacks ~config ~ticker ~callbacks ~bars_for_volume_resistance ~prior_stage ~as_of_date` — the indicator-callback shape of `Stock_analysis.analyze`.
  - New `Stock_analysis.callbacks` record bundles per-callee callbacks: panel-shaped `get_high : week_offset:int -> float option` and `get_volume : week_offset:int -> float option` (volume float-encoded to match the panel layout) for the breakout-price scan and the peak-volume scan, plus nested `Stage.callbacks` and `Rs.callbacks` for the Stage / RS sub-analyses. Volume.analyze_breakout and Resistance.analyze still consume `Daily_price.t list` (their reshape is deferred to PR-E/F/G or a sibling); `analyze_with_callbacks` therefore takes a separate `bars_for_volume_resistance` parameter that panel-backed callers in PR-H will reconstruct from panels until those callees are reshaped.
  - Adds `Stage.callbacks` + `Stage.callbacks_from_bars` and `Rs.callbacks` + `Rs.callbacks_from_bars` constructor pairs (small additions to those modules' `.mli`). Stage's existing `classify ~bars` and Rs's `analyze ~stock_bars ~benchmark_bars` wrappers refactor to delegate through `callbacks_from_bars` — no behaviour change but eliminates the duplicated index-closure plumbing.
  - Reshapes Stock_analysis's internals: `_scan_max_high_callback` walks `get_high` over `[base_end_offset, base_lookback)` (matching the bar-list `_scan_max_high`'s `[base_start, base_end)` slice in week-offset space). `_count_defined` + `_peak_offset_in` + `_find_peak_volume_offset_callback` replicate the bar-list `_find_peak_volume_idx` exactly — including the strict `>` tiebreak that keeps the oldest among ties (verified by walking offsets `defined-1 .. 0` rather than newest-first).
  - Existing `Stock_analysis.analyze` is now a thin wrapper that builds a `callbacks` record via `callbacks_from_bars` and threads `bars` through as `bars_for_volume_resistance`. Behaviour is byte-identical for all bar-list callers; nothing in the call graph (`weinstein_strategy.ml` screener cascade, `screener` lib) needs to change.
  - Eight new parity tests in `test_stock_analysis.ml` covering pre-breakout (Stage4 declining series, no volume confirmation), confirmed breakout with strong volume (Stage1 prior + spike), confirmed breakout with weak volume (uniform volume → Weak), Stage2 / Stage3 / Stage1 input regimes, insufficient bars (5-bar series), and the exact-base-window edge (n=60 with default 52/8 lookback). Each test builds external `callbacks` via the public `callbacks_from_bars` and asserts `Stock_analysis.t` is bit-identical via composed matchers (`stage_result_is_bit_identical` over Stage's float fields, `volume_result_is_bit_identical` over Volume's, structural `equal_to` over Resistance / Rs option records).
  - Verify: `cd trading/trading && TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data dune build && dune runtest analysis/weinstein/stock_analysis` (16 tests, 8 pre-existing + 8 new parity, all OK). Full `dune runtest` passes; only the two pre-existing linter failures (csv_storage.ml nesting, tiered_runner.ml magic numbers) remain — both unrelated. `dune build @fmt` clean.
  - LOC: stock_analysis.ml grows from 165 to 298 lines; stock_analysis.mli from 77 to 157. Stage.ml grows from 393 to 415 (callbacks record + constructor); Stage.mli from 178 to 199. Rs.ml grows from 238 to 259; Rs.mli from 109 to 132.
  - PR is bookmarked at `feat/panels-stage02-pr-d-stock-analysis`.
  - PRs E–G follow the same recipe for Sector, Macro, Stops. PR-H ports the six `Bar_history` reader sites to use the new callback APIs, deletes `Bar_history`, and reshapes Volume/Resistance to drop the `bars_for_volume_resistance` parameter.

- **`feat/panels-stage02-pr-c-rs-analyze`** (Stage 2 PR-C, MERGED #560) — second callee reshape.
  - Adds `Rs.analyze_with_callbacks ~get_stock_close:(week_offset:int -> float option) ~get_benchmark_close:(week_offset:int -> float option) ~get_date:(week_offset:int -> Core.Date.t option)` — the indicator-callback shape of `Rs.analyze`. `week_offset:0` = current week, `1` = previous, etc.; `None` = warmup or out-of-range. The walk stops at the first offset where any of the three callbacks returns `None`, yielding the depth of aligned weekly data the caller has already produced. Returns `None` if depth `< rs_ma_period`.
  - The three callbacks reflect the fact that `Rs.result.history : raw_rs list` carries per-point dates downstream (consumed by sector / stock_analysis / screener tests). The callback shape preserves dates rather than dropping them; the panel-backed caller is responsible for date-aligning the two close series so that the same `week_offset:k` resolves consistently across all three callbacks.
  - Reshapes Rs's internals: a shared `_history_of_aligned ~rs_ma_period (date, sc, bc) list -> raw_rs list option` runs the same `Sma.calculate_sma` kernel `Relative_strength.analyze` uses (so float arithmetic is the same source kernel — bit-identical raw RS / normalized values). Trend classification is unchanged.
  - Existing `Rs.analyze ~stock_bars ~benchmark_bars` is now a thin wrapper that joins the two bar lists on date once, builds three closures over the resulting aligned arrays, and delegates to `analyze_with_callbacks`. Behaviour is byte-identical for all bar-list callers; nothing in the call graph (`weinstein_strategy.ml`, `sector.ml`, `stock_analysis.ml`, screener cascade) needs to change.
  - Six new parity tests in `test_rs.ml` covering positive RS (stock outperforms), negative RS (stock underperforms), near-zero (identical series), bullish crossover, insufficient-data early-return (`n < rs_ma_period`), and exact-minimum (`n = rs_ma_period`). Each test builds external `get_*` callbacks with the same indexing rules the wrapper uses internally and asserts `Rs.result` is bit-identical via structural `equal_to` over float fields and per-element `raw_rs` comparison through `elements_are` (so any ULP drift in `rs_value`, `rs_normalized`, or any date mismatch fails the test).
  - Verify: `cd trading/trading && TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data dune build && dune runtest analysis/weinstein/rs/test` (15 tests, all OK — 9 original + 6 parity). Full `dune runtest` passes; only the two pre-existing linter failures (`csv_storage.ml` nesting, `tiered_runner.ml` magic numbers) remain — both unrelated.
  - LOC: rs.ml grows from 85 to 237 lines; rs.mli from 64 to 108. No `@large-module:` opt-in needed.
  - PR is bookmarked at `feat/panels-stage02-pr-c-rs-analyze`.
  - PRs D–G follow the same recipe for Stock_analysis, Sector, Macro, Stops. PR-H finally ports the six `Bar_history` reader sites to use the new callback APIs and deletes `Bar_history`.

- **`feat/panels-stage02-pr-b-stage-classify`** (Stage 2 PR-B, MERGED #559) — first callee reshape (PR-B in the eight-PR A–H sequence per plan).
  - Adds `Stage.classify_with_callbacks ~get_ma:(week_offset:int -> float option) ~get_close:(week_offset:int -> float option)` — the indicator-callback shape of `Stage.classify`. `week_offset:0` = current week, `1` = previous, etc.; `None` = warmup or out-of-range.
  - Reshapes Stage's internal helpers (`_compute_ma_slope_callback`, `_count_above_ma_callback`, `_is_late_stage2_callback`, `_ma_depth`, `_largest_defined_offset`) to read MA / close via callbacks.
  - Existing `Stage.classify ~bars` is now a thin wrapper that precomputes the MA series + closes once into arrays, builds `get_ma`/`get_close` closures over those arrays, and delegates to `classify_with_callbacks`. Behaviour is byte-identical for all bar-list callers; nothing in the call graph (`weinstein_strategy.ml`, screener cascade, etc.) needs to change.
  - Six new parity tests in `test_stage.ml` covering Stage1/Stage2/Stage3/Stage4 on 100-bar synthetic series + late-Stage-2 deceleration + insufficient-data early-return. Each test builds external `get_ma`/`get_close` callbacks with the same indexing rules the wrapper uses internally and asserts `Stage.result` is bit-identical between the bar-list and callback paths (via structural `equal_to` over float fields, so any drift fails).
  - Verify: `cd trading/trading && dune build && dune runtest analysis/weinstein/stage/test` (18 tests, all OK). Full `dune runtest` passes; only the two pre-existing linter failures (csv_storage.ml nesting, tiered_runner.ml magic numbers) remain — both unrelated to this PR.
  - File length: stage.ml grows from 295 to ~390 lines and now carries `(* @large-module: ... *)` opt-in (rationale: the module holds two parallel entry points sharing one set of stage-selection helpers; splitting would cut bidirectional dependencies).
  - PRs C–G follow the same recipe for Rs, Stock_analysis, Sector, Macro, Stops. PR-H finally ports the six `Bar_history` reader sites to use the new callback APIs and deletes `Bar_history`.
- **`feat/panels-stage02-no-bar-history`** (Stage 2 foundation, MERGED #558):
  - Adds `Bar_panels` reader module (`trading/trading/data_panel/bar_panels.{ml,mli}`) — backs the strategy's bar-list reads with `Ohlcv_panels` slices. API mirrors `Bar_history`: `daily_bars_for ~symbol ~as_of_day`, `weekly_bars_for ~symbol ~n ~as_of_day`, `low_window ~symbol ~as_of_day ~len` (the support-floor primitive — returns a zero-copy `Bigarray.Array1.sub` over the Low panel row).
  - Adds `adjusted_close` panel to `Ohlcv_panels` (a Stage 2 prerequisite missed by Stage 0/1 — without it, panel-reconstructed `Daily_price.t` records would silently use raw close in indicator math, breaking parity for stocks with dividends or splits).
  - 14 new `bar_panels_test.ml` cases — calendar-mismatch rejection, daily-bars truncation, NaN-cell skip, weekly aggregation, low_window zero-copy slice, underflow/unknown-symbol/zero-len → None.
  - Verify: `dune runtest data_panel` (60 tests, including 14 new); full `dune runtest` passes.
  - **Stage 2 dispatch deviation**: the dispatch read Stage 2 as a 6-reader-site swap from `Bar_history.weekly_bars_for sym` to a single `get_indicator_fn` MA read. The actual code shape is different — every reader site consumes `Daily_price.t list` (passed into `Stage.classify`, `Sector.analyze`, `Macro.analyze`, `Stock_analysis.analyze`, `Weinstein_stops.compute_initial_stop_with_floor` — none of which take MA values directly). Replacing list reads with single-value MA reads requires reshaping all of those callees, which crosses the line into Stage 4 territory. The pragmatic Stage 2 path is: keep callees list-shaped; back the lists with on-the-fly panel reconstruction via `Bar_panels`. This still eliminates the parallel `Bar_history` cache (the +95% Tiered RSS gap source) and lands the structural memory win.
- **Stage 2 work remaining** (estimated ~1100 LOC across follow-up sessions):
  - Update `Panel_runner` and `Tiered_runner` to build a `Bar_panels.t` (the latter requires also building `Ohlcv_panels` in the Tiered path, since today's Tiered loader doesn't use panels).
  - Change `Weinstein_strategy.make` from `?bar_history` to `?bar_panels`. Internal calls switch from `Bar_history.weekly_bars_for` → `Bar_panels.weekly_bars_for ~as_of_day`. Today's `as_of_day` is derived from the strategy wrapper's calendar lookup (Panel_strategy_wrapper already does this; need to plumb it into the inner strategy).
  - Migrate 6 reader sites: `macro_inputs.ml:28,39` (build_global_index_bars, _sector_context_for), `stops_runner.ml:11` (_compute_ma), `weinstein_strategy.ml:110,220,314` (entry initial-stop floor, screen-universe stage analysis, primary-index Friday detection).
  - Delete `Bar_history` module + tests + the `Tiered_strategy_wrapper.bar_history` field + `_seed_from_full` + `_run_friday_cycle` seed step (the Friday cycle's only purpose was Bar_history seeding; with panels pre-loaded, the seed is dead code).
  - Update test fixtures: `test_weinstein_strategy.ml`, `test_stops_runner.ml`, `test_macro_inputs.ml`, `test_runner_tiered_cycle.ml`, `test_bar_history.ml` (delete the last; the others swap `Bar_history.create ()` for synthetic `Bar_panels.t` fixtures).
  - Strengthen `test_panel_loader_parity`: full `round_trips` list bit-identity + per-step PV match across multiple scenarios. Today's gate is "vacuous" per QC behavioral pre-flag because the strategy doesn't yet read from panels.
- **`feat/panels-stage01-get-indicator`** (Stage 1, MERGED #557). Adds:
  - `Sma_kernel`, `Atr_kernel` (Wilder), `Rsi_kernel` (Wilder), each with bit-identical scalar parity tests (max_ulp=0 at N=50–100 T=252).
  - `Indicator_spec` (hashable {name; period; cadence}) and `Indicator_panels` registry. Owns output panels + RSI scratch (avg_gain/avg_loss). Validates spec at create (Daily-only, period ≥ 1, name in {EMA,SMA,ATR,RSI}). `advance_all` dispatches per registered kernel.
  - `Get_indicator_adapter.make` produces the strategy's `get_indicator_fn` closure backed by panel reads (returns `None` for unknown symbols, unregistered specs, or NaN cells).
  - `Ohlcv_panels.load_from_csv_calendar` — calendar-aware loader that aligns CSV bars by date column. Dedicated test fixtures: two symbols with different start dates against a 5-day calendar, plus dates-outside-calendar and missing-CSV cases.
  - `Loader_strategy.t` extended with `Panel`. New `Panel_runner` reuses Tiered execution + builds OHLCV panels (calendar-aware), Indicator_panels registry (default specs EMA-50 / SMA-50 / ATR-14 / RSI-14, daily), wraps strategy via `Panel_strategy_wrapper` which intercepts `on_market_close`, advances panels to today's column, and substitutes a panel-backed `get_indicator`.
  - Integration parity gate `test_panel_loader_parity`: Tiered vs Panel on the 7-symbol bull-2019h2 fixture — n_round_trips, final PV, and step-sample PVs identical to ≤ $0.01.
  - `Bar_history` left alive per Stage 1 invariant — Stage 2 deletes it.
- **Verify** (Stage 1): `TRADING_DATA_DIR=$PWD/trading/test_data dune build && TRADING_DATA_DIR=$PWD/trading/test_data dune runtest data_panel/ backtest/test`. 46 data_panel tests + 13 backtest/test tests pass.

### Stage 1 pre-flags (from QC behavioral, non-blocking)

To address before / during Stage 1:
1. `Ohlcv_panels.load_from_csv` is not calendar-aware — must resolve before Stage 4 (weekly cadence) but Stage 1 can specify the contract.
2. `Panel_snapshot` dump-twice byte-equality is not tested — needed for reproducible golden fixtures; add the test in Stage 1.
3. Unrounded EMA values will flow into `stage.ml` once Stage 4 wires the kernel — add a boundary golden-parity check (current `Ema.calculate_ema` rounds output to 2 decimals via TA-Lib FFI; downstream callers (`stage.ml` slope/above-MA, `above_30w_ema`) appear insensitive but verify before Stage 4).

### RSS / memory gate

RSS gate (≤50% of scalar at N=300 T=6y on bull-crash goldens) is NOT measured at Stage 0 by design — that's a follow-up sweep run once Stages 1+ wire panels into the runner.

### Awaiting human

Per plan §Decision point: "if parity gate fails (FP drift > 1 ULP and end-to-end PV moves) or RSS gain < 30% or snapshot round-trip is lossy, abort the migration and revisit." Parity gate held bit-identical; snapshot round-trip is bit-exact; RSS gate deferred to post-Stage-1. **Recommendation: green-light Stage 1.**

## Five-stage phasing (from the plan)

| Stage | Owner | Scope | Branch | LOC |
|---|---|---|---|---|
| 0 | feat-backtest | Spike: `Symbol_index`, OHLCV panels, EMA kernel, parity test, snapshot serialization — **MERGED #555** | `feat/panels-stage00-spike` | ~700 (incl. tests) |
| 1 | feat-backtest | Panel-backed `get_indicator` for EMA/SMA/ATR/RSI; Bar_history kept alive | `feat/panels-stage01-get-indicator` | ~500 |
| 2 | feat-backtest | Replace 6 Bar_history reader sites with panel views; delete Bar_history | `feat/panels-stage02-no-bar-history` | ~400 |
| 3 | feat-backtest | Collapse Bar_loader tier system + Friday cycle | `feat/panels-stage03-tier-collapse` | ~400 |
| 4 | feat-backtest | Weekly cadence panels + remaining indicators (Stage, Volume, Resistance, RS) | `feat/panels-stage04-weekly` | ~300 |
| 5 | feat-backtest | Live-mode universe-rebalance handling (deferred until live mode lands) | `feat/panels-stage05-live` | ~150 |

Total: ~2200 LOC across 6 PRs over ~10 working days. Stage-by-stage
parity gate against existing scalar implementation. Each stage
mergeable independently (Stage 1 alone gives the indicator
abstraction; Stage 2 alone gives the memory win).

## Stage 0 gate criteria (decision point)

If Stage 0 spike fails any of these, abort migration and revisit:

- Byte-identical EMA values OR ≤ 1 ULP drift compounded over 1y with
  end-to-end PV unchanged
- RSS < 50% of current scalar implementation at N=300 T=6y on
  bull-crash goldens (target gain ≥ 30%)
- Snapshot serialization round-trip: bit-identical values, load wall
  < 100 ms at N=1000 T=3y

### Stage 0 result (2026-04-25, branch `feat/panels-stage00-spike`)

- **EMA parity: PASSED — bit-identical (max_ulp=0, max_abs=0.0)** at
  N=100 symbols × T=252 days × period=50 against a scalar reference
  using the same expression form (warmup = left-to-right `+.`
  accumulation; recurrence = bind `new_v` and `prev` to locals before
  the multiply-add).
  - Surprise observation: an earlier reference variant that inlined
    `data.(t)` and `out.(t-1)` directly into the multiply-add drifted
    by 1–6 ULP over compounded 1y. The OCaml compiler schedules
    instructions differently when reads aren't bound to named locals,
    and IEEE 754 multiplication isn't associative. **For Stage 1+
    indicator ports, ensure the kernel and any reference comparator
    use identical expression form** — specifically, named locals for
    each panel read before the arithmetic. Documented inline in
    `ema_kernel_test.ml` and the kernel's `.mli`.
- **Snapshot round-trip: PASSED — bit-identical** on single-panel
  (3×5 Float64) and multi-panel (2×4, three panels including NaN +
  inf cells) cases. Format is `[int64-LE header_len][sexp header][page-aligned float64 panels]`;
  load uses `Caml_unix.map_file` so it is mmap-backed and effectively
  O(milliseconds). Wall-clock measurement at N=1000 T=3y is deferred
  to Stage 1+ alongside the RSS sweep.
- **RSS gate: NOT measured at Stage 0**. The dispatch explicitly
  scoped this out — RSS measurement against the bull-crash N=300 T=6y
  goldens needs the perf-sweep harness wired in, which only happens
  when Stages 1+ start consuming panels in the runner. That sweep is
  the post-merge follow-up.
- **Verify**: `cd trading/trading && dune build data_panel/ &&
  for t in symbol_index ohlcv_panels ema_kernel panel_snapshot; do
  ../_build/default/trading/data_panel/test/${t}_test.exe; done`
  (20 tests, all OK).

## Memory targets (from plan §Memory expectations)

| Scale | Today (extrapolated) | Columnar projected |
|---|---:|---:|
| N=292 T=6y bull-crash | L 1.87 / T 3.74 GB | < 800 MB |
| N=1000 T=3y | L 1.83 / T 3.83 GB | < 1.0 GB |
| N=5000 T=10y (release-gate tier 4) | 12-22 GB | ~1.2 GB |

## Ownership

`feat-backtest` agent. All five stages owned by the same agent for
continuity (the indicator porting in stage 4 touches `weinstein/*`
modules but the work is panel-shaped, not strategy logic).

## Branch convention

`feat/panels-stage<NN>-<short-name>`, one per stage. Stages 1+ stack
on each prior stage's branch tip (per orchestrator fresh-stack rule)
since each stage needs the prior stage's types but not its merge.

## Blocked on

- Stage 0 must complete + parity-gate pass before any subsequent
  stage starts. No stages start until human reviews the spike result.

## Blocks

- `backtest-perf` tier-4 release-gate scenarios are blocked on
  Stage 3 (tier collapse) at minimum, ideally Stage 4 (weekly
  cadence). Until then the 5000×10y scenario doesn't fit in 8 GB.

## Decision items (need human or QC sign-off)

All ratified 2026-04-25; see plan §Decisions. None outstanding
pre-Stage 0.

Post-Stage 0 spike result will produce the next decision point: did
parity hold within tolerance, did RSS gain hit the gate, did
snapshot round-trip work? Stages 1+ proceed only on green.

## References

- Plan: `dev/plans/columnar-data-shape-2026-04-25.md` (PR #554)
- Superseded plan: `dev/plans/incremental-summary-state-2026-04-25.md`
  (PR #551 merged; kept as historical record)
- Sibling: `dev/status/backtest-perf.md` — tier 4 release-gate
  scenarios blocked here
- Predecessor: `dev/status/backtest-scale.md` (READY_FOR_REVIEW) —
  bull-crash hypothesis-test sequence that motivated this redesign
- Strategy interface (already exposes `get_indicator_fn`):
  `trading/trading/strategy/lib/strategy_interface.mli:23-24`
- Bar_history reader audit:
  `dev/notes/bar-history-readers-2026-04-24.md` (6 sites)
- Perf findings that motivated this: `dev/notes/bull-crash-sweep-2026-04-25.md`,
  `dev/notes/perf-sweep-2026-04-25.md`
