# Short-side strategy — plan 2026-04-18

## Context

The Weinstein strategy (`trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`) currently only emits long-side entries:

- Line ~84: `_make_entry_transition` hardcodes `~side:Trading_base.Types.Long` both when computing the initial stop via `Weinstein_stops.compute_initial_stop_with_floor` and when constructing the `CreateEntering` transition.
- Line ~220: the macro-trend branch in `_run_screen` short-circuits on `Bearish` with `[]` — the strategy never looks at the screener's `short_candidates`.

Everything downstream already supports shorts:

- `Trading_base.Types.position_side = Long | Short` (types.ml:14).
- `Position.CreateEntering { side; ... }` carries the side already (position.ml).
- `simulation/lib/order_generator.ml:9-18` already has `_entry_order_side` and `_exit_order_side` cases for `Short` (Sell on entry, Buy to cover on exit).
- `Weinstein_stops.compute_initial_stop_with_floor ~side` is symmetric (PR #382 landed support for short — resistance ceiling feeds stops).
- `Portfolio_risk.snapshot` already splits `long_exposure` / `short_exposure`.
- `Screener._evaluate_shorts` (screener.ml:367) already produces `short_candidates` and is gated on `macro_trend ∈ {Bearish, Neutral}`.

So the gap is isolated to the strategy entry path and the screener candidate record: **which side a candidate belongs to is implicit today** (two separate lists `buy_candidates` and `short_candidates`) and the strategy's entry generator assumes Long.

## Approach

Additive, side-parameterised, defaults preserve long-side behaviour.

### 1. Tag each `scored_candidate` with its side

Add `side : Trading_base.Types.position_side` to `Screener.scored_candidate`. Populated in `_build_candidate` from the `is_short` flag — both `_long_candidate` and `_short_candidate` already thread this. Callers reading `buy_candidates`/`short_candidates` continue to work; the added field is purely informational until the strategy consumes it. Screener tests only assert on `.ticker`, so the addition is backwards-compatible.

### 2. Parameterise `_make_entry_transition` by the candidate's side

Replace the two hardcoded `Long` uses in `_make_entry_transition` with `cand.side`. Thread the side into both:

- `Weinstein_stops.compute_initial_stop_with_floor ~side:cand.side`
- `Position.CreateEntering { side = cand.side; ... }`

`Portfolio_risk.compute_position_size` uses `risk_per_share = entry - stop`. For a long, stop < entry, so positive. For a short, stop > entry, so we need absolute value there. Fix the helper in weinstein_strategy (or add a wrapper) that takes `|entry - stop|` before passing to sizing — or call sizing with the correct semantics. Simplest is: keep `compute_position_size` as-is (positive risk_per_share contract preserved) and have `_make_entry_transition` pass `|cand.suggested_entry - cand.suggested_stop|` values in the order the sizer expects. Since `Portfolio_risk.compute_position_size` is a public API consumed elsewhere, I won't change its contract — I'll adapt inside the strategy.

Plan: at the call site, swap so that for shorts, `~entry_price = cand.suggested_entry` but `~stop_price` is called with a synthetic value such that `entry - stop > 0`. Equivalently: pass `~entry_price:(max entry stop)` and `~stop_price:(min entry stop)` — same dollar-risk-per-share, same share count. Document this adapter inline.

### 3. Feed short candidates through the Bearish branch

In `_run_screen`, replace `if prior_macro = Bearish then []` with: under `Bearish`, compute the screener, take `short_candidates`, flow through `_entries_from_candidates`. Under `Neutral`, take both `buy_candidates` and `short_candidates`. Under `Bullish`, only `buy_candidates` (matches today's behaviour).

This preserves today's exact behaviour under `Bullish` and under `Bearish` when the screener finds no shorts. The macro-branch change is:

```
match macro_trend with
| Bullish -> screen-and-return buy_candidates
| Neutral -> screen-and-return buy_candidates @ short_candidates
| Bearish -> screen-and-return short_candidates
```

The screener itself already gates by macro; we can just concatenate `buy_candidates @ short_candidates` and let the screener's own macro logic drop the empty list. Simpler and keeps the macro-gating in one place.

### 4. Short-side screener rules (Ch. 11 — minimal)

`_short_candidate` already checks `Stage4` breakdown (via `is_breakdown_candidate`) and the sector gate rejects Strong sectors. `_rs_short_signal` rewards `Bearish_crossover`, `Negative_declining`, `Negative_improving`. Chapter 11 rule "NEVER short a stock with strong RS" — today the screener has no **hard gate** on RS sign for shorts; the scorer rewards negative RS but doesn't exclude positive RS. For this session, in `_short_candidate`, add a **hard gate** that rejects candidates whose RS trend is positive (`Positive_rising`, `Positive_flat`, `Bullish_crossover`). That encodes the Ch. 11 "never short strong RS" rule as a filter rather than only a score penalty.

### 5. Portfolio risk limits — verify short signed exposure

`Portfolio_risk.snapshot` already tracks `short_exposure` as absolute value and `check_limits` routes `\`Short` → `max_short_exposure_pct`. The strategy doesn't currently call `check_limits` in `_make_entry_transition` — only `compute_position_size`. This is consistent with current long-side behaviour (no limit check at entry emission — simulator constraints handle it). Out of scope for this PR to add a check; note in status file as a follow-up.

### 6. Unit test: end-to-end short entry under Bearish macro

Add a test in `test_weinstein_strategy.ml` that:

1. Configures the strategy with a universe containing one synthetic Stage-4 stock.
2. Feeds bars that establish: primary index in Stage 4 (drives Bearish macro), sector ETF weak, ticker in Stage 4 with negative RS.
3. Runs `on_market_close` on a Friday.
4. Asserts at least one `CreateEntering` transition with `side = Short`.

This test will be fiddly (requires producing the right market state to make `Macro.analyze` return `Bearish` and the stock's `Stock_analysis.analyze` return a Stage-4 breakdown candidate). The test may need synthetic bar construction helpers; if it proves too unwieldy in one session, the fallback is a narrower unit test: seed a screener result directly into a new test entry point. Prefer the end-to-end path; fall back only if necessary.

## Files to change

1. **`trading/analysis/weinstein/screener/lib/screener.mli`** — add `side : Trading_base.Types.position_side` to `scored_candidate`.
2. **`trading/analysis/weinstein/screener/lib/screener.ml`** — populate `side` in `_build_candidate` (map `is_short:true`→`Short`, else `Long`). Add hard-gate on positive RS in `_short_candidate`.
3. **`trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`**:
   - `_make_entry_transition`: thread `cand.side` through stop computation and `CreateEntering`.
   - Adapter: normalise entry/stop for `compute_position_size` so risk_per_share is always positive.
   - `_run_screen` Bearish branch: replace `[]` with `buy_candidates @ short_candidates` (concatenated, macro-gated by screener).
   - `_entries_from_candidates` / `_screen_universe` signature unchanged — they just handle one combined list.
4. **`trading/trading/weinstein/strategy/test/test_weinstein_strategy.ml`** — add end-to-end short-entry test.
5. **`dev/status/short-side-strategy.md`** — PENDING → IN_PROGRESS (session end: READY_FOR_REVIEW).

No changes to:
- `Portfolio_risk` (short paths already present and correct).
- `order_generator` (`_entry_order_side`/`_exit_order_side` for `Short` already handle Sell/Buy).
- `Weinstein_stops` / `Support_floor` (already side-parameterised).
- `Position` / `Portfolio` / `Engine` / `Simulator`.

## Risks / unknowns

- **Short-entry end-to-end test instability.** Driving `Macro.analyze` to `Bearish` from bar data alone is non-trivial (needs the right AD/breadth inputs which the test helpers don't easily produce). Mitigation: if the end-to-end test is too large for this session, add a narrower test that exercises `_make_entry_transition` directly with a synthetic `Screener.scored_candidate` where `side = Short`, and leave the macro-level integration test as follow-up.
- **Portfolio risk sizing for shorts.** The `entry - stop` swap for shorts is a small adapter. It's tempting to change `compute_position_size` itself but that would ripple into existing tests. Keep the fix localised.
- **RS hard gate in screener.** Adding a hard filter could drop today's short candidates that previously still scored (e.g. Negative_improving — which is still technically "RS negative"). Mitigation: only reject *positive* RS (`Positive_rising`, `Positive_flat`, `Bullish_crossover`); keep `Negative_improving` eligible. Cross-check existing screener tests — no short-candidate test currently asserts on positive-RS → short eligibility, so this is safe.

## Acceptance criteria

- `Screener.scored_candidate` carries `side : Trading_base.Types.position_side`; all existing `_long_candidate` call sites produce `Long`, `_short_candidate` produces `Short`.
- `_make_entry_transition` takes side from the candidate; no hardcoded `Trading_base.Types.Long` remains in the entry path.
- `_run_screen`'s Bearish branch no longer unconditionally returns `[]` — it returns short candidates when available.
- Hard RS gate in `_short_candidate` rejects positive-RS stocks per Ch. 11.
- New unit test confirms a short-side `CreateEntering` transition is generated end-to-end (or at minimum via `_make_entry_transition` with a synthetic `Screener.scored_candidate { side = Short; ... }` — fallback scope if macro-driven e2e is too large for one session).
- `dev/lib/run-in-env.sh dune build @runtest` passes.
- `dune build @fmt` passes.
- All prior long-side behaviour preserved (all existing strategy + screener tests still pass).
- `dev/status/short-side-strategy.md` reflects current state (IN_PROGRESS or READY_FOR_REVIEW).

## Out of scope

- Bear-window backtest regression pins (scope item 6) — follow-up track.
- Signed-exposure `check_limits` call inside `_make_entry_transition` (current strategy doesn't call this for longs either; keep parity).
- Margin / borrow cost modelling.
- Buy-to-cover trailing stop tuning (already in `Weinstein_stops`).
- Head-and-shoulder top detection (Ch. 11 pattern; separate feature).
- Full Stage-3 distribution detection — `Stock_analysis.is_breakdown_candidate` already covers the minimum.
