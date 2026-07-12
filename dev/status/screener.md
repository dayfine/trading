# Status: screener

## Last updated: 2026-06-02

## Status
MERGED

**2026-07-12**: `fix(resistance): insufficient-history label instead of false Virgin_territory (default-off)` (branch `feat/resistance-insufficient-history`, PR #1941 MERGED 2026-07-12 run-2) — C4 in `next-session-priorities-2026-07-12.md` / fix #1 in `visual-trade-audit-2026-07-12.md` ("Resistance-mapper data starvation"). The resistance mapper's spec wants ~520 weekly bars of virgin lookback, but backtest panels carry ~52 and the live weekly-review warehouse ~110; on a starved window the mapper printed `Virgin_territory` (no overhead resistance) for names actually sitting under years of tops — observed COO (backtest) and CWST (live picks). Fix is the **label**, not a gate: added `Resistance.config.min_history_bars : int` (default `0`) + a new `Weinstein_types.overhead_quality` variant `Insufficient_history`. When `callbacks.n_bars < min_history_bars`, `analyze` / `analyze_with_callbacks` emit `Insufficient_history` instead of any grade (observed `zones_above` still reported); default `0` disables the check → **bit-identical** to the prior mapper (no golden moves, per `experiment-flag-discipline.md` R1). No consumer change was needed: `Screener_scoring._resistance_signal`'s catch-all already scores an `Insufficient_history` result at 0 (not virgin/clean), satisfying "must NOT be scored as virgin territory". Aligns with the post-run validation harness check V7 (`Validator_bar_checks`), which pins the same defect from the trade-record side. NOT an entry gate (overhead-resistance entry gates were screened NO-BUILD). 5 new `test_resistance.ml` cases (default-still-virgin, armed→insufficient, armed+sufficient→normal grade, zones-still-reported, callback parity). Files: `weinstein_types.{ml,mli}`, `resistance/lib/resistance.{ml,mli}`, `resistance/test/test_resistance.ml`. **Follow-up:** arming (positive `min_history_bars` in live weekly-review config + record convention) is a separate decision.

**2026-06-28**: `feat(screener): candidate_ranking quality tiebreak (default-off)` (branch `feat/screener-quality-ranking`, PR OPEN) — the buildable mechanism behind issue #1782 (Phase 1; Phase 2 WF-CV follows separately). Adds `Screener.config.candidate_ranking : candidate_ranking [@sexp.default Alphabetical]` (a `[ Alphabetical | Quality ]` variant). The screener sorts buy/short candidates by `score` desc then `String.compare ticker`, caps at `max_buy_candidates` (20); the coarse additive score makes ties common, so over-subscribed selection broke ties alphabetically → A-ticker skew (live + every backtest, since `Weinstein_strategy` consumes the same ordering). `Alphabetical` (default) is **bit-identical** to the prior ticker-only tiebreak — the primary `score` sort is unchanged, so no golden moves. `Quality` re-orders **only equal-score ties** by a continuous Weinstein-faithful key: RS magnitude (`rs.current_normalized`, spine item 7) desc → earliness (`weeks_advancing` asc, avoid extended Stage 2) → volume-expansion (`volume_ratio`) desc → `ticker` asc (final deterministic fallback, required for reproducible backtests). Surgical: the additive score itself is untouched; spine intact (still buy only Stage-2 breakouts). Tiebreak logic extracted to a new sibling `Screener_ranking` module (`candidate_ranking` type, `rankable`, `compare_rankable`) `include`d into `Screener` — keeps `screener.ml` under the declared-large file-length cap; comparator re-exposed as `Screener.compare_for_ranking` for unit-testability. Threaded `~ranking:config.candidate_ranking` through `_filter_and_cap`/`_evaluate_longs`/`_evaluate_shorts`/`_evaluate_candidates`. Reachable from the override path via `((screening_config ((candidate_ranking Quality))))` → resolves through `Overlay_validator.apply_overrides`, a `Variant_matrix` `Key` axis (per `experiment-flag-discipline.md` R2). 6 new `test_screener.ml` cases: Alphabetical=ticker-order parity, Quality-orders-by-RS, RS-tie→earliness, score-stays-primary, field-serializes+round-trips, omitted-field→Alphabetical default. All existing screener goldens/tests pass unchanged. Also added `candidate_ranking = Screener.Alphabetical` to the one full-record `Screener.config` literal in `stage_transition_scanner.ml` (preserves behaviour). **Follow-up:** Phase 2 — run the `Quality` axis through WF-CV + the confirmation grid; if ACCEPT, consider promoting the default (needs ledger verdict per R3). Optionally mirror a top-level `Weinstein_strategy.config` field for axis ergonomics (not required — `screening_config.candidate_ranking` already resolves).

**2026-06-02**: `feat(screener): min_price liquidity floor (default-off)` (branch `feat/screener-min-price`, PR #1428, OPEN) — adds `Screener.config.min_price : float [@sexp.default 0.0]`, a default-off liquidity floor that excludes penny / illiquid names from buy and short candidates (faithful screener filter; Weinstein trades liquid leaders — book §4.2). `0.0` = no floor, bit-identical to pre-floor behaviour; positive values (1/5/10) exclude candidates whose setup price (`breakout_price` longs / `breakdown_price` shorts) is below the floor or unknown. Gate helper `Screener_admission.passes_price_floor` (kept out of the already-large `screener.ml`); threaded through `_long_candidate`/`_short_candidate`/`_evaluate_*`/`screen`/`screen_with_cooldown` mirroring `min_score_override`, folds into the breakout/breakdown diagnostics phase. Reachable from the scenario/strategy override path via `((screening_config ((min_price 5.0))))` (two deep-merge tests in `test_runner_hypothesis_overrides.ml`). 6 new `test_screener.ml` cases (no-op / floor-rejects-below / short-side / missing-price). Note: brief assumed a `Stock_analysis.t.get_high` accessor that doesn't exist on main — gated on the `float option` setup price instead (matches the `None`-rejection semantics). **Follow-up:** wire `min_price` into the automated tuner sweep surface (`grid_search` / `bayesian_runner_spec`).

**2026-06-01**: `feat(weinstein): neutral_blocks_longs default-off entry-gate axis` (branch `feat/neutral-blocks-longs-axis`, OPEN) — lever #2 of the Cell E 2020-2026 stall diagnosis. Adds `Screener.config.neutral_blocks_longs : bool [@sexp.default false]` plus a mirrored top-level `Weinstein_strategy.config.neutral_blocks_longs` field threaded into `screening_config` at screen time. When `true`, a macro-`Neutral` tape blocks new long candidates exactly as `Bearish` does (only `Bullish` admits longs); default `false` preserves the historical gate bit-equally. The short-side gate is unaffected. A *tightening* of Weinstein's unconditional macro gate (a faithful dial, spine intact). Default-off axis per `.claude/rules/experiment-flag-discipline.md` — proven `Variant_matrix`-expressible (`(flag neutral_blocks_longs)`) by `test_variant_matrix.ml`. No default flipped; no golden config_overrides touched. Tests: bit-identical-when-off + flag-on-blocks-Neutral + Bullish-unaffected + short-side-unchanged in `test_screener_e2e.ml`.

**2026-05-25**: `fix(screener): NaN/inf guards in resistance/support/volume` (PR #1309) MERGED at `bee5e663c`. Defensive guards in `resistance.ml` (`_bucket_idx`), `support.ml` (`_bucket_idx_below`), and `volume.ml` (`_result_of_volumes`) are now pinned with three regression tests addressing the prior CP4 finding (band_size=0.0 → +inf offsets short-circuited; Float.nan event volume → None). Re-QC verdict on tip `774edc7f4`: structural APPROVED + behavioral APPROVED quality_score 4 (see `dev/reviews/screener-nan-inf-guards.md`); CI green (build-and-test + perf-tier1-smoke + golden-runs-custom-universe). Auto-merged via Step 6.5 after one branch-update cycle (got behind when #1313 merged ahead).

**Prior**: Cascade post-stop-out cooldown gate landed via PR #718 (merged 2026-04-30 evening). 2026-05-14: `feat/screener-pi-filter` (PR #1089, MERGED) adds an opt-in point-in-time universe-membership gate (`Screener.screen_with_cooldown ?membership_at`) plus strategy-side wiring (`enable_pi_filter` config flag → `Bar_reader.daily_bars_for` → `Daily_price.active_through`). Default-off preserves all baselines. 2026-05-14: `feat/snapshot-active-through-propagation` closes the snapshot-pipeline propagation gap — `Snapshot_manifest.file_metadata` carries per-symbol `active_through`, surfaced via `Daily_panels.active_through_for` and `Snapshot_callbacks.active_through_for`, stamped onto every reconstituted `Daily_price.t`. With this PR the PI filter is behaviourally active on the in-memory + snapshot path (verified by `test_pi_filter_wiring`); production-data backtests still see `active_through = None` everywhere because the source CSVs / Wiki universe builder do not populate the field — that is the next slice. See `dev/notes/historical-universe-status-2026-05-13.md`.

## QC Review
APPROVED — See dev/reviews/screener.md (2026-03-30). All prior blockers resolved.
Merged to main (PRs #120, #121, #122, #134, #144, #160, #164, #165).

## Interface stable
YES

## Blocked on
- None (data-layer MERGED)

## Completed

- SMA and Weighted MA indicators (`analysis/technical/indicators/sma/`) — 11 tests
- Weinstein shared types (`analysis/weinstein/types/`) — stage, ma_slope, overhead_quality,
  rs_trend, volume_confirmation, market_trend, grade variant types with metadata
- Stage Classifier (`analysis/weinstein/stage/`) — pure 4-stage classification with MA slope
  computation, prior_stage disambiguation (Stage1 vs Stage3), late-Stage2 detection,
  transition tracking — 12 tests; ma_type variant (Sma/Wma/Ema) added in review
- Relative Strength analyzer (`analysis/weinstein/rs/`) — Mansfield RS formula with
  zero-line normalization, 6 trend states, date-aligned intersection — 10 tests
- Volume analyzer (`analysis/weinstein/volume/`) — Weinstein's 2× breakout rule,
  Strong/Adequate/Weak classification, pullback contraction check — 12 tests
- Resistance mapper (`analysis/weinstein/resistance/`) — overhead resistance zone finder,
  Virgin/Clean/Moderate/Heavy grading, chart_years window filtering — 9 tests
- Stock Analyzer (`analysis/weinstein/stock_analysis/`) — aggregates all sub-analyses
  per ticker, breakout/breakdown candidate detection — 8 tests
- Screener (`analysis/weinstein/screener/`) — cascade filter (macro gate → sector gate →
  scoring → grade), buy/short candidate ranking with entry/stop/risk/swing — 9 tests
- Macro Analyzer (`analysis/weinstein/macro/`) — weighted composite regime from 5 indicators
  (index stage, A-D divergence, momentum index, NH-NL, global consensus), regime change
  detection — 10 tests
- Sector Analyzer (`analysis/weinstein/sector/`) — stage + RS + constituent breadth
  combines into Strong/Neutral/Weak rating, sector_context_of for screener — 6 tests

Total: 87 new tests across 9 modules, all passing.

## In Progress
- None. PR #718 (cascade post-stop-out cooldown gate) merged 2026-04-30 evening
  via 70f9b2c. Adds `Screener.config.cascade_post_stop_cooldown_weeks` (default 0;
  preserves bit-equality) and `Screener.screen_with_cooldown`. Wired through
  `Weinstein_strategy._on_market_close` so a per-symbol last-stop-out date map
  populates from `TriggerExit { exit_reason = StopLoss _ }` and feeds the screener
  every Friday. Source finding: `dev/notes/sp500-trade-quality-findings-2026-04-30.md`
  §"Cascade re-firing within days of stop-out". Sweep / scenario rerun is a
  separate follow-up.

## Followup / Known Improvements

### Cascade post-stop-out — re-base detection
PR #718 lands a time-based cooldown only. The findings note flags that
"may need to be combined with re-base detection for full book conformance"
— require the symbol to dip below the prior breakout level and re-emerge
before the screener re-fires. Out of scope for #718.

### Stage classifier: segmentation-based MA direction
`stage/lib/stage.ml` currently classifies MA direction via a two-point slope
comparison (MA_now vs MA_[lookback]_ago). Consider replacing this with the
piecewise linear segmentation in `analysis/technical/trend/lib/segmentation.ml`,
which fits a regression to the MA series and classifies the slope of the most
recent segment. Benefits: fewer false direction flips from short-term noise,
better base-building detection. See module comment in `stage.mli` for details.

### Stage state machine functor
`_classify_new_stage` encodes the valid Stage 1–4 transitions as a large
pattern match. A state machine functor would make valid transitions explicit and
could be shared with the Weinstein stop state machine in `weinstein/portfolio_risk`.
Consider when both state machines are stable enough to identify shared structure.

### Shared MA slope utility
`_compute_ma_slope` duplicates a pattern also in the RS analyser and likely the
macro analyser. Extract a `Ma_utils` module under `analysis/technical/indicators/`
with a single `slope ~lookback ~threshold series → ma_direction * float` function.
See module comment in `stage.mli` for the proposed signature.

### `TODO(screener/segmentation-weights)` — Segmentation score weights hardcoded
`analysis/technical/trend/lib/segmentation.ml` has `trend_bonus_weight` (0.5) and `penalty_weight` (0.2) hardcoded in the scoring function. Move into `params` record for tuning.

### Stage classifier: incremental `classify_step` for simulation
`classify` recomputes the full MA series from all bars on each call — O(n) per
weekly step. For the simulation loop this is fine at current scale, but when
simulation performance becomes a bottleneck add a `classify_step` that takes the
previous `result` + one new bar and updates the MA incrementally in O(1). The
existing `classify` stays as the cold-start entry point. See module comment in
`stage.mli` for the proposed signature.

### Sector map key resolution
`Sector_map._build_sector_map` should be ticker-keyed (currently resolves to a
composite that's awkward for downstream consumers). Unblocks once the upstream
data-fetching work (originally #250–#253) lands or is closed. Source:
`dev/daily/2026-04-11.md`.
