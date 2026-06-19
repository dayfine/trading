# Status: short-side-strategy

## Last updated: 2026-06-19

## Status
IN_PROGRESS

## 2026-06-19 — reserved short sleeve (default-off) SHIPPED (branch `feat/short-sleeve`)

Addresses the short-funnel crowd-out diagnosed in
`dev/agent-memory/project_short_funnel_crowded_out.md`: over a 28y long-short
run the short cascade **offers** 1,662 candidate-slots but only 37 **enter**
(2%), with **0 short fills rejected** — shorts are crowded out at the entry walk
(`buy_candidates @ short_candidates` walked through one shared `remaining_cash`;
longs exhaust cash before the appended shorts are reached), not by signal rarity
or cash rejection.

**Mechanism:** new default-off config field
`Weinstein_strategy_config.short_sleeve_fraction : float [@sexp.default 0.0]`.
- `<= 0.0` (default): **bit-identical to baseline** — single combined entry walk
  over `buy_candidates @ short_candidates` against one `remaining_cash` seeded at
  `portfolio.cash`. All existing goldens/baselines replay unchanged
  (experiment-flag-discipline R1).
- `> 0.0`: partitions the per-Friday cash budget in
  `weinstein_strategy_screening.entries_from_candidates`. Reserves
  `short_budget = short_sleeve_fraction * portfolio_value` for a short-only walk;
  longs walk against `max 0 (portfolio.cash - short_budget)`. Two independent
  `remaining_cash` refs, **shared** `short_notional_acc` + `sector_exposure_acc`
  so the `max_short_notional_fraction` cap and per-sector cap still bind across
  both sides. Kept transitions re-emitted in original screener order (audit
  ordering preserved).

**Faithfulness (W1/W2):** portfolio-allocation / diversification dial —
Weinstein runs long+short simultaneously in bear markets
(weinstein-book-reference §Short Selling). Spine untouched: Stage-4-only short
entry, RS hard gate, Ch.11 cascade all unaffected; only the *capital available*
to already-screened shorts changes.

**Searchable axis (R2):** `short_sleeve_fraction` is a real top-level float
config field, so it routes through `Overlay_validator.apply_overrides` and
expands as `((flag short_sleeve_fraction) (values (0.0 0.1 0.2 0.3)))`.
Test `test_short_sleeve_fraction_axis_expands` pins this. NOT wired into any
default config/preset — stays default-off until a ledger ACCEPT
(experiment-flag-discipline R3 + promotion-confirmation grid).

**Tests** (`test_weinstein_strategy.ml` + `test_variant_matrix.ml`):
- `test_short_sleeve_default_crowds_out_shorts` — default 0.0: 3 longs exhaust
  $30k cash, 0 shorts enter (bit-identical crowd-out).
- `test_short_sleeve_active_admits_short` — 0.3 reserves $9k: short now enters
  (count 1 vs 0), longs reduced to 2 of 3 by the reserved budget.
- `test_short_sleeve_short_notional_cap_binds` — `max_short_notional_fraction=0`
  admits 0 shorts even with a funded sleeve.
- `test_short_sleeve_fraction_axis_expands` — variant-matrix axis validates.

**Files:** `weinstein_strategy_config.{ml,mli}`, `weinstein_strategy.mli`
(config mirror), `weinstein_strategy_screening.ml` (partition),
`test_weinstein_strategy.ml`, `test_variant_matrix.ml`.

**Next:** screen the sleeve fractions with the decision-grading lens (do the
now-numerous shorts add a real offsetting / DD-reducing leg?) → WF-CV → grid
before any default flip. `[non-blocking]`.

## 2026-06-16 — short-side ranking differentiation SHIPPED (PR #1612)

Resolved the GHA-queued ranking-collapse defect below. **Root cause** of the
2026-06-12 uniform score-50: the displayed `50.00` is the raw composed integer
score (`Float.of_int c.score` in `weekly_snapshot_generator.ml`), not a
normalized midpoint — the composition path *was* applying weights. The collapse
came from two factors acting together:

1. **RS contributed nothing.** `analysis.rs` was `None` for all 5 candidates —
   the freshly built weekly-picks universe lacked the ≥52 aligned weekly bars
   the RS 52-week MA needs (`Rs.analyze` returns `None` below `rs_ma_period`).
   `_rs_short_signal None = []`. They still pass `rs_blocks_short` (None is not
   blocked), so they entered scoring with zero RS weight.
2. **Virgin and Clean support were flattened.** `_support_signal` weighted
   `Virgin_territory` and `Clean` support **identically** at `w_clean_resistance`
   (15). So every candidate sharing Early-Stage4 (15) + Strong breakdown volume
   (20) + any-clean support (15) composed to exactly **50**, regardless of
   whether its below-support was Virgin (most explosive) or merely Clean.

The short cascade differentiates fine when RS is present (e2e COVID test pins
JPM 72 / KO 55 / CVX 52). The visible flattening the live data exposed is the
Virgin==Clean collapse.

**Fix (PR #1612, branch `feat/short-side-ranking-diff`):** added
`w_virgin_support : int option [@sexp.default None]` to `scoring_weights`
(default `Some 20`), used only in `_support_signal` for `Virgin_territory`,
falling back to `w_clean_resistance` when `None`. Virgin support now ranks
strictly above Clean — matching the `Support` module's documented ordering
("Virgin_territory … Most explosive downside potential"). Spreads the live
ranking: ADMA/ADT/AHCO (Virgin → 70) now outrank ABG/ABR (Clean → 65) instead
of all tying at 50.

- **Short path only** — `_resistance_signal` (long side) untouched; no long /
  Cell-E golden re-pinned. Full `dune build && dune runtest` (incl. the cached
  7-stock bear-window scenarios that emit shorts, and the magic-number linter)
  exits 0 unchanged.
- **Backward-compat / axis-able:** `None` falls back to `w_clean_resistance`, so
  omitting-field configs round-trip bit-identically; `[@sexp.default None]`
  keeps the field present in the serialized form so it stays a `Variant_matrix`
  axis (same pattern as `w_early_stage2`). Spine untouched (Stage-4-only shorts,
  Ch.11 RS hard gate unchanged).
- **Tests:** `test_support_below_scoring_order` flattening pin flipped from
  `virgin == clean` to `virgin > clean`;
  `test_short_ranking_spreads_with_rs_absent` (end-to-end `screen` repro of the
  live defect with `rs = None`, Virgin ranks first);
  `test_short_score_composition_is_additive` (exact composed score 90 pins the
  short cascade sums weights additively like the long cascade). 62/62 screener
  unit tests pass.
- **Note on snapshot-gen fixtures:** a synthetic-bar short fixture was attempted
  but a pure linear `Declining` series does not trigger the screener's Stage-3→4
  breakdown detection (long-standing limitation, see Follow-up #1) — it produced
  zero short candidates. The differentiation is instead pinned deterministically
  at the screener-`screen` seam (the exact path the generator calls), which is
  more robust than brittle synthetic short bars.

## 2026-06-15 PM — GHA-queued: differentiate short-side ranking `[non-blocking]` (ADDRESSED, see above)

**Owner: feat-weinstein. GHA-dispatchable (fixture-testable, no PIT warehouse
needed). `[non-blocking]`** — queued while the maintainer session is locked on a
long local backtest; nothing local depends on it landing this cycle, so the
orchestrator owns it end-to-end (no reclaim/poll).

**Observed defect (from the first live weekly picks, `dev/weekly-picks/58ff1e79/2026-06-12.md`):**
all 5 short candidates (ABG / ABR / ADMA / ADT / AHCO) came out **uniform grade
C / score 50.00** — the short-side ranking is collapsing to a constant and not
differentiating candidates. The long cascade differentiates fine; the short
cascade does not, despite the volume/support/RS signals already wired (Follow-up
#2 below).

**Task:** diagnose *why* every Stage-4 short candidate scores an identical 50,
then spread the ranking using the signals that already exist (breakdown-volume
strength, below-support cleanliness, RS bearishness). Likely the short
score-composition path isn't applying the cascade weights the way the long path
does, or is short-circuiting to a default. Pin with screener unit tests +
snapshot-generator fixture tests (the `weinstein/snapshot/gen` + screener test
dirs already have fixtures — **no warehouse needed**).

**Constraints (keep it safe):** ranking/display correctness only — **shorts are
not traded yet** (gated on margin Initiative B), so this changes no live trading
and no long-only Cell-E behavior. Do **not** touch the long entry path or re-pin
any long/Cell-E goldens. Do **not** edit `dev/status/_index.md` from the PR
(dispatcher reconciles the index post-merge). Standard 3-gate merge.

## 2026-06-15 — margin Phase 1 item 3 (`sizing_cash` plumbing) shipped

Closed the one deferred slice of issue #859 Phase 1. PR #1113's body
deferred "`Portfolio_risk.compute_position_size` plumbing for
`sizing_cash` (deferred to a follow-up for review focus)" — every other
Phase-1 + Phase-2 surface (margin_config, `Portfolio_margin`,
`Margin_runner`, maintenance force-cover, borrow fee, dedup #1274) was
already merged. This PR adds the missing follow-up:

- `Portfolio_risk.compute_position_size` gains optional `?sizing_cash`
  (branch `feat/margin-phase1-sizing-cash`). When omitted it defaults to
  `portfolio_value`, so the new spendable-cash cap
  (`floor(sizing_cash / entry_price)`) is `>=` both fractional caps and
  never binds — **bit-identical** to the prior code; full
  `dune build && dune runtest` (incl. all sp500 goldens) exits 0
  unchanged. Margin-aware callers pass `Portfolio.available_cash`
  (current_cash net of locked short collateral) to fix the Stance-A
  long-sizing inflation (`dev/notes/short-cash-accounting-design-2026-05-01.md`).
- Tests: omitted == explicit-`portfolio_value` bit-equality; cap inert at
  default; cap binds when spendable cash is tight; the plan §1.1 worked
  example ($10k cash, short 100@$50 → $7,500 available → long capped at
  150 vs un-netted 200 shares); non-binding leaves %-caps intact.
- **Strategy/simulator wiring of `available_cash` into the entry path is
  NOT in this PR** — that flips sizing and re-pins goldens, which belongs
  to the Phase-5 long-short re-pin step. The seam is now *ready* for it.
- A1 watch-list: modifies `weinstein/portfolio_risk/` (core risk module),
  strategy-agnostic — `sizing_cash` is a generic spendable-cash cap, no
  Weinstein logic. Default-off (`= portfolio_value`) is the load-bearing
  mitigation.

## 2026-06-13 — `enable_short_side=false` suppression made honest + pinned

Resolved the trade-forensics G5 question ("shorts present in a 'long'
baseline"): **the production multi-symbol path was already CLEAN** — the
`enable_short_side=false` gate in `weinstein_strategy_screening.screen_universe`
correctly dropped all short candidates before the entry walk. The shorts seen in
the 2026-06-12 forensics run came from an ad-hoc `cell-e-top3000-2011-15y`
scenario that was not committed; the committed canonical Cell-E configs all set
`((enable_short_side false))` and the deep-merge override applies it faithfully
(`Overlay_validator.apply_overrides`). No leak.

Hardening shipped (correctness, no new mechanism, spine untouched):

- Extracted the previously-inline `if enable_short_side then … else …` candidate
  assembly into a named, pure, unit-tested function `Short_side_gate.combine`
  (new micro-lib `weinstein_trading.short_side_gate`, sibling to
  `short_min_price_gate`). `screen_universe` now calls it — bit-identical
  behaviour, but the long-only contract is no longer an unpinned inline guard a
  refactor could silently break.
- Regression tests (`test_short_side_gate.ml`): `enable_short_side=false` →
  zero short candidates (and end-to-end zero Short transitions through
  `entries_from_candidates` on the bear-window fixture that otherwise emits
  shorts); `=true` admits shorts after longs and applies the `short_min_price`
  floor — pins that a THM-class $0.69 short is dropped when `short_min_price=17.0`.
- No golden re-pin needed: default `enable_short_side=true` path is unchanged
  (combine with `short_min_price=0.0` is the prior concat); the `false` path was
  already suppressing shorts. `dune build && dune runtest` exits 0.

## 2026-06-12 — `short_min_price` short-entry gate (default-off axis)

Added a no-op-default `short_min_price : float [@sexp.default 0.0]` config
field on `Weinstein_strategy.config` plus a pure gate
(`Short_min_price_gate.filter`) that drops short candidates whose
`Screener.scored_candidate.suggested_entry` is below the threshold, wired at
the short-candidate seam in `weinstein_strategy_screening.ml`. Encodes the
researched sub-$17 economic-margin floor on shorts
(`dev/notes/long-short-margin-mechanics-2026-06-12.md`) as a searchable
`Variant_matrix` axis.

- **R1 default-off:** threshold `0.0` short-circuits the gate to the identity,
  so every golden/baseline decodes (via `[@sexp.default 0.0]`) and replays
  bit-equal. Full `dune build && dune runtest` exits 0 (all goldens/snapshots
  unchanged). `enable_short_side` default unchanged (`true`).
- **R2 axis-able (verified):** `short_min_price` is a top-level float field, so
  `Variant_matrix` resolves it by sexp name with no `Overlay_validator` change
  (same mechanism as `stage3_exit_margin_pct`). Axis test added to
  `test_variant_matrix.ml` (`short_min_price float axis expands`).
- **R3:** not wired into any default config or preset (stays default-off).
- The gate lives in its own micro-lib
  (`weinstein_trading.short_min_price_gate`) to keep the strategy coordinator
  module under the file-length cap and give tests a direct dependency.
- Tests: `test_short_min_price_gate.ml` (no-op at 0.0, drop-below/retain-above
  at 15.0, boundary-inclusive, gate untouches the long list).
- Branch `feat/short-side-min-price`.

## Interface stable
YES

Issue #859 margin work: **Phase 1 + Phase 2 both MERGED 2026-05-16.**
Phase 1 (margin_config + Portfolio extensions + Portfolio_margin
module) landed via #1113 + #1115 (file-length fix-forward). Phase 2
(simulator wiring — daily borrow fee accrual + maintenance-margin
force-cover) merged as #1119. Both phases gate behind
`Margin_config.enabled = false` so prior MERGED baselines stay bit-equal
until a scenario opts in.

**Phase 3 (Stage A bear-window validation) executed 2026-05-23.** Sweep
ran 4 bear windows × 2 configs (margin off / on): 2000-2002 dot-com +
2008 GFC (broad-1000-30y) + 2020-Q1 COVID + 2022 modern bear
(sp500-2010-01-01). Results, scenarios, and recommendation:
`dev/notes/margin-phase3-bear-windows-2026-05-23.md`. Scenarios:
`dev/experiments/margin-phase3-bear-windows-2026-05-23/`. Headline
verdicts:

1. **Effect of flipping the margin flag on existing metrics is
   negligible** in the three clean windows (Sharpe / MaxDD / return
   deltas in the 4th decimal place; zero margin_call exits fired).
2. **GFC is the one bear-window where short-side has positive edge**:
   Sharpe 1.08, Calmar 1.43, 50% short win rate (vs 19% in dot-com).
   The other bears are flat-to-losing. Plan §2.2 acceptance gate
   FAILS at "Sharpe > 0 in ≥ 2 of 3 windows" (only GFC qualifies).
3. **Phase 2 has a real transition bug** — `margin_call`
   `TriggerExit` is rejected when the strategy's stop-loss runner
   already queued a `TriggerExit` for the same position on the same
   tick. Surfaced reproducibly in dot-com 2000-2002 within ~30 sec of
   simulator start. Fix sketch: dedup margin-call candidates against
   pending strategy transitions in `Margin_runner.tick`.
4. **Recommendation**: keep `margin_config.enabled = false` default
   for now; file Phase-2 fix issue; gate Phase 5 (long-short re-pin)
   on the fix.

**Next short-side step: ~~fix the Phase 2 margin_call transition bug~~**
**(Finding A) — ALREADY FIXED.** Reconciled by lead-orchestrator
2026-06-14: PR #1274 (`8636e636 fix(margin): dedup same-tick TriggerExit
across margin/stop/strategy (closes #1266)`) landed
`Margin_runner.dedup_strategy_exits_for_margin`, wired into
`Margin_runner.tick` (margin wins by priority, strategy TriggerExit
dropped), documented in `margin_runner.mli`, tested in
`test_margin_runner.ml`. This §2026-05-23 "next step" claim was stale.
Remaining open work: re-run the dot-com margin-on sweep cell to populate
the empty cell (data-gated), then Phase 4-5 (long-short combined re-pin).

**Earlier MERGED note retained below.**

Track wrapped on the MVP + initial follow-up axis. New follow-ups surfaced overnight in `dev/notes/force-liq-cascade-findings-2026-05-01.md` (G14 split-adjustment on Position.t Holding state) and `dev/notes/g14-deep-dive-2026-05-01.md` (Option 1 fix recommendation). G15 (short-side risk control) also filed. Both are `feat-weinstein` — strategy + position state machine; current `feat-weinstein` scope is closed. See §Follow-ups below for the new items.

All four follow-ups landed via PRs #617 (bear-window regression test),
#623 (live-cascade Bearish macro plumbing fix), #630 (full short
screener cascade), and #631 (Ch.11 spot-check on real data). MVP
originally landed via #420 on 2026-04-19. Track wraps; future
short-side work is performance-driven (e.g., revisiting the cascade
parameters once the trade-audit track ships) rather than feature
build-out.

**2026-04-30 (evening) update**: shorts now live in the sp500
regression scenario. After G1-G5 + G7-G9 closed (PRs #689-#710),
`goldens-sp500/sp500-2019-2023.sexp` has the `enable_short_side =
false` override removed and ranges re-pinned to the with-shorts
baseline (32 trades / -0.01% / 0 force-liquidations / 43d avg holding
/ 5.8% MaxDD). See `dev/notes/sp500-shortside-reenabled-2026-04-30.md`.
The 5-year sp500 scenario is now the standing regression gate for
short-side correctness; the 4 short trades the strategy emits during
the 2019 Bearish-macro window all exit via stop_loss with the correct
sign convention.

**Historical: live-cascade bug (resolved by #623)**: real-data SP500
verification (PR #612) revealed 0 short trades + 37 long entries in
2022 bear despite `Macro.analyze` correctly returning Bearish at the
unit level. Root cause: `Weinstein_strategy.make` loaded composer-AD
bars covering ~1973 to April 2026 and passed them to every Friday's
`_on_market_close` without filtering by `current_date`. Future-leaking
synthetic A-D disagreed with the real 2022 Stage 4 GSPC index,
flipping the macro composite from Bearish to Neutral/Bullish. Fix:
`Macro_inputs.ad_bars_at_or_before` called in `_run_screen`.

Pinned by `trading/trading/weinstein/strategy/test/test_macro_panel_callbacks_real_data.ml`:
- Real 2022 GSPC + empty AD bars + panel-callbacks → Bearish (mirrors
  `test_macro_2022_bear_market` in macro/test/test_macro_e2e.ml).
- Real 2022 GSPC + synthetic AD bars filtered to `<= 2022-10-14`
  → Bearish, confidence < 0.5 (the fix's contract).
- Real 2022 GSPC + synthetic AD bars extending through 2026 unfiltered
  → non-Bearish (the bug, double-pinned to catch regressions from
  either direction).

Run-2 (2026-04-27): the second commit on `feat/short-side-bear-window-fix-cascade-plumbing`
swaps `Ad_bars.load`/`Ad_bars_aggregation.daily_to_weekly` in the test for
a deterministic two-phase synthetic series so the contract pins on CI runs
where `TRADING_DATA_DIR=trading/test_data` ships only Unicorn breadth
2017-2020 (no synthetic CSV). Same commit pulls the parent commit's
`weinstein_strategy.ml` back to the 500-line `@large-module` ceiling and
splits `Macro_inputs.ad_bars_at_or_before` so neither helper exceeds the
nesting limit.

## Interface stable
YES

`Screener.scored_candidate.side` and public `Weinstein_strategy.entries_from_candidates` signature landed in main.

## Merged PR
- #420 (feat/short-side-strategy) — MVP vertical slice: side through screener → strategy → order_generator, with Ch.11 RS hard gate and unit tests for Short + Long entry transitions.

## Blocked on
- No hard interface block. Practical block: the three § Follow-ups
  need broad-universe Tiered-loader backtest scale to be feasible.
  Tracked in `backtest-scale.md` § Follow-up "Reciprocal short-side
  practical block".

## Goal

Wire short-side entries into `Weinstein_strategy` so the simulation emits short positions in bearish macro regimes. The end-to-end infra (portfolio signed quantities, orders Buy/Sell, simulator order_generator with `_entry_order_side`/`_exit_order_side` for Short, `Weinstein_stops` parameterised by `side`) already supports shorts. Gap is isolated to the strategy entry path.

## Completed (MVP slice)

- Plan committed: `dev/plans/short-side-strategy-2026-04-18.md`.
- `Screener.scored_candidate` carries `side : Trading_base.Types.position_side`. Populated in `_build_candidate` based on whether the cascade path is buy or short. Ch.11 hard RS gate blocks shorts when RS trend is `Positive_rising`, `Positive_flat`, or `Bullish_crossover` (never short a stock with positive/rising RS).
- `Weinstein_strategy._make_entry_transition` parameterised by `cand.side`. Threads through to `Weinstein_stops.compute_initial_stop_with_floor` and `Position.CreateEntering { side; _ }`. Sizing adapter (`_normalised_entry_stop_for_sizing`) uses `Float.max`/`min` so the `entry - stop` diff is positive for both sides.
- `Weinstein_strategy.entries_from_candidates` is now public (was `_entries_from_candidates`). Full docstring covers candidate side threading, sizing, stop initialisation, and cash-tracking behaviour.
- `Bearish` macro branch now emits shorts: `_screen_universe` concatenates `buy_candidates @ short_candidates`; the earlier `Bearish → []` short-circuit in `_run_screen` is removed.
- Screener tests: `test_buy_candidates_are_long`, `test_short_candidates_are_short`, `test_positive_rs_blocks_short` — all 18 screener tests pass.
- Strategy tests: `test_entries_from_candidates_emits_short` + `test_entries_from_candidates_emits_long` direct unit tests that inject a synthetic `scored_candidate` and assert `CreateEntering.side` matches — 15 total strategy tests pass.
- `dune build && dune runtest trading/weinstein/strategy/test --force` green; `dune build @fmt` applied.

## Scope

1. ~~**Screener candidate carries side.**~~ Done.
2. ~~**`_make_entry_transition` parameterised by side.**~~ Done.
3. ~~**Macro branch for shorts.**~~ Done (Bearish → short candidates emitted).
4. ~~**Screener short-side rules.**~~ Ch.11 hard RS gate done. Mirror of long-side Stage-2 breakout rules (Stage 4 breakdown, resistance ceiling, negative RS as positive signal rather than just hard gate) is a follow-up.
5. ~~**Position sizing for shorts.**~~ Done (sizing adapter handles signed entry/stop).
6. **Backtest regression pins** — **follow-up**. Bear-market-window scenario in `test_weinstein_backtest.ml` exercising short entries. Deferred — the integration smoke test proved harder to set up than expected (synthetic Declining pattern did not trigger a Stage 3 → Stage 4 transition through accumulated `prior_stage` under default screener `min_grade = C`); pivoted to direct unit tests for the MVP.

## Not in scope

- Buy-to-cover trailing stop tuning beyond what `Weinstein_stops` already does (resistance ceiling → rally stop).
- Margin / borrow cost modelling — separate simulation track if it matters.
- Hard-to-borrow filtering.

## Follow-ups

1. ~~**Bear-window backtest regression** (item 6 above)~~ — landed in PR #617 (`feat/short-side-bear-window-regression`). New file `trading/trading/weinstein/strategy/test/test_short_side_bear_window.ml` pins both directions of the bear-window contract through the public `Screener.screen` -> `Weinstein_strategy.entries_from_candidates` seam (synthetic-mocked candidates, not full simulator). Pivoted from the `test_weinstein_backtest.ml` end-to-end approach because the synthetic Declining pattern still does not trigger a clean Stage 3 → Stage 4 transition under the default screener — the right primitive seam is the screener -> entries_from_candidates pipeline, which catches regressions deterministically. Live-cascade gap (PR #612 — 0 short trades and 37 long entries opened in 2022 bear on real SP500 data) remains; diagnosis is upstream of this seam, in `_run_screen`'s `macro_callbacks` construction. Tracked separately.
2. ~~**Full short screener cascade**~~ — DONE via `feat/short-side-cascade-rules` (this PR). Adds three weighted signals to the short cascade: (a) `_volume_short_signal` boosts Strong / Adequate breakdown volume by `w_strong_volume` / `w_adequate_volume`, mirroring the long-side breakout-volume signal; (b) new `Support` module under `analysis/weinstein/support/` grades below-breakdown clean space (Virgin / Clean / Moderate_resistance / Heavy_resistance) and `Screener._support_signal` weights Virgin and Clean by `w_clean_resistance`, Moderate by half; (c) the Ch.11 hard RS gate stays load-bearing, with `_rs_short_signal` already weighting `Bearish_crossover > Negative_declining > Negative_improving` from prior MVP. Stock_analysis.t now carries `support : Support.result option` and `breakdown_price : float option`. Pinned values updated: VOL_STRONG synthetic 70→85 (+Clean), e2e bear-window JPM 65→72 / CVX 45→52 (+Moderate support), backtest 6-year n_buys/n_sells 36/33→39/36 (+3 trades, symbols unchanged). 22 screener unit tests + 8 new Support tests + 5 e2e tests all pass.
3. ~~**Ch.11 spot-check**~~ — DONE via `feat/short-side-ch11-spotcheck`. Two new tests in `analysis/weinstein/screener/test/test_screener_e2e.ml` pin the Stage 4 + negative RS + Bearish macro combination on real 2022 bear data (7-stock universe, `Test_data_loader` cached bars): `test_ch11_spotcheck_2022_bear` pins MSFT (Stage 4 + RS bearish crossover, score 45, entry $351.42) and JPM (Stage 4 + Adequate breakdown volume + RS negative & declining, score 45, entry $173.82) at the 2022-07-15 mid-bear cut; `test_ch11_no_shorts_under_bullish_macro_2022` pins the negation (Bullish macro emits zero shorts even with Stage 4 stocks present). The per-Ch.11-pattern → test mapping is in `dev/notes/short-side-ch11-spotcheck-2026-04-27.md`. Universe limitation noted: known archetypal 2022 Stage 4 names (CVNA, COIN, PTON, AFRM) not in test fixture; universe-level expansion would belong to a separate follow-up (extend `Scenario.expected` with `total_short_trades` metric).
4. ~~**Live-cascade Bearish macro plumbing** (new, ex-#612)~~ — fixed
   in `feat/short-side-bear-window-fix-cascade-plumbing`. Root cause was
   upstream of `Panel_callbacks.macro_callbacks_of_weekly_views`: the
   composer-loaded AD breadth series was time-unfiltered, so the macro
   analyzer's `get_cumulative_ad ~week_offset:0` returned the cumulative
   as of the last loaded synthetic bar (~April 2026), date-misaligned by
   ~3 years against the index close at the simulator's current 2022 tick.
   Fix: `Macro_inputs.ad_bars_at_or_before` filters AD bars to dates
   `<= current_date` inside `_run_screen` before they reach the panel
   callbacks. Pinned by `test_macro_panel_callbacks_real_data.ml`.

5. **Verify SP500 5y backtest emits non-zero shorts in 2022** — follow-up
   to (4): rerun the full SP500 2019-2023 scenario with the fix to
   confirm the symptom (0 shorts, 37 long entries in 2022) is resolved.
   Out of scope for the fix PR per cost (~2.5 min wall, full backtest);
   covered by the next nightly Tier-3 perf run.

6. **G14 — split-adjustment on Position.t Holding state** (filed 2026-05-01,
   merged 2026-05-01 via PR #736). Fixed both interlocked bugs together
   per Option 1 (raw close-price space + lookback truncation):
   - **Bug A**: `_scan_max_high_callback` / `_scan_min_low_callback` in
     `analysis/weinstein/stock_analysis/lib/stock_analysis.ml` now truncate
     at the most recent split boundary using a `_no_split_between`
     guard keyed off the per-bar `adjusted_close / close_price` factor
     (threshold 0.20 — distinguishes splits from dividend drift).
   - **Bug B**: `entry_audit_capture._effective_entry_price` reads the
     most recent close from `bar_reader` and threads it through sizing,
     stop computation, the `CreateEntering` transition, and audit-row
     dollar fields. The audit row's `candidate.suggested_entry` is
     preserved verbatim so consumers can reconcile screener intent vs
     realised entry.
   - **Result on sp500-2019-2023-long-only**: force-liqs 6 → 0;
     return +65.0% → +21.6%; MaxDD 31.8% → 43.0% (the shifts reflect
     underlying short-side risk previously masked by inflated
     entry_price values; G15 is the follow-up).
   - **Acceptance tests**: `test_breakout_truncates_at_split_boundary`,
     `test_breakdown_truncates_at_split_boundary`,
     `test_no_split_no_truncation` (stock_analysis);
     `test_effective_entry_overrides_suggested_entry`,
     `test_empty_bar_reader_falls_back_to_suggested_entry`
     (entry_audit_capture).
   - 2026-05-02 redispatch (this session) was a no-op — verified the
     fix is on `origin/main` and all acceptance criteria from the
     dispatch prompt are met by code already merged. No PR opened.
     See `dev/notes/g14-deep-dive-2026-05-01.md` for the full
     root-cause writeup.

7. **G15 — short-side risk control** (filed 2026-05-01, `feat-weinstein`
   scope). With G12 (#725) + G13 (#726) eliminating the spurious
   `Portfolio_floor` cascade, sp500-2019-2023 portfolio goes negative
   (-$175K minimum 2021-11-04, -66.7% return, 117.5% MaxDD). The phantom
   floor was acting as an unintended risk control. Real candidates:
   (a) max total short notional as fraction of portfolio; (b) tighter
   per-position short stop-loss threshold (Weinstein recommends tighter
   stops on shorts than longs); (c) honest portfolio-floor based on real
   peak observations (now correct post-G13). Combination of (a) + (b)
   likely needed. See `dev/notes/force-liq-cascade-findings-2026-05-01.md`
   §G15. Owner: `feat-weinstein` — same scope-extension prereq as G14.

8. **#872 — Stage-3 force-exit detector for capital recycling on the
   long side** (filed 2026-05-06, PR #902, `feat-weinstein` scope).
   Implements an opt-in mechanism that liberates portfolio cash from
   mature long-runners whose 30-week MA has flattened. Empirical
   motivation: the 15y SP500 baseline locks ~$1M in 18 long-runners
   opened in Q1 2010 for the entire 16-year window; cascade idles
   90.7% of Fridays with `Insufficient_cash` (per
   `dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md`).
   - **Pure detector**: `analysis/weinstein/stage3_force_exit/` —
     reuses `Stage.classify` authority; emits `Force_exit` after K=2
     consecutive Friday Stage-3 reads on a held long position
     (configurable). 16 unit tests pinning hysteresis and reset
     semantics.
   - **Strategy wiring**: new
     `Stage3_force_exit_runner` between `Stops_runner.update` and
     `Force_liquidation_runner.update`. Friday cadence; long-only;
     skips positions already exiting via stops on the same tick.
     9 unit tests pinning the wiring contract.
   - **New `exit_reason` variant**: `Position.Stage3ForceExit
     { weeks_in_stage3 : int }` — separate per-trade attribution in
     `trades.csv` as `stage3_force_exit`.
   - **Opt-in via** `enable_stage3_force_exit : bool` config field
     (default `false`). 5y baseline `sp500-2019-2023` PASSes scenario_runner
     unchanged with default off (53.4% / 73 trades, inside pinned
     [45.0-72.0%, 70-95 trades] band).
   - Re-pinning under `enable=true` is a separate post-merge step per
     `dev/notes/capital-recycling-framing-2026-05-06.md` §3.
   - Reserved knob `stage3_reentry_cooldown_weeks` defaults to 0 and
     is currently unwired — placeholder for future RS-conditioned
     tuning.

10. **#859 — Margin accounting Phase 1** (filed 2026-05-13 via
    `dev/plans/short-side-margin-2026-05-13.md`; PR #1113 opened
    2026-05-16). First of 5 PRs implementing Reg-T-style short-side
    margin accounting. Adds `Margin_config.t` (enabled/initial_margin_pct
    /maintenance_margin_pct/short_borrow_fee_annual_pct, default OFF) +
    `Portfolio.locked_collateral` + `Portfolio.accrued_borrow_fee` +
    new APIs `available_cash`, `apply_single_trade_with_margin`,
    `apply_trades_with_margin`, `accrue_daily_borrow_fee`,
    `check_maintenance_margin`, `sum_short_notional`. With the flag
    off, all margin-aware APIs are bit-equal pass-throughs of the
    legacy entry points — long-only goldens stay pinned. 21 new tests
    pin flag-off bit-equality, initial collateral lock, maintenance
    threshold boundaries (exactly-at-threshold, 1bp past), partial
    cover proportional release, multi-year borrow fee math, and
    sorted-output of flagged shorts. **Out of scope** in this PR:
    `Portfolio_risk.compute_position_size` plumbing for `sizing_cash`
    (deferred to a follow-up for review focus); simulator/strategy
    wiring of the daily borrow-fee tick + maintenance-margin
    force-cover (Phase 2 of the plan); `Weinstein_strategy_config`
    flag plumbing (Phase 2). A1 watch-list note: change modifies
    `trading/trading/portfolio/` but is strategy-agnostic — margin is
    a broker-side concept that applies identically to any strategy
    opening shorts. Default-off invariant is the load-bearing
    mitigation.

11. **#887 — Laggard rotation detector for capital recycling on the
   long side** (filed 2026-05-06, PR #909, `feat-weinstein` scope).
   Implements Weinstein Ch.4 §portfolio sizing rotation rule (book-ref
   §5.6): "if it's lagging badly and acting poorly, lighten up on that
   position even if the sell-stop isn't hit. Move the proceeds into a
   new Stage 2 stock with greater promise." Distinct from #872 — fires
   mid-Stage-2 on weak RS-vs-benchmark behaviour alone, before the
   30-week MA flattens. Complementary mechanism per the framing-note
   table (Stage-2-weak-RS region in the position-state matrix).
   - **Pure detector**: `analysis/weinstein/laggard_rotation/` —
     observes position 13-week return vs benchmark 13-week return,
     emits `Laggard_exit` after K=4 consecutive Friday negative-RS
     reads (configurable). 19 unit tests pinning hysteresis edges
     (K=1/4/6/0/negative defensive), tied-RS reset, whipsaw reset,
     bear-market both-negative comparison, per-symbol wrapper isolation.
   - **Strategy wiring**: new `Laggard_rotation_runner` between
     `Stage3_force_exit_runner.update` and the entry walk. Friday
     cadence; long-only; skips positions already exiting via stops or
     Stage-3 on the same tick (skip-list = `stop_exited_ids ∪
     stage3_exited_ids`). 11 unit tests pinning the wiring contract.
   - **Generic `StrategySignal` exit_reason**: emitted with
     `label = "laggard_rotation"; detail = Some "rs_13w_neg_weeks=N"`
     — no new variant added (per framing-note Q4 + PR #907 plumbing).
   - **Opt-in via** `enable_laggard_rotation : bool` config field
     (default `false`). 5y baseline `sp500-2019-2023` runs path-
     equivalent at default OFF (runner is a no-op without code-path
     entry); pinned baseline 58.34% / 81 trades preserved.
   - Reserved knob `laggard_reentry_cooldown_weeks` defaults to 0 and
     is currently unwired — placeholder for future tuning.
   - Re-pinning under `enable=true` is a separate post-merge step per
     `dev/notes/capital-recycling-framing-2026-05-06.md` §3.

## References

- `docs/design/weinstein-book-reference.md` Ch. 11 — bear-market shorting rules (never short Stage 2; only Stage 4 with negative RS + bearish macro).
- `docs/design/eng-design-3-portfolio-stops.md:152` — trade-log schema already has `` `Short | `Cover `` actions.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` — `_make_entry_transition` now takes `cand.side`; `_screen_universe` concatenates buy + short candidates.
- `trading/trading/simulation/lib/order_generator.ml:9-18` — `_entry_order_side` / `_exit_order_side` already handle Short.
- `trading/trading/portfolio/lib/types.mli:20` — signed position quantities (long/short).
- `trading/trading/weinstein/stops/lib/support_floor.mli` — `find_recent_level ~side` handles both sides (merged via support-floor-stops PR A #382).
- `dev/plans/short-side-strategy-2026-04-18.md` — plan.

## Ownership
`feat-weinstein` agent (dispatched 2026-04-18).

## QC
overall_qc: APPROVED (merged)
structural_qc: APPROVED
behavioral_qc: APPROVED

Review artifacts (run-4): side parameterisation clean through screener → strategy → order_generator; no hardcoded Long remaining. Ch.11 hard RS gate tested via `test_positive_rs_blocks_short`.
