Reviewed SHA: a1443930d7ff55e0814abe8a733df1d3b32c0a4e

# Behavioral QC — feat/force-liquidation (PR #695)
Date: 2026-04-29
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | FAIL | See below — most `Force_liquidation.*` claims are pinned; several `Force_liquidation_runner.*` and all `Force_liquidation_log.*` claims are unpinned. |
| CP2 | Each claim in PR body / commit message has a corresponding test | FAIL | "ForceLiquidation audit record visible in trades.csv with distinct exit_trigger" claim is unpinned — `force_liquidation_position` / `force_liquidation_portfolio` strings are produced only in `result_writer.ml` and not asserted by any test. |
| CP3 | Pass-through / identity tests pin identity, not just size_is | PASS | The runner integration test `test_portfolio_floor_trigger_closes_all` uses bare `size_is 2` for both transitions and captured events without per-element reason assertions; however, the equivalent claim is pinned at the unit level by `test_portfolio_floor_fires_after_drawdown` (asserts `reason = Portfolio_floor` per element via `elements_are`). The composition is acceptable — no claim is left to size-only. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | Five explicit guards are unpinned: (i) zero/negative cost-basis is silently dropped; (ii) `_position_input_of_holding` returns None for non-Holding positions; (iii) `_position_input_of_holding` returns None for symbols without a price feed; (iv) `_positions_minus_exited` filters positions already exited by `Stops_runner.update` (avoid double-exit); (v) halt-and-resume on macro flip via `_maybe_reset_halt`. |

### CP1 detail (claim → test)

`Force_liquidation` (mli):
- `default_config = { 0.5; 0.4 }` → `test_default_config_values` PASS
- `Peak_tracker.observe` raises monotonically → `test_peak_tracker_observe_monotone` PASS
- `Peak_tracker.halt_state / mark_halted / reset` semantics → `test_peak_tracker_halt_state` PASS
- `unrealized_pnl` long/short asymmetry → `test_pnl_long_winner` / `test_pnl_long_loser` / `test_pnl_short_winner` / `test_pnl_short_loser` PASS
- `check`: per-position trigger fires when `loss_fraction > max_unrealized_loss_fraction` → `test_per_position_long_fires_on_exceed` / `test_per_position_short_fires_on_exceed` / `test_per_position_long_no_fire_under_threshold` / `test_per_position_does_not_fire_on_winner` / `test_per_position_custom_threshold` PASS
- `check`: portfolio-floor trigger fires when `value < peak * fraction` → `test_portfolio_floor_fires_after_drawdown` / `test_portfolio_floor_no_fire_under_threshold` PASS
- `check`: peak-zero on first observation does not fire → `test_portfolio_floor_first_observation_no_fire` PASS
- `check`: portfolio-floor takes precedence (no per-position events emitted on the same tick) → `test_portfolio_floor_precedence` PASS
- `check`: side-effect — `mark_halted` flips on portfolio-floor fire → `test_portfolio_floor_marks_halted` PASS

`Force_liquidation_runner` (mli):
- `update`: builds inputs from Holding positions and emits TriggerExit transitions → `test_per_position_trigger_emits_exit` PASS
- `update`: routes events through `audit_recorder.record_force_liquidation` → asserted via captured ref counter PASS
- `update`: short positions handled correctly → `test_short_position_loss_fires` PASS
- `update`: empty positions → no events → `test_no_positions_no_events` PASS
- `update`: builds `position_input` only for Holding positions (returns None for Entering/Exiting/Closed) — **not pinned**
- `update`: `_portfolio_value` matches `Portfolio_view.portfolio_value` semantics — **not pinned** (only the integration in `test_portfolio_floor_trigger_closes_all` exercises it)

`Force_liquidation_log` (mli):
- `events` returns events sorted by `(date, position_id)` ascending — **not pinned**
- `count` returns `List.length (events t)` — **not pinned**
- `save_sexp` is a no-op when collector is empty — **not pinned**
- `load_sexp` is the inverse of `save_sexp` — **not pinned**

### CP2 detail (PR body claim → test)

| PR body claim | Test |
|---|---|
| Per-position fires when unrealized loss > 50% of cost basis (default) | `test_per_position_long_fires_on_exceed` (60% loss fires; threshold 50% PASS) |
| Per-position does NOT fire at 40% loss | `test_per_position_long_no_fire_under_threshold` PASS |
| Portfolio fires when value drops below 40% of peak | `test_portfolio_floor_fires_after_drawdown` (peak 1M → 350K = 65% drawdown fires) PASS |
| Portfolio does NOT fire at 50% drawdown (peak 1M → 500K) | `test_portfolio_floor_no_fire_under_threshold` PASS |
| Per-scenario count visible in release report | `test_render_flags_force_liquidations` (asserts `Force-liq count` row + `:rotating_light:` glyph for non-zero count) PASS |
| ForceLiquidation event persisted as `force_liquidations.sexp` | **not pinned** — `Force_liquidation_log.save_sexp` has no test |
| `trades.csv` `exit_trigger` overridden to `force_liquidation_position` / `force_liquidation_portfolio` | **FAIL** — `_force_liq_label` and `_build_force_liq_index` in `result_writer.ml` are produced only at runtime and never asserted by any test. The labels exist solely as string literals in the implementation file. |
| Halted state suppresses new entries until macro flips off Bearish | **not pinned** — neither the entry-block in `_on_market_close` (`if halted ... then []`) nor `_maybe_reset_halt` is exercised by any test |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Structural QC marked A1 = NA. PR adds new modules under `weinstein/portfolio_risk/lib` and `weinstein/strategy/lib`; touches `trading/portfolio` zero times; reads `unrealized_pnl_per_position` only via the existing G3 surface. The `Force_liquidation` module itself depends only on `Trading_base.Types.position_side` and is purely strategy-agnostic logic (per-position threshold + portfolio-of-peak floor). |
| S1–S4 | Stage definitions | NA | Force-liquidation is a portfolio-level guardrail; Stage classifier untouched. |
| S5 | Buy criteria: Stage 2 entry | NA | Entry side untouched. |
| S6 | No buy signals in Stage 1/3/4 | NA | Entry side untouched. |
| L1 | Initial stop below base | NA | Stops_runner unchanged; force-liquidation runs AFTER stops as defense in depth. |
| L2 | Trailing stop never lowered | NA | Stops_runner unchanged. |
| L3 | Stop triggers on weekly close | NA | Stops_runner unchanged. The force-liquidation policy operates on daily close (every `_on_market_close` tick) — but this is an explicit design choice; the PR is layered on top of stops, not replacing them. |
| L4 | Stop state machine transitions | NA | Stops_runner state machine unchanged. The new `Peak_tracker` is a separate state machine with its own (Active, Halted) variants — pinned by `test_peak_tracker_halt_state`. |
| C1 | Screener cascade order | NA | Screener untouched. |
| C2 | Bearish macro blocks all buys | NA | Screener untouched. The new entry-block (`if halted`) is a separate gate that runs BEFORE the cascade. |
| C3 | Sector RS vs. market | NA | Sector logic untouched. |
| T1 | Tests cover all 4 stage transitions | NA | Stage logic untouched. |
| T2 | Bearish macro → zero buy candidates test | NA | Macro gate untouched. |
| T3 | Stop-loss tests verify trailing | NA | Stops_runner untouched. |
| T4 | Tests assert domain outcomes | PASS | Tests pin `reason = Per_position` / `Portfolio_floor`, exact `unrealized_pnl_pct` values (e.g. `-0.6` for the canonical 60%-loss case), `halt_state = Halted`, and concrete sexp round-trip equality. Domain outcomes — not just "no error" — are asserted throughout `test_force_liquidation.ml`. |

## Critical-question disposition

**Q1 — Default thresholds (0.5 / 0.4) are sane**: PASS on motivation. The 94% MaxDD evidence cited in `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md` motivates the 40% portfolio-of-peak floor; the 50% per-position threshold is a defense-in-depth backstop for trades that escape the trailing stop entirely. Both are configurable via `Portfolio_risk.config.force_liquidation` (`default_config` pinned). The `0.4` floor would force-close at $0.4 × peak — a 60% drawdown. Reasonable as a hard guardrail. The thresholds carry no domain-specific assumption tying them to Weinstein.

**Q2 — Strategy-agnostic**: PASS. `Force_liquidation` itself reads only generic position-side (Long/Short), entry/current price, and quantity. No Weinstein-specific notion (no Stage, Macro, Screener, RS, etc. anywhere in the module). The runner is wired into `Weinstein_strategy._on_market_close` as the integration point but the policy itself could be lifted to any strategy. The placement under `weinstein/portfolio_risk/` is reasonable for now since `Portfolio_risk` is already a Weinstein-namespaced module — promoting it is a future call.

**Q3 — Halt-and-resume semantics**: **PARTIAL FAIL** on test coverage. The implementation IS macro-aware (not time-based): `_maybe_reset_halt` reads `prior_macro` and resets the halt only when macro is `Bullish | Neutral`. Critical sequencing detail in `_on_market_close`:
```
1. force_liquidation runs (may flip halt → Halted)
2. screen_universe runs ONLY IF (not halted && is_screening_day)
   — _run_screen updates prior_macro
3. _maybe_reset_halt runs (consults the JUST-UPDATED prior_macro)
```
This is correct: when macro flips off Bearish, the next Friday will (a) NOT run the screener (still halted), (b) BUT also will NOT reset the halt because `_maybe_reset_halt` is gated on `not halted && is_screening_day`.

**Bug?** Re-reading: when `halted = true`, line 462-468 sets `entry_transitions = []` and **never invokes `_run_screen`**, so `prior_macro` is never updated. Then line 472-473: `if (not halted) && _is_screening_day_view ...` — but `halted` is still `true` because we never reset it. The condition `not halted` is `false`, so `_maybe_reset_halt` is NEVER called. The halt is **permanent** after the first portfolio-floor fire.

Reading `_maybe_reset_halt` more carefully: it is gated on `(not halted) && _is_screening_day_view`. After the halt fires, `halted` is `true` on every subsequent Friday, so the reset branch is never reached. The halt is therefore irreversibly latched. This contradicts the .mli claim:

> "halt new entries until macro flips off Bearish"

and the PR body claim:

> "When this fires, all positions close and new entries halt until macro flips."

**This is a genuine domain bug** (or at minimum a contract violation), not just missing tests. The latch is permanent. To fix the contract, the macro check must either (a) run the screener even when halted (just to refresh `prior_macro` and consider resuming), or (b) consult macro state outside the screener (e.g. read it via a separate cheap path). As written, once portfolio-floor fires, the strategy never re-enters for the rest of the run.

## Quality Score

2 — Halt-and-resume macro-flip recovery is permanently latched (contract violation vs. .mli + PR body claims); CP4 guards are unpinned (5 explicit guards including `cost_basis ≤ 0`, non-Holding positions, missing prices, double-exit avoidance, and the halt-resume path); CP2 trades.csv exit-trigger override is unpinned end-to-end. The unit-level `Force_liquidation` math is well-tested and clean — the score is dragged down by the integration-side gaps and the latch bug.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### B1: Halt state never resets after portfolio-floor fires (permanent latch)

- Finding: `_maybe_reset_halt` is gated by `(not halted) && _is_screening_day_view`. Once `Peak_tracker.mark_halted` fires (portfolio-floor breach), `halt_state = Halted` is set. On every subsequent Friday, line 462-468 short-circuits to `entry_transitions = []` (correct — block entries) AND `prior_macro` is never updated because `_run_screen` does not run AND `_maybe_reset_halt` is never called because `not halted` is false. The halt is irreversibly latched: no path resets `halt_state` back to `Active` once it has been flipped.
- Location:
  - `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` lines 462-473 (entry-block conditional + `_maybe_reset_halt` gate)
  - `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` line 397-402 (`_maybe_reset_halt` definition)
- Authority:
  - `force_liquidation.mli` lines 64-65: "Portfolio-floor threshold exceeded — all open positions are closed and new entries are halted **until macro flips**"
  - `force_liquidation_runner.mli` lines 16-17: "The [Halted] state in the [peak_tracker] is consulted by the strategy to suppress new entries **until macro flips off Bearish**"
  - PR body / commit message: "all positions close and new entries halt **until macro flips**"
- Required fix: One of:
  - (a) Always update `prior_macro` on Friday (run the macro-only path even when halted), then reset the halt before deciding whether to invoke the full cascade.
  - (b) Move the `_maybe_reset_halt` call to BEFORE the entry-block conditional, with logic that re-runs at least the macro analyzer (cheap path) to refresh `prior_macro` regardless of halt state.
  - (c) Add an explicit time-based or bar-count grace (less consistent with the macro-flip claim — only acceptable if the contract is rewritten).
  - The contract claim in the .mli must match the implementation. Either fix the implementation or revise the docstring to say "halted permanently for the remainder of the run."
- harness_gap: ONGOING_REVIEW — this requires inferential interpretation of strategy-state composition (multi-step interaction between `_run_screen`, `_maybe_reset_halt`, and the halt-block). A linter on data shapes won't catch it; a behavioral test that fires the floor + flips macro + asserts entries resume would.

### B2: Trades.csv exit-trigger override (`force_liquidation_position` / `force_liquidation_portfolio`) is unpinned end-to-end

- Finding: `_force_liq_label` and `_build_force_liq_index` produce the strings only at runtime; no test verifies the substitution actually happens in `trades.csv`. The PR body and commit message both claim "ForceLiquidation audit record visible in trades.csv with distinct exit_trigger".
- Location: `trading/trading/backtest/lib/result_writer.ml` lines 67-78, 104-118
- Authority: PR body §"Audit Recorder" / "Trades.csv exit-trigger column overrides" + dev/notes/short-side-gaps-2026-04-29.md §G4 ("These records must surface in `trades.csv` (with a distinct `exit_trigger`)")
- Required fix: Add a test that constructs a synthetic `Runner.result` with one or two `Force_liquidation.event`s + matching `Metrics.trade_metrics`, calls `Result_writer.write` (or the relevant sub-helper), reads back the on-disk `trades.csv`, and asserts the row's `exit_trigger` column is `force_liquidation_position` / `force_liquidation_portfolio` (one test per reason). Also pin that an event with a non-matching `(symbol, exit_date)` does NOT override the row.
- harness_gap: LINTER_CANDIDATE — golden-scenario test with deterministic fixture (synthetic events + trades) would deterministically pin the trades.csv override.

### B3: CP4 guards unpinned (5 explicit defensive comments without tests)

- Finding: The implementation calls out five guards in docstrings/comments that are not exercised by any test:
  1. `force_liquidation.ml:198-199` "Cost basis must be strictly positive — degenerate inputs (zero-cost basis) are not flagged" — no test for `entry_price = 0` or `quantity = 0`.
  2. `force_liquidation_runner.ml:11-12` "Returns [None] for non-Holding positions and for symbols without a price feed" — no test for `Entering` / `Exiting` / `Closed` positions or for missing-price (`get_price` returns `None`).
  3. `weinstein_strategy.ml:373-377` `_positions_minus_exited` "a position that already received a stop-out exit transition this tick must NOT be double-exited via force-liquidation" — no test that constructs an exit transition from `Stops_runner` and a force-liquidation candidate for the same position and asserts force-liquidation does not re-exit.
  4. `weinstein_strategy.ml:454-460` "New entries are blocked entirely while the halt is active" — no test for the entry-block conditional.
  5. `weinstein_strategy.ml:393-402` `_maybe_reset_halt` macro-flip semantics — no test (and see B1 — this also has a correctness bug).
- Location: as listed above.
- Authority: Each guard is a docstring claim attached to a specific code path; per qc-behavioral-authority.md, "Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario."
- Required fix: Add five tests (one per guard). For (1) a unit test in `test_force_liquidation.ml` with `entry_price = 0.0` confirming no event fires. For (2) two tests in `test_force_liquidation_runner.ml`: one with a `Closed` (or `Entering`) position confirming no event fires; one with `get_price = fun _ -> None` confirming no event fires. For (3) a test in `test_force_liquidation_runner.ml` that passes an existing exit transition for the same position and asserts the runner does not emit another. For (4) and (5) integration-style tests on `Weinstein_strategy.make`'s `on_market_close` exercising the halt → flip → resume sequence (fixes B1 simultaneously).
- harness_gap: LINTER_CANDIDATE for guards (1)–(3) (deterministic golden inputs); ONGOING_REVIEW for (4)–(5) (multi-step state composition).

### B4: Force_liquidation_log persistence claims unpinned

- Finding: `Force_liquidation_log.events` (sorting), `count`, `save_sexp` (no-op-when-empty contract), and `load_sexp` (round-trip inverse) are all explicit `.mli` claims with no corresponding test. The unit-level `test_event_sexp_round_trip` exists for a single `Force_liquidation.event` value but does not exercise the collector / artefact wrapper.
- Location: `trading/trading/backtest/lib/force_liquidation_log.mli` (entire interface) and `force_liquidation_log.ml`
- Authority: qc-behavioral-authority CP1 — "each non-trivial .mli claim has a test pin"
- Required fix: Add `test_force_liquidation_log.ml` (or extend an existing backtest test file) covering: (a) `events` returns sorted-by-`(date, position_id)` order even when records arrive out of order; (b) `count` matches `List.length (events t)`; (c) `save_sexp` of an empty collector produces no file; (d) `save_sexp` + `load_sexp` round-trips multi-event collectors faithfully.
- harness_gap: LINTER_CANDIDATE — straight golden serialization test.
