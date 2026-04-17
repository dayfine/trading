# Plan: support-floor-based stops (2026-04-16)

Track: [support-floor-stops](../status/support-floor-stops.md)
Branch: `feat/support-floor-stops`

## Context

Today's `Weinstein_stops.compute_initial_stop` accepts a `reference_level`
parameter which the caller (`Weinstein_strategy._make_entry_transition`)
currently derives via a fixed-buffer proxy:

```ocaml
let initial_stop =
  Weinstein_stops.compute_initial_stop ~config:config.stops_config
    ~side:Trading_base.Types.Long
    ~reference_level:(cand.suggested_stop *. config.initial_stop_buffer)
```

That proxy — `suggested_stop *. initial_stop_buffer` — is a coarse placeholder.
Weinstein Ch. 6 §5.1 is explicit:

> Place below the significant support floor (prior correction low) BEFORE the breakout.

This track replaces the proxy with a real primitive that walks recent price
history, identifies the prior correction low, and returns it when the pullback
depth is meaningful (default 8%, per Ch. 6). The existing state machine
(Initial → Trailing → Tightened) is untouched.

Downstream, `feat-backtest` is blocked on this primitive to run the
fixed-buffer vs support-floor experiment on the golden scenarios
(see `dev/status/backtest-infra.md`).

## Approach

### Module shape

New module `Support_floor` in `trading/trading/weinstein/stops/lib/`, exposing:

```ocaml
val find_recent_low :
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  min_pullback_pct:float ->
  lookback_bars:int ->
  float option
```

- `bars` are daily bars in chronological order (oldest first — matching
  `Bar_history.t`). The function slices them to bars with date ≤ `as_of`,
  then takes the last `lookback_bars` of that slice.
- Identifies the **highest high** in the window as the "peak".
- Identifies the **lowest low** among bars strictly **after** the peak bar
  (i.e. the drawdown that followed the peak), extending through `as_of`.
- Returns `Some low` when `(peak_high - low) / peak_high >= min_pullback_pct`.
- Returns `None` when:
  - the slice is empty (no bars at or before `as_of`),
  - the peak is at the last bar (no bars after it — no pullback has occurred yet),
  - the depth threshold is not met.

Tie-breaking: if multiple bars share the same high, the **latest** peak date
is used (conservative — ensures the "pullback" is strictly the decline that
followed the most recent extreme). If multiple bars share the same low after
the peak, the first one wins (doesn't matter — only the float value is returned).

### Rationale for highest-high-then-lowest-low

Alternatives considered:

1. **Scan for local peaks** (a bar whose high exceeds `k` neighbours on each side)
   and then find the lowest low between the latest such peak and `as_of`. More
   faithful to "prior peak" intuition, but adds a `k`-parameter and depends on
   bar granularity. Overkill for a weekly-entry use case where we only care about
   the deepest recent pullback, not multi-peak topography.

2. **Lowest low in window**, period, regardless of peak. Too loose — would return
   a low from a prior uptrend rather than a drawdown, and the depth threshold
   would fire against noise rather than a real correction.

The chosen "highest-high then lowest-low-after" approach captures the single
most recent significant drawdown, which is what §5.1 refers to as "the significant
support floor." It's O(n) and parameter-free beyond the two documented knobs.

### Wiring into `compute_initial_stop`

Add a thin wrapper:

```ocaml
val compute_initial_stop_with_floor :
  config:config ->
  side:position_side ->
  entry_price:float ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  fallback_buffer:float ->
  stop_state
```

- When `Support_floor.find_recent_low` returns `Some floor`, call
  `compute_initial_stop` with `reference_level = floor`.
- When it returns `None`, call `compute_initial_stop` with
  `reference_level = entry_price *. fallback_buffer` — behaviour identical to
  today's call site.
- The existing `compute_initial_stop` keeps its signature unchanged.
- `min_pullback_pct` and `lookback_bars` read from `stops_config` (add fields
  to `config` with defaults matching Weinstein book: 0.08 and 52 weeks ≈ 260
  trading days; but we'll use a sensible default like 60 or 90 bars to match
  what `Bar_history` typically accumulates at entry time).

Actually — to keep the wrapper minimal and keep all config in one place, I'll
add `support_floor_lookback_bars` and reuse `min_correction_pct` (already in
`config`, value 0.08) as `min_pullback_pct`. Weinstein's 8% rule is the same
concept in both places; using two independent knobs would be a refactor hazard.

### Callers

The `weinstein_strategy.ml` call site swaps from `compute_initial_stop` to
`compute_initial_stop_with_floor`, passing the accumulated bar history for the
candidate ticker. No changes to the state machine, screener, portfolio_risk,
order_gen, or trading_state.

## Files to change

| File | Purpose |
|---|---|
| `trading/trading/weinstein/stops/lib/support_floor.mli` | new — interface for `find_recent_low` |
| `trading/trading/weinstein/stops/lib/support_floor.ml` | new — implementation |
| `trading/trading/weinstein/stops/lib/stop_types.mli` | add `support_floor_lookback_bars` to `config` |
| `trading/trading/weinstein/stops/lib/stop_types.ml` | update `default_config` |
| `trading/trading/weinstein/stops/lib/weinstein_stops.mli` | expose `compute_initial_stop_with_floor` |
| `trading/trading/weinstein/stops/lib/weinstein_stops.ml` | implement wrapper |
| `trading/trading/weinstein/stops/test/test_support_floor.ml` | new — unit tests |
| `trading/trading/weinstein/stops/test/dune` | add new test binary |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` | swap to `compute_initial_stop_with_floor` at the entry call site (minimal touch) |
| `dev/status/support-floor-stops.md` | status updates |
| `dev/status/_index.md` | row update for this track |

## Risks / unknowns

- **Empty bars**: returns `None` — caller falls back to fixed buffer. Verified
  by unit test.
- **Single bar**: peak = only bar, no bars after → `None`. Verified by unit
  test.
- **Monotonic advance with no pullback**: highest high is the last bar → `None`.
  Verified by unit test.
- **Multiple equal highs / equal lows**: latest high wins; first-encountered low
  wins (irrelevant — float value is the same). Documented.
- **`as_of` before all bars**: slice empty → `None`. Documented.
- **`lookback_bars <= 0`**: undefined; we'll treat as "no bars considered" → `None`.
- **Stops config change is additive**: new field has a default, no consumer
  breaks.

## Acceptance

Mirrors `.claude/agents/feat-weinstein.md` §Acceptance Checklist:

- [ ] `Support_floor.find_recent_low` implemented with unit tests:
  peak+pullback identification, depth threshold, lookback truncation,
  no-pullback → None, empty bars → None, single bar, monotonic series
- [ ] `Stops.compute_initial_stop_with_floor` accepts bar history; `None`
  path is behaviourally identical to today's fixed-buffer code path
  (unit test compares both outputs for a tickless history)
- [ ] `weinstein_strategy.ml` call site swapped; downstream tests still green
- [ ] `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest`
  passes
- [ ] `dev/lib/run-in-env.sh dune build @fmt` clean
- [ ] No changes to screener, portfolio_risk, order_gen, or trading_state

Smoke check: the strategy's e2e tests (`test_weinstein_strategy`,
`test_stops_runner`, `test_portfolio_risk_e2e`) already feed the strategy
cached-like bar histories. Confirm at least one entry placement runs through
`Support_floor.find_recent_low` returning `Some _` in those fixtures. If none
of the existing fixtures exercise the "support-floor present" path, add a
targeted strategy-level test that seeds bar history with a clear
peak+correction pattern and verifies the initial stop tracks the correction
low rather than `entry_price * fallback_buffer`.

## Out of scope

- **Round-number shading of the support-floor value** (§5.1). The existing
  `nudge_round_number` in `weinstein_stops.ml` already applies to the computed
  stop level; no new nudge layer is added at the support-floor step. Parked in
  status §Follow-ups.
- **Fixed-buffer vs support-floor backtest experiment** — `feat-backtest`'s
  follow-on.
- **Regime-aware buffers** — separate exploration listed in
  `dev/status/backtest-infra.md`.
- **Pinnacle / external data source for synthetic ADL** — already decided
  (synthetic-only) per `dev/decisions.md` 2026-04-16.
- **Weinstein Ch. 6 15% max-risk rejection rule** (§5.1: "If stop requires
  >15% risk from entry → prefer other candidates"). Screener concern, not
  a stop-primitive concern.
