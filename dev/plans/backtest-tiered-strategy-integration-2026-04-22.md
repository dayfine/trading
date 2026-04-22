# Plan: strategy ↔ bar_loader integration (tiered-loader track follow-on)

Track: [backtest-scale](../status/backtest-scale.md)
Branch: `feat/backtest-scale-strategy-bar-loader-integration`
Parent plan: `dev/plans/backtest-tiered-loader-2026-04-19.md` §"Integration
point: strategy wrapper"

## Context

The tiered-loader track has landed 3a through 3h: Bar_loader exists, the
Tiered runner path wires Friday Summary-promote and per-transition
Full-promote, the shadow screener adapter is in place, and a nightly
Legacy-vs-Tiered A/B is firing. But today's wrapper only does
tier-bookkeeping — it does not actually change what data the strategy
reads.

Evidence: `trading/trading/backtest/lib/tiered_strategy_wrapper.ml:187-189`
passes `get_price` through to `inner` unchanged. Zero references to
`Bar_loader.{get_full, get_summary, tier_of}` under
`trading/trading/weinstein/`. `Bar_history` grows once per universe symbol
per step regardless of `loader_strategy`. The first nightly A/B
(`run 24761375492`) returned `$0.00` PV deltas on all 3 broad goldens —
unsurprising, since the two paths run bit-identical simulations.

Until this lands, flipping the `loader_strategy` default Legacy → Tiered
is a no-op on memory.

## Goal

Tiered must actually reduce `Bar_history` growth and exercise the
`Bar_loader` Summary / Full tiers for the Weinstein strategy. After the
integration, the inner strategy should only accumulate bars for
Full-tier symbols plus the always-needed macro inputs (primary index,
sector ETFs, global indices). Parity test + nightly A/B must still
report trade-count and PV-delta parity on all three broad goldens —
any divergence is a bug in the integration.

## The landmine the parent plan flagged

`Weinstein_strategy._make_entry_transition` and
`Weinstein_strategy._screen_universe` both pull bars from
`Bar_history.{weekly,daily}_bars_for`. If we throttle the wrapper's
`get_price` to return `None` for non-Full-tier symbols, `Bar_history`
doesn't grow for them — and the Friday a symbol is promoted to Full,
the strategy's own queries against `Bar_history` return zero bars.
Entry sizing and stop placement would fail. Stage classification on
the screener side would return empty, so the inner screener would
produce zero candidates even for symbols the shadow screener just
promoted.

The parent plan asked us to choose between:

- **Option a** — strategy reads `Bar_loader.get_full` directly for
  entry/stops under the Tiered path. Wider strategy change.
- **Option b-seed** — add a `Bar_history.seed` primitive so the wrapper
  can backfill after a Full promote. Strategy unchanged.
- **Option c** — warmup period. Causes trade-count divergence. Do not
  ship.

## Decision: Option b-seed, with one small strategy-interface extension

We pick **b-seed**. Rationale:

- Keeps `Bar_history` as the strategy's single source of truth for daily
  bars. All existing readers
  (`Stops_runner._compute_ma`, `Macro_inputs.build_sector_map`,
  `_screen_universe._analyze_ticker`, `_make_entry_transition`) continue
  to read from `Bar_history`. No strategy-code changes per call site.
- One new additive primitive (`Bar_history.seed`) rather than multi-site
  surgery inside the strategy.
- Diagnosing parity divergence is cheaper: seed writes deterministic
  CSV-derived data into the same buffer `accumulate` would have grown.

Because the wrapper needs to seed the strategy's `Bar_history`, we add
one small surface to `Weinstein_strategy.make`: it accepts an optional
`?bar_history:Bar_history.t`, defaulting to a fresh one (current
behavior preserved). The Tiered runner allocates one shared
`Bar_history.t`, passes it to both `make` and the wrapper. The wrapper
owns seeding; the strategy reads. This is the minimum plumbing needed
to make b-seed reach the strategy's closure.

### Rejected: Option (a)

Embedding `Bar_loader.get_full` lookups into `Weinstein_strategy`
spreads the Tiered data path through strategy code that today knows
nothing about tiering. It also means the strategy's parity semantics
diverge between Legacy and Tiered at more call sites — every reader
(`Stops_runner`, `Macro_inputs`, `_make_entry_transition`,
`_screen_universe`) would need a Tiered branch. That's a wider surface
for bugs and a wider diff for QC to read.

### Rejected: Option (c)

A warmup period where Tiered waits N days before trading would produce
fewer trades than Legacy. Parity test is a hard gate — ship-stopper.

## The throttled get_price contract

The wrapper constructs a filtered `get_price'` that wraps the
simulator's `get_price`:

```
get_price' sym =
  if sym ∈ always_loaded then get_price sym
  else if tier_of loader ~sym = Some Full_tier then get_price sym
  else if sym ∈ held_symbols portfolio then get_price sym
  else None
```

`always_loaded` is the set of symbols the strategy structurally needs
every day regardless of tier:

- `config.indices.primary` (required for day-of-week detection + macro)
- all `config.sector_etfs` keys (sector map build on Fridays)
- all `config.indices.global` keys (global consensus signal)

These are at most ~15 symbols — not a memory concern.

Held positions pass through unconditionally so the stops runner always
sees today's bar for every live position. In practice every held
position is also at Full tier (we promote on `CreateEntering`), so this
is belt-and-braces; it prevents a divergence where a symbol's tier
state is out-of-sync with the portfolio.

`Bar_history.accumulate` iterates `_all_accumulated_symbols` and writes
a new entry iff `get_price` returns `Some bar`. Under the throttle, the
inner strategy's accumulate walks the full list but only writes for
always-loaded + Full + held. The hashtable entries for Metadata /
Summary-only symbols stay absent.

## The seed API

```ocaml
val seed :
  t ->
  symbol:string ->
  bars:Types.Daily_price.t list ->
  unit
```

`seed t ~symbol ~bars` merges `bars` into `t`'s history for `symbol`:

- If `symbol` has no prior history, `bars` becomes the whole history.
- If `symbol` has history ending on date `d_last`, only bars with
  `bar.date > d_last` are appended.

This matches the idempotency contract `accumulate` already has. It's
valid to call `seed` repeatedly — a second call with the same bars is
a no-op.

Implementation note: `Full.t.bars` from `Bar_loader.get_full` already
covers a long tail (1800 days by default), so a single `seed` call
after promotion gives the strategy a complete history up to `as_of`.

## Integration: wrapper flow per call

The wrapper's `_on_market_close_wrapped` gains a seed step and reorders
Friday work. New flow:

1. **Pre-inner (Friday only):** promote universe to Summary, run Shadow
   screener, promote top-N to Full, **seed `bar_history` from each
   newly-Full symbol's `Bar_loader.get_full.bars`**. This guarantees
   inner's `_screen_universe` sees weekly bars for every Full-tier
   symbol — the same weekly bars Legacy would have accumulated over
   the warmup window.
2. **Pre-inner (every day):** construct the throttled `get_price'`
   from the current tier state + held positions.
3. **Inner:** delegate to `inner.on_market_close` with `get_price'`
   instead of `get_price`.
4. **Post-inner (every day):** stop-log capture, per-Closed demote.
5. **Post-inner:** per-CreateEntering promote to Full **and seed
   `bar_history`** with the Full bars so the next day's stops runner
   sees a populated buffer.
6. Update prior-positions snapshot.

The Friday cycle moves from post-inner to pre-inner (step 1). Today's
wrapper runs it post-inner. Moving it pre-inner is necessary so the
inner screener can see the Full-tier bars on the same day as the
promote. The result is still pure bookkeeping with respect to the
inner strategy's own transition output.

## Parity expectations

The goal is trade-count identity on the parity scenario and PV delta
inside the warn threshold (`max($1.00, 0.001% of final PV)`) on the
three broad goldens.

The remaining risk is that the **Shadow screener's Full-promote set
differs from Legacy's candidate set**. The shadow screener applies the
same `is_breakout_candidate` gate as Legacy (Stage + volume + RS), so
in principle a symbol Legacy would admit must also land in shadow's
candidate list. Known divergences documented in
`shadow_screener.mli`:

- Volume is always synthesized as `Adequate 1.5` — shadow is strictly
  **more liberal** on the volume axis (it never rejects for missing
  volume). Legacy can reject a candidate for `volume = None`.
- Resistance bonus absent — affects scoring, not gating.
- RS crossover bonus absent — affects scoring, not gating.

The gating divergence is asymmetric in our favor: shadow admits a
**superset** of Legacy's gate-passers. Inner's fresh
`Stock_analysis.analyze` on seeded bars then re-filters that superset
with Legacy's stricter gate, and the final candidate list matches
Legacy's. Provided the shadow → full-promote set is large enough to
include everything Legacy would have admitted, parity holds.

On the parity-7sym fixture this is trivially true — a 7-symbol
universe fits inside the `full_candidate_limit` (`max_buy + max_short =
5 + 5 = 10` by default). All 7 symbols get Full-promoted every Friday,
so inner sees identical data to Legacy.

On broad goldens the risk is concrete: if `full_candidate_limit` is
below the number of symbols Legacy would admit, some candidates will
be culled. The first nightly A/B is the definitive data point; if
parity breaks we raise the limit or rethink.

## Files to change

### New

- `trading/trading/weinstein/strategy/lib/bar_history.{ml,mli}` —
  extend with `seed` primitive (the module file exists; this is an
  additive API).

### Modified

- `trading/trading/weinstein/strategy/lib/weinstein_strategy.{ml,mli}`
  — `make` gains optional `?bar_history:Bar_history.t`. Behaviour
  preserved when absent.
- `trading/trading/backtest/lib/tiered_strategy_wrapper.{ml,mli}` —
  wrapper config gains `bar_history`, `always_loaded_symbols`. `wrap`
  constructs the throttled `get_price'`, reorders Friday cycle to
  pre-inner, seeds `bar_history` after Full promotes.
- `trading/trading/backtest/lib/tiered_runner.ml` — allocate shared
  `Bar_history.t`, pass to `Weinstein_strategy.make` and the wrapper
  config. Populate `always_loaded_symbols` from `input.config`.
- `trading/trading/weinstein/strategy/test/test_bar_history.ml` —
  tests for `seed` contract (empty-history seed, merge seed, no-op
  re-seed).
- `trading/trading/backtest/test/test_runner_tiered_cycle.ml` —
  tests for throttle (primary + always-loaded pass through, Full
  passes, Metadata blocks; held overrides Metadata).

## Risks / unknowns

1. **Shadow promote set size.** If the shadow screener admits more
   candidates than `full_candidate_limit` (currently
   `max_buy_candidates + max_short_candidates` = 10), some get culled.
   Legacy would have screened all of them. On the parity 7-symbol
   universe this is impossible; on broad goldens it's the main
   parity-break candidate. **Mitigation:** if local parity fails,
   raise the limit or remove the cap on Friday Full promotions
   (re-demote next week).

2. **Seed timing.** Inner's `_all_accumulated_symbols` iteration is
   the only call-site that writes to `Bar_history`. Under the
   throttle, only always-loaded + Full + held symbols get appended.
   If we seed AFTER inner runs (on a CreateEntering), the strategy's
   next-day stops runner sees seeded data correctly. The Friday
   pre-inner seed covers the screener path. This ordering matches
   the design and has no race.

3. **Held-position pass-through correctness.** A symbol that's held
   but not at Full tier would happen only if promotion failed or the
   wrapper's bookkeeping drifted. The passthrough is defensive.

4. **`Bar_history.seed` + `accumulate` ordering.** After seed, later
   accumulate calls (for the same symbol, on subsequent days) must
   append new bars cleanly. The `_is_new_bar` check inside
   `accumulate` already handles this: a seeded bar ending on date `d`
   means future accumulates append only bars with date `> d`.

5. **Test fixture coverage.** The unit tests drive the wrapper with
   a stub strategy — they observe throttle + seed via trace phase
   counts, not via real bar queries. Real parity behaviour is the
   job of `test_tiered_loader_parity` and the nightly A/B.

## Acceptance criteria

- [ ] `Bar_history.seed` lands with unit tests covering empty-history,
  merge, and idempotent re-seed.
- [ ] Tiered path accumulates bars **only** for always-loaded + Full
  + held symbols (pinned by a wrapper unit test).
- [ ] `dune build && dune runtest` passes with zero warnings.
- [ ] `dune build @fmt` clean.
- [ ] `test_tiered_loader_parity` still passes — trade count
  identical, sampled step PVs within $0.01, final PV within $0.01.
- [ ] Local A/B via `dev/scripts/tiered_loader_ab_compare.sh` against
  each of the three broad goldens: trade counts identical, PV delta
  inside warn threshold.
- [ ] `dev/status/backtest-scale.md` updated: record that the
  integration lands on this branch and identify the default-flip PR
  as the next step.
- [ ] PR body states which option was chosen and shows local parity
  evidence.

## Out of scope

- Flipping `loader_strategy` default Legacy → Tiered. Separate
  follow-up PR.
- Retiring `_run_legacy`. Post-flip cleanup.
- Changing `Price_cache`, `Simulator`, or `Backtest.Runner`'s Legacy
  path.
- Changing the shadow screener's output format or parity test
  assertions.
- Changing `Weinstein_strategy` internals beyond the optional
  `?bar_history` parameter on `make`.
- Native Summary-driven screener (plan §Open questions #3 —
  deferred).
